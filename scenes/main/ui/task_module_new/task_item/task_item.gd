class_name TaskItem
extends PanelContainer

signal edit_requested(id)
signal drag_started(item: TaskItem)
signal drag_ended(item: TaskItem)

@onready var complete_check_box: CheckBox = $MarginContainer/HBoxContainer/CompleteCheckBox
@onready var title_label: Label = $MarginContainer/HBoxContainer/VBoxContainer/TitleLabel
@onready var due_time_label: Label = $MarginContainer/HBoxContainer/VBoxContainer/DueTimeLabel
@onready var edit_button: Button = $MarginContainer/HBoxContainer/EditButton
@onready var long_press_timer: Timer = $LongPressTimer

var is_pressing: bool = false

var task_data: TaskData

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS 
	
func set_task(data: TaskData):
	self.task_data = data
	
	# 检查数据是否存在，防止出错
	if not is_instance_valid(task_data):
		push_error("["+self.name+"]"+"Invaild Data")
		visible = false
		return
		
	visible = true
	
	title_label.text = task_data.title
	due_time_label.text = task_data.get_formatted_due_time()
	complete_check_box.button_pressed = task_data.is_completed

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			is_pressing = true
			long_press_timer.start() # 按下开始计时
		elif not event.pressed:
			is_pressing = false
			long_press_timer.stop() # 松开停止计时
			drag_ended.emit(self) # 通知主脚本结束拖拽

func _on_edit_button_pressed() -> void:
	edit_requested.emit(task_data.id)


func _on_long_press_timer_timeout() -> void:
	if is_pressing:
		drag_started.emit(self)
