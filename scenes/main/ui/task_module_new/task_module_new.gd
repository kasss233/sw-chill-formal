extends Control

# 信号定义（保留，供上层连接）
signal task_completed(task_id: int, task_title: String)

@export var task_item: PackedScene
@onready var scroll_container: ScrollContainer = $PanelContainer/VBoxContainer/MarginContainer/ScrollContainer
@onready var v_box_container: ReorderableVBox = $PanelContainer/VBoxContainer/MarginContainer/ScrollContainer/VBoxContainer
@onready var module_title_label: Label = $PanelContainer/VBoxContainer/MarginContainer2/HBoxContainer/ModuleTitleLabel
@onready var finished_check_box: CheckBox = $PanelContainer/VBoxContainer/MarginContainer/ScrollContainer/VBoxContainer/FinishedCheckBox

# UI 节点映射：task_id → TaskItem 节点
var _task_items: Dictionary = {}

# 分隔符节点 - 用于视觉分隔已完成和未完成任务
var separator_index: int = 0

# 防止递归调用的标志
var _is_programmatic_reorder: bool = false

func _ready() -> void:
	# 初始化分隔符位置（从编辑器中的 FinishedCheckBox 获取索引）
	separator_index = finished_check_box.get_index()
	finished_check_box.set_meta("reorderable_exclude", true)
	finished_check_box.toggled.connect(_on_separator_toggled)

	# 连接拖拽动画信号
	v_box_container.drag_started.connect(_on_drag_started)
	v_box_container.drag_ended.connect(_on_drag_ended)

	# 连接 TaskState 信号
	TaskState.task_added.connect(_on_state_task_added)
	TaskState.task_removed.connect(_on_state_task_removed)
	TaskState.task_updated.connect(_on_state_task_updated)
	TaskState.task_state_changed.connect(_on_state_task_state_changed)
	TaskState.tasks_reordered.connect(_on_state_tasks_reordered)
	TaskState.data_loaded.connect(_on_state_data_loaded)

	# 如果 TaskState 已经有数据（autoload 先于场景 _ready），立即渲染
	if TaskState.get_task_count() > 0:
		_render_all()


func _exit_tree() -> void:
	if TaskState.task_added.is_connected(_on_state_task_added):
		TaskState.task_added.disconnect(_on_state_task_added)
	if TaskState.task_removed.is_connected(_on_state_task_removed):
		TaskState.task_removed.disconnect(_on_state_task_removed)
	if TaskState.task_updated.is_connected(_on_state_task_updated):
		TaskState.task_updated.disconnect(_on_state_task_updated)
	if TaskState.task_state_changed.is_connected(_on_state_task_state_changed):
		TaskState.task_state_changed.disconnect(_on_state_task_state_changed)
	if TaskState.tasks_reordered.is_connected(_on_state_tasks_reordered):
		TaskState.tasks_reordered.disconnect(_on_state_tasks_reordered)
	if TaskState.data_loaded.is_connected(_on_state_data_loaded):
		TaskState.data_loaded.disconnect(_on_state_data_loaded)

# ======================== TaskState 信号回调 ========================

func _on_state_task_added(task: TaskData) -> void:
	_create_task_item(task)
	_update_ui()
	_update_separator_position()

func _on_state_task_removed(task_id: int) -> void:
	_remove_task_item(task_id)
	_update_ui()
	_update_separator_position()

func _on_state_task_updated(task: TaskData) -> void:
	# title / due_time 等字段变化，更新对应的 UI
	var item = _task_items.get(task.id)
	if item and is_instance_valid(item):
		item.update_display(task)

