extends Node

## 云同步状态管理单例（Data Autoload）
## 负责变更追踪、push/pull/full 同步、设备注册、ID 映射
## 支持增量同步（task/note/category）和全量 bundle 同步（habit/achievement/level/room_decor/stats）

# --- 信号 ---
signal sync_started
signal sync_completed(success: bool, summary: Dictionary)
signal sync_error(message: String)
signal device_registered(device_id: String)

# --- 配置常量 ---
const SYNC_DATA_PATH = "user://sync_data.json"
const SYNC_CHANGES_PATH = "user://sync_changes.json"
const AUTO_SYNC_INTERVAL = 120.0  # 2 分钟自动同步
const DEBOUNCE_DELAY = 5.0        # 5 秒防抖
const MAX_CONSECUTIVE_FAILURES = 5
const MAX_PULL_PAGES = 10

# --- 内部状态 ---
var _device_id: String = ""
var _last_sync_time: int = 0      # 上次成功同步的 server_time（毫秒）
var _change_queue: Array = []     # Array[SyncChange]
var _is_syncing: bool = false
var _is_applying_remote: bool = false
var _is_registered: bool = false
var _id_mapping: IdMapping = null
var _auto_sync_timer: Timer = null
var _debounce_timer: Timer = null
var _consecutive_failures: int = 0
var _task_server_hints: Dictionary = {}
var _note_server_hints: Dictionary = {}
var _category_server_hints: Dictionary = {}
var _last_push_summary: Dictionary = {}
var _last_pull_summary: Dictionary = {}

# 全量同步 bundle 注册表
# key: bundle_type, value: { "export": Callable, "merge": Callable }
var _full_sync_bundles: Dictionary = {}
# bundle 脏标记（数据变更时标记，push 后清除）
var _bundle_dirty: Dictionary = {}


func _ready() -> void:
	_id_mapping = IdMapping.new()

	# 加载持久化数据
	_load_sync_data()
	_load_change_queue()
	_id_mapping.load_from_file()

	# 创建定时器
	_auto_sync_timer = Timer.new()
	_auto_sync_timer.wait_time = AUTO_SYNC_INTERVAL
	_auto_sync_timer.autostart = false
	_auto_sync_timer.timeout.connect(_on_auto_sync_timeout)
	add_child(_auto_sync_timer)

	_debounce_timer = Timer.new()
	_debounce_timer.wait_time = DEBOUNCE_DELAY
	_debounce_timer.one_shot = true
	_debounce_timer.autostart = false
	_debounce_timer.timeout.connect(_on_debounce_timeout)
	add_child(_debounce_timer)

	# 连接 AuthState 信号
	AuthState.auth_state_changed.connect(_on_auth_state_changed)

	# 连接 TaskState 信号
	TaskState.task_added.connect(_on_task_added)
	TaskState.task_removed.connect(_on_task_removed)
	TaskState.task_updated.connect(_on_task_updated)
	TaskState.task_state_changed.connect(_on_task_state_changed)
	TaskState.tasks_reordered.connect(_on_tasks_reordered)

	# 连接 NoteState 信号
	NoteState.note_added.connect(_on_note_added)
	NoteState.note_removed.connect(_on_note_removed)
	NoteState.note_updated.connect(_on_note_updated)
	NoteState.category_added.connect(_on_category_added)
	NoteState.category_removed.connect(_on_category_removed)

	# 注册全量同步 bundles 并连接脏标记信号
	_register_full_sync_bundles()
	_connect_bundle_dirty_signals()
	_rebuild_sync_hints()

	# 如果已登录，延迟触发同步启动（AuthState 的信号在 SyncState 初始化前已发射）
	if AuthState.is_logged_in():
		call_deferred("_deferred_login_sync")

	print("[SyncState] 初始化完成, device_id=%s, registered=%s" % [_device_id, _is_registered])


# ======================== Bundle 注册与脏标记 ========================

func _register_full_sync_bundles() -> void:
	_register_bundle("habit_bundle", HabitState, "export_data", "import_sync_data")
	_register_bundle("achievement_bundle", AchievementState, "export_data", "import_sync_data")
	_register_bundle("level", LevelState, "export_data", "import_sync_data")
	_register_bundle("room_decor_bundle", RoomDecorState, "export_data", "import_sync_data")
	_register_bundle("stats_bundle", StatsState, "export_data", "import_sync_data")


func _register_bundle(bundle_type: String, state_node: Node, export_method: String, merge_method: String) -> void:
	if state_node == null:
		push_warning("[SyncState] 无法注册 bundle '%s': State 节点为空" % bundle_type)
		return
	_full_sync_bundles[bundle_type] = {
		"export": Callable(state_node, export_method),
		"merge": Callable(state_node, merge_method),
	}
	_bundle_dirty[bundle_type] = false


func _connect_bundle_dirty_signals() -> void:
	# HabitState
	if HabitState:
		HabitState.habit_added.connect(_on_bundle_dirty.bind("habit_bundle"))
		HabitState.habit_removed.connect(_on_bundle_dirty.bind("habit_bundle"))
		HabitState.habit_updated.connect(_on_bundle_dirty.bind("habit_bundle"))
		HabitState.schedule_updated.connect(_on_bundle_dirty.bind("habit_bundle"))
		HabitState.execution_updated.connect(_on_bundle_dirty.bind("habit_bundle"))
	# AchievementState
	if AchievementState:
		AchievementState.daily_task_state_updated.connect(_on_bundle_dirty.bind("achievement_bundle"))
		AchievementState.daily_task_reward_claimed.connect(_on_bundle_dirty.bind("achievement_bundle"))
		AchievementState.achievement_state_updated.connect(_on_bundle_dirty.bind("achievement_bundle"))
		AchievementState.achievement_reward_claimed.connect(_on_bundle_dirty.bind("achievement_bundle"))
	# LevelState
	if LevelState:
		LevelState.level_state_changed.connect(_on_bundle_dirty.bind("level"))
	# RoomDecorState
	if RoomDecorState:
		RoomDecorState.room_decor_state_changed.connect(_on_bundle_dirty.bind("room_decor_bundle"))
	# StatsState
	if StatsState:
		StatsState.record_added.connect(_on_bundle_dirty.bind("stats_bundle"))
		StatsState.record_removed.connect(_on_bundle_dirty.bind("stats_bundle"))


func _on_bundle_dirty(_arg1 = null, bundle_type: String = "") -> void:
	if _is_applying_remote:
		return
	if bundle_type != "":
		_bundle_dirty[bundle_type] = true


func _has_dirty_bundles() -> bool:
	for bt in _bundle_dirty:
		if _bundle_dirty[bt]:
			return true
	return false


func _push_dirty_bundles() -> void:
	for bundle_type in _bundle_dirty:
		if not _bundle_dirty[bundle_type]:
			continue
		if not _full_sync_bundles.has(bundle_type):
			continue
		var bundle_info = _full_sync_bundles[bundle_type]
		var export_data: Dictionary = bundle_info["export"].call()
		_record_change(SyncChange.new(bundle_type, "full_replace", 0, bundle_type, export_data))
		_bundle_dirty[bundle_type] = false
	print("[SyncState] 已将脏 bundle 加入推送队列")


# ======================== 认证状态响应 ========================

## 延迟启动同步（用于冷启动时 AuthState 信号已错过的场景）
func _rebuild_sync_hints() -> void:
	_task_server_hints.clear()
	for task in TaskState.get_all_tasks():
		_remember_task_sync_hint(task)

	_note_server_hints.clear()
	for note in NoteState.get_all_notes():
		_remember_note_sync_hint(note)

	_category_server_hints.clear()
	for category in NoteState.get_categories():
		_remember_category_sync_hint(category)


func _remember_task_sync_hint(task: TaskData) -> void:
	if task == null:
		return
	var server_id = task.server_id
	if server_id <= 0:
		server_id = _id_mapping.get_server_id("task", str(task.id))
	if server_id > 0:
		_task_server_hints[task.id] = server_id


func _remember_note_sync_hint(note: NoteData) -> void:
	if note == null:
		return
	var server_id = note.server_id
	if server_id <= 0:
		server_id = _id_mapping.get_server_id("note", str(note.id))
	if server_id > 0:
		_note_server_hints[note.id] = server_id


