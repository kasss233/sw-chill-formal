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
	_record_change(SyncChange.new("task", "delete", task_id, str(task_id)))

func _on_task_updated(task: TaskData) -> void:
	if _is_applying_remote:
		return
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
			"ordered_ids": ordered_ids
		}))

func _on_note_added(note: NoteData) -> void:
	if _is_applying_remote:
		return
	_record_change(SyncChange.new("note", "create", note.id, str(note.id), {
		"title": note.title,
		"content": note.content,
		"created_at": note.created_at,
	}))

func _on_note_removed(note_id: int) -> void:
	if _is_applying_remote:
		return
	_record_change(SyncChange.new("note", "delete", note_id, str(note_id)))

func _on_note_updated(note: NoteData) -> void:
	if _is_applying_remote:
		return
	_record_change(SyncChange.new("note", "update", note.id, str(note.id), {
		"title": note.title,
		"content": note.content,
		"updated_at": note.updated_at,
	}))

func _on_category_added(cat_name: String) -> void:
	if _is_applying_remote:
		return
	var position = NoteState.get_category_position(cat_name)
	_record_change(SyncChange.new("category", "create", 0, cat_name, {
		"name": cat_name,
		"position": position
	}))

func _on_category_removed(cat_name: String) -> void:
	if _is_applying_remote:
		return
	_record_change(SyncChange.new("category", "delete", 0, cat_name))


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

		# 通过 local_key 匹配（category 用 name，其他用 id）
		var same_item = false
		if new_change.resource == "category":
			same_item = existing.local_key == new_change.local_key and existing.local_key != ""
		else:
			same_item = existing.local_id == new_change.local_id and existing.local_id > 0

		if not same_item:
			continue

		# reorder：只保留最新一条
		if new_change.action == "reorder" and existing.action == "reorder":
			_change_queue.remove_at(i)
			break

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

	var changes_to_push: Array = []
	for change in _change_queue:
		var push_item = _convert_to_push_format(change)
		if push_item.size() > 0:
			changes_to_push.append(push_item)

	if changes_to_push.size() == 0:
		_change_queue.clear()
		_save_change_queue()
		return true

	var body = {
		"device_id": _device_id,
		"changes": changes_to_push
	}

	var result = await ApiClient.api_post("/sync/push", body)
	if not result.success:
		print("[SyncState] Push 失败: %s" % result.message)
		return false

	var data = result.data
	if not data is Dictionary:
		return false

	# 处理 results
	var results = data.get("results", [])
	_process_push_results(results)

	# 清空已处理的变更队列
	_change_queue.clear()
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

	match change.action:
		"create":
			item["data"] = change.data.duplicate(true)
			item["data"]["client_id"] = "local-%s" % str(change.local_id) if change.resource != "category" else "local-cat-%s" % change.local_key
			# 时间戳 s→ms
			if item["data"].has("created_at"):
				item["data"]["created_at"] = _to_ms(item["data"]["created_at"])
		"update":
			var server_id = _id_mapping.get_server_id(change.resource, change.local_key)
			if server_id == 0:
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
			var server_id: int = 0
			if change.resource == "category":
				server_id = _id_mapping.get_server_id("category", change.local_key)
			else:
				server_id = _id_mapping.get_server_id(change.resource, str(change.local_id))
			if server_id == 0:
				return {}  # 没有映射说明服务器没有此数据
			item["data"] = {"id": server_id}
		"reorder":
			item["data"] = change.data.duplicate(true)
		"full_replace":
			item["data"] = change.data.duplicate(true)

	return item


## 处理 push 返回的 results
func _process_push_results(results: Array) -> void:
	for r in results:
		if not r is Dictionary:
			continue
		var status = r.get("status", "")
		var resource = r.get("resource", "")
		var action = r.get("action", "")

		if status == "accepted" and action == "create":
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
						task.server_id = server_id
				elif resource == "note" and local_id > 0:
					var note = NoteState.get_note_by_id(local_id)
					if note:
						note.server_id = server_id


# ======================== Pull 流程 ========================

