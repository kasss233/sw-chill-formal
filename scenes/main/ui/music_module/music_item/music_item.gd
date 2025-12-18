class_name MusicItem
extends Control
var music_name:String
@onready var button=$HBoxContainer/Button
signal music_changed(_name:String)
func _ready() -> void:
	set_music_name(music_name)
func set_music_name(_name:String):
	music_name=_name
	if button:
		button.text=music_name
func get_music_name():
	return music_name
func play_music():
	emit_signal("music_changed",music_name)
func _on_button_pressed() -> void:
	emit_signal("music_changed",music_name)
