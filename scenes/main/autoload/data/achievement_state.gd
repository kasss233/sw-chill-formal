extends Node

## 成就数据状态单例（Data Autoload）
## 职责：维护每日任务/成就数据，提供统一 API，负责持久化与信号分发

signal daily_task_added(data: Dictionary)
signal daily_task_removed(item_id: int)
signal daily_task_state_updated(data: Dictionary)
signal daily_task_completed(data: Dictionary)
signal daily_task_reward_claimed(data: Dictionary)

signal achievement_added(data: Dictionary)
signal achievement_removed(item_id: int)
signal achievement_state_updated(data: Dictionary)
signal achievement_completed(data: Dictionary)
signal achievement_reward_claimed(data: Dictionary)

signal data_loaded

# 存档路径：遵循 user:// 持久化约定
const SAVE_PATH := "user://achievement_data.json"

const AUTO_DAILY_TASK_DEFS := [
	{
		"auto_key": "todo_complete_5",
		"title": "完成五个待办任务",
		"description": "今日完成 5 个待办任务",
		"target": 5
	},
	{
		"auto_key": "pomodoro_complete_2",
		"title": "完成两次番茄钟",
		"description": "今日完成 2 次番茄钟工作阶段",
		"target": 2
	}
]

const AUTO_ACHIEVEMENT_DEFS := [
	{
		"auto_key": "achievement_todo_complete_50",
		"title": "累计完成50个待办任务",
		"description": "累计完成 50 个待办任务",
		"target": 50
	},
	{
		"auto_key": "achievement_pomodoro_complete_20",
		"title": "累计完成20次番茄钟",
		"description": "累计完成 20 次番茄钟工作阶段",
		"target": 20
	}
]

# 统一存放每日任务与成就，使用 category 区分
var _items: Array = []
# 自增 ID
var _next_id: int = 1
var _daily_claimed_records: Dictionary = {}
var _last_daily_refresh_key: String = ""
var _daily_check_timer: Timer = null

func _ready() -> void:
	# 启动时自动加载本地数据
	load_data()
	_connect_external_state_signals()
	_setup_daily_check_timer()
	_refresh_daily_tasks()

# ======================== 查询 API ========================

## 获取每日任务列表（深拷贝，避免 UI 侧误改）
func get_daily_tasks() -> Array:
	var result: Array = []
	for item in _items:
		if str(item.get("category", "")) == "daily_task":
			result.append(item.duplicate(true))
	return result

## 获取成就列表（深拷贝，避免 UI 侧误改）
func get_achievements() -> Array:
	var result: Array = []
	for item in _items:
		if str(item.get("category", "")) == "achievement":
			result.append(item.duplicate(true))
	return result

## 获取每日任务数量
func get_daily_task_count() -> int:
	var count := 0
	for item in _items:
		if str(item.get("category", "")) == "daily_task":
			count += 1
	return count

## 获取成就数量
func get_achievement_count() -> int:
	var count := 0
	for item in _items:
		if str(item.get("category", "")) == "achievement":
			count += 1
	return count

# ======================== 修改 API ========================

## 添加每日任务
func add_daily_task(title: String, description: String = "", target: int = 1, current: int = 0) -> Dictionary:
	return add_daily_task_by_config({
		"title": title,
		"description": description,
		"target": target,
		"current": current
	})

## 统一添加每日任务接口（支持自动任务/进度来源）
## config 字段：
## - title: String
## - description: String
## - target: int
## - current: int（可选）
## - auto_key: String（可选，系统任务唯一键）
func add_daily_task_by_config(config: Dictionary) -> Dictionary:
	var title := str(config.get("title", ""))
	if title.is_empty():
		return {}

	var description := str(config.get("description", ""))
	var target: int = max(1, int(config.get("target", 1)))
	var current: int = int(config.get("current", 0))
	var auto_key := str(config.get("auto_key", ""))
	var today_key := DateUtil.get_today_key()

	if not auto_key.is_empty():
		var existing := _get_daily_task_ref_by_auto_key(auto_key)
		if not existing.is_empty():
			var changed := false
			changed = _apply_daily_task_meta(existing, title, description, target, auto_key) or changed
			if str(existing.get("daily_date_key", "")) != today_key:
				existing["daily_date_key"] = today_key
				existing["current"] = 0
				existing["completed"] = false
				existing["reward_claimed"] = false
				changed = true
			var claimed_today := _is_auto_daily_reward_claimed_today(auto_key)
			if bool(existing.get("reward_claimed", false)) != claimed_today:
				existing["reward_claimed"] = claimed_today
				changed = true
			if changed:
				_save_data()
				_emit_state_updated("daily_task", existing)
			return existing.duplicate(true)

	var data := _build_item_data("daily_task", title, description, target, current)
	data["auto_key"] = auto_key
	data["daily_date_key"] = today_key
	if not auto_key.is_empty() and _is_auto_daily_reward_claimed_today(auto_key):
		data["reward_claimed"] = true
	_items.append(data)
	_save_data()
	daily_task_added.emit(data.duplicate(true))
	return data.duplicate(true)

