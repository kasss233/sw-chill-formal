extends Control

@export var task_item: PackedScene
@onready var scroll_container: ScrollContainer = $PanelContainer/VBoxContainer/MarginContainer/ScrollContainer
@onready var v_box_container: ReorderableVBox = $PanelContainer/VBoxContainer/MarginContainer/ScrollContainer/VBoxContainer2/VBoxContainer
@onready var module_title_label: Label = $PanelContainer/VBoxContainer/MarginContainer2/HBoxContainer/ModuleTitleLabel
@onready var finished_check_box: CheckBox = $PanelContainer/VBoxContainer/MarginContainer/ScrollContainer/VBoxContainer2/VBoxContainer2/FinishedCheckBox
@onready var finish_v_box_container: VBoxContainer = $PanelContainer/VBoxContainer/MarginContainer/ScrollContainer/VBoxContainer2/VBoxContainer2/FinishVBoxContainer
@onready var v_box_container_2: VBoxContainer = $PanelContainer/VBoxContainer/MarginContainer/ScrollContainer/VBoxContainer2/VBoxContainer2

#数据源
var task_cnt:int = 0
var finished_task_cnt:int = 0
#TODO:考虑合并成一个list方便动画
var tasks_data_list: Array[TaskData] = []
var finished_task_data_list: Array[TaskData] = []
var task_id:int = 1 #控制自增id

func _ready() -> void:
	# 连接ReorderableVBox的reordered信号
	#v_box_container.reordered.connect(_on_v_box_container_reordered)
	
	add_task(TaskData.create_example(task_id))
	task_id += 1

#============API==============
func add_task(task: TaskData) -> void:
	task_cnt += 1
	tasks_data_list.append(task)
	var t = task_item.instantiate() as TaskItem
	v_box_container.add_child(t)
	t.set_task(task)
	
	# 连接信号
	t.content_changed.connect(_on_task_item_content_changed)
	t.delete_requested.connect(_on_item_delete_requested)
	t.state_changed.connect(_on_task_state_changed)
	print("[%s]Added a Task(id: %s title: %s)" % [self.name, task.id, task.title])
	_set_label_string()

#删除task
func remove_task(id:int) -> void:
	# 先在未完成列表中查找
	for i in range(tasks_data_list.size()):
		if tasks_data_list[i].id == id:
			tasks_data_list.remove_at(i)
			task_cnt -= 1
			# 删除对应的UI节点
			var item = v_box_container.get_child(i)
			v_box_container.remove_child(item)
			item.queue_free()
			_set_label_string()
			print("[%s]Removed Task(id: %s)" % [self.name, id])
			return
	
	# 如果未找到，在已完成列表中查找
	for i in range(finished_task_data_list.size()):
		if finished_task_data_list[i].id == id:
			finished_task_data_list.remove_at(i)
			finished_task_cnt -= 1
			# 删除对应的UI节点
			var item = finish_v_box_container.get_child(i)
			finish_v_box_container.remove_child(item)
			item.queue_free()
			_set_label_string()
			print("[%s]Removed Finished Task(id: %s)" % [self.name, id])
			return
	
	print("[%s]Task with id %s not found" % [self.name, id])

func get_task_from_id(id:int) -> TaskData:
	# 在未完成列表中查找
	for task in tasks_data_list:
		if task.id == id:
			return task
	
	# 在已完成列表中查找
	for task in finished_task_data_list:
		if task.id == id:
			return task
	
	return null

func get_task_from_name(name:String) -> TaskData:
	# 在未完成列表中查找
	for task in tasks_data_list:
		if task.title == name:
			return task
	
	# 在已完成列表中查找
	for task in finished_task_data_list:
		if task.title == name:
			return task
	
	return null

func get_task_list() -> Array[TaskData]:
	return tasks_data_list

func get_finished_task_list() -> Array[TaskData]:
	return finished_task_data_list

