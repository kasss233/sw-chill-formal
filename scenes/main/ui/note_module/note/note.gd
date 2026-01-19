class_name Note
extends Control

var holding = false
var drag_offset = Vector2.ZERO
signal note_closed
func _on_close_button_pressed() -> void:
	note_closed.emit()
	self.queue_free()


func _on_move_button_button_up() -> void:
	holding = false


func _on_move_button_button_down() -> void:
	holding = true
	drag_offset = get_global_mouse_position() - global_position


func _input(event: InputEvent) -> void:
	if holding and event is InputEventMouseMotion:
		global_position = get_global_mouse_position() - drag_offset
