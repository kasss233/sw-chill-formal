extends Node

# --- 信号 ---
signal task_added(task: TaskData)
signal task_removed(task_id: int)
signal task_updated(task: TaskData) # title/due_time 等字段变化
signal task_state_changed(task: TaskData) # 完成状态变化（触发 UI 排序）
signal task_completed
signal tasks_reordered
signal data_loaded
signal task_deadline_reached(task: TaskData)
signal task_deadline_warning(task: TaskData)

# --- 内部状态 ---
var _tasks: Array[TaskData] = []
var _next_id: int = 1
var _deadline_timer: Timer = null

# 截止时间警告记录
var _warned_15min: Dictionary = {} # {task_id: bool}
var _warned_deadline: Dictionary = {} # {task_id: bool}

const SAVE_PATH = "user://task_data.json"

func _ready() -> void:
	# 创建截止时间检查定时器
	_deadline_timer = Timer.new()
	_deadline_timer.wait_time = 60.0
	_deadline_timer.autostart = true
	_deadline_timer.timeout.connect(_check_deadlines)
	add_child(_deadline_timer)

	load_data()

# ======================== 查询 API ========================

func get_all_tasks() -> Array[TaskData]:
	return _tasks.duplicate()

func get_incomplete_tasks() -> Array[TaskData]:
	var result: Array[TaskData] = []
	for task in _tasks:
		if not task.is_completed:
			result.append(task)
	return result

func get_completed_tasks() -> Array[TaskData]:
	var result: Array[TaskData] = []
	for task in _tasks:
		if task.is_completed:
			result.append(task)
	return result

func get_task_by_id(id: int) -> TaskData:
	for task in _tasks:
		if task.id == id:
			return task
	return null

func get_task_count() -> int:
	return _tasks.size()

func get_incomplete_count() -> int:
	var count = 0
	for task in _tasks:
		if not task.is_completed:
			count += 1
	return count

func get_completed_count() -> int:
	var count = 0
	for task in _tasks:
		if task.is_completed:
			count += 1
	return count

func get_overdue_tasks() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var now = Time.get_unix_time_from_system()
	for task in _tasks:
		if task.due_timestamp > 0 and now > task.due_timestamp and not task.is_completed:
			result.append({
				"id": task.id,
				"title": task.title,
				"is_completed": task.is_completed,
				"due_timestamp": task.due_timestamp,
				"finish_timestamp": task.finish_timestamp,
				"overdue_seconds": now - task.due_timestamp
			})
	return result

# ======================== 修改 API ========================

func add_task(title: String, due_timestamp: int = 0) -> TaskData:
	var task = TaskData.new(_next_id, title, due_timestamp, false)
	task.order = 0
	_next_id += 1

	# 未完成任务插入到列表最前面
	_tasks.insert(0, task)
	# 更新所有 order
	_update_orders()

	_save_data()
	task_added.emit(task)
	print("[TaskState] Added task(id: %d, title: %s)" % [task.id, task.title])
	return task

func remove_task(id: int) -> bool:
	for i in range(_tasks.size()):
		if _tasks[i].id == id:
			_tasks.remove_at(i)
			# 清理警告记录
			_warned_15min.erase(id)
			_warned_deadline.erase(id)
			_update_orders()
			_save_data()
			task_removed.emit(id)
			print("[TaskState] Removed task(id: %d)" % id)
			return true
	print("[TaskState] Task with id %d not found" % id)
	return false

func update_task_title(id: int, title: String) -> bool:
	var task = get_task_by_id(id)
	if task == null:
		return false
	task.title = title
	_save_data()
	task_updated.emit(task)
	print("[TaskState] Updated task(id: %d) title to '%s'" % [id, title])
	return true

func set_task_completed(id: int, completed: bool) -> bool:
	var task = get_task_by_id(id)
	if task == null:
		return false
	if task.is_completed == completed:
		return true

	task.is_completed = completed

	if completed:
		task.finish_timestamp = int(Time.get_unix_time_from_system())
		# 停止截止时间检查
		_warned_15min.erase(id)
		_warned_deadline.erase(id)
	else:
		task.finish_timestamp = 0
		# 取消完成时，如果截止时间已过期，重置截止时间
		if task.due_timestamp > 0:
			var now = Time.get_unix_time_from_system()
			if now > task.due_timestamp:
				task.due_timestamp = 0

	# 重新排序：移动到对应区域
	var old_index = _tasks.find(task)
	_tasks.remove_at(old_index)

	if completed:
		# 移动到已完成区域的第一个位置（即未完成任务末尾之后）
		var incomplete_count = 0
		for t in _tasks:
			if not t.is_completed:
				incomplete_count += 1
		_tasks.insert(incomplete_count, task)
	else:
		# 移动到未完成区域的第一个位置
		_tasks.insert(0, task)

	_update_orders()
	_save_data()
	task_state_changed.emit(task)
	if completed:
		task_completed.emit()
	print("[TaskState] Task(id: %d) completed=%s" % [id, completed])
	return true

func set_task_due_time(id: int, timestamp: int) -> bool:
	var task = get_task_by_id(id)
	if task == null:
		return false
	task.due_timestamp = timestamp

	# 重置警告标志
	_warned_15min.erase(id)
	_warned_deadline.erase(id)

	_save_data()
	task_updated.emit(task)
	print("[TaskState] Task(id: %d) due_time set to %d" % [id, timestamp])
	return true