## 添加成就
func add_achievement(title: String, description: String = "", target: int = 1, current: int = 0) -> Dictionary:
	return add_achievement_by_config({
		"title": title,
		"description": description,
		"target": target,
		"current": current
	})


## 统一添加成就接口（支持自动成就）
## config 字段：
## - title: String
## - description: String
## - target: int
## - current: int（可选）
## - auto_key: String（可选，系统成就唯一键）
func add_achievement_by_config(config: Dictionary) -> Dictionary:
	var title := str(config.get("title", ""))
	if title.is_empty():
		return {}

	var description := str(config.get("description", ""))
	var target: int = max(1, int(config.get("target", 1)))
	var current: int = int(config.get("current", 0))
	var auto_key := str(config.get("auto_key", ""))

	if not auto_key.is_empty():
		var existing := _get_achievement_ref_by_auto_key(auto_key)
		if not existing.is_empty():
			var changed := _apply_achievement_meta(existing, title, description, target, auto_key)
			if changed:
				_save_data()
				_emit_state_updated("achievement", existing)
			return existing.duplicate(true)

	var data := _build_item_data("achievement", title, description, target, current)
	data["auto_key"] = auto_key
	_items.append(data)
	_save_data()
	achievement_added.emit(data.duplicate(true))
	return data.duplicate(true)

## 删除单个每日任务
func remove_daily_task(item_id: int) -> bool:
	return _remove_item("daily_task", item_id)

## 删除单个成就
func remove_achievement(item_id: int) -> bool:
	return _remove_item("achievement", item_id)

## 清空所有每日任务
func clear_daily_tasks() -> int:
	return _clear_items_by_category("daily_task")

## 清空所有成就
func clear_achievements() -> int:
	return _clear_items_by_category("achievement")

## 设置每日任务进度
func set_daily_task_progress(item_id: int, current: int, target: int = -1) -> bool:
	return _set_progress("daily_task", item_id, current, target)

## 设置成就进度
func set_achievement_progress(item_id: int, current: int, target: int = -1) -> bool:
	return _set_progress("achievement", item_id, current, target)

## 显式设置每日任务完成状态
func set_daily_task_completed(item_id: int, completed: bool = true) -> bool:
	var item := _get_item_ref("daily_task", item_id)
	if item.is_empty():
		return false
	if _is_new_day_for_item(item):
		_reset_daily_task_item(item, DateUtil.get_today_key())

	var old_completed := bool(item.get("completed", false))
	var old_current := int(item.get("current", 0))
	var old_reward_claimed := bool(item.get("reward_claimed", false))
	var new_current := old_current
	var new_reward_claimed := old_reward_claimed

	if completed:
		new_current = int(item.get("target", 1))
	else:
		new_reward_claimed = false

	if old_completed == completed and old_current == new_current and old_reward_claimed == new_reward_claimed:
		return true

	item["completed"] = completed
	item["current"] = new_current
	item["reward_claimed"] = new_reward_claimed
	item["daily_date_key"] = DateUtil.get_today_key()
	_save_data()
	if completed and not old_completed:
		_emit_completed("daily_task", item)
	else:
		_emit_state_updated("daily_task", item)
	return true

## 显式设置成就完成状态（补充 API）
## - completed=true: current 自动补齐到 target
## - completed=false: 若 current 已达标则回退到 target-1，并重置 reward_claimed
func set_achievement_completed(item_id: int, completed: bool = true) -> bool:
	var item := _get_item_ref("achievement", item_id)
	if item.is_empty():
		return false

	var old_completed := bool(item.get("completed", false))
	var old_current := int(item.get("current", 0))
	var old_reward_claimed := bool(item.get("reward_claimed", false))
	var target: int = max(1, int(item.get("target", 1)))
	var new_current := old_current
	var new_reward_claimed := old_reward_claimed
	if completed:
		new_current = target
	else:
		new_current = min(old_current, target - 1)
		new_reward_claimed = false

	if old_completed == completed and old_current == new_current and old_reward_claimed == new_reward_claimed:
		return true

	item["completed"] = completed
	item["current"] = new_current
	item["reward_claimed"] = new_reward_claimed

	_save_data()
	if completed and not old_completed:
		_emit_completed("achievement", item)
	else:
		_emit_state_updated("achievement", item)
	return true

