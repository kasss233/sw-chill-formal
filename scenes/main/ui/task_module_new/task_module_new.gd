extends Control

@export var task_item: PackedScene
@onready var v_box_container: VBoxContainer = $PanelContainer/VBoxContainer/ScrollContainer/VBoxContainer
@onready var scroll_container: ScrollContainer = $PanelContainer/VBoxContainer/ScrollContainer

# 拖拽相关变量
var dragging_item: TaskItem = null
var drag_preview: Control = null
var drag_offset: Vector2 = Vector2.ZERO
var is_dragging: bool = false

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
	var t = task_item.instantiate() as TaskItem
	v_box_container.add_child(t)
	t.set_task(task)
	
	# 连接信号
	t.drag_started.connect(_on_item_drag_started)
	t.drag_ended.connect(_on_item_drag_ended)
	
	print("[%s] Added a Task(id: %s title: %s)" % [self.name, task.id, task.title])

# --- 拖拽逻辑实现 ---

func _on_item_drag_started(item: TaskItem):
	is_dragging = true
	dragging_item = item
	
	# 1. 创建视觉替身 (Ghost)
	drag_preview = item.duplicate(0) # 0表示不复制信号，只复制节点属性
	add_child(drag_preview) # 加到最外层，保证显示在最上面
	drag_preview.modulate.a = 0.8 # 半透明
	drag_preview.size = item.size # 强制尺寸
	
	# 计算偏移量，让替身跟手指位置对应
	drag_offset = get_global_mouse_position() - item.global_position
	drag_preview.global_position = item.global_position
	
	# 2. 隐藏真实 Item (或者变透明)
	item.modulate.a = 0.0
	
	# 3. 禁用 ScrollContainer 的触摸滚动，防止拖拽时列表乱跑
	# (视情况而定，有时候只需要禁用垂直滚动)                                                                                                                                                                                                                                                           
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

func _reorder_list():
	# 获取鼠标在 VBox 内部的 Y 坐标
	var local_mouse_y = v_box_container.get_local_mouse_position().y
	
	# 遍历所有子节点，找到应该插入的位置
	var new_index = 0
	var children = v_box_container.get_children()
	
	for i in children.size():
		var child = children[i]
		if child == dragging_item: continue # 跳过自己
		
		# 如果鼠标在这个 child 的上半部分以上
		if local_mouse_y < child.position.y + child.size.y / 2.0:
			break
		new_index += 1
	
	# 修正索引（因为 move_child 处理当前节点会影响索引计算）
	# 但 v_box_container.move_child 智能处理，直接传目标位置通常即可
	# 这里为了防止抖动，可以加一个判断：只有索引变了才移动
	if new_index != dragging_item.get_index():
		v_box_container.move_child(dragging_item, new_index)

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
