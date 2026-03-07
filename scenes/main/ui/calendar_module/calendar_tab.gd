extends MarginContainer

@onready var canvas_layer: CanvasLayer = $CanvasLayer
@onready var calendar_module: MarginContainer = $CanvasLayer/CalendarModule
@onready var toggle_button: MaterialToggleButton = $MaterialToggleButton

func _ready() -> void:
	calendar_module.visible = false
	canvas_layer.layer = 10

# --- Agent API（纯 UI 操作） ---
func show_module():
	if toggle_button.current_state == 0:
		LayerManager.bring_to_front(canvas_layer)
		GuiTransitions.show("calendar")
		toggle_button.set_state_no_signal(1)

func hide_module():
	if toggle_button.current_state == 1:
		GuiTransitions.hide("calendar")
		toggle_button.set_state_no_signal(0)

func _on_material_toggle_button_state_changed(old_state: int, new_state: int) -> void:
	if new_state == 0:
		GuiTransitions.hide("calendar")
	else:
		LayerManager.bring_to_front(canvas_layer)
		GuiTransitions.show("calendar")