## 领取成就奖励（仅完成且未领取时成功）
func claim_achievement(item_id: int) -> bool:
	var item := _get_item_ref("achievement", item_id)
	if item.is_empty():
		return false
	if not bool(item.get("completed", false)):
		return false
	if bool(item.get("reward_claimed", false)):
		return false
	item["reward_claimed"] = true
	_save_data()
	_emit_reward_claimed("achievement", item)
	return true

## 领取每日任务奖励（仅完成且未领取时成功）
func claim_daily_task(item_id: int) -> bool:
	var item := _get_item_ref("daily_task", item_id)
	if item.is_empty():
		return false
	if not bool(item.get("completed", false)):
		return false
	if bool(item.get("reward_claimed", false)):
		return false
	item["reward_claimed"] = true
	var auto_key := str(item.get("auto_key", ""))
	if not auto_key.is_empty():
		_mark_auto_daily_reward_claimed_today(auto_key)
	_save_data()
	_emit_reward_claimed("daily_task", item)
	return true

# ======================== 持久化 ========================

## 从本地读取数据
func load_data() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		data_loaded.emit()
		return

	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		push_error("[AchievementState] 打开存档失败")
		data_loaded.emit()
		return

	var json_string := file.get_as_text()
	file.close()

	var json := JSON.new()
	if json.parse(json_string) != OK:
		push_error("[AchievementState] 解析存档失败: %s" % json.get_error_message())
		data_loaded.emit()
		return

	var data = json.get_data()
	if not (data is Dictionary):
		push_error("[AchievementState] 存档格式错误")
		data_loaded.emit()
		return

	_next_id = int(data.get("next_id", 1))
	_daily_claimed_records = data.get("daily_claimed_records", {})
	if not (_daily_claimed_records is Dictionary):
		_daily_claimed_records = {}
	_items.clear()

	var items: Array = data.get("items", [])
	for raw in items:
		if raw is Dictionary:
			var normalized := _normalize_item(raw)
			if not normalized.is_empty():
				_items.append(normalized)

	# 修正 _next_id，防止旧存档 next_id 错误导致 ID 冲突
	var max_id := 0
	for item in _items:
		max_id = max(max_id, int(item.get("id", 0)))
	_next_id = max(_next_id, max_id + 1)

	data_loaded.emit()

## 导出数据（云同步/调试可用）
func export_data() -> Dictionary:
	return {
		"version": 1,
		"next_id": _next_id,
		"daily_claimed_records": _daily_claimed_records.duplicate(true),
		"items": _items.duplicate(true)
	}

## 导入数据（会覆盖当前数据并持久化）
func import_data(data: Dictionary) -> void:
	if not data.has("items"):
		push_error("[AchievementState] 导入数据缺少 items")
		return

	_next_id = int(data.get("next_id", 1))
	_daily_claimed_records = data.get("daily_claimed_records", {})
	if not (_daily_claimed_records is Dictionary):
		_daily_claimed_records = {}
	_items.clear()

	var items: Array = data.get("items", [])
	for raw in items:
		if raw is Dictionary:
			var normalized := _normalize_item(raw)
			if not normalized.is_empty():
				_items.append(normalized)

	var max_id := 0
	for item in _items:
		max_id = max(max_id, int(item.get("id", 0)))
	_next_id = max(_next_id, max_id + 1)

	_save_data()
	data_loaded.emit()
	_refresh_daily_tasks()


## 同步导入数据（直接导入后刷新每日任务）
func import_sync_data(data: Dictionary) -> void:
	import_data(data)

## 写入本地文件
func _save_data() -> void:
	var data := {
		"version": 1,
		"next_id": _next_id,
		"daily_claimed_records": _daily_claimed_records,
		"items": _items
	}
	var json_string := JSON.stringify(data, "\t")
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("[AchievementState] 保存失败: %s" % SAVE_PATH)
		return
	file.store_string(json_string)
	file.close()

# ======================== 内部辅助 ========================

