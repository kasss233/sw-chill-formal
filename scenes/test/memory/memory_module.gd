extends MarginContainer
@export var memory: Control
@export var memory_immutable: Control

func _on_material_segmented_button_segment_selected(index: int, text: String) -> void:
	match index:
		0:
			memory.visible = true
			memory_immutable.visible = false
		1:
			memory.visible = false
			memory_immutable.visible = true
