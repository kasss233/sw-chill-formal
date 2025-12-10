extends Node

@onready var sound_effect = $SoundEffect
@onready var bgm=$BGM

func play_sound_effect(_name:String):
	var audio = sound_effect.get_node(_name) as AudioStreamPlayer
	if audio == null:
		return
	audio.play(0)
func play_bgm(_name:String):
		# 找到当前正在播放的 BGM	
	for child in bgm.get_children():
		if child is AudioStreamPlayer and child.is_playing():
			child.stop()
			break	
	var audio = bgm.get_node(_name) as AudioStreamPlayer
	if audio == null:
		return
	audio.play(0)