## 构建标准条目数据
func _build_item_data(category: String, title: String, description: String, target: int, current: int) -> Dictionary:
	var safe_target: int = max(1, target)
	var safe_current: int = clampi(current, 0, safe_target)
	var completed: bool = safe_current >= safe_target
	var data := {
		"id": _next_id,
		"category": category,
		"title": title,
		"description": description,
		"target": safe_target,
		"current": safe_current,
		"completed": completed,
		"reward_claimed": false
	}
	_next_id += 1
	return data


func _setup_daily_check_timer() -> void:
	_daily_check_timer = Timer.new()
	_daily_check_timer.wait_time = 60.0
	_daily_check_timer.one_shot = false
	_daily_check_timer.autostart = true
	_daily_check_timer.timeout.connect(_on_daily_check_timer_timeout)
	add_child(_daily_check_timer)


func _connect_external_state_signals() -> void:
	if TaskState and TaskState.has_signal("task_state_changed"):
		if not TaskState.task_state_changed.is_connected(_on_task_state_changed):
			TaskState.task_state_changed.connect(_on_task_state_changed)
	if TaskState and TaskState.has_signal("task_completed"):
		if not TaskState.task_completed.is_connected(_on_task_completed):
			TaskState.task_completed.connect(_on_task_completed)
	if TaskState and TaskState.has_signal("data_loaded"):
		if not TaskState.data_loaded.is_connected(_on_task_state_data_loaded):
			TaskState.data_loaded.connect(_on_task_state_data_loaded)
	if PomodoroState and PomodoroState.has_signal("work_phase_completed"):
		if not PomodoroState.work_phase_completed.is_connected(_on_pomodoro_work_phase_completed):
			PomodoroState.work_phase_completed.connect(_on_pomodoro_work_phase_completed)


func _on_daily_check_timer_timeout() -> void:
	_refresh_daily_tasks()


func _on_task_state_changed(_task) -> void:
	_refresh_daily_tasks()
	_sync_auto_achievement_progress()


func _on_task_completed() -> void:
	_increment_auto_achievement_progress("achievement_todo_complete_50")


func _on_task_state_data_loaded() -> void:
	_refresh_daily_tasks()
	_sync_auto_achievement_progress()


func _on_pomodoro_work_phase_completed() -> void:
	_refresh_daily_tasks()
	_increment_pomodoro_daily_task_progress()
	_increment_auto_achievement_progress("achievement_pomodoro_complete_20")


func _refresh_daily_tasks() -> void:
	var today_key := DateUtil.get_today_key()

	if _last_daily_refresh_key != today_key:
		_reset_all_daily_tasks_for_new_day(today_key)

	_ensure_builtin_daily_tasks()
	_ensure_builtin_achievements()
	_sync_todo_completed_daily_task()
	_sync_auto_achievement_progress()

	_last_daily_refresh_key = today_key


func _ensure_builtin_daily_tasks() -> void:
	for def in AUTO_DAILY_TASK_DEFS:
		add_daily_task_by_config(def)


func _ensure_builtin_achievements() -> void:
	for def in AUTO_ACHIEVEMENT_DEFS:
		add_achievement_by_config(def)


func _sync_todo_completed_daily_task() -> void:
	var today_key := DateUtil.get_today_key()
	var completed_today := 0
	if TaskState and TaskState.has_method("get_completed_tasks"):
		var completed_tasks = TaskState.get_completed_tasks()
		for task in completed_tasks:
			if task == null:
				continue
			var finish_timestamp := int(task.finish_timestamp)
			if finish_timestamp <= 0:
				continue
			if DateUtil.get_day_key_from_unix(finish_timestamp) == today_key:
				completed_today += 1

	var task := _get_daily_task_ref_by_auto_key("todo_complete_5")
	if task.is_empty():
		return
	set_daily_task_progress(int(task.get("id", -1)), completed_today)


func _increment_pomodoro_daily_task_progress() -> void:
	var task := _get_daily_task_ref_by_auto_key("pomodoro_complete_2")
	if task.is_empty():
		return

	var item_id := int(task.get("id", -1))
	if item_id <= 0:
		return

	var old_current: int = int(task.get("current", 0))
	set_daily_task_progress(item_id, old_current + 1)


func _sync_auto_achievement_progress() -> void:
	if TaskState and TaskState.has_method("get_completed_count"):
		var completed_count :int= max(0, int(TaskState.get_completed_count()))
		var achievement := _get_achievement_ref_by_auto_key("achievement_todo_complete_50")
		if not achievement.is_empty():
			var item_id := int(achievement.get("id", -1))
			if item_id > 0:
				var old_current := int(achievement.get("current", 0))
				if completed_count > old_current:
					set_achievement_progress(item_id, completed_count)


