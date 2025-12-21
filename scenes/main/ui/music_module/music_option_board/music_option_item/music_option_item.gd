extends Control
class_name MusicOptionItem
@onready var label=$HBoxContainer/Label
func set_option_name(_name:String):
	label.text=_name
