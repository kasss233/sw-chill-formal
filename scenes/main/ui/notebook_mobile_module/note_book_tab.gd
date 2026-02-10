extends MarginContainer

@onready var canvas_layer: CanvasLayer = $CanvasLayer
@onready var note_book_mobile: NoteBookMobile = $CanvasLayer/NoteBookMobile
@onready var todo_button: MaterialToggleButton = $TodoButton

func _ready() -> void:
	note_book_mobile.visible = false
	# 设置 CanvasLayer 的初始层级
	canvas_layer.layer = 10

# --- Agent API（纯 UI 操作） ---
func show_module():
	if todo_button.current_state==0:
		LayerManager.bring_to_front(canvas_layer)
		GuiTransitions.show("notebookmobile")
		todo_button.set_state_no_signal(1)

func hide_module():
	if todo_button.current_state==1:
		GuiTransitions.hide("notebookmobile")
		todo_button.set_state_no_signal(0)

func _on_toggle_button_state_changed(old_state: int, new_state: int) -> void:
	if new_state==0:
		GuiTransitions.hide("notebookmobile")
	else:
		LayerManager.bring_to_front(canvas_layer)
		GuiTransitions.show("notebookmobile")