func _remember_category_sync_hint(category: String) -> void:
	if category == "":
		return
	var server_id = _id_mapping.get_server_id("category", category)
	if server_id > 0:
		_category_server_hints[category] = server_id


func _forget_sync_hint(resource: String, local_id: int = 0, local_key: String = "") -> void:
	match resource:
		"task":
			if local_id > 0:
				_task_server_hints.erase(local_id)
		"note":
			if local_id > 0:
				_note_server_hints.erase(local_id)
		"category":
			if local_key != "":
				_category_server_hints.erase(local_key)


func _make_delete_change(resource: String, local_id: int = 0, local_key: String = "") -> SyncChange:
	var data: Dictionary = {}
	var server_id = _resolve_server_id_from_state(resource, local_id, local_key)
	if server_id > 0:
		data["server_id_hint"] = server_id
	print("[SyncState][DeleteTrace] record delete change resource=%s local_id=%d local_key=%s server_id_hint=%d" % [
		resource, local_id, local_key, server_id
	])
	return SyncChange.new(resource, "delete", local_id, local_key, data)


func _deferred_login_sync() -> void:
	if not AuthState.is_logged_in():
		return
	if not _is_registered:
		await register_device()
	if _is_registered:
		_start_auto_sync()
		await do_full_sync()

func _on_auth_state_changed(is_logged_in: bool) -> void:
	if is_logged_in:
		print("[SyncState] 用户已登录，检查设备注册状态")
		if not _is_registered:
			await register_device()
		if _is_registered:
			_start_auto_sync()
			# 登录后执行全量同步
			await do_full_sync()
	else:
		print("[SyncState] 用户已登出")
		# 登出前尝试最后一次 push
		if _is_registered and (_change_queue.size() > 0 or _has_dirty_bundles()):
			if _has_dirty_bundles():
				_push_dirty_bundles()
			await _do_push()
		_stop_auto_sync()
		_reset_sync_state()


# ======================== 设备注册 ========================

func register_device() -> void:
	if not AuthState.is_logged_in():
		push_warning("[SyncState] 未登录，无法注册设备")
		return

	var body = {
		"device_name": "Godot-%s" % OS.get_unique_id().substr(0, 8),
		"device_type": _get_device_type(),
		"client_version": "1.0.0"
	}

	var result = await ApiClient.api_post("/sync/register-device", body)
	if result.success and result.data is Dictionary:
		_device_id = result.data.get("device_id", "")
		_is_registered = true
		_save_sync_data()
		device_registered.emit(_device_id)
		print("[SyncState] 设备注册成功: %s" % _device_id)
	else:
		push_error("[SyncState] 设备注册失败: %s" % result.message)
		sync_error.emit("设备注册失败: %s" % result.message)


# ======================== 变更追踪 ========================

func _on_task_added(task: TaskData) -> void:
	if _is_applying_remote:
		return
	_remember_task_sync_hint(task)
	_record_change(SyncChange.new("task", "create", task.id, str(task.id), {
		"title": task.title,
		"due_timestamp": task.due_timestamp,
		"finish_timestamp": task.finish_timestamp,
		"is_completed": task.is_completed,
		"created_at": task.created_at,
		"position": task.order
	}))

func _on_task_removed(task_id: int) -> void:
	if _is_applying_remote:
		return
	_record_change(_make_delete_change("task", task_id, str(task_id)))

func _on_task_updated(task: TaskData) -> void:
	if _is_applying_remote:
		return
	_remember_task_sync_hint(task)
	_record_change(SyncChange.new("task", "update", task.id, str(task.id), {
		"title": task.title,
		"due_timestamp": task.due_timestamp,
		"is_completed": task.is_completed,
		"finish_timestamp": task.finish_timestamp,
		"updated_at": task.updated_at,
		"position": task.order
	}))

func _on_task_state_changed(task: TaskData) -> void:
	if _is_applying_remote:
		return
	_remember_task_sync_hint(task)
	_record_change(SyncChange.new("task", "update", task.id, str(task.id), {
		"is_completed": task.is_completed,
		"finish_timestamp": task.finish_timestamp,
		"updated_at": task.updated_at,
		"position": task.order
	}))

func _on_tasks_reordered() -> void:
	if _is_applying_remote:
		return
	# 收集所有有映射的 task 的 server_id 排序列表
	var ordered_ids: Array = []
	for task in TaskState.get_all_tasks():
		var sid = _id_mapping.get_server_id("task", str(task.id))
		if sid > 0:
			ordered_ids.append(sid)
	if ordered_ids.size() > 0:
		_record_change(SyncChange.new("task", "reorder", 0, "", {
			"list_type": "all",
			"ordered_ids": ordered_ids
		}))

func _on_note_added(note: NoteData) -> void:
	if _is_applying_remote:
		return
	_remember_note_sync_hint(note)
	_record_change(SyncChange.new("note", "create", note.id, str(note.id), {
		"title": note.title,
		"content": note.content,
		"created_at": note.created_at,
	}))

func _on_note_removed(note_id: int) -> void:
	if _is_applying_remote:
		return
	_record_change(_make_delete_change("note", note_id, str(note_id)))

func _on_note_updated(note: NoteData) -> void:
	if _is_applying_remote:
		return
	_remember_note_sync_hint(note)
	_record_change(SyncChange.new("note", "update", note.id, str(note.id), {
		"title": note.title,
		"content": note.content,
		"updated_at": note.updated_at,
	}))

func _on_category_added(cat_name: String) -> void:
	if _is_applying_remote:
		return
	_remember_category_sync_hint(cat_name)
	var position = NoteState.get_category_position(cat_name)
	_record_change(SyncChange.new("category", "create", 0, cat_name, {
		"name": cat_name,
		"position": position
	}))

func _on_category_removed(cat_name: String) -> void:
	if _is_applying_remote:
		return
	_record_change(_make_delete_change("category", 0, cat_name))


## 记录变更到队列，触发防抖
func _record_change(change: SyncChange) -> void:
	_merge_change(change)
	_save_change_queue()
	# 触发防抖定时器
	if _is_registered and AuthState.is_logged_in():
		_debounce_timer.stop()
		_debounce_timer.start()


## 智能合并变更队列
func _merge_change(new_change: SyncChange) -> void:
	# full_replace：同 resource 只保留最新一条
	if new_change.action == "full_replace":
		for i in range(_change_queue.size() - 1, -1, -1):
			var existing: SyncChange = _change_queue[i]
			if existing.resource == new_change.resource and existing.action == "full_replace":
				_change_queue.remove_at(i)
		_change_queue.append(new_change)
		return

	# 查找同资源同 key 的已有变更
	for i in range(_change_queue.size() - 1, -1, -1):
		var existing: SyncChange = _change_queue[i]
		if existing.resource != new_change.resource:
			continue

		if new_change.action == "reorder" and existing.action == "reorder":
			_change_queue.remove_at(i)
			break

		# 通过 local_key 匹配（category 用 name，其他用 id）
		var same_item = false
		if new_change.resource == "category":
			same_item = existing.local_key == new_change.local_key and existing.local_key != ""
		else:
			same_item = existing.local_id == new_change.local_id and existing.local_id > 0

		if not same_item:
			continue

		# create 后续 update → 合并到 create.data
		if existing.action == "create" and new_change.action == "update":
			for key in new_change.data:
				existing.data[key] = new_change.data[key]
			existing.timestamp = new_change.timestamp
			return  # 不添加新变更

		# create 后续 delete → 两者都从队列移除
		if existing.action == "create" and new_change.action == "delete":
			_change_queue.remove_at(i)
			return  # 不添加新变更

		# update 后续 update → 合并 fields
		if existing.action == "update" and new_change.action == "update":
			for key in new_change.data:
				existing.data[key] = new_change.data[key]
			existing.timestamp = new_change.timestamp
			return  # 不添加新变更

		# update 后续 delete → 移除 update，保留 delete
		if existing.action == "update" and new_change.action == "delete":
			_change_queue.remove_at(i)
			break

	_change_queue.append(new_change)


# ======================== Push 流程 ========================

