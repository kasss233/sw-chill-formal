extends ColorRect

func _ready():
	# 初始状态
	set_playing(true)

func set_playing(is_playing: bool):
	var target = 1.0 if is_playing else 0.0
	var tween = create_tween()
	# 平滑过渡 intensity 属性，实现收缩动画
	tween.tween_property(self.material, "shader_parameter/playback_intensity", target, 0.4)\
		.set_trans(Tween.TRANS_CUBIC)\
		.set_ease(Tween.EASE_OUT)
