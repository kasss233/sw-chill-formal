extends Control

@onready var todo_button: MaterialToggleButton = $FrostedPanel/MarginContainer/VBoxContainer/TodoButton
@onready var note_button: MaterialToggleButton = $FrostedPanel/MarginContainer/VBoxContainer/NoteButton
@onready var task_module_new: MarginContainer = $CanvasLayer/TaskModuleNew


func _ready() -> void:
	task_module_new.visible = false

func _on_todo_button_state_changed(old_state: int, new_state: int) -> void:
	task_module_new.visible = !task_module_new.visible