func _do_push() -> bool:
	if _change_queue.size() == 0:
		return true
	if not _is_registered or _device_id == "":
		return false

	var pending_queue: Array = []
	var changes_to_push: Array = []
	var queued_changes: Array = []
	for change in _change_queue:
		var push_item = _convert_to_push_format(change)
		if push_item.size() > 0:
			if change.action == "delete":
				print("[SyncState][DeleteTrace] queue delete for push resource=%s local_id=%d local_key=%s payload=%s" % [
					change.resource, change.local_id, change.local_key, JSON.stringify(push_item)
				])
			queued_changes.append(change)
			changes_to_push.append(push_item)
		elif _should_drop_unpushable_change(change):
			print("[SyncState] 丢弃无法推送的变更: resource=%s action=%s key=%s" % [
				change.resource, change.action, change.local_key if change.local_key != "" else str(change.local_id)
			])
		else:
			if change.action == "delete":
				print("[SyncState][DeleteTrace] retain delete in pending queue resource=%s local_id=%d local_key=%s change_data=%s" % [
					change.resource, change.local_id, change.local_key, JSON.stringify(change.data)
				])
			pending_queue.append(change)

	if changes_to_push.size() == 0:
		_change_queue = pending_queue
		_save_change_queue()
		return true

	var body = {
		"device_id": _device_id,
		"changes": changes_to_push
	}
	var delete_push_count := 0
	for item in changes_to_push:
		if item is Dictionary and item.get("action", "") == "delete":
			delete_push_count += 1
	if delete_push_count > 0:
		print("[SyncState][DeleteTrace] pushing %d delete changes device_id=%s" % [delete_push_count, _device_id])

	var result = await ApiClient.api_post("/sync/push", body)
	if not result.success:
		print("[SyncState] Push 失败: %s" % result.message)
		return false

	var data = result.data
	if not data is Dictionary:
		return false

	# 处理 results
	var results = data.get("results", [])
	var push_summary = _process_push_results(queued_changes, results)
	_last_push_summary = push_summary.duplicate(true)
	_change_queue = pending_queue
	for change in push_summary.get("retained_changes", []):
		_change_queue.append(change)
	_save_change_queue()
	_id_mapping.save_to_file()

	print("[SyncState] Push 完成: accepted=%s, rejected=%s" % [
		data.get("accepted", 0), data.get("rejected", 0)
	])
	return true


## 将 SyncChange 转换为后端 push 格式
func _convert_to_push_format(change: SyncChange) -> Dictionary:
	var item = {
		"resource": change.resource,
		"action": change.action,
		"timestamp": change.timestamp,
		"data": {}
	}

	if change.action == "update":
		var update_server_id = _resolve_server_id_for_change(change)
		if update_server_id == 0:
			print("[SyncState] Retain update change without server_id for retry: resource=%s key=%s" % [
				change.resource, change.local_key if change.local_key != "" else str(change.local_id)
			])
			return {}
		item["data"] = {"id": update_server_id, "fields": {}}
		for key in change.data:
			var value = change.data[key]
			if key == "updated_at" and value is int:
				value = _to_ms(value)
			item["data"]["fields"][key] = value
		return item

	if change.action == "delete":
		var delete_server_id: int = _resolve_server_id_for_change(change)
		if delete_server_id == 0:
			print("[SyncState] Retain delete change without server_id for retry: resource=%s key=%s" % [
				change.resource, change.local_key if change.local_key != "" else str(change.local_id)
			])
			return {}
		print("[SyncState][DeleteTrace] build delete payload resource=%s local_id=%d local_key=%s server_id=%d hint=%s" % [
			change.resource, change.local_id, change.local_key, delete_server_id, JSON.stringify(change.data)
		])
		item["data"] = {"id": delete_server_id}
		return item

	match change.action:
		"create":
			item["data"] = change.data.duplicate(true)
			item["data"]["client_id"] = "local-%s" % str(change.local_id) if change.resource != "category" else "local-cat-%s" % change.local_key
			# 时间戳 s→ms
			if item["data"].has("created_at"):
				item["data"]["created_at"] = _to_ms(item["data"]["created_at"])
		"update":
			var server_id = _resolve_server_id_for_change(change)
			if server_id == 0:
				print("[SyncState] 保留缺少 server_id 的 delete 变更重试: resource=%s key=%s" % [
					change.resource, change.local_key if change.local_key != "" else str(change.local_id)
				])
				return {}
				print("[SyncState] 保留缺少 server_id 的 update 变更重试: resource=%s key=%s" % [
					change.resource, change.local_key if change.local_key != "" else str(change.local_id)
				])
				return {}
				# 没有映射的项无法 update，跳过
				return {}
			item["data"] = {"id": server_id, "fields": {}}
			for key in change.data:
				var value = change.data[key]
				# updated_at 时间戳 s→ms
				if key == "updated_at" and value is int:
					value = _to_ms(value)
				item["data"]["fields"][key] = value
		"delete":
			var server_id: int = _resolve_server_id_for_change(change)
			if server_id == 0:
				return {}  # 没有映射说明服务器没有此数据
			item["data"] = {"id": server_id}
		"reorder":
			item["data"] = change.data.duplicate(true)
		"full_replace":
			item["data"] = change.data.duplicate(true)

	return item


## 处理 push 返回的 results
func _process_push_results(queued_changes: Array, results: Array) -> Dictionary:
	var retained_changes: Array = []
	var accepted_count := 0
	var rejected_count := 0

	for i in range(queued_changes.size()):
		var change: SyncChange = queued_changes[i]
		var r: Dictionary = {}
		if i < results.size() and results[i] is Dictionary:
			r = results[i]
		else:
			print("[SyncState] Push 返回缺少结果，保留变更重试: resource=%s action=%s" % [change.resource, change.action])
			retained_changes.append(change)
			continue

		if not r is Dictionary:
			continue
		var status = r.get("status", "")
		var resource = r.get("resource", "")
		var action = r.get("action", "")

		if status == "accepted":
			accepted_count += 1
			if change.action == "delete":
				print("[SyncState][DeleteTrace] delete push accepted resource=%s local_id=%d local_key=%s result=%s" % [
					change.resource, change.local_id, change.local_key, JSON.stringify(r)
				])
			if action == "create":
				var server_id = r.get("server_id", 0)
				var client_id = r.get("client_id", "")
				if server_id > 0 and client_id != "":
					# 从 client_id 解析本地 key
					var local_key = ""
					var local_id = 0
					if client_id.begins_with("local-cat-"):
						local_key = client_id.substr(10)  # "local-cat-" 长度 10
					elif client_id.begins_with("local-"):
						local_key = client_id.substr(6)
						local_id = int(local_key)
					_id_mapping.set_mapping(resource, local_key, server_id)
					# 更新本地数据模型的 server_id
					if resource == "task" and local_id > 0:
						var task = TaskState.get_task_by_id(local_id)
						if task:
							_persist_local_server_id("task", local_id, server_id)
					elif resource == "note" and local_id > 0:
						var note = NoteState.get_note_by_id(local_id)
						if note:
							_persist_local_server_id("note", local_id, server_id)
					_repair_mapping(resource, local_id, local_key, server_id)
			elif action == "delete":
				_forget_sync_hint(change.resource, change.local_id, change.local_key)
			continue

		rejected_count += 1
		if change.action == "delete":
			print("[SyncState][DeleteTrace] delete push rejected resource=%s local_id=%d local_key=%s result=%s" % [
				change.resource, change.local_id, change.local_key, JSON.stringify(r)
			])
		print("[SyncState] Push 结果被拒绝: resource=%s action=%s reason=%s" % [
			resource, action, r.get("reason", "unknown")
		])
		if action == "reorder":
			_apply_reorder_snapshot(resource, r.get("server_data", {}))
		retained_changes.append(change)

	return {
		"accepted_count": accepted_count,
		"rejected_count": rejected_count,
		"retained_changes": retained_changes,
	}


# ======================== Pull 流程 ========================