func _increment_auto_achievement_progress(auto_key: String, delta: int = 1) -> void:
	if delta <= 0:
		return
	var achievement := _get_achievement_ref_by_auto_key(auto_key)
	if achievement.is_empty():
		return
	var item_id := int(achievement.get("id", -1))
	if item_id <= 0:
		return
	var old_current := int(achievement.get("current", 0))
	set_achievement_progress(item_id, old_current + delta)


func _reset_all_daily_tasks_for_new_day(today_key: String) -> void:
	for item in _items:
		if str(item.get("category", "")) != "daily_task":
			continue
		if not _is_new_day_for_item(item):
			continue

		var item_id := int(item.get("id", -1))
		if item_id <= 0:
			continue

		set_daily_task_progress(item_id, 0)
		set_daily_task_completed(item_id, false)
		var updated_item := _get_item_ref("daily_task", item_id)
		if not updated_item.is_empty():
			updated_item["daily_date_key"] = today_key


func _is_new_day_for_item(item: Dictionary) -> bool:
	return str(item.get("daily_date_key", "")) != DateUtil.get_today_key()


func _reset_daily_task_item(item: Dictionary, today_key: String) -> void:
	item["current"] = 0
	item["completed"] = false
	item["reward_claimed"] = false
	item["daily_date_key"] = today_key


func _apply_daily_task_meta(item: Dictionary, title: String, description: String, target: int, auto_key: String) -> bool:
	var changed := false
	if str(item.get("title", "")) != title:
		item["title"] = title
		changed = true
	if str(item.get("description", "")) != description:
		item["description"] = description
		changed = true
	if int(item.get("target", 1)) != target:
		item["target"] = target
		if int(item.get("current", 0)) > target:
			item["current"] = target
		item["completed"] = int(item.get("current", 0)) >= target
		changed = true
	if str(item.get("auto_key", "")) != auto_key:
		item["auto_key"] = auto_key
		changed = true
	return changed


func _apply_achievement_meta(item: Dictionary, title: String, description: String, target: int, auto_key: String) -> bool:
	var changed := false
	if str(item.get("title", "")) != title:
		item["title"] = title
		changed = true
	if str(item.get("description", "")) != description:
		item["description"] = description
		changed = true
	if int(item.get("target", 1)) != target:
		item["target"] = target
		if int(item.get("current", 0)) > target:
			item["current"] = target
		item["completed"] = int(item.get("current", 0)) >= target
		changed = true
	if str(item.get("auto_key", "")) != auto_key:
		item["auto_key"] = auto_key
		changed = true
	return changed


func _get_daily_task_ref_by_auto_key(auto_key: String) -> Dictionary:
	for item in _items:
		if str(item.get("category", "")) != "daily_task":
			continue
		if str(item.get("auto_key", "")) == auto_key:
			return item
	return {}


func _get_achievement_ref_by_auto_key(auto_key: String) -> Dictionary:
	for item in _items:
		if str(item.get("category", "")) != "achievement":
			continue
		if str(item.get("auto_key", "")) == auto_key:
			return item
	return {}


func _is_auto_daily_reward_claimed_today(auto_key: String) -> bool:
	if auto_key.is_empty():
		return false
	var today_key := DateUtil.get_today_key()
	var day_records = _daily_claimed_records.get(today_key, {})
	if not (day_records is Dictionary):
		return false
	return bool(day_records.get(auto_key, false))


func _mark_auto_daily_reward_claimed_today(auto_key: String) -> void:
	if auto_key.is_empty():
		return
	var today_key := DateUtil.get_today_key()
	var day_records = _daily_claimed_records.get(today_key, {})
	if not (day_records is Dictionary):
		day_records = {}
	day_records[auto_key] = true
	_daily_claimed_records[today_key] = day_records


## 标准化存档条目并进行安全兜底
func _normalize_item(data: Dictionary) -> Dictionary:
	var category := str(data.get("category", ""))
	if category != "daily_task" and category != "achievement":
		return {}

	var id: int = int(data.get("id", -1))
	if id <= 0:
		return {}

	var target: int = max(1, int(data.get("target", 1)))
	var current: int = clampi(int(data.get("current", 0)), 0, target)
	var completed: bool = bool(data.get("completed", false))
	if completed:
		current = target

	return {
		"id": id,
		"category": category,
		"title": str(data.get("title", "")),
		"description": str(data.get("description", "")),
		"target": target,
		"current": current,
		"completed": completed,
		"reward_claimed": bool(data.get("reward_claimed", false)),
		"auto_key": str(data.get("auto_key", "")),
		"daily_date_key": str(data.get("daily_date_key", ""))
	}

