extends Node3D
@onready var particles = $GPUParticles3D
@export var min_amount: int = 300
@export var max_amount: int = 1200
## 雨滴数量,300-1000
func set_amount(_amount: int):
	## 判断数量是否在合理范围内
	if _amount < min_amount:
		_amount = min_amount
	elif _amount > max_amount:
		_amount = max_amount
	particles.amount = _amount
