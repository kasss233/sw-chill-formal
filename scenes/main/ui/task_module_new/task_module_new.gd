extends Control

@export var task_item: PackedScene
@onready var scroll_container: ScrollContainer = $PanelContainer/VBoxContainer/MarginContainer/ScrollContainer
@onready var v_box_container: ReorderableVBox = $PanelContainer/VBoxContainer/MarginContainer/ScrollContainer/VBoxContainer
@onready var module_title_label: Label = $PanelContainer/VBoxContainer/MarginContainer2/HBoxContainer/ModuleTitleLabel
@onready var finished_check_box: CheckBox = $PanelContainer/VBoxContainer/MarginContainer/ScrollContainer/VBoxContainer/FinishedCheckBox

# 数据源 - 统一的任务列表，按顺序排列（未完成在前，已完成在后）
var task_cnt: int = 0
var finished_task_cnt: int = 0
var all_tasks_data_list: Array[TaskData] = [] # 统一管理所有任务
var task_id: int = 1 # 控制自增id

# 分隔符节点 - 用于视觉分隔已完成和未完成任务
var separator_index: int = 0 # 分隔符在容器中的索引位置

# 防止递归调用的标志
var _is_programmatic_reorder: bool = false

func _ready() -> void:
	# 初始化分隔符位置（从编辑器中的 FinishedCheckBox 获取索引）
	separator_index = finished_check_box.get_index()
	finished_check_box.toggled.connect(_on_separator_toggled)
	
	# 连接 ReorderableVBox 的 reordered 信号
	#v_box_container.reordered.connect(_on_v_box_container_reordered)
	
	add_task(TaskData.create_example(task_id))
	task_id += 1

#============API==============
func add_task(task: TaskData) -> void:
	# 创建任务项
	var t = task_item.instantiate() as TaskItem
	
	# 设置初始状态为不可见（用于动画）
	t.modulate.a = 0.0
	t.scale = Vector2(0.8, 0.8)
	t.pivot_offset = t.size / 2.0  # 设置缩放中心点
	
	# 先添加到场景树，确保 @onready 节点已初始化
	v_box_container.add_child(t)
	
	# 设置数据（在连接信号之前，避免初始化时触发状态变化）
	t.set_task(task)
	
	# 根据任务状态决定插入位置
	if task.is_completed:
		# 已完成任务添加到末尾
		all_tasks_data_list.append(task)
		finished_task_cnt += 1
		# 已经在末尾，不需要移动
	else:
		# 未完成任务添加到分隔符之前
		all_tasks_data_list.insert(separator_index, task)
		v_box_container.reorder_child_to(t, separator_index, false)
		separator_index += 1
		task_cnt += 1
	
	# 最后连接信号（在数据完全设置好之后）
	t.content_changed.connect(_on_task_item_content_changed)
	t.delete_requested.connect(_on_item_delete_requested)
	t.state_changed.connect(_on_task_state_changed)
	
	# 播放添加动画
	_play_add_animation(t)
	
	print("[%s]Added a Task(id: %s title: %s, completed: %s)" % [self.name, task.id, task.title, task.is_completed])
	_update_ui()
	_update_separator_position()

# 播放添加任务的动画
func _play_add_animation(item: Control) -> void:
	# 创建淡入动画
	var tween = create_tween()
	tween.set_parallel(true)  # 并行执行多个动画
	tween.set_trans(Tween.TRANS_BACK)  # 使用回弹效果
	tween.set_ease(Tween.EASE_OUT)
	
	# 淡入效果
	tween.tween_property(item, "modulate:a", 1.0, 0.4)
	
	# 缩放效果
	tween.tween_property(item, "scale", Vector2.ONE, 0.4)

#删除task
func remove_task(id: int) -> void:
	for i in range(all_tasks_data_list.size()):
		if all_tasks_data_list[i].id == id:
			var task_data = all_tasks_data_list[i]
			var was_completed = task_data.is_completed
			
			# 移除数据
			all_tasks_data_list.remove_at(i)
			
			# 找到并移除UI节点（跳过分隔符）
			var ui_index = _get_ui_index_for_task(i)
			if ui_index >= 0 and ui_index < v_box_container.get_child_count():
				var item = v_box_container.get_child(ui_index)
				if item is TaskItem:
					v_box_container.remove_child(item)
					item.queue_free()
			
			# 更新计数
			if was_completed:
				finished_task_cnt -= 1
			else:
				task_cnt -= 1
				separator_index -= 1
			
			_update_ui()
			_update_separator_position()
			print("[%s]Removed Task(id: %s)" % [self.name, id])
			return
	
	print("[%s]Task with id %s not found" % [self.name, id])

