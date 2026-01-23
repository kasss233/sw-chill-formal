class_name Page
extends Control
@onready var text_edit = $TextEdit

signal text_changed(_text: String)

var _tween: Tween

func get_text() -> String:
	return text_edit.text

func set_text(text: String, animate: bool = false) -> void:
	if _tween:
		_tween.kill()
	
	if not animate:
		text_edit.text = text
		text_edit.mouse_filter = Control.MOUSE_FILTER_STOP
		return

	text_edit.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_edit.text = ""
	_tween = create_tween()
	
	var duration = text.length() / 15 # 每秒显示 15 个字符
	if duration <= 0:
		text_edit.text = text
		text_edit.mouse_filter = Control.MOUSE_FILTER_STOP
		return
		
	_tween.tween_method(func(i): text_edit.text = text.left(i), 0, text.length(), duration)
	_tween.tween_callback(func(): text_edit.mouse_filter = Control.MOUSE_FILTER_STOP)

func _on_text_edit_text_changed() -> void:
	text_changed.emit(text_edit.text)
