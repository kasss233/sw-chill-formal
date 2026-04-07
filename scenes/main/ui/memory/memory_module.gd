extends MarginContainer
@export var memory: Control
@export var memory_immutable: Control
@export var canvas_layer:CanvasLayer
func _on_material_segmented_button_segment_selected(index: int, text: String) -> void:
	match index:
		0:
			memory.visible = true
			memory_immutable.visible = false
		1:
			memory.visible = false
			memory_immutable.visible = true


func _on_memory_button_state_changed(old_state: int, new_state: int) -> void:
	if new_state==0:
		GuiTransitions.hide("memory")
	else:
		LayerManager.bring_to_front(canvas_layer)
		GuiTransitions.show("memory")