func get_task_from_id(id: int) -> TaskData:
	for task in all_tasks_data_list:
		if task.id == id:
			return task
	return null

func get_task_from_name(name: String) -> TaskData:
	for task in all_tasks_data_list:
		if task.title == name:
			return task
	return null

func get_task_list() -> Array[TaskData]:
	var uncompleted: Array[TaskData] = []
	for task in all_tasks_data_list:
		if not task.is_completed:
			uncompleted.append(task)
	return uncompleted

func get_finished_task_list() -> Array[TaskData]:
	var completed: Array[TaskData] = []
	for task in all_tasks_data_list:
		if task.is_completed:
			completed.append(task)
	return completed

func mark_task_as_completed(id: int) -> void:
	for i in range(all_tasks_data_list.size()):
		if all_tasks_data_list[i].id == id and not all_tasks_data_list[i].is_completed:
			var task_data = all_tasks_data_list[i]
			task_data.is_completed = true
			
			# 移动任务到已完成区域（分隔符之后）
			var ui_index = _get_ui_index_for_task(i)
			var item = v_box_container.get_child(ui_index)
			
			# 更新数据列表顺序
			all_tasks_data_list.remove_at(i)
			all_tasks_data_list.append(task_data)
			
			# 更新UI顺序
			v_box_container.reorder_child_by_index(ui_index, v_box_container.get_child_count() - 1)
			
			# 更新计数
			task_cnt -= 1
			finished_task_cnt += 1
			separator_index -= 1
			
			if item is TaskItem:
				item.set_task(task_data)
			
			_update_ui()
			_update_separator_position()
			print("[%s]Task(id: %s) marked as completed" % [self.name, id])
			return
	
	print("[%s]Task with id %s not found in active tasks" % [self.name, id])

func mark_task_as_uncompleted(id: int) -> void:
	for i in range(all_tasks_data_list.size()):
		if all_tasks_data_list[i].id == id and all_tasks_data_list[i].is_completed:
			var task_data = all_tasks_data_list[i]
			task_data.is_completed = false
			
			# 移动任务到未完成区域（分隔符之前）
			var ui_index = _get_ui_index_for_task(i)
			var item = v_box_container.get_child(ui_index)
			
			# 更新数据列表顺序
			all_tasks_data_list.remove_at(i)
			all_tasks_data_list.insert(separator_index, task_data)
			
			# 更新UI顺序
			v_box_container.reorder_child_by_index(ui_index, separator_index)
			
			# 更新计数
			finished_task_cnt -= 1
			task_cnt += 1
			separator_index += 1
			
			if item is TaskItem:
				item.set_task(task_data)
			
			_update_ui()
			_update_separator_position()
			print("[%s]Task(id: %s) marked as not completed" % [self.name, id])
			return
	
	print("[%s]Task with id %s not found in finished tasks" % [self.name, id])



#============APIEND===========

#============内部辅助方法===========
# 获取任务在UI中的实际索引（考虑分隔符）
func _get_ui_index_for_task(data_index: int) -> int:
	# 如果任务在分隔符之前（未完成任务），UI索引 = 数据索引
	if data_index < separator_index:
		return data_index
	# 如果任务在分隔符之后（已完成任务），UI索引 = 数据索引 + 1（因为有分隔符）
	else:
		return data_index + 1

# 获取UI索引对应的数据索引
func _get_data_index_for_ui(ui_index: int) -> int:
	var sep_ui_index = separator_index
	# 如果UI索引是分隔符，返回-1
	if ui_index == sep_ui_index:
		return -1
	# 如果UI索引在分隔符之前，数据索引 = UI索引
	elif ui_index < sep_ui_index:
		return ui_index
	# 如果UI索引在分隔符之后，数据索引 = UI索引 - 1
	else:
		return ui_index - 1