func _on_state_task_state_changed(task: TaskData) -> void:
	var item = _task_items.get(task.id)
	if not item or not is_instance_valid(item):
		# 兜底：节点丢失时完整重建
		_render_all()
		return

	# 更新 item 显示
	item.update_display(task)

	if _is_programmatic_reorder:
		# 拖拽引起的状态变化 —— item 已经在正确位置，只需同步 separator
		separator_index = finished_check_box.get_index()
		_update_ui()
		if task.is_completed:
			task_completed.emit(task.id, task.title)
		return

	# 勾选/取消勾选 —— 用 reorder_child_to 带动画移动
	var current_index = item.get_index()
	var sep_index = finished_check_box.get_index()

	if task.is_completed and current_index < sep_index:
		# 未完成 → 已完成：移到分隔符后面（即当前 sep_index 位置）
		_is_programmatic_reorder = true
		v_box_container.reorder_child_to(item, sep_index, true)
		_is_programmatic_reorder = false
		separator_index = finished_check_box.get_index()
	elif not task.is_completed and current_index > sep_index:
		# 已完成 → 未完成：移到第一个位置
		_is_programmatic_reorder = true
		v_box_container.reorder_child_to(item, 0, true)
		_is_programmatic_reorder = false
		separator_index = finished_check_box.get_index()

	_update_ui()

	if task.is_completed:
		task_completed.emit(task.id, task.title)

func _on_state_tasks_reordered() -> void:
	# 同区域拖拽 —— VBox 已经是正确顺序，只需同步 separator_index
	separator_index = finished_check_box.get_index()

func _on_state_data_loaded() -> void:
	_render_all()
	_update_ui()

# ======================== 渲染方法 ========================

## 清空并重建所有 TaskItem
func _render_all() -> void:
	# 清空现有 UI 节点（保留 FinishedCheckBox）
	for child in v_box_container.get_children():
		if child.has_method("set_task"):
			v_box_container.remove_child(child)
			child.queue_free()
	_task_items.clear()

	# 获取所有任务（TaskState 保证顺序：未完成在前，已完成在后）
	var all_tasks = TaskState.get_all_tasks()
	var incomplete_count = 0

	# 创建所有任务 UI 节点（add_child 追加到末尾）
	for task in all_tasks:
		var t = task_item.instantiate() as InnerPanel
		v_box_container.add_child(t)
		t.set_task(task)
		_task_items[task.id] = t
		_connect_task_item_signals(t)
		if not task.is_completed:
			incomplete_count += 1

	# 移动分隔符到正确位置（未完成任务之后）
	separator_index = incomplete_count
	_update_separator_position()

	# 同步已完成任务的可见性
	var show_completed = finished_check_box.button_pressed
	for i in range(finished_check_box.get_index() + 1, v_box_container.get_child_count()):
		var child = v_box_container.get_child(i)
		if child.has_method("set_task"):
			child.visible = show_completed

	_update_ui()

## 创建任务 UI 节点（带动画）
func _create_task_item(task: TaskData) -> void:
	var t = task_item.instantiate() as InnerPanel

	# 先添加到场景树、设置数据、移动位置
	v_box_container.add_child(t)
	t.set_task(task)

	# 根据任务状态决定插入位置
	if task.is_completed:
		pass
	else:
		# 未完成任务添加到第一个位置（不带动画，避免和入场动画冲突）
		_is_programmatic_reorder = true
		v_box_container.reorder_child_to(t, 0, false)
		_is_programmatic_reorder = false
		separator_index += 1

	# 注册到映射
	_task_items[task.id] = t

	# 连接信号
	_connect_task_item_signals(t)

	# 所有布局完成后，再设置动画初始状态并播放
	t.modulate.a = 0.0
	t.scale = Vector2(0.8, 0.8)
	_play_add_animation(t)

	print("[%s]Created TaskItem(id: %s, title: %s)" % [self.name, task.id, task.title])

## 连接 TaskItem 信号
func _connect_task_item_signals(item: Control) -> void:
	item.completed_changed.connect(_on_task_item_completed_changed)
	item.content_changed.connect(_on_task_item_content_changed)
	item.delete_requested.connect(_on_task_item_delete_requested)
	item.due_time_changed.connect(_on_task_item_due_time_changed)

## 移除任务 UI 节点
func _remove_task_item(task_id: int) -> void:
	var item = _task_items.get(task_id)
	if item and is_instance_valid(item):
		# 检查是否需要更新分隔符
		var ui_index = item.get_index()
		var sep_index = finished_check_box.get_index()
		if ui_index < sep_index:
			separator_index -= 1

		v_box_container.remove_child(item)
		item.queue_free()
		_task_items.erase(task_id)
		print("[%s]Removed TaskItem(id: %s)" % [self.name, task_id])

