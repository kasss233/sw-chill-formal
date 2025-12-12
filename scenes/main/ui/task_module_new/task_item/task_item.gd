class_name TaskItem
extends PanelContainer

signal edit_requested(id)

@onready var complete_check_box: CheckBox = $MarginContainer/HBoxContainer/CompleteCheckBox
@onready var title_label: Label = $MarginContainer/HBoxContainer/VBoxContainer/TitleLabel
@onready var due_time_label: Label = $MarginContainer/HBoxContainer/VBoxContainer/DueTimeLabel
@onready var edit_button: Button = $MarginContainer/HBoxContainer/EditButton


var task_data: TaskData

func _ready() -> void:
	pass
	
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

func _on_edit_button_pressed() -> void:
	edit_requested.emit(task_data.id)
