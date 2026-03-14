extends Node3D
@export var flowers: Node3D
@export var cat: Node3D
func show_flowers():
	flowers.visible = true
	cat.visible = false
func show_cat():
	cat.visible = true
	flowers.visible = false
func hide_all():
	cat.visible = false
	flowers.visible = false
