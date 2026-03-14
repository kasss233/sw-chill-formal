extends Node3D
@export var alarm_clock: Node3D
@export var night_light: Node3D
func show_alarm_clock() -> void:
	alarm_clock.visible = true
	night_light.visible = false
func show_night_light() -> void:
	alarm_clock.visible = false
	night_light.visible = true
func hide_all() -> void:
	alarm_clock.visible = false
	night_light.visible = false