func _do_pull() -> bool:
	if not _is_registered or _device_id == "":
		return false

	_last_pull_summary = {
		"applied_count": 0,
		"mapping_repaired_count": 0,
		"unresolved_count": 0,
	}
	var pull_count = 0
	var has_more = true

	while has_more and pull_count < MAX_PULL_PAGES:
		var body = {
			"device_id": _device_id,
			"last_sync_time": _last_sync_time,
			"resources": ["task", "note", "category"]
		}

		var result = await ApiClient.api_post("/sync/pull", body)
		if not result.success:
			print("[SyncState] Pull 失败: %s" % result.message)
			return false

		var data = result.data
		if not data is Dictionary:
			return false

		var changes = data.get("changes", [])
		if changes.size() > 0:
			var delete_changes: Array = []
			for change in changes:
				if change is Dictionary and change.get("action", "") == "delete":
					delete_changes.append(change)
			if not delete_changes.is_empty():
				print("[SyncState][DeleteTrace] pull received %d delete changes page=%d payload=%s" % [
					delete_changes.size(), pull_count + 1, JSON.stringify(delete_changes)
				])
			var page_summary = _apply_remote_changes(changes)
			_last_pull_summary = _merge_remote_apply_summary(_last_pull_summary, page_summary)

		_last_sync_time = data.get("server_time", _last_sync_time)
		has_more = data.get("has_more", false)
		pull_count += 1

		print("[SyncState] Pull 第 %d 页: %d 条变更" % [pull_count, changes.size()])

	_save_sync_data()
	_id_mapping.save_to_file()
	return true


## 应用远程变更到本地
func _apply_remote_changes(changes: Array) -> Dictionary:
	var summary = {
		"applied_count": 0,
		"mapping_repaired_count": 0,
		"unresolved_count": 0,
	}
	_is_applying_remote = true

	for change in changes:
		if not change is Dictionary:
			continue
		var resource = change.get("resource", "")
		var action = change.get("action", "")
		var data = change.get("data", {})
		if not data is Dictionary:
			print("[SyncState] 跳过非法远端变更: resource=%s action=%s" % [resource, action])
			continue

		match resource:
			"task":
				var task_result = _apply_remote_task_change_v2(action, data)
				summary = _merge_remote_apply_summary(summary, task_result)
			"note":
				var note_result = _apply_remote_note_change_v2(action, data)
				summary = _merge_remote_apply_summary(summary, note_result)
			"category":
				var category_result = _apply_remote_category_change_v2(action, data)
				summary = _merge_remote_apply_summary(summary, category_result)

	_is_applying_remote = false
	_rebuild_sync_hints()
	return summary


func _merge_remote_apply_summary(base: Dictionary, delta: Dictionary) -> Dictionary:
	var merged = base.duplicate(true)
	for key in ["applied_count", "mapping_repaired_count", "unresolved_count"]:
		merged[key] = int(merged.get(key, 0)) + int(delta.get(key, 0))
	return merged


func _apply_remote_task_change_v2(action: String, data: Dictionary) -> Dictionary:
	var summary = {"applied_count": 0, "mapping_repaired_count": 0, "unresolved_count": 0}
	var server_id = int(data.get("id", 0))
	var had_mapping = _id_mapping.get_local_key("task", server_id) != ""

	match action:
		"create":
			var existing_local_id = _resolve_task_local_id(server_id, data)
			if existing_local_id > 0:
				if not had_mapping:
					summary["mapping_repaired_count"] += 1
				var create_fields = _extract_remote_fields(data, ["title", "is_completed", "due_timestamp", "finish_timestamp", "updated_at", "position"])
				create_fields["server_id"] = server_id
				if create_fields.has("updated_at"):
					create_fields["updated_at"] = _to_sec(int(create_fields["updated_at"]))
				TaskState.sync_update_task(existing_local_id, create_fields)
				_remember_task_sync_hint(TaskState.get_task_by_id(existing_local_id))
				summary["applied_count"] += 1
				return summary
			var local_id = TaskState.allocate_id()
			var task = TaskData.new(local_id, data.get("title", ""), data.get("due_timestamp", 0), data.get("is_completed", false))
			task.finish_timestamp = data.get("finish_timestamp", 0)
			task.order = data.get("position", 0)
			task.created_at = _to_sec(data.get("created_at", 0))
			task.updated_at = _to_sec(data.get("updated_at", 0))
			task.server_id = server_id
			TaskState.sync_create_task(task)
			_repair_mapping("task", local_id, str(local_id), server_id)
			_remember_task_sync_hint(task)
			summary["applied_count"] += 1

		"update":
			var local_id = _resolve_task_local_id(server_id, data)
			if local_id == 0:
				print("[SyncState] Skip task update: unresolved local target, server_id=%d" % server_id)
				summary["unresolved_count"] += 1
				return summary
			if not had_mapping:
				summary["mapping_repaired_count"] += 1
			var fields = _extract_remote_fields(data, ["title", "is_completed", "due_timestamp", "finish_timestamp", "updated_at", "position"])
			fields["server_id"] = server_id
			if fields.has("updated_at"):
				fields["updated_at"] = _to_sec(int(fields["updated_at"]))
			TaskState.sync_update_task(local_id, fields)
			_remember_task_sync_hint(TaskState.get_task_by_id(local_id))
			summary["applied_count"] += 1

		"delete":
			var local_id = _resolve_task_local_id(server_id, data)
			print("[SyncState][DeleteTrace] apply task delete server_id=%d resolved_local_id=%d mapping_key=%s data=%s" % [
				server_id, local_id, _id_mapping.get_local_key("task", server_id), JSON.stringify(data)
			])
			if local_id == 0:
				print("[SyncState] Skip task delete: unresolved local target, server_id=%d" % server_id)
				summary["unresolved_count"] += 1
				return summary
			if not had_mapping:
				summary["mapping_repaired_count"] += 1
			TaskState.sync_remove_task(local_id)
			_id_mapping.remove_by_server("task", server_id)
			_forget_sync_hint("task", local_id)
			summary["applied_count"] += 1

	return summary


func _apply_remote_note_change_v2(action: String, data: Dictionary) -> Dictionary:
	var summary = {"applied_count": 0, "mapping_repaired_count": 0, "unresolved_count": 0}
	var server_id = int(data.get("id", 0))
	var had_mapping = _id_mapping.get_local_key("note", server_id) != ""

	match action:
		"create":
			var existing_local_id = _resolve_note_local_id(server_id, data)
			if existing_local_id > 0:
				if not had_mapping:
					summary["mapping_repaired_count"] += 1
				var create_fields = _extract_remote_fields(data, ["title", "content", "categories", "updated_at", "position"])
				create_fields["server_id"] = server_id
				if create_fields.has("updated_at"):
					create_fields["updated_at"] = _to_sec(int(create_fields["updated_at"]))
				NoteState.sync_update_note(existing_local_id, create_fields)
				_remember_note_sync_hint(NoteState.get_note_by_id(existing_local_id))
				summary["applied_count"] += 1
				return summary
			var local_id = NoteState.allocate_id()
			var note = NoteData.new(local_id, data.get("title", ""), data.get("content", ""))
			note.created_at = _to_sec(data.get("created_at", 0))
			note.updated_at = _to_sec(data.get("updated_at", 0))
			note.server_id = server_id
			NoteState.sync_create_note(note)
			_repair_mapping("note", local_id, str(local_id), server_id)
			_remember_note_sync_hint(note)
			summary["applied_count"] += 1

		"update":
			var local_id = _resolve_note_local_id(server_id, data)
			if local_id == 0:
				print("[SyncState] Skip note update: unresolved local target, server_id=%d" % server_id)
				summary["unresolved_count"] += 1
				return summary
			if not had_mapping:
				summary["mapping_repaired_count"] += 1
			var fields = _extract_remote_fields(data, ["title", "content", "categories", "updated_at", "position"])
			fields["server_id"] = server_id
			if fields.has("updated_at"):
				fields["updated_at"] = _to_sec(int(fields["updated_at"]))
			NoteState.sync_update_note(local_id, fields)
			_remember_note_sync_hint(NoteState.get_note_by_id(local_id))
			summary["applied_count"] += 1

		"delete":
			var local_id = _resolve_note_local_id(server_id, data)
			print("[SyncState][DeleteTrace] apply note delete server_id=%d resolved_local_id=%d mapping_key=%s data=%s" % [
				server_id, local_id, _id_mapping.get_local_key("note", server_id), JSON.stringify(data)
			])
			if local_id == 0:
				print("[SyncState] Skip note delete: unresolved local target, server_id=%d" % server_id)
				summary["unresolved_count"] += 1
				return summary
			if not had_mapping:
				summary["mapping_repaired_count"] += 1
			NoteState.sync_remove_note(local_id)
			_id_mapping.remove_by_server("note", server_id)
			_forget_sync_hint("note", local_id)
			summary["applied_count"] += 1

	return summary


