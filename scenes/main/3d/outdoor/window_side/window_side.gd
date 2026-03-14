extends Node3D
@export var cherry: Node3D
@export var whale: Node3D
func show_cherry():
	cherry.visible = true
	whale.visible = false
func show_whale():
	cherry.visible = false
	whale.visible = true
func hide_all():
	cherry.visible = false
	whale.visible = false