# ======================== TaskItem 信号回调 ========================

func _on_task_item_completed_changed(task_id: int, completed: bool) -> void:
	TaskState.set_task_completed(task_id, completed)

func _on_task_item_content_changed(task_id: int, new_content: String) -> void:
	TaskState.update_task_title(task_id, new_content)

func _on_task_item_delete_requested(task_id: int) -> void:
	TaskState.remove_task(task_id)

func _on_task_item_due_time_changed(task_id: int, timestamp: int) -> void:
	TaskState.set_task_due_time(task_id, timestamp)

# ======================== 动画 ========================

func _on_drag_started(child: Control) -> void:
	child.pivot_offset = child.size / 2.0
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_BACK)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(child, "scale", Vector2(1.05, 1.05), 0.2)

func _on_drag_ended(child: Control) -> void:
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_BACK)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(child, "scale", Vector2.ONE, 0.2)

func _play_add_animation(item: Control) -> void:
	# 等待一帧让布局计算完成，确保 size 有效
	await get_tree().process_frame
	if not is_instance_valid(item):
		return
	item.pivot_offset = item.size / 2.0
	var tween = create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_BACK)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(item, "modulate:a", 1.0, 0.4)
	tween.tween_property(item, "scale", Vector2.ONE, 0.4)

# ======================== UI 按钮事件 ========================

func _on_add_button_pressed() -> void:
	TaskState.add_task("新任务")

# ======================== 拖拽重排序 ========================

func _on_v_box_container_reordered(from: int, to: int) -> void:
	if _is_programmatic_reorder:
		return

	_is_programmatic_reorder = true

	if to >= v_box_container.get_child_count():
		_is_programmatic_reorder = false
		return
	var child = v_box_container.get_child(to)
	if child == finished_check_box:
		_is_programmatic_reorder = false
		return

	if not child.has_method("set_task"):
		_is_programmatic_reorder = false
		return

	var item = child
	var task_data = item.task_data

	if task_data == null:
		print("[%s]Warning: task_data is null during reorder" % [self.name])
		_is_programmatic_reorder = false
		return

	# 确定新状态
	var separator_pos = finished_check_box.get_index()
	var should_be_completed = (to > separator_pos)

	print("[%s]Reorder: from=%d, to=%d, separator_pos=%d, should_be_completed=%s" % [self.name, from, to, separator_pos, should_be_completed])

	# 计算新的数据索引
	var new_data_index = _get_data_index_for_ui(to)

	# 通过 TaskState 处理
	TaskState.reorder_by_drag(task_data.id, new_data_index, should_be_completed)

	_is_programmatic_reorder = false

# ======================== 内部辅助方法 ========================

func _get_data_index_for_ui(ui_index: int) -> int:
	var sep_ui_index = finished_check_box.get_index()
	if ui_index == sep_ui_index:
		return -1
	elif ui_index < sep_ui_index:
		return ui_index
	else:
		return ui_index - 1

func _update_separator_position() -> void:
	var target_sep_ui_index = separator_index
	var sep_current_index = finished_check_box.get_index()
	if sep_current_index != target_sep_ui_index:
		var max_index = v_box_container.get_child_count() - 1
		var safe_index = min(target_sep_ui_index, max_index)
		if safe_index >= 0:
			_is_programmatic_reorder = true
			v_box_container.reorder_child_to(finished_check_box, safe_index, false)
			_is_programmatic_reorder = false

func _update_ui() -> void:
	module_title_label.text = "     Tasks(%d)" % TaskState.get_incomplete_count()
	finished_check_box.text = "已完成(%d)" % TaskState.get_completed_count()

func _on_separator_toggled(toggled_on: bool) -> void:
	for i in range(finished_check_box.get_index() + 1, v_box_container.get_child_count()):
		var child = v_box_container.get_child(i)
		if child.has_method("set_task"):
			child.visible = toggled_on