func _apply_remote_category_change_v2(action: String, data: Dictionary) -> Dictionary:
	var summary = {"applied_count": 0, "mapping_repaired_count": 0, "unresolved_count": 0}
	var server_id = int(data.get("id", 0))
	var name = str(data.get("name", ""))
	var had_mapping = _id_mapping.get_local_key("category", server_id) != ""

	match action:
		"create":
			var local_key = _resolve_category_key(server_id, name)
			if local_key != "":
				if not had_mapping:
					summary["mapping_repaired_count"] += 1
				summary["applied_count"] += 1
				return summary
			var position = data.get("position", NoteState.get_categories().size())
			NoteState.sync_insert_category_at(name, position)
			_repair_mapping("category", 0, name, server_id)
			summary["applied_count"] += 1

		"update":
			var update_key = _resolve_category_key(server_id, name)
			if update_key == "":
				summary["unresolved_count"] += 1
				return summary
			if not had_mapping:
				summary["mapping_repaired_count"] += 1
			summary["applied_count"] += 1

		"delete":
			var delete_key = _resolve_category_key(server_id, name)
			print("[SyncState][DeleteTrace] apply category delete server_id=%d resolved_key=%s mapping_key=%s data=%s" % [
				server_id, delete_key, _id_mapping.get_local_key("category", server_id), JSON.stringify(data)
			])
			if delete_key == "":
				print("[SyncState] Skip category delete: unresolved local target, server_id=%d name=%s" % [server_id, name])
				summary["unresolved_count"] += 1
				return summary
			if not had_mapping:
				summary["mapping_repaired_count"] += 1
			NoteState.sync_remove_category(delete_key)
			_id_mapping.remove_by_server("category", server_id)
			_forget_sync_hint("category", 0, delete_key)
			summary["applied_count"] += 1

	return summary


func _apply_remote_task_change(action: String, data: Dictionary) -> void:
	var server_id = data.get("id", 0)

	match action:
		"create":
			# 幂等检查
			if _id_mapping.has_server_id("task", server_id):
				return
			var local_id = TaskState.allocate_id()
			var task = TaskData.new(local_id, data.get("title", ""), data.get("due_timestamp", 0), data.get("is_completed", false))
			task.finish_timestamp = data.get("finish_timestamp", 0)
			task.order = data.get("position", 0)
			task.created_at = _to_sec(data.get("created_at", 0))
			task.updated_at = _to_sec(data.get("updated_at", 0))
			task.server_id = server_id
			TaskState.sync_create_task(task)
			_id_mapping.set_mapping("task", str(local_id), server_id)

		"update":
			var local_key = _id_mapping.get_local_key("task", server_id)
			if local_key == "":
				print("[SyncState] 跳过 task update，缺少本地映射: server_id=%d" % server_id)
				return
			var local_id = int(local_key)
			var fields = _extract_remote_fields(data, ["title", "is_completed", "due_timestamp", "finish_timestamp", "updated_at", "position"])
			if fields.has("updated_at"):
				fields["updated_at"] = _to_sec(fields["updated_at"])
			TaskState.sync_update_task(local_id, fields)

		"delete":
			var local_key = _id_mapping.get_local_key("task", server_id)
			if local_key == "":
				print("[SyncState] 跳过 task delete，缺少本地映射: server_id=%d" % server_id)
				return
			var local_id = int(local_key)
			TaskState.sync_remove_task(local_id)
			_id_mapping.remove_by_server("task", server_id)


func _apply_remote_note_change(action: String, data: Dictionary) -> void:
	var server_id = data.get("id", 0)

	match action:
		"create":
			if _id_mapping.has_server_id("note", server_id):
				return
			var local_id = NoteState.allocate_id()
			var note = NoteData.new(local_id, data.get("title", ""), data.get("content", ""))
			note.created_at = _to_sec(data.get("created_at", 0))
			note.updated_at = _to_sec(data.get("updated_at", 0))
			note.server_id = server_id
			NoteState.sync_create_note(note)
			_id_mapping.set_mapping("note", str(local_id), server_id)

		"update":
			var local_key = _id_mapping.get_local_key("note", server_id)
			if local_key == "":
				print("[SyncState] 跳过 note update，缺少本地映射: server_id=%d" % server_id)
				return
			var local_id = int(local_key)
			var fields = _extract_remote_fields(data, ["title", "content", "categories", "updated_at", "position"])
			if fields.has("updated_at"):
				fields["updated_at"] = _to_sec(fields["updated_at"])
			NoteState.sync_update_note(local_id, fields)

		"delete":
			var local_key = _id_mapping.get_local_key("note", server_id)
			if local_key == "":
				print("[SyncState] 跳过 note delete，缺少本地映射: server_id=%d" % server_id)
				return
			var local_id = int(local_key)
			NoteState.sync_remove_note(local_id)
			_id_mapping.remove_by_server("note", server_id)


func _apply_remote_category_change(action: String, data: Dictionary) -> void:
	var server_id = data.get("id", 0)
	var name = data.get("name", "")

	match action:
		"create":
			if _id_mapping.has_server_id("category", server_id):
				return
			var position = data.get("position", NoteState.get_categories().size())
			NoteState.sync_insert_category_at(name, position)
			_repair_mapping("category", 0, name, server_id)

		"update":
			# category 目前只有 name 和 position，暂不处理 rename
			pass

		"delete":
			var local_key = _id_mapping.get_local_key("category", server_id)
			if local_key == "":
				return
			NoteState.sync_remove_category(local_key)
			_id_mapping.remove_by_server("category", server_id)


# ======================== 全量同步 ========================

func do_full_sync() -> void:
	if _is_syncing:
		return
	if not _is_registered or _device_id == "":
		return

	_is_syncing = true
	sync_started.emit()
	print("[SyncState] 开始全量同步...")

	# 构建请求：增量资源 + bundle 类型
	var resources: Array = ["task", "note", "category"]
	for bundle_type in _full_sync_bundles:
		resources.append(bundle_type)

	var body = {
		"device_id": _device_id,
		"resources": resources
	}

	var result = await ApiClient.api_post("/sync/full", body)
	if not result.success:
		_handle_sync_failure("全量同步失败: %s" % result.message)
		return

	var data = result.data
	if not data is Dictionary:
		_handle_sync_failure("全量同步返回数据格式无效")
		return

	_is_applying_remote = true

	# 处理 tasks
	var server_tasks = data.get("tasks", [])
	_merge_full_sync_tasks(server_tasks)

	# 处理 notes
	var server_notes = data.get("notes", [])
	_merge_full_sync_notes(server_notes)

	# 处理 categories
	var server_categories = data.get("categories", [])
	_merge_full_sync_categories(server_categories)

	# 处理 bundles
	_merge_full_sync_bundles(data)

	_is_applying_remote = false

	# 上传本地独有数据（包括 bundle）
	_push_local_only_bundles(data)
	if _change_queue.size() > 0:
		await _do_push()

	_last_sync_time = data.get("server_time", _last_sync_time)
	_save_sync_data()
	_id_mapping.save_to_file()

	# 全量同步完成后清除所有 bundle 脏标记
	for bt in _bundle_dirty:
		_bundle_dirty[bt] = false

	_consecutive_failures = 0
	_is_syncing = false
	sync_completed.emit(true, {"type": "full"})
	print("[SyncState] 全量同步完成")


## 全量同步 - 合并 bundles
func _merge_full_sync_bundles(server_data: Dictionary) -> void:
	for bundle_type in _full_sync_bundles:
		var bundle_key = bundle_type  # 响应中 key 与 bundle_type 相同
		if not server_data.has(bundle_key):
			continue
		var server_bundle = server_data[bundle_key]
		if not server_bundle is Dictionary:
			continue
		var bundle_info = _full_sync_bundles[bundle_type]
		bundle_info["merge"].call(server_bundle)
		print("[SyncState] 已合并 bundle: %s" % bundle_type)


## 全量同步 - 推送服务器端没有的 bundles
func _push_local_only_bundles(server_data: Dictionary) -> void:
	for bundle_type in _full_sync_bundles:
		if server_data.has(bundle_type):
			continue  # 服务器已有，跳过
		var bundle_info = _full_sync_bundles[bundle_type]
		var export_data: Dictionary = bundle_info["export"].call()
		if export_data.is_empty():
			continue
		_change_queue.append(SyncChange.new(bundle_type, "full_replace", 0, bundle_type, export_data))
		print("[SyncState] 推送本地 bundle: %s" % bundle_type)