func _do_pull() -> bool:
	if not _is_registered or _device_id == "":
		return false

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
			_apply_remote_changes(changes)

		_last_sync_time = data.get("server_time", _last_sync_time)
		has_more = data.get("has_more", false)
		pull_count += 1

		print("[SyncState] Pull 第 %d 页: %d 条变更" % [pull_count, changes.size()])

	_save_sync_data()
	_id_mapping.save_to_file()
	return true


## 应用远程变更到本地
func _apply_remote_changes(changes: Array) -> void:
	_is_applying_remote = true

	for change in changes:
		if not change is Dictionary:
			continue
		var resource = change.get("resource", "")
		var action = change.get("action", "")
		var data = change.get("data", {})

		match resource:
			"task":
				_apply_remote_task_change(action, data)
			"note":
				_apply_remote_note_change(action, data)
			"category":
				_apply_remote_category_change(action, data)

	_is_applying_remote = false


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
			task.created_at = _to_sec(data.get("created_at", 0))
			task.updated_at = _to_sec(data.get("updated_at", 0))
			task.server_id = server_id
			TaskState.sync_create_task(task)
			_id_mapping.set_mapping("task", str(local_id), server_id)

		"update":
			var local_key = _id_mapping.get_local_key("task", server_id)
			if local_key == "":
				return
			var local_id = int(local_key)
			var fields = {}
			if data.has("title"):
				fields["title"] = data["title"]
			if data.has("is_completed"):
				fields["is_completed"] = data["is_completed"]
			if data.has("due_timestamp"):
				fields["due_timestamp"] = data["due_timestamp"]
			if data.has("finish_timestamp"):
				fields["finish_timestamp"] = data["finish_timestamp"]
			if data.has("updated_at"):
				fields["updated_at"] = _to_sec(data["updated_at"])
			TaskState.sync_update_task(local_id, fields)

		"delete":
			var local_key = _id_mapping.get_local_key("task", server_id)
			if local_key == "":
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
				return
			var local_id = int(local_key)
			var fields = {}
			if data.has("title"):
				fields["title"] = data["title"]
			if data.has("content"):
				fields["content"] = data["content"]
			if data.has("updated_at"):
				fields["updated_at"] = _to_sec(data["updated_at"])
			NoteState.sync_update_note(local_id, fields)

		"delete":
			var local_key = _id_mapping.get_local_key("note", server_id)
			if local_key == "":
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
			_id_mapping.set_mapping("category", name, server_id)

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
		var matched = false
		for li in local_items:
			if get_item_server_id.call(li) > 0:
				continue
			if _id_mapping.get_server_id(resource_name, str(get_item_id.call(li))) > 0:
				continue
			if get_item_title.call(li) == si.get("title", "") and abs(_to_ms(get_item_created_at.call(li)) - si.get("created_at", 0)) < 60000:
				_id_mapping.set_mapping(resource_name, str(get_item_id.call(li)), server_id)
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
			_id_mapping.set_mapping(resource_name, str(local_id), server_id)

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


## 全量同步 - 合并 categories
func _merge_full_sync_categories(server_categories: Array) -> void:
	var local_categories = NoteState.get_categories()

	for sc in server_categories:
		if not sc is Dictionary:
			continue
		var server_id = sc.get("id", 0)
		var name = sc.get("name", "")

		if _id_mapping.has_server_id("category", server_id):
			continue  # 已映射，跳过

		# 按名称匹配
		if name in local_categories:
			_id_mapping.set_mapping("category", name, server_id)
			continue

		# 服务器有本地无 → 创建
		var position = sc.get("position", NoteState.get_categories().size())
		NoteState.sync_insert_category_at(name, position)
		_id_mapping.set_mapping("category", name, server_id)

	# 本地有服务器无 → 加入 push 队列
	for cat in local_categories:
		if _id_mapping.get_server_id("category", cat) == 0:
			_change_queue.append(SyncChange.new("category", "create", 0, cat, {
				"name": cat,
				"position": NoteState.get_category_position(cat)
			}))


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

	var push_ok = await _do_push()
	var pull_ok = await _do_pull()

	var success = push_ok and pull_ok
	if success:
		_consecutive_failures = 0
	else:
		_consecutive_failures += 1

	_is_syncing = false
	sync_completed.emit(success, {"type": "incremental", "push": push_ok, "pull": pull_ok})


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