func mark_task_as_completed(id:int) -> void:
	# 在未完成列表中查找
	for i in range(tasks_data_list.size()):
		if tasks_data_list[i].id == id:
			var task_data = tasks_data_list.pop_at(i)
			task_data.is_completed = true
			finished_task_data_list.append(task_data)
			
			# 移动UI
			var item = v_box_container.get_child(i)
			v_box_container.remove_child(item)
			finish_v_box_container.add_child(item)
			item.set_task(task_data)  # 更新UI显示
			
			# 更新计数
			task_cnt -= 1
			finished_task_cnt += 1
			_set_label_string()
			
			print("[%s]Task(id: %s) marked as completed" % [self.name, id])
			return
	
	print("[%s]Task with id %s not found in active tasks" % [self.name, id])

func mark_task_as_uncompleted(id:int) -> void:
	# 在已完成列表中查找
	for i in range(finished_task_data_list.size()):
		if finished_task_data_list[i].id == id:
			var task_data = finished_task_data_list.pop_at(i)
			task_data.is_completed = false
			tasks_data_list.append(task_data)
			
			# 移动UI
			var item = finish_v_box_container.get_child(i)
			finish_v_box_container.remove_child(item)
			v_box_container.add_child(item)
			item.set_task(task_data)  # 更新UI显示
			
			# 更新计数
			finished_task_cnt -= 1
			task_cnt += 1
			_set_label_string()
			
			print("[%s]Task(id: %s) marked as not completed" % [self.name, id])
			return
	
	print("[%s]Task with id %s not found in finished tasks" % [self.name, id])



#============APIEND===========

# ReorderableVBox的reordered信号处理函数
func _on_v_box_container_reordered(from: int, to: int) -> void:
	# 同步更新数据数组
	var data_to_move = tasks_data_list.pop_at(from)
	tasks_data_list.insert(to, data_to_move)
	print("[%s]Task reordered from %d to %d" % [self.name, from, to])

func _set_label_string() -> void:
	module_title_label.text = "     Tasks(%d)" %[task_cnt]
	finished_check_box.text = "已完成(%d)" %[finished_task_cnt]

func _on_add_button_pressed() -> void:
	#TODO 如何设置具体数据
	add_task(TaskData.create_example(task_id))
	task_id += 1

func _on_task_item_content_changed(item: TaskItem) -> void:
	var index = item.get_index()
	if not item.task_data.is_completed:
		tasks_data_list[index] = item.task_data
	else:
		finished_task_data_list[index] = item.task_data

func _on_item_delete_requested(item: TaskItem):
	if item.task_data.is_completed:
		var index = item.get_index()
		# 1. 移除数据
		finished_task_data_list.remove_at(index)
		finished_task_cnt -= 1
		# 2. 移除 UI
		finish_v_box_container.remove_child(item)
		item.queue_free()
		print("[%s]Deleted Finished Task at index %d" % [self.name, index])
		
	else:
		var index = item.get_index()
		# 1. 移除数据
		tasks_data_list.remove_at(index)
		task_cnt -= 1
		finished_task_cnt += 1
		# 2. 移除 UI
		v_box_container.remove_child(item)
		item.queue_free()
		
		print("[%s]Deleted Task at index %d" % [self.name, index])
		
	_set_label_string()


func _on_task_state_changed(item: TaskItem):
	if item.task_data.is_completed:
		finished_task_cnt += 1
		task_cnt -= 1
		#移到已完成列表
		var index = item.get_index()
		var task_data = tasks_data_list.pop_at(index)
		finished_task_data_list.append(task_data)
		v_box_container.remove_child(item)
		finish_v_box_container.add_child(item)
		print("[%s]Task(id: %s) marked as completed" % [self.name, task_data.id])
	else:
		finished_task_cnt -= 1
		task_cnt += 1
		#移到未完成列表
		var index = item.get_index()
		var task_data = finished_task_data_list.pop_at(index)
		tasks_data_list.append(task_data)
		finish_v_box_container.remove_child(item)
		v_box_container.add_child(item)
		print("[%s]Task(id: %s) marked as not completed" % [self.name, task_data.id])
	
	_set_label_string()


func _on_finished_check_box_toggled(toggled_on: bool) -> void:
	finish_v_box_container.visible = toggled_on
