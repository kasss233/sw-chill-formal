extends Control
@onready var text_edit=$TextEdit
@onready var enter_button=$Enter
signal text_entered(_text:String)




func _on_enter_pressed() -> void:
	emit_signal("text_entered",text_edit.text)
