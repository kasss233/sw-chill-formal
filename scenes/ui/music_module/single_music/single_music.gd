class_name SingleMusic
extends Control

@onready var button=$Button
signal change_music(_name:String)
func music_set_name(_name:String):
	button.text=_name
func _on_button_pressed() -> void:
	emit_signal("change_music",button.text)
