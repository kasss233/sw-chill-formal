class_name TaskItem
extends PanelContainer

signal state_changed(item: TaskItem)
signal edit_requested(id)
signal delete_requested(item: TaskItem)
signal content_changed(item: TaskItem)
signal drag_started(item: TaskItem)
signal drag_ended(item: TaskItem)

@onready var complete_check_box: CheckBox = $MarginContainer/VBoxContainer/HBoxContainer/CompleteCheckBox
@onready var due_time_label: Label = $MarginContainer/VBoxContainer/HBoxContainer/VBoxContainer/DueTimeLabel
@onready var line_edit: LineEdit = $MarginContainer/VBoxContainer/HBoxContainer/VBoxContainer/LineEdit
@onready var h_box_container_2: HBoxContainer = $MarginContainer/VBoxContainer/HBoxContainer2
@onready var close_button: Button = $MarginContainer/VBoxContainer/HBoxContainer2/CloseButton

#@onready var long_press_timer: Timer = $LongPressTimer

var is_pressing: bool = false
var is_dragging: bool = false
var is_editing: bool = false # 新增：用于判断当前状态

var task_data: TaskData

func _ready() -> void:
	# 初始状态设置
	mouse_filter = Control.MOUSE_FILTER_PASS 
	
	# 初始化关闭编辑模式
	_disable_edit_mode() 
	
	# 连接关闭按钮信号
	if close_button:
		close_button.pressed.connect(_on_close_button_pressed)

func set_task(data: TaskData):
	self.task_data = data
	
	if not is_instance_valid(task_data):
		push_error("["+self.name+"]"+"Invaild Data")
		visible = false
		return
		
	visible = true
	
	line_edit.text = task_data.title
	due_time_label.text = task_data.get_formatted_due_time()
	complete_check_box.button_pressed = task_data.is_completed

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			# 鼠标按下
			is_pressing = true
			is_dragging = false
		
		else:
			# 鼠标松开
			if is_pressing and not is_dragging:
				# 单击事件逻辑：根据当前是否在编辑来切换状态
				if is_editing:
					_disable_edit_mode() # 如果正在编辑，再次点击背景则退出
				else:
					_enable_edit_mode() # 如果没在编辑，点击则进入
			
			# 重置状态
			if is_dragging and not task_data.is_completed:
				drag_ended.emit(self)
			
			is_pressing = false
			is_dragging = false


# 开启编辑模式
func _enable_edit_mode() -> void:
	is_editing = true
	h_box_container_2.visible = true
	
	# 启用 LineEdit 鼠标交互，允许选中文字
	line_edit.mouse_filter = Control.MOUSE_FILTER_STOP 
	# 可选：如果你想点开就自动聚焦输入框
	# line_edit.grab_focus() 

# 关闭编辑模式
func _disable_edit_mode() -> void:
	is_editing = false
	h_box_container_2.visible = false
	
	# 禁用 LineEdit 鼠标交互，让点击事件能穿透到 PanelContainer (背景)
	line_edit.mouse_filter = Control.MOUSE_FILTER_IGNORE 
	
	# 清除焦点（如果在输入状态下）
	if line_edit.has_focus():
		line_edit.release_focus()

func _on_close_button_pressed() -> void:
	# 按钮点击事件处理
	_disable_edit_mode()

func _on_edit_button_pressed() -> void:
	edit_requested.emit(task_data.id)

func _on_long_press_timer_timeout() -> void:
	if is_pressing:
		is_dragging = true
		drag_started.emit(self)

func _on_line_edit_text_changed(new_text: String) -> void:
	print("[%s]Task title change to \"%s\"" %[self.name,new_text])
	task_data.title = new_text
	content_changed.emit(self)


func _on_line_edit_editing_toggled(toggled_on: bool) -> void:
	var new_text = line_edit.text
	if new_text == task_data.title:
		return
	print("[%s]Task title change to \"%s\"" %[self.name,new_text])
	task_data.title = new_text
	content_changed.emit(self)

func _on_del_button_pressed() -> void:
	delete_requested.emit(self)

func _on_complete_check_box_toggled(toggled_on: bool) -> void:
	task_data.is_completed = toggled_on
	line_edit.is_completed = toggled_on
	if toggled_on:
		task_data.finish_timestamp = Time.get_unix_time_from_system()
	else:
		task_data.finish_timestamp = 0

	state_changed.emit(self)
