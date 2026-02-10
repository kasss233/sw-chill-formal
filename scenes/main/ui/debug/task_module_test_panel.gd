extends Control

## TaskModule测试页 - 测试 TaskState 单例

# UI节点引用

@onready var info_label: RichTextLabel = $MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/InfoLabel
@onready var task_title_input: LineEdit = $MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/InputSection/TaskTitleInput
@onready var task_id_input: LineEdit = $MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/InputSection/TaskIdInput
@onready var task_position_input: LineEdit = $MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/InputSection/TaskPositionInput
@onready var due_timestamp_input: LineEdit = $MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/InputSection/DueTimestampInput

# 测试按钮
@onready var add_task_btn: Button = $MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/ButtonSection/AddTaskBtn
@onready var update_title_btn: Button = $MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/ButtonSection/UpdateTitleBtn
@onready var mark_completed_btn: Button = $MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/ButtonSection/MarkCompletedBtn
@onready var mark_uncompleted_btn: Button = $MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/ButtonSection/MarkUncompletedBtn
@onready var remove_task_btn: Button = $MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/ButtonSection/RemoveTaskBtn
@onready var reorder_task_btn: Button = $MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/ButtonSection/ReorderTaskBtn
@onready var get_task_info_btn: Button = $MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/ButtonSection/GetTaskInfoBtn
@onready var get_all_tasks_btn: Button = $MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/ButtonSection/GetAllTasksBtn
@onready var set_due_time_btn: Button = $MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/ButtonSection/SetDueTimeBtn
@onready var get_overdue_tasks_btn: Button = $MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/ButtonSection/GetOverdueTasksBtn
@onready var is_task_overdue_btn: Button = $MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/ButtonSection/IsTaskOverdueBtn

var last_added_task_id: int = -1  # 记录最后添加的任务ID

func _ready() -> void:
	# 连接按钮信号
	add_task_btn.pressed.connect(_on_add_task_pressed)
	update_title_btn.pressed.connect(_on_update_title_pressed)
	mark_completed_btn.pressed.connect(_on_mark_completed_pressed)
	mark_uncompleted_btn.pressed.connect(_on_mark_uncompleted_pressed)
	remove_task_btn.pressed.connect(_on_remove_task_pressed)
	reorder_task_btn.pressed.connect(_on_reorder_task_pressed)
	get_task_info_btn.pressed.connect(_on_get_task_info_pressed)
	get_all_tasks_btn.pressed.connect(_on_get_all_tasks_pressed)
	set_due_time_btn.pressed.connect(_on_set_due_time_pressed)
	get_overdue_tasks_btn.pressed.connect(_on_get_overdue_tasks_pressed)
	is_task_overdue_btn.pressed.connect(_on_is_task_overdue_pressed)

	_log_info("TaskModule测试面板已就绪")
	_log_info("所有数据操作通过 TaskState 单例执行")

## 测试: 添加任务
func _on_add_task_pressed() -> void:
	var title = task_title_input.text
	if title.is_empty():
		title = "测试任务 " + str(Time.get_ticks_msec())

	_log_info("调用 TaskState.add_task(title='%s')" % title)
	var task = TaskState.add_task(title)
	last_added_task_id = task.id
	_log_success("任务已添加，ID: %d" % task.id)
	task_id_input.text = str(task.id)

## 测试: 更新任务标题
func _on_update_title_pressed() -> void:
	var id = task_id_input.text.to_int()
	var new_title = task_title_input.text

	if new_title.is_empty():
		_log_error("请输入新标题")
		return

	_log_info("调用 TaskState.update_task_title(id=%d, title='%s')" % [id, new_title])
	var success = TaskState.update_task_title(id, new_title)
	if success:
		_log_success("任务标题已更新")
	else:
		_log_error("更新失败，任务ID不存在")

## 测试: 标记任务为已完成
func _on_mark_completed_pressed() -> void:
	var id = task_id_input.text.to_int()
	_log_info("调用 TaskState.set_task_completed(id=%d, completed=true)" % id)
	var success = TaskState.set_task_completed(id, true)

	if success:
		_log_success("任务已标记为完成")
	else:
		_log_error("操作失败")

## 测试: 标记任务为未完成
func _on_mark_uncompleted_pressed() -> void:
	var id = task_id_input.text.to_int()
	_log_info("调用 TaskState.set_task_completed(id=%d, completed=false)" % id)
	var success = TaskState.set_task_completed(id, false)

	if success:
		_log_success("任务已标记为未完成")
	else:
		_log_error("操作失败")

