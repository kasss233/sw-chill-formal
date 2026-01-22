class_name PageButton
extends Control
@onready var button = $MaterialButton
signal page_changed(_name: String)
var page_name: String = " "
func set_page_name(_name: String):
	page_name = _name
	button.text = page_name
func get_page_name() -> String:
	return page_name
func _on_material_button_pressed() -> void:
	page_changed.emit(page_name)