# 更新分隔符位置（确保分隔符在正确的位置）
func _update_separator_position() -> void:
	# 计算分隔符应该在的UI位置
	var target_sep_ui_index = separator_index
	
	# 如果分隔符不在正确位置，移动它
	var sep_current_index = finished_check_box.get_index()
	if sep_current_index != target_sep_ui_index:
		# 确保目标索引在有效范围内
		var max_index = v_box_container.get_child_count() - 1
		var safe_index = min(target_sep_ui_index, max_index)
		if safe_index >= 0:
			v_box_container.move_child(finished_check_box, safe_index)

# 更新UI显示
func _update_ui() -> void:
	module_title_label.text = "     Tasks(%d)" % [task_cnt]
	finished_check_box.text = "已完成(%d)" % [finished_task_cnt]

# ReorderableVBox的reordered信号处理函数 - 拖拽重排序逻辑
func _on_v_box_container_reordered(from: int, to: int) -> void:
	# 忽略程序性的重排序（非拖拽触发）
	if _is_programmatic_reorder:
		return
	
	# 设置标志防止递归
	_is_programmatic_reorder = true
	
	# 忽略分隔符本身的移动
	if to >= v_box_container.get_child_count():
		_is_programmatic_reorder = false
		return
	var child = v_box_container.get_child(to)
	if child == finished_check_box:
		_is_programmatic_reorder = false
		return
	
	# 获取被移动的任务项
	if not (child is TaskItem):
		_is_programmatic_reorder = false
		return
	
	var item = child as TaskItem
	var task_data = item.task_data
	
	# 检查 task_data 是否有效
	if task_data == null:
		print("[%s]Warning: task_data is null during reorder" % [self.name])
		_is_programmatic_reorder = false
		return
	
	# 确定任务的新状态（根据是否跨越分隔符）
	# 使用分隔符的实时位置而不是 separator_index 变量
	var separator_pos = finished_check_box.get_index()
	var was_completed = task_data.is_completed
	var should_be_completed = (to > separator_pos)
	
	print("[%s]Reorder: from=%d, to=%d, separator_pos=%d, should_be_completed=%s" % [self.name, from, to, separator_pos, should_be_completed])
	
	# 找到任务在数据列表中的旧索引
	var old_data_index = -1
	for i in range(all_tasks_data_list.size()):
		if all_tasks_data_list[i].id == task_data.id:
			old_data_index = i
			break
	
	if old_data_index == -1:
		print("[%s]Error: Task data not found during reorder" % [self.name])
		_is_programmatic_reorder = false
		return
	
	# 更新数据列表
	var moved_task = all_tasks_data_list[old_data_index]
	all_tasks_data_list.remove_at(old_data_index)
	
	# 计算新的数据索引
	var new_data_index = _get_data_index_for_ui(to)
	if new_data_index >= 0 and new_data_index <= all_tasks_data_list.size():
		all_tasks_data_list.insert(new_data_index, moved_task)
	else:
		all_tasks_data_list.append(moved_task)
	
	# 如果任务状态改变
	if was_completed != should_be_completed:
		moved_task.is_completed = should_be_completed
		
		# 临时断开 state_changed 信号，避免触发重复的状态变化逻辑
		if item.state_changed.is_connected(_on_task_state_changed):
			item.state_changed.disconnect(_on_task_state_changed)
		
		# 更新任务数据和UI
		item.task_data = moved_task
		item.complete_check_box.set_checked_no_signal(should_be_completed)
		item.line_edit.is_completed = should_be_completed
		
		# 重新连接信号
		item.state_changed.connect(_on_task_state_changed)
		
		if should_be_completed:
			# 未完成 -> 已完成
			task_cnt -= 1
			finished_task_cnt += 1
			separator_index -= 1
			if should_be_completed:
				moved_task.finish_timestamp = Time.get_unix_time_from_system()
			print("[%s]Task(id: %s) marked as completed by dragging" % [self.name, task_data.id])
		else:
			# 已完成 -> 未完成
			finished_task_cnt -= 1
			task_cnt += 1
			separator_index += 1
			moved_task.finish_timestamp = 0
			print("[%s]Task(id: %s) marked as not completed by dragging" % [self.name, task_data.id])
		
		_update_ui()
		_update_separator_position()
	else:
		print("[%s]Task(id: %s) reordered from %d to %d (same status)" % [self.name, task_data.id, from, to])
	
	_is_programmatic_reorder = false

