extends Node3D
@export var black_hole: Node3D
@export var purple_planet: Node3D
@export var fire_planet: Node3D


func show_black_hole():
	black_hole.visible = true
	purple_planet.visible = false
	fire_planet.visible = false
func show_purple_planet():
	black_hole.visible = false
	purple_planet.visible = true
	fire_planet.visible = false
func show_fire_planet():
	black_hole.visible = false
	purple_planet.visible = false
	fire_planet.visible = true
func hide_all():
	black_hole.visible = false
	purple_planet.visible = false
	fire_planet.visible = false
