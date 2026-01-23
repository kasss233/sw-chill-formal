class_name PageButton
extends Control
@onready var line_edit = $InnerPanel/HBoxContainer/LineEdit
@onready var remove_button = $InnerPanel/HBoxContainer/RemoveButton
@onready var inner_panel = $InnerPanel
signal page_changed(_name: String)
signal page_removed(_name: String)
var page_name: String = " "


func _ready() -> void:
	inner_panel.focus_mode = Control.FOCUS_ALL
	inner_panel.focus_exited.connect(_on_inner_panel_focus_exited)
	inner_panel.gui_input.connect(_on_inner_panel_gui_input)


func set_page_name(_name: String):
	page_name = _name
	line_edit.text = _name
func get_page_name() -> String:
	return page_name


func select_button(_emit: bool = true) -> void:
	inner_panel.grab_focus()
	if _emit:
		page_changed.emit(page_name)
func _on_line_edit_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if event.double_click:
			line_edit.editable = true
			line_edit.grab_focus()
			line_edit.select_all()
		else:
			select_button()
func _on_inner_panel_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		select_button()
func _on_line_edit_focus_exited() -> void:
	line_edit.editable = false
	page_name = line_edit.text

func _on_line_edit_text_submitted(_new_text: String) -> void:
	line_edit.editable = false
	line_edit.release_focus()


func _on_remove_button_pressed() -> void:
	page_removed.emit(page_name)


func _on_inner_panel_focus_entered() -> void:
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(inner_panel, "border_color", Color(1, 1, 1, 0.5), 0.2)
	tween.tween_property(inner_panel, "background_color", Color(1, 1, 1, 0.15), 0.2)

func _on_inner_panel_focus_exited() -> void:
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(inner_panel, "border_color", Color(1, 1, 1, 0.1), 0.2)
	tween.tween_property(inner_panel, "background_color", Color(1, 1, 1, 0.05), 0.2)
