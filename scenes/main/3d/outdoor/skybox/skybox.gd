extends Node3D
@export var sea: Node3D
@export var universe: Node3D
@export var snow: Node3D
func show_sea():
	sea.visible = true
	universe.visible = false
	snow.visible = false
func show_universe():
	sea.visible = false
	universe.visible = true
	snow.visible = false
func show_snow():
	sea.visible = false
	universe.visible = false
	snow.visible = true
func hide_all():
	sea.visible = false
	universe.visible = false
	snow.visible = false
