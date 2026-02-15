extends Node3D
@onready var particles = $GPUParticles3D
@export var min_amount: int = 500
@export var max_amount: int = 2000
func set_amount(_amount: int):
	print("Setting snow amount to: ", _amount)
	## 判断数量是否在合理范围内
	if _amount < min_amount:
		_amount = min_amount
	elif _amount > max_amount:
		_amount = max_amount
	particles.amount = _amount