## 在同类别中重排序
func reorder_task(id: int, new_position: int, is_completed: bool) -> bool:
	var task = get_task_by_id(id)
	if task == null:
		return false

	var old_index = _tasks.find(task)
	_tasks.remove_at(old_index)

	# 计算目标绝对索引
	var target_index: int
	if is_completed:
		var incomplete_count = 0
		for t in _tasks:
			if not t.is_completed:
				incomplete_count += 1
		target_index = incomplete_count + new_position
	else:
		target_index = new_position

	target_index = clamp(target_index, 0, _tasks.size())
	_tasks.insert(target_index, task)
	_update_orders()
	_save_data()
	tasks_reordered.emit()
	print("[TaskState] Task(id: %d) reordered to position %d" % [id, new_position])
	return true

## 拖拽重排序（UI 层调用，支持跨区域拖拽）
func reorder_by_drag(task_id: int, new_data_index: int, new_completed: bool) -> bool:
	var task = get_task_by_id(task_id)
	if task == null:
		return false

	var old_index = _tasks.find(task)
	var was_completed = task.is_completed

	_tasks.remove_at(old_index)

	# 插入到新位置
	new_data_index = clamp(new_data_index, 0, _tasks.size())
	_tasks.insert(new_data_index, task)

	# 如果跨区域拖拽，改变完成状态
	if was_completed != new_completed:
		task.is_completed = new_completed
		if new_completed:
			task.finish_timestamp = int(Time.get_unix_time_from_system())
		else:
			task.finish_timestamp = 0
			# 如果截止时间已过期，重置
			if task.due_timestamp > 0:
				var now = Time.get_unix_time_from_system()
				if now > task.due_timestamp:
					task.due_timestamp = 0

	_update_orders()
	_save_data()

	if was_completed != new_completed:
		task_state_changed.emit(task)
		if new_completed:
			task_completed.emit()
	else:
		tasks_reordered.emit()

	print("[TaskState] Task(id: %d) drag-reordered to index %d, completed=%s" % [task_id, new_data_index, new_completed])
	return true

func clear_completed() -> int:
	var removed_count = 0
	var i = _tasks.size() - 1
	while i >= 0:
		if _tasks[i].is_completed:
			var id = _tasks[i].id
			_tasks.remove_at(i)
			_warned_15min.erase(id)
			_warned_deadline.erase(id)
			task_removed.emit(id)
			removed_count += 1
		i -= 1
	if removed_count > 0:
		_update_orders()
		_save_data()
	print("[TaskState] Cleared %d completed tasks" % removed_count)
	return removed_count

# ======================== 持久化 ========================

func _save_data() -> void:
	var data = {
		"version": 1,
		"next_id": _next_id,
		"tasks": []
	}
	for task in _tasks:
		data["tasks"].append(task.to_dict())

	var json_string = JSON.stringify(data, "\t")
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(json_string)
		file.close()
	else:
		push_error("[TaskState] Failed to save data to %s" % SAVE_PATH)

func load_data() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		print("[TaskState] No save file found, starting fresh")
		data_loaded.emit()
		return

	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		push_error("[TaskState] Failed to open save file")
		data_loaded.emit()
		return

	var json_string = file.get_as_text()
	file.close()

	var json = JSON.new()
	var error = json.parse(json_string)
	if error != OK:
		push_error("[TaskState] Failed to parse save file: %s" % json.get_error_message())
		data_loaded.emit()
		return

	var data = json.get_data()
	if not data is Dictionary:
		push_error("[TaskState] Invalid save data format")
		data_loaded.emit()
		return

	_next_id = data.get("next_id", 1)
	_tasks.clear()

	var tasks_array = data.get("tasks", [])
	for task_dict in tasks_array:
		var task = TaskData.from_dict(task_dict)
		_tasks.append(task)

	print("[TaskState] Loaded %d tasks, next_id=%d" % [_tasks.size(), _next_id])
	data_loaded.emit()

## 导出数据（用于云端上传）
func export_data() -> Dictionary:
	var data = {
		"version": 1,
		"next_id": _next_id,
		"tasks": []
	}
	for task in _tasks:
		data["tasks"].append(task.to_dict())
	return data

## 导入数据（用于云端下载）
func import_data(data: Dictionary) -> void:
	if not data.has("tasks"):
		push_error("[TaskState] Invalid import data")
		return

	_next_id = data.get("next_id", 1)
	_tasks.clear()
	_warned_15min.clear()
	_warned_deadline.clear()

	var tasks_array = data.get("tasks", [])
	for task_dict in tasks_array:
		var task = TaskData.from_dict(task_dict)
		_tasks.append(task)

	_save_data()
	print("[TaskState] Imported %d tasks" % _tasks.size())
	data_loaded.emit()

# ======================== 截止时间检查 ========================

func _check_deadlines() -> void:
	var now = Time.get_unix_time_from_system()

	for task in _tasks:
		if task.is_completed or task.due_timestamp == 0:
			continue

		var time_remaining = task.due_timestamp - now

		# 检查是否到达截止时间
		if time_remaining <= 0 and not _warned_deadline.get(task.id, false):
			_warned_deadline[task.id] = true
			task_deadline_reached.emit(task)
			print("[TaskState] Task(id: %d) deadline reached!" % task.id)
			continue

		# 检查是否剩余15分钟（仅当总时间>30分钟时）
		if not _warned_15min.get(task.id, false):
			# 判断创建时到截止时间是否超过30分钟
			var total_time = task.due_timestamp - task.created_at
			if total_time > 1800 and time_remaining <= 900 and time_remaining > 0:
				_warned_15min[task.id] = true
				task_deadline_warning.emit(task)
				print("[TaskState] Task(id: %d) has 15 minutes remaining!" % task.id)

# ======================== 内部辅助 ========================

func _update_orders() -> void:
	for i in range(_tasks.size()):
		_tasks[i].order = i
