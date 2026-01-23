extends Control

## TaskModule测试页 - 测试TaskModule的Agent API

# UI节点引用
var task_module: TaskModule = null  # 需要从外部设置

@onready var info_label: RichTextLabel = $MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/InfoLabel
@onready var task_title_input: LineEdit = $MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/InputSection/TaskTitleInput
@onready var task_id_input: LineEdit = $MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/InputSection/TaskIdInput
@onready var task_position_input: LineEdit = $MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/InputSection/TaskPositionInput

# 测试按钮
@onready var add_task_btn: Button = $MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/ButtonSection/AddTaskBtn
@onready var update_title_btn: Button = $MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/ButtonSection/UpdateTitleBtn
@onready var mark_completed_btn: Button = $MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/ButtonSection/MarkCompletedBtn
@onready var mark_uncompleted_btn: Button = $MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/ButtonSection/MarkUncompletedBtn
@onready var remove_task_btn: Button = $MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/ButtonSection/RemoveTaskBtn
@onready var reorder_task_btn: Button = $MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/ButtonSection/ReorderTaskBtn
@onready var get_task_info_btn: Button = $MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/ButtonSection/GetTaskInfoBtn
@onready var get_all_tasks_btn: Button = $MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/ButtonSection/GetAllTasksBtn

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

	_log_info("TaskModule测试面板已就绪")
	_log_info("请先设置task_module引用")

## 设置要测试的TaskModule实例
func set_task_module(module: TaskModule) -> void:
	task_module = module
	_log_info("已连接到TaskModule: %s" % module.name)

## 测试: 添加任务
func _on_add_task_pressed() -> void:
	if not _check_module():
		return

	var title = task_title_input.text
	if title.is_empty():
		title = "测试任务 " + str(Time.get_ticks_msec())

	_log_info("调用 agent_add_task(title='%s')" % title)
	var new_id = task_module.agent_add_task(title)
	last_added_task_id = new_id
	_log_success("✓ 任务已添加，ID: %d" % new_id)
	task_id_input.text = str(new_id)

## 测试: 更新任务标题
func _on_update_title_pressed() -> void:
	if not _check_module():
		return

	var id = task_id_input.text.to_int()
	var new_title = task_title_input.text

	if new_title.is_empty():
		_log_error("✗ 请输入新标题")
		return

	_log_info("调用 agent_update_task_title(id=%d, new_title='%s')" % [id, new_title])
	var success = await task_module.agent_update_task_title(id, new_title, 0.05)

	if success:
		_log_success("✓ 任务标题已更新")
	else:
		_log_error("✗ 更新失败，任务ID不存在")

## 测试: 标记任务为已完成
func _on_mark_completed_pressed() -> void:
	if not _check_module():
		return

	var id = task_id_input.text.to_int()
	_log_info("调用 agent_mark_task_completed(id=%d, completed=true)" % id)
	var success = task_module.agent_mark_task_completed(id, true)

	if success:
		_log_success("✓ 任务已标记为完成")
	else:
		_log_error("✗ 操作失败")

## 测试: 标记任务为未完成
func _on_mark_uncompleted_pressed() -> void:
	if not _check_module():
		return

	var id = task_id_input.text.to_int()
	_log_info("调用 agent_mark_task_completed(id=%d, completed=false)" % id)
	var success = task_module.agent_mark_task_completed(id, false)

	if success:
		_log_success("✓ 任务已标记为未完成")
	else:
		_log_error("✗ 操作失败")

## 测试: 删除任务
func _on_remove_task_pressed() -> void:
	if not _check_module():
		return

	var id = task_id_input.text.to_int()
	_log_info("调用 agent_remove_task(id=%d)" % id)
	var success = task_module.agent_remove_task(id)

	if success:
		_log_success("✓ 任务已删除")
	else:
		_log_error("✗ 删除失败")

## 测试: 调整任务顺序
func _on_reorder_task_pressed() -> void:
	if not _check_module():
		return

	var id = task_id_input.text.to_int()
	var new_position = task_position_input.text.to_int()

	_log_info("调用 agent_reorder_task(id=%d, new_position=%d)" % [id, new_position])
	var success = task_module.agent_reorder_task(id, new_position)

	if success:
		_log_success("✓ 任务顺序已调整")
	else:
		_log_error("✗ 调整失败，请检查任务ID和位置是否有效")

## 测试: 获取任务信息
func _on_get_task_info_pressed() -> void:
	if not _check_module():
		return

	var id = task_id_input.text.to_int()
	_log_info("调用 agent_get_task_info(id=%d)" % id)
	var info = task_module.agent_get_task_info(id)

	if info.is_empty():
		_log_error("✗ 任务不存在")
	else:
		_log_success("✓ 任务信息:")
		_log_data(JSON.stringify(info, "  "))

## 测试: 获取所有任务
func _on_get_all_tasks_pressed() -> void:
	if not _check_module():
		return

	_log_info("调用 agent_get_all_tasks()")
	var all_tasks = task_module.agent_get_all_tasks()

	_log_success("✓ 共有 %d 个任务:" % all_tasks.size())
	for task in all_tasks:
		_log_data("  - [%d] %s (完成: %s)" % [task.id, task.title, task.is_completed])

## 检查TaskModule是否已设置
func _check_module() -> bool:
	if task_module == null:
		_log_error("✗ TaskModule未设置，请先调用set_task_module()")
		return false
	return true

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
