extends Control
@onready var vbox=$FoldableContainer/ScrollContainer/VBoxContainer
@onready var folder=$FoldableContainer
signal music_changed(_name:String)
signal music_changed_play_status
signal music_changed_to_next
signal music_changed_to_last
func _ready() -> void:
	get_signal()

func get_signal() -> void:
	for c in vbox.get_children():
		c = c as SingleMusic
		if c:
			c.music_changed.connect(change_music)

func change_music(_name:String) -> void:
	print("[%s] change_music" % name)
	music_changed.emit(_name)
	folder.title = _name


func _on_last_button_pressed() -> void:
	music_changed_to_last.emit()
	print("[%s] music_changed_to_last emitted" % name)


func _on_status_button_pressed() -> void:
	music_changed_play_status.emit()
	print("[%s] music_changed_play_status emitted" % name)


func _on_next_button_pressed() -> void:
	music_changed_to_next.emit()
	print("[%s] music_changed_to_next emitted" % name)
