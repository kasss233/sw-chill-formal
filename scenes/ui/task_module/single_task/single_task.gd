class_name SingleTask
extends Control
@onready var check_box=$HBoxContainer/CheckBox
@onready var button =$HBoxContainer/Button
@onready var line_edit=$HBoxContainer/LineEdit
func set_task_name(_name:String):
	line_edit.text=_name
func get_task_name()->String:
	return line_edit.text
func _on_button_pressed() -> void:
	self.queue_free()
func remove_task():
	self.queue_free()