func _on_add_button_pressed() -> void:
	add_task(TaskData.create_example(task_id))
	task_id += 1

func _on_task_item_content_changed(item: TaskItem) -> void:
	# 查找并更新对应的任务数据
	for i in range(all_tasks_data_list.size()):
		if all_tasks_data_list[i].id == item.task_data.id:
			all_tasks_data_list[i] = item.task_data
			break

func _on_item_delete_requested(item: TaskItem):
	var task_data = item.task_data
	var ui_index = item.get_index()
	
	# 查找数据索引
	var data_index = -1
	for i in range(all_tasks_data_list.size()):
		if all_tasks_data_list[i].id == task_data.id:
			data_index = i
			break
	
	if data_index >= 0:
		# 移除数据
		all_tasks_data_list.remove_at(data_index)
		
		# 更新计数
		if task_data.is_completed:
			finished_task_cnt -= 1
		else:
			task_cnt -= 1
			separator_index -= 1
		
		# 移除UI
		v_box_container.remove_child(item)
		item.queue_free()
		
		_update_ui()
		_update_separator_position()
		print("[%s]Deleted Task(id: %s) at ui_index %d" % [self.name, task_data.id, ui_index])

func _on_task_state_changed(item: TaskItem):
	var task_data = item.task_data
	var ui_index = item.get_index()
	
	# 检查 task_data 是否有效
	if task_data == null:
		print("[%s]Warning: task_data is null in state change" % [self.name])
		return
	
	# 查找数据索引
	var data_index = -1
	for i in range(all_tasks_data_list.size()):
		if all_tasks_data_list[i].id == task_data.id:
			data_index = i
			break
	
	if data_index < 0:
		print("[%s]Error: Task data not found in state change" % [self.name])
		return
	
	# 设置标志防止递归
	_is_programmatic_reorder = true
	
	if task_data.is_completed:
		# 任务被标记为已完成 - 移动到分隔符之后的第一个位置
		var moved_task = all_tasks_data_list[data_index]
		
		# 计算插入位置（在移除之前）
		# 如果任务在分隔符之前（未完成区域），移除后分隔符位置会前移
		var insert_index = separator_index
		if data_index < separator_index:
			insert_index = separator_index - 1
		
		all_tasks_data_list.remove_at(data_index)
		all_tasks_data_list.insert(insert_index, moved_task)
		
		# 更新计数
		finished_task_cnt += 1
		task_cnt -= 1
		separator_index -= 1
		
		# 移动UI到分隔符后的第一个位置
		var target_ui_index = separator_index + 1  # +1 是因为分隔符本身占一个位置
		if target_ui_index < v_box_container.get_child_count():
			v_box_container.reorder_child_by_index(ui_index, target_ui_index)
		
		print("[%s]Task(id: %s) marked as completed" % [self.name, task_data.id])
	else:
		# 任务被标记为未完成 - 移动到分隔符之前的末尾
		var moved_task = all_tasks_data_list[data_index]
		
		# 计算插入位置（在移除之前）
		# 如果任务在分隔符之后（已完成区域），插入位置就是当前的 separator_index
		var insert_index = separator_index
		
		all_tasks_data_list.remove_at(data_index)
		all_tasks_data_list.insert(insert_index, moved_task)
		
		# 更新计数
		finished_task_cnt -= 1
		task_cnt += 1
		separator_index += 1
		
		# 移动UI到分隔符前
		if separator_index <= v_box_container.get_child_count():
			v_box_container.reorder_child_by_index(ui_index, separator_index)
		
		print("[%s]Task(id: %s) marked as not completed" % [self.name, task_data.id])
	
	_is_programmatic_reorder = false
	
	_update_ui()
	_update_separator_position()

func _on_separator_toggled(toggled_on: bool) -> void:
	# 控制已完成任务的可见性
	for i in range(separator_index + 1, v_box_container.get_child_count()):
		var child = v_box_container.get_child(i)
		if child is TaskItem:
			child.visible = toggled_on
