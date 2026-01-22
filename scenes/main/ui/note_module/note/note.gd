class_name Note
extends Control
@onready var text_edit: TextEdit = $TextEdit

var _tween: Tween
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


## ---api---
func set_text(text: String) -> void:
	if not is_node_ready():
		await ready
	
	if _tween:
		_tween.kill()
	
	_tween = create_tween()
	text_edit.text = ""
	
	# 设置打字速度，例如每秒20个字符
	var duration = text.length() / 10.0
	if duration < 0.1: duration = 0.1
	
	_tween.tween_method(
		func(length: int):
			text_edit.text = text.left(length)
			text_edit.set_caret_line(text_edit.get_line_count()),
		0,
		text.length(),
		duration
	)
