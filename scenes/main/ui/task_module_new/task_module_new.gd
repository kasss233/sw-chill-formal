extends Control

@export var task_item: PackedScene
@onready var scroll_container: ScrollContainer = $PanelContainer/VBoxContainer/MarginContainer/ScrollContainer
@onready var v_box_container: VBoxContainer = $PanelContainer/VBoxContainer/MarginContainer/ScrollContainer/VBoxContainer


# 拖拽相关变量
var dragging_item: TaskItem = null
var drag_preview: Control = null
var drag_offset: Vector2 = Vector2.ZERO
var is_dragging: bool = false

#数据源
var tasks_data_list: Array[TaskData] = []


func _ready() -> void:
	add_task(TaskData.create_example())

func _process(_delta: float) -> void:
	if is_dragging and dragging_item and drag_preview:
		# 1. 让替身跟随鼠标/手指
		var mouse_pos = get_global_mouse_position()
		drag_preview.global_position = mouse_pos - drag_offset
		
		# 2. 自动滚动 (当拖拽到边缘时)
		_handle_auto_scroll(mouse_pos)
		
		# 3. 核心：计算并在列表中重新排序
		_reorder_list()

func add_task(task: TaskData) -> void:
	tasks_data_list.append(task)
	var t = task_item.instantiate() as TaskItem
	v_box_container.add_child(t)
	t.set_task(task)
	
	# 连接信号
	t.drag_started.connect(_on_item_drag_started)
	t.drag_ended.connect(_on_item_drag_ended)
	t.content_changed.connect(_on_task_item_content_changed)
	
	print("[%s] Added a Task(id: %s title: %s)" % [self.name, task.id, task.title])


func _reorder_list():
	# 获取鼠标在 VBox 内部的 Y 坐标
	var local_mouse_y = v_box_container.get_local_mouse_position().y
	
	# 1. 计算目标插入位置 (New Index)
	var new_index = 0
	var children = v_box_container.get_children()
	
	for child in children:
		if child == dragging_item: continue # 跳过自己不参与计算
		
		# 如果鼠标在这个 child 的上半部分以上，说明要插入在这个 child 前面
		if local_mouse_y < child.position.y + child.size.y / 2.0:
			break
		new_index += 1
	
	# 2. 获取当前位置 (Old Index)
	var old_index = dragging_item.get_index()
	
	# 3. 只有位置发生变化时才执行移动操作
	if new_index != old_index:
		# --- 关键修复：先处理数据，再处理UI，或者保证 old_index 在 move_child 之前获取 ---
		
		# A. 移动数据 (Model)
		# 注意：pop_at 取出旧位置的数据，insert 插入到新位置
		var data_to_move = tasks_data_list.pop_at(old_index)
		tasks_data_list.insert(new_index, data_to_move)
		
		# B. 移动 UI (View)
		v_box_container.move_child(dragging_item, new_index)
		
		# (可选) 打印调试，确保同步
		print("[%s]Moved from %d to %d" %[self.name,old_index,new_index])

# (可选) 边缘自动滚动
func _handle_auto_scroll(mouse_pos: Vector2):
	var scroll_speed = 5.0
	var view_rect = scroll_container.get_global_rect()
	
	if mouse_pos.y < view_rect.position.y + 50: # 顶部区域
		scroll_container.scroll_vertical -= scroll_speed
	elif mouse_pos.y > view_rect.end.y - 50: # 底部区域
		scroll_container.scroll_vertical += scroll_speed

func _on_add_button_pressed() -> void:
	#TODO 如何设置具体数据
	add_task(TaskData.create_example())

func _on_task_item_content_changed(item: TaskItem) -> void:
	var index = item.get_index()
	tasks_data_list[index] = item.task_data


# --- 拖拽逻辑实现 ---

func _on_item_drag_started(item: TaskItem):
	is_dragging = true
	dragging_item = item
	
	# 1. 创建视觉替身
	drag_preview = item.duplicate(0)
	add_child(drag_preview)
	drag_preview.modulate.a = 0.8
	drag_preview.size = item.size
	
	# [新增/修复] 关键：让替身完全不接收鼠标事件，防止它挡住下面的列表检测
	drag_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE 
	
	drag_offset = get_global_mouse_position() - item.global_position
	drag_preview.global_position = item.global_position
	
	# 2. 隐藏真实 Item
	item.modulate.a = 0.0
	
	# 3. 禁用 ScrollContainer 滚动
	scroll_container.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _on_item_drag_ended(item: TaskItem):
	if not is_dragging: return
	
	is_dragging = false
	
	# 1. 清理替身
	if drag_preview:
		drag_preview.queue_free()
		drag_preview = null
	
	# 2. 恢复真实 Item
	if dragging_item:
		dragging_item.modulate.a = 1.0
		dragging_item = null
	
	# 恢复滚动
	scroll_container.mouse_filter = Control.MOUSE_FILTER_PASS