## 全量同步 - 合并 tasks（通用方法 wrapper）
func _merge_full_sync_tasks(server_tasks: Array) -> void:
	_merge_full_sync_items(
		"task", server_tasks,
		TaskState.get_all_tasks,
		func(item): return item.id,
		func(item): return item.server_id,
		func(item, sid): item.server_id = sid,
		func(item): return item.title,
		func(item): return item.created_at,
		func(item): return item.updated_at,
		["title", "is_completed", "due_timestamp", "finish_timestamp", "updated_at"],
		func(st, _sid):
			var local_id = TaskState.allocate_id()
			var task = TaskData.new(local_id, st.get("title", ""), st.get("due_timestamp", 0), st.get("is_completed", false))
			task.finish_timestamp = st.get("finish_timestamp", 0)
			task.order = st.get("position", 0)
			task.created_at = _to_sec(st.get("created_at", 0))
			task.updated_at = _to_sec(st.get("updated_at", 0))
			task.server_id = _sid
			TaskState.sync_create_task(task)
			return local_id,
		func(local_id, fields): TaskState.sync_update_task(local_id, fields),
		func(item): return {
			"title": item.title,
			"due_timestamp": item.due_timestamp,
			"finish_timestamp": item.finish_timestamp,
			"is_completed": item.is_completed,
			"created_at": item.created_at,
			"position": item.order
		}
	)
	_prune_missing_full_sync_tasks(server_tasks)


## 全量同步 - 合并 notes（通用方法 wrapper）
func _merge_full_sync_notes(server_notes: Array) -> void:
	_merge_full_sync_items(
		"note", server_notes,
		NoteState.get_all_notes,
		func(item): return item.id,
		func(item): return item.server_id,
		func(item, sid): item.server_id = sid,
		func(item): return item.title,
		func(item): return item.created_at,
		func(item): return item.updated_at,
		["title", "content", "updated_at"],
		func(sn, _sid):
			var local_id = NoteState.allocate_id()
			var note = NoteData.new(local_id, sn.get("title", ""), sn.get("content", ""))
			note.created_at = _to_sec(sn.get("created_at", 0))
			note.updated_at = _to_sec(sn.get("updated_at", 0))
			note.server_id = _sid
			NoteState.sync_create_note(note)
			return local_id,
		func(local_id, fields): NoteState.sync_update_note(local_id, fields),
		func(item): return {
			"title": item.title,
			"content": item.content,
			"created_at": item.created_at,
		}
	)
	_prune_missing_full_sync_notes(server_notes)


## 通用全量合并方法
## 提取 _merge_full_sync_tasks 和 _merge_full_sync_notes 的共同逻辑
func _merge_full_sync_items(
	resource_name: String,
	server_items: Array,
	get_local_items: Callable,
	get_item_id: Callable,
	get_item_server_id: Callable,
	set_item_server_id: Callable,
	get_item_title: Callable,
	get_item_created_at: Callable,
	get_item_updated_at: Callable,
	sync_field_names: Array,
	create_local_item: Callable,
	sync_update_item: Callable,
	to_push_data: Callable,
) -> void:
	var local_items = get_local_items.call()

	for si in server_items:
		if not si is Dictionary:
			continue
		var server_id = si.get("id", 0)

		# 检查是否已有映射
		if _id_mapping.has_server_id(resource_name, server_id):
			var local_key = _id_mapping.get_local_key(resource_name, server_id)
			var local_item = _find_local_item_by_id(local_items, get_item_id, int(local_key))
			if local_item != null:
				var server_updated = si.get("updated_at", 0)
				var local_updated = _to_ms(get_item_updated_at.call(local_item))
				if server_updated > local_updated:
					var fields = _extract_sync_fields(si, sync_field_names)
					sync_update_item.call(get_item_id.call(local_item), fields)
			continue

		# 尝试匹配本地未映射项
		var matched_by_server_id = false
		for li in local_items:
			if get_item_server_id.call(li) != server_id:
				continue
			_repair_mapping(resource_name, get_item_id.call(li), str(get_item_id.call(li)), server_id)
			sync_update_item.call(get_item_id.call(li), {"server_id": server_id})
			var persisted_server_updated = si.get("updated_at", 0)
			var persisted_local_updated = _to_ms(get_item_updated_at.call(li))
			if persisted_server_updated > persisted_local_updated:
				var persisted_fields = _extract_sync_fields(si, sync_field_names)
				sync_update_item.call(get_item_id.call(li), persisted_fields)
			matched_by_server_id = true
			break
		if matched_by_server_id:
			continue

		var matched = false
		for li in local_items:
			if get_item_server_id.call(li) > 0:
				continue
			if _id_mapping.get_server_id(resource_name, str(get_item_id.call(li))) > 0:
				continue
			if get_item_title.call(li) == si.get("title", "") and abs(_to_ms(get_item_created_at.call(li)) - si.get("created_at", 0)) < 60000:
				_repair_mapping(resource_name, get_item_id.call(li), str(get_item_id.call(li)), server_id)
				sync_update_item.call(get_item_id.call(li), {"server_id": server_id})
				set_item_server_id.call(li, server_id)
				var server_updated = si.get("updated_at", 0)
				var local_updated = _to_ms(get_item_updated_at.call(li))
				if server_updated > local_updated:
					var fields = _extract_sync_fields(si, sync_field_names)
					sync_update_item.call(get_item_id.call(li), fields)
				matched = true
				break

		if not matched:
			var local_id = create_local_item.call(si, server_id)
			_repair_mapping(resource_name, local_id, str(local_id), server_id)

	# 本地有服务器无 → 作为 create 加入 push 队列
	for li in local_items:
		if get_item_server_id.call(li) == 0 and _id_mapping.get_server_id(resource_name, str(get_item_id.call(li))) == 0:
			var push_data = to_push_data.call(li)
			_change_queue.append(SyncChange.new(resource_name, "create", get_item_id.call(li), str(get_item_id.call(li)), push_data))


## 从服务器数据中提取同步字段
func _extract_sync_fields(server_data: Dictionary, field_names: Array) -> Dictionary:
	var fields = {}
	for field_name in field_names:
		if server_data.has(field_name):
			var value = server_data[field_name]
			if field_name == "updated_at" and value is float:
				value = int(value)
			if field_name == "updated_at":
				fields[field_name] = _to_sec(int(value))
			else:
				fields[field_name] = value
	return fields


## 在本地列表中查找指定 id 的项
func _find_local_item_by_id(local_items: Array, get_id: Callable, target_id: int):
	for item in local_items:
		if get_id.call(item) == target_id:
			return item
	return null


func _prune_missing_full_sync_tasks(server_tasks: Array) -> void:
	var server_ids: Dictionary = {}
	for st in server_tasks:
		if st is Dictionary:
			var sid = int(st.get("id", 0))
			if sid > 0:
				server_ids[sid] = true

	for task in TaskState.get_all_tasks():
		var server_id = task.server_id
		if server_id <= 0:
			server_id = _id_mapping.get_server_id("task", str(task.id))
		if server_id <= 0:
			continue
		if server_ids.has(server_id):
			continue
		print("[SyncState][DeleteTrace] full sync prune task local_id=%d server_id=%d" % [task.id, server_id])
		TaskState.sync_remove_task(task.id)
		_id_mapping.remove_by_server("task", server_id)
		_forget_sync_hint("task", task.id)


func _prune_missing_full_sync_notes(server_notes: Array) -> void:
	var server_ids: Dictionary = {}
	for sn in server_notes:
		if sn is Dictionary:
			var sid = int(sn.get("id", 0))
			if sid > 0:
				server_ids[sid] = true

	for note in NoteState.get_all_notes():
		var server_id = note.server_id
		if server_id <= 0:
			server_id = _id_mapping.get_server_id("note", str(note.id))
		if server_id <= 0:
			continue
		if server_ids.has(server_id):
			continue
		print("[SyncState][DeleteTrace] full sync prune note local_id=%d server_id=%d" % [note.id, server_id])
		NoteState.sync_remove_note(note.id)
		_id_mapping.remove_by_server("note", server_id)
		_forget_sync_hint("note", note.id)


