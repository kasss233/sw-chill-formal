extends Control
class_name MusicOptionBoard
@export var option_scene:PackedScene
@onready var vbox=$VBoxContainer
@onready var label=$VBoxContainer/HBoxContainer/Label
func add_option(_name:String):
	var option_instance=option_scene.instantiate() as MusicOptionItem
	vbox.add_child(option_instance)
	option_instance.set_option_name(_name)
func set_music_name(_name:String):
	if label:
		label.text=_name


func _on_close_button_pressed() -> void:
	self.queue_free()
