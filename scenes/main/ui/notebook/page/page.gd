class_name Page
extends Control
@onready var text_edit = $TextEdit
signal text_changed(_text: String)
func get_text() -> String:
	return text_edit.text
func set_text(text: String) -> void:
	text_edit.text = text
func _on_text_edit_text_changed() -> void:
	text_changed.emit(text_edit.text)
