class_name SingleMusic
extends Control
@export var music_name:String="null"
@onready var button=$Button
signal music_changed(_name:String)
func _ready() -> void:
	set_music_name(music_name)
func set_music_name(_name:String):
	button.text=_name
func get_music_name():
	return button.text
func _on_button_pressed() -> void:
	emit_signal("music_changed",button.text)