## 全量同步 - 合并 categories
func _merge_full_sync_categories(server_categories: Array) -> void:
	var local_categories = NoteState.get_categories()
	var server_ids: Dictionary = {}

	for sc in server_categories:
		if not sc is Dictionary:
			continue
		var server_id = sc.get("id", 0)
		var name = sc.get("name", "")
		if server_id > 0:
			server_ids[int(server_id)] = true

		if _id_mapping.has_server_id("category", server_id):
			continue  # 已映射，跳过

		# 按名称匹配
		if name in local_categories:
			_repair_mapping("category", 0, name, server_id)
			continue

		# 服务器有本地无 → 创建
		var position = sc.get("position", NoteState.get_categories().size())
		NoteState.sync_insert_category_at(name, position)
		_repair_mapping("category", 0, name, server_id)

	# 本地有服务器无 → 加入 push 队列
	for cat in local_categories:
		if _id_mapping.get_server_id("category", cat) == 0:
			_change_queue.append(SyncChange.new("category", "create", 0, cat, {
				"name": cat,
				"position": NoteState.get_category_position(cat)
			}))

	for cat in NoteState.get_categories():
		var server_id = _id_mapping.get_server_id("category", cat)
		if server_id <= 0:
			server_id = int(_category_server_hints.get(cat, 0))
		if server_id <= 0:
			continue
		if server_ids.has(server_id):
			continue
		print("[SyncState][DeleteTrace] full sync prune category name=%s server_id=%d" % [cat, server_id])
		NoteState.sync_remove_category(cat)
		_id_mapping.remove_by_server("category", server_id)
		_forget_sync_hint("category", 0, cat)


func _extract_remote_fields(data: Dictionary, field_names: Array) -> Dictionary:
	var source = data
	if data.has("fields") and data["fields"] is Dictionary:
		source = data["fields"]
	var fields = {}
	for field_name in field_names:
		if source.has(field_name):
			fields[field_name] = source[field_name]
	return fields


func _resolve_server_id_for_change(change: SyncChange) -> int:
	if change.resource == "category":
		return _resolve_server_id_from_state("category", 0, change.local_key, change.data)
	return _resolve_server_id_from_state(change.resource, change.local_id, change.local_key, change.data)


func _resolve_server_id_from_state(resource: String, local_id: int = 0, local_key: String = "", change_data: Dictionary = {}) -> int:
	var mapping_key = local_key if local_key != "" else str(local_id)
	var server_id = _id_mapping.get_server_id(resource, mapping_key)
	if server_id > 0:
		return server_id

	if change_data.has("server_id_hint"):
		server_id = int(change_data.get("server_id_hint", 0))
		if server_id > 0:
			print("[SyncState][DeleteTrace] resolve server_id from hint resource=%s local_id=%d local_key=%s server_id=%d" % [
				resource, local_id, local_key, server_id
			])
			_repair_mapping(resource, local_id, local_key, server_id)
			return server_id

	match resource:
		"task":
			if local_id > 0 and _task_server_hints.has(local_id):
				server_id = int(_task_server_hints[local_id])
		"note":
			if local_id > 0 and _note_server_hints.has(local_id):
				server_id = int(_note_server_hints[local_id])
		"category":
			if local_key != "" and _category_server_hints.has(local_key):
				server_id = int(_category_server_hints[local_key])
	if server_id > 0:
		print("[SyncState][DeleteTrace] resolve server_id from hint cache resource=%s local_id=%d local_key=%s server_id=%d" % [
			resource, local_id, local_key, server_id
		])
		_repair_mapping(resource, local_id, local_key, server_id)
		return server_id

	match resource:
		"task":
			var task = TaskState.get_task_by_id(local_id)
			if task != null and task.server_id > 0:
				server_id = task.server_id
		"note":
			var note = NoteState.get_note_by_id(local_id)
			if note != null and note.server_id > 0:
				server_id = note.server_id
	if server_id > 0:
		print("[SyncState][DeleteTrace] resolve server_id from local model resource=%s local_id=%d local_key=%s server_id=%d" % [
			resource, local_id, local_key, server_id
		])
		_repair_mapping(resource, local_id, local_key, server_id)
	else:
		print("[SyncState][DeleteTrace] failed to resolve server_id resource=%s local_id=%d local_key=%s change_data=%s" % [
			resource, local_id, local_key, JSON.stringify(change_data)
		])
	return server_id


func _repair_mapping(resource: String, local_id: int = 0, local_key: String = "", server_id: int = 0) -> void:
	if server_id <= 0:
		return
	var resolved_key = local_key if local_key != "" else str(local_id)
	if resolved_key == "":
		return
	_id_mapping.set_mapping(resource, resolved_key, server_id)
	match resource:
		"task":
			if local_id > 0:
				_task_server_hints[local_id] = server_id
		"note":
			if local_id > 0:
				_note_server_hints[local_id] = server_id
		"category":
			_category_server_hints[resolved_key] = server_id


func _persist_local_server_id(resource: String, local_id: int, server_id: int) -> void:
	if local_id <= 0 or server_id <= 0:
		return
	print("[SyncState][DeleteTrace] persist server_id resource=%s local_id=%d server_id=%d" % [
		resource, local_id, server_id
	])
	var old_flag = _is_applying_remote
	_is_applying_remote = true
	match resource:
		"task":
			TaskState.sync_update_task(local_id, {"server_id": server_id})
		"note":
			NoteState.sync_update_note(local_id, {"server_id": server_id})
	_is_applying_remote = old_flag


func _resolve_task_local_id(server_id: int, remote_data: Dictionary = {}) -> int:
	if server_id <= 0:
		return 0
	var local_key = _id_mapping.get_local_key("task", server_id)
	if local_key != "":
		var local_id = int(local_key)
		if TaskState.get_task_by_id(local_id) != null:
			print("[SyncState][DeleteTrace] resolve task local by mapping server_id=%d local_id=%d" % [server_id, local_id])
			_task_server_hints[local_id] = server_id
			return local_id

	var task = TaskState.get_task_by_server_id(server_id)
	if task != null:
		print("[SyncState][DeleteTrace] resolve task local by persisted server_id=%d local_id=%d" % [server_id, task.id])
		_repair_mapping("task", task.id, str(task.id), server_id)
		return task.id

	var matched_task = _match_task_by_remote_data(remote_data)
	if matched_task != null:
		print("[SyncState][DeleteTrace] resolve task local by heuristic server_id=%d local_id=%d" % [server_id, matched_task.id])
		TaskState.sync_update_task(matched_task.id, {"server_id": server_id})
		_repair_mapping("task", matched_task.id, str(matched_task.id), server_id)
		return matched_task.id
	print("[SyncState][DeleteTrace] failed to resolve task local server_id=%d remote_data=%s" % [server_id, JSON.stringify(remote_data)])
	return 0


func _resolve_note_local_id(server_id: int, remote_data: Dictionary = {}) -> int:
	if server_id <= 0:
		return 0
	var local_key = _id_mapping.get_local_key("note", server_id)
	if local_key != "":
		var local_id = int(local_key)
		if NoteState.get_note_by_id(local_id) != null:
			print("[SyncState][DeleteTrace] resolve note local by mapping server_id=%d local_id=%d" % [server_id, local_id])
			_note_server_hints[local_id] = server_id
			return local_id

	var note = NoteState.get_note_by_server_id(server_id)
	if note != null:
		print("[SyncState][DeleteTrace] resolve note local by persisted server_id=%d local_id=%d" % [server_id, note.id])
		_repair_mapping("note", note.id, str(note.id), server_id)
		return note.id

	var matched_note = _match_note_by_remote_data(remote_data)
	if matched_note != null:
		print("[SyncState][DeleteTrace] resolve note local by heuristic server_id=%d local_id=%d" % [server_id, matched_note.id])
		NoteState.sync_update_note(matched_note.id, {"server_id": server_id})
		_repair_mapping("note", matched_note.id, str(matched_note.id), server_id)
		return matched_note.id
	print("[SyncState][DeleteTrace] failed to resolve note local server_id=%d remote_data=%s" % [server_id, JSON.stringify(remote_data)])
	return 0