## 删除单个条目
func _remove_item(category: String, item_id: int) -> bool:
	var index := _find_item_index(category, item_id)
	if index == -1:
		return false
	_items.remove_at(index)
	_save_data()
	if category == "achievement":
		achievement_removed.emit(item_id)
	else:
		daily_task_removed.emit(item_id)
	return true

## 批量清空某个分类
func _clear_items_by_category(category: String) -> int:
	var preserved_auto_keys: Dictionary = {}
	if category == "daily_task":
		for def in AUTO_DAILY_TASK_DEFS:
			if def is Dictionary:
				var auto_key := str(def.get("auto_key", ""))
				if not auto_key.is_empty():
					preserved_auto_keys[auto_key] = true
	elif category == "achievement":
		for def in AUTO_ACHIEVEMENT_DEFS:
			if def is Dictionary:
				var auto_key := str(def.get("auto_key", ""))
				if not auto_key.is_empty():
					preserved_auto_keys[auto_key] = true

	var removed_ids: Array[int] = []
	var i := _items.size() - 1
	while i >= 0:
		if str(_items[i].get("category", "")) == category:
			if category == "daily_task" or category == "achievement":
				var item_auto_key := str(_items[i].get("auto_key", ""))
				if preserved_auto_keys.has(item_auto_key):
					i -= 1
					continue
			removed_ids.append(int(_items[i].get("id", -1)))
			_items.remove_at(i)
		i -= 1

	if removed_ids.is_empty():
		return 0

	_save_data()
	for item_id in removed_ids:
		if category == "achievement":
			achievement_removed.emit(item_id)
		else:
			daily_task_removed.emit(item_id)
	return removed_ids.size()

## 通用进度更新逻辑
func _set_progress(category: String, item_id: int, current: int, target: int) -> bool:
	var item := _get_item_ref(category, item_id)
	if item.is_empty():
		return false
	if category == "daily_task" and _is_new_day_for_item(item):
		_reset_daily_task_item(item, DateUtil.get_today_key())

	var old_target := int(item.get("target", 1))
	var old_current := int(item.get("current", 0))
	var old_completed := bool(item.get("completed", false))
	var old_reward_claimed := bool(item.get("reward_claimed", false))

	if target > 0:
		item["target"] = max(1, target)
	var safe_target: int = int(item.get("target", 1))
	item["current"] = clampi(current, 0, safe_target)
	item["completed"] = int(item.get("current", 0)) >= safe_target
	if category == "daily_task":
		item["daily_date_key"] = DateUtil.get_today_key()
		if not bool(item.get("completed", false)):
			item["reward_claimed"] = false

	var changed := old_target != int(item.get("target", 1))
	changed = changed or old_current != int(item.get("current", 0))
	changed = changed or old_completed != bool(item.get("completed", false))
	changed = changed or old_reward_claimed != bool(item.get("reward_claimed", false))
	if not changed:
		return true

	_save_data()
	var new_completed := bool(item.get("completed", false))
	if new_completed and not old_completed:
		_emit_completed(category, item)
	else:
		_emit_state_updated(category, item)
	return true


func _emit_state_updated(category: String, item: Dictionary) -> void:
	var payload := item.duplicate(true)
	if category == "daily_task":
		daily_task_state_updated.emit(payload)
	else:
		achievement_state_updated.emit(payload)


func _emit_completed(category: String, item: Dictionary) -> void:
	var payload := item.duplicate(true)
	if category == "daily_task":
		daily_task_completed.emit(payload)
	else:
		achievement_completed.emit(payload)


func _emit_reward_claimed(category: String, item: Dictionary) -> void:
	var payload := item.duplicate(true)
	if category == "daily_task":
		daily_task_reward_claimed.emit(payload)
	else:
		achievement_reward_claimed.emit(payload)

## 获取条目引用（内部可写）
func _get_item_ref(category: String, item_id: int) -> Dictionary:
	var index := _find_item_index(category, item_id)
	if index == -1:
		return {}
	return _items[index]

## 查找条目索引
func _find_item_index(category: String, item_id: int) -> int:
	for index in range(_items.size()):
		var item: Dictionary = _items[index]
		if str(item.get("category", "")) == category and int(item.get("id", -1)) == item_id:
			return index
	return -1