## 测试: 删除任务
func _on_remove_task_pressed() -> void:
	var id = task_id_input.text.to_int()
	_log_info("调用 TaskState.remove_task(id=%d)" % id)
	var success = TaskState.remove_task(id)

	if success:
		_log_success("任务已删除")
	else:
		_log_error("删除失败")

## 测试: 调整任务顺序
func _on_reorder_task_pressed() -> void:
	var id = task_id_input.text.to_int()
	var new_position = task_position_input.text.to_int()

	var task = TaskState.get_task_by_id(id)
	if task == null:
		_log_error("任务不存在")
		return

	_log_info("调用 TaskState.reorder_task(id=%d, new_position=%d)" % [id, new_position])
	var success = TaskState.reorder_task(id, new_position, task.is_completed)

	if success:
		_log_success("任务顺序已调整")
	else:
		_log_error("调整失败，请检查任务ID和位置是否有效")

## 测试: 获取任务信息
func _on_get_task_info_pressed() -> void:
	var id = task_id_input.text.to_int()
	_log_info("调用 TaskState.get_task_by_id(id=%d)" % id)
	var task = TaskState.get_task_by_id(id)

	if task == null:
		_log_error("任务不存在")
	else:
		_log_success("任务信息:")
		_log_data(JSON.stringify(task.to_dict(), "  "))

## 测试: 获取所有任务
func _on_get_all_tasks_pressed() -> void:
	_log_info("调用 TaskState.get_all_tasks()")
	var all_tasks = TaskState.get_all_tasks()

	_log_success("共有 %d 个任务:" % all_tasks.size())
	for task in all_tasks:
		_log_data("  - [%d] %s (完成: %s)" % [task.id, task.title, task.is_completed])

## 日志输出 - 普通信息
func _log_info(message: String) -> void:
	info_label.append_text("[color=white]%s[/color]\n" % message)
	print("[TaskModuleTest] %s" % message)

## 日志输出 - 成功信息
func _log_success(message: String) -> void:
	info_label.append_text("[color=green]%s[/color]\n" % message)
	print("[TaskModuleTest] %s" % message)

## 日志输出 - 错误信息
func _log_error(message: String) -> void:
	info_label.append_text("[color=red]%s[/color]\n" % message)
	print("[TaskModuleTest] ERROR: %s" % message)

## 日志输出 - 数据信息
func _log_data(message: String) -> void:
	info_label.append_text("[color=cyan]%s[/color]\n" % message)
	print("[TaskModuleTest] %s" % message)

## 测试: 设置任务截止时间
func _on_set_due_time_pressed() -> void:
	var id = task_id_input.text.to_int()
	var due_timestamp = due_timestamp_input.text.to_int()

	if due_timestamp == 0:
		due_timestamp = Time.get_unix_time_from_system() + 3600
		_log_info("未输入时间戳，默认设置为1小时后: %d" % due_timestamp)

	_log_info("调用 TaskState.set_task_due_time(id=%d, timestamp=%d)" % [id, due_timestamp])
	var success = TaskState.set_task_due_time(id, due_timestamp)

	if success:
		_log_success("任务截止时间已设置")
		var task = TaskState.get_task_by_id(id)
		if task:
			_log_data("  格式化时间: %s" % task.get_formatted_due_time())
	else:
		_log_error("设置失败，任务ID不存在")

## 测试: 获取过期任务列表
func _on_get_overdue_tasks_pressed() -> void:
	_log_info("调用 TaskState.get_overdue_tasks()")
	var overdue_tasks = TaskState.get_overdue_tasks()

	if overdue_tasks.is_empty():
		_log_success("没有过期任务")
	else:
		_log_success("共有 %d 个过期任务:" % overdue_tasks.size())
		for task in overdue_tasks:
			var overdue_hours = task.overdue_seconds / 3600.0
			_log_data("  - [%d] %s (过期: %.1f小时)" % [task.id, task.title, overdue_hours])

## 测试: 检查任务是否过期
func _on_is_task_overdue_pressed() -> void:
	var id = task_id_input.text.to_int()
	_log_info("检查任务是否过期(id=%d)" % id)
	var task = TaskState.get_task_by_id(id)

	if task == null:
		_log_error("任务不存在")
		return

	var now = Time.get_unix_time_from_system()
	var is_overdue = task.due_timestamp > 0 and now > task.due_timestamp and not task.is_completed

	if is_overdue:
		_log_success("任务已过期")
	else:
		_log_success("任务未过期")
