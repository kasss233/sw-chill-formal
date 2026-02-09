extends Node3D

@export var sway_strength := 1      # 摆动幅度（角度）
@export var sway_speed := 1.5         # 摆动速度

var time := 0.0

func _process(delta):
	time += delta
	rotation.z = deg_to_rad(
		sin(time * sway_speed) * sway_strength
	)
