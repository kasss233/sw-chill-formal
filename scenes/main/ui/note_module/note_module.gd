extends Control
@export var note: PackedScene
var cnt: int = 0
func _on_material_button_pressed() -> void:
	if (cnt >= 20):
		print("[Note Module] note count limit reached")
		return
	cnt +=1
	var new_note = note.instantiate() as Note
	new_note.note_closed.connect(_on_note_closed)
	get_parent().add_child(new_note)
	#放在中间
	new_note.global_position = get_viewport().get_visible_rect().size / 2 - new_note.size / 2
func _on_note_closed() -> void:
	cnt -= 1