func _resolve_category_key(server_id: int, name: String) -> String:
	if name == "":
		return ""
	var local_key = _id_mapping.get_local_key("category", server_id)
	if local_key != "" and NoteState.has_category(local_key):
		print("[SyncState][DeleteTrace] resolve category key by mapping server_id=%d key=%s" % [server_id, local_key])
		_category_server_hints[local_key] = server_id
		return local_key
	if NoteState.has_category(name):
		print("[SyncState][DeleteTrace] resolve category key by name server_id=%d key=%s" % [server_id, name])
		_repair_mapping("category", 0, name, server_id)
		return name
	print("[SyncState][DeleteTrace] failed to resolve category key server_id=%d name=%s" % [server_id, name])
	return ""


func _match_task_by_remote_data(remote_data: Dictionary):
	var title = str(remote_data.get("title", ""))
	var created_at = int(remote_data.get("created_at", 0))
	if title == "" or created_at <= 0:
		return null
	var matched_task = null
	for task in TaskState.get_all_tasks():
		if task.server_id > 0:
			continue
		if task.title != title:
			continue
		if abs(_to_ms(task.created_at) - created_at) > 60000:
			continue
		if matched_task != null:
			return null
		matched_task = task
	return matched_task


func _match_note_by_remote_data(remote_data: Dictionary):
	var title = str(remote_data.get("title", ""))
	var created_at = int(remote_data.get("created_at", 0))
	if title == "" or created_at <= 0:
		return null
	var matched_note = null
	for note in NoteState.get_all_notes():
		if note.server_id > 0:
			continue
		if note.title != title:
			continue
		if abs(_to_ms(note.created_at) - created_at) > 60000:
			continue
		if matched_note != null:
			return null
		matched_note = note
	return matched_note


func _should_drop_unpushable_change(change: SyncChange) -> bool:
	match change.action:
		"update":
			return false
		"delete":
			return false
		"reorder":
			return change.data.get("ordered_ids", []).is_empty()
		_:
			return false


func _apply_reorder_snapshot(resource: String, server_data: Dictionary) -> void:
	if not server_data is Dictionary:
		return
	var ordered_ids = server_data.get("ordered_ids", [])
	if not ordered_ids is Array or ordered_ids.is_empty():
		return
	match resource:
		"task":
			for server_id in ordered_ids:
				_resolve_task_local_id(int(server_id))
			TaskState.sync_reorder_by_server_ids(ordered_ids)
		_:
			print("[SyncState] 暂未实现 %s 的远端排序快照应用" % resource)


# ======================== 同步触发 ========================

func _on_auto_sync_timeout() -> void:
	if _is_syncing:
		return
	if _consecutive_failures >= MAX_CONSECUTIVE_FAILURES:
		print("[SyncState] 连续失败 %d 次，暂停自动同步" % _consecutive_failures)
		_stop_auto_sync()
		sync_error.emit("同步连续失败，已暂停自动同步")
		return
	await _do_sync_cycle()

func _on_debounce_timeout() -> void:
	if _is_syncing:
		return
	if _change_queue.size() > 0:
		await _do_push()


## 执行一次完整的同步周期（push + pull + bundle push）
func _do_sync_cycle() -> void:
	if _is_syncing:
		return
	if not _is_registered or not AuthState.is_logged_in():
		return

	_is_syncing = true
	sync_started.emit()

	# 推送脏 bundles
	if _has_dirty_bundles():
		_push_dirty_bundles()

	_last_push_summary = {}
	var push_ok = await _do_push()
	var pull_ok = await _do_pull()

	var success = push_ok and pull_ok
	if success:
		_consecutive_failures = 0
	else:
		_consecutive_failures += 1

	_is_syncing = false
	sync_completed.emit(success, {
		"type": "incremental",
		"push": push_ok,
		"pull": pull_ok,
		"accepted_count": int(_last_push_summary.get("accepted_count", 0)),
		"rejected_count": int(_last_push_summary.get("rejected_count", 0)),
		"applied_remote_count": int(_last_pull_summary.get("applied_count", 0)),
		"mapping_repaired_count": int(_last_pull_summary.get("mapping_repaired_count", 0)),
		"unresolved_remote_count": int(_last_pull_summary.get("unresolved_count", 0)),
	})


## 手动触发同步（供 UI 调用）
func trigger_sync() -> void:
	if _consecutive_failures >= MAX_CONSECUTIVE_FAILURES:
		# 重置失败计数，允许重试
		_consecutive_failures = 0
		_start_auto_sync()
	await _do_sync_cycle()


func _start_auto_sync() -> void:
	_auto_sync_timer.start()
	print("[SyncState] 自动同步已启动（每 %d 秒）" % int(AUTO_SYNC_INTERVAL))

func _stop_auto_sync() -> void:
	_auto_sync_timer.stop()
	_debounce_timer.stop()
	print("[SyncState] 自动同步已停止")


# ======================== 错误处理 ========================

func _handle_sync_failure(message: String) -> void:
	_consecutive_failures += 1
	_is_syncing = false
	push_error("[SyncState] %s" % message)
	sync_error.emit(message)
	sync_completed.emit(false, {"error": message})

	if _consecutive_failures >= MAX_CONSECUTIVE_FAILURES:
		_stop_auto_sync()
		sync_error.emit("同步连续失败 %d 次，已暂停自动同步" % _consecutive_failures)


# ======================== 登出重置 ========================

func _reset_sync_state() -> void:
	_device_id = ""
	_last_sync_time = 0
	_change_queue.clear()
	_is_registered = false
	_consecutive_failures = 0
	_id_mapping.clear_all()
	for bt in _bundle_dirty:
		_bundle_dirty[bt] = false
	_save_sync_data()
	_save_change_queue()
	_id_mapping.save_to_file()
	print("[SyncState] 同步状态已重置")


# ======================== 持久化 ========================

func _save_sync_data() -> void:
	var data = {
		"version": 1,
		"device_id": _device_id,
		"last_sync_time": _last_sync_time,
		"is_registered": _is_registered
	}
	var json_string = JSON.stringify(data, "\t")
	var file = FileAccess.open(SYNC_DATA_PATH, FileAccess.WRITE)
	if file:
		file.store_string(json_string)
		file.close()

func _load_sync_data() -> void:
	if not FileAccess.file_exists(SYNC_DATA_PATH):
		return
	var file = FileAccess.open(SYNC_DATA_PATH, FileAccess.READ)
	if not file:
		return
	var json_string = file.get_as_text()
	file.close()
	var json = JSON.new()
	if json.parse(json_string) != OK:
		return
	var data = json.get_data()
	if not data is Dictionary:
		return
	_device_id = data.get("device_id", "")
	_last_sync_time = data.get("last_sync_time", 0)
	_is_registered = data.get("is_registered", false)

func _save_change_queue() -> void:
	var arr = []
	for change in _change_queue:
		arr.append(change.to_dict())
	var json_string = JSON.stringify(arr, "\t")
	var file = FileAccess.open(SYNC_CHANGES_PATH, FileAccess.WRITE)
	if file:
		file.store_string(json_string)
		file.close()

func _load_change_queue() -> void:
	_change_queue.clear()
	if not FileAccess.file_exists(SYNC_CHANGES_PATH):
		return
	var file = FileAccess.open(SYNC_CHANGES_PATH, FileAccess.READ)
	if not file:
		return
	var json_string = file.get_as_text()
	file.close()
	var json = JSON.new()
	if json.parse(json_string) != OK:
		return
	var data = json.get_data()
	if data is Array:
		for d in data:
			if d is Dictionary:
				_change_queue.append(SyncChange.from_dict(d))
	print("[SyncState] 加载了 %d 条待同步变更" % _change_queue.size())


# ======================== 工具方法 ========================

## 秒 → 毫秒
func _to_ms(seconds: int) -> int:
	return seconds * 1000

## 毫秒 → 秒
func _to_sec(ms: int) -> int:
	@warning_ignore("integer_division")
	return ms / 1000

## 当前时间毫秒
func _now_ms() -> int:
	return int(Time.get_unix_time_from_system() * 1000)

## 获取设备类型
func _get_device_type() -> String:
	match OS.get_name():
		"Android":
			return "mobile"
		"iOS":
			return "mobile"
		"Windows", "macOS", "Linux":
			return "desktop"
		"Web":
			return "web"
		_:
			return "desktop"
