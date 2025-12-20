extends Control
class_name UI
@onready var music_module=$MusicModule

signal music_changed(_name:String)
signal music_status_changed
func _ready() -> void:
	get_signal()
func get_signal():
	music_module.music_changed.connect(change_music)
	music_module.music_status_changed.connect(change_music_status)
	
	
	
func change_music(_name:String):
	music_changed.emit(_name)
	print("[UI] Changing music to: %s" % _name)
	
func change_music_status():
	music_status_changed.emit()
	print("[UI] Music status changed")
	
	
	
