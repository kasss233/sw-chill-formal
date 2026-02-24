extends Node

## 成就数据状态单例（Data Autoload）
## 职责：维护每日任务/成就数据，提供统一 API，负责持久化与信号分发

signal daily_task_added(data: Dictionary)
signal daily_task_removed(item_id: int)
signal daily_task_updated(data: Dictionary)
signal daily_task_state_changed(data: Dictionary)

signal achievement_added(data: Dictionary)
signal achievement_removed(item_id: int)
signal achievement_updated(data: Dictionary)
signal achievement_state_changed(data: Dictionary)

signal data_loaded

# 存档路径：遵循 user:// 持久化约定
const SAVE_PATH := "user://achievement_data.json"

# 统一存放每日任务与成就，使用 category 区分
var _items: Array = []
# 自增 ID
var _next_id: int = 1

func _ready() -> void:
	# 启动时自动加载本地数据
	load_data()

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
	var data := _build_item_data("daily_task", title, description, target, current)
	_items.append(data)
	_save_data()
	daily_task_added.emit(data.duplicate(true))
	return data.duplicate(true)

## 添加成就
func add_achievement(title: String, description: String = "", target: int = 1, current: int = 0) -> Dictionary:
	var data := _build_item_data("achievement", title, description, target, current)
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
	item["completed"] = completed
	if completed:
		item["current"] = int(item.get("target", 1))
	_save_data()
	daily_task_state_changed.emit(item.duplicate(true))
	daily_task_updated.emit(item.duplicate(true))
	return true

## 显式设置成就完成状态（补充 API）
## - completed=true: current 自动补齐到 target
## - completed=false: 若 current 已达标则回退到 target-1，并重置 reward_claimed
func set_achievement_completed(item_id: int, completed: bool = true) -> bool:
	var item := _get_item_ref("achievement", item_id)
	if item.is_empty():
		return false

	var target: int = max(1, int(item.get("target", 1)))
	item["completed"] = completed
	if completed:
		item["current"] = target
	else:
		item["current"] = min(int(item.get("current", 0)), target - 1)
		item["reward_claimed"] = false

	_save_data()
	achievement_state_changed.emit(item.duplicate(true))
	achievement_updated.emit(item.duplicate(true))
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
	achievement_state_changed.emit(item.duplicate(true))
	achievement_updated.emit(item.duplicate(true))
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
		"items": _items.duplicate(true)
	}

## 导入数据（会覆盖当前数据并持久化）
func import_data(data: Dictionary) -> void:
	if not data.has("items"):
		push_error("[AchievementState] 导入数据缺少 items")
		return

	_next_id = int(data.get("next_id", 1))
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

## 写入本地文件
func _save_data() -> void:
	var data := {
		"version": 1,
		"next_id": _next_id,
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
		"reward_claimed": bool(data.get("reward_claimed", false))
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
	var removed_ids: Array[int] = []
	var i := _items.size() - 1
	while i >= 0:
		if str(_items[i].get("category", "")) == category:
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

	if target > 0:
		item["target"] = max(1, target)
	var safe_target: int = int(item.get("target", 1))
	item["current"] = clampi(current, 0, safe_target)
	item["completed"] = int(item.get("current", 0)) >= safe_target

	_save_data()
	if category == "achievement":
		achievement_updated.emit(item.duplicate(true))
		if bool(item.get("completed", false)):
			achievement_state_changed.emit(item.duplicate(true))
	else:
		daily_task_updated.emit(item.duplicate(true))
		if bool(item.get("completed", false)):
			daily_task_state_changed.emit(item.duplicate(true))
	return true

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
