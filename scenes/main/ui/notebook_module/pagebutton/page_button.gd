class_name PageButton
extends Control
@onready var line_edit = $InnerPanel/HBoxContainer/LineEdit
@onready var remove_button = $InnerPanel/HBoxContainer/RemoveButton
@onready var inner_panel = $InnerPanel
signal page_changed(_name: String)
signal page_removed(_name: String)
var page_name: String = " "


func set_page_name(_name: String):
	page_name = _name
	line_edit.text = _name
func get_page_name() -> String:
	return page_name

func _on_line_edit_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if event.double_click:
			line_edit.editable = true
			line_edit.grab_focus()
			line_edit.select_all()
		else:
			page_changed.emit(page_name)

func _on_line_edit_focus_exited() -> void:
	line_edit.editable = false
	page_name = line_edit.text

func _on_line_edit_text_submitted(_new_text: String) -> void:
	line_edit.editable = false
	line_edit.release_focus()

func _on_inner_panel_mouse_entered() -> void:
	remove_button.show()

func _on_inner_panel_mouse_exited() -> void:
	remove_button.hide()


func _on_line_edit_mouse_entered() -> void:
	remove_button.show()


func _on_line_edit_mouse_exited() -> void:
	remove_button.hide()


func _on_remove_button_mouse_entered() -> void:
	remove_button.show()


func _on_remove_button_mouse_exited() -> void:
	remove_button.hide()


func _on_remove_button_pressed() -> void:
	page_removed.emit(page_name)
