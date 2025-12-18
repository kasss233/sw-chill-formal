extends Node

@onready var sound_effect = $SoundEffect
@onready var bgm=$BGM
@export var audio_res:AudioRes
func _ready() -> void:
	setup_audio()
func setup_audio()->void:
	for item in audio_res.sound_effect:
		var audio = AudioStreamPlayer.new()
		audio.name = item.name
		audio.stream = item.stream
		sound_effect.add_child(audio)
		print("Loaded sound effect: %s" % item.name)
	for item in audio_res.BGM:
		var audio = AudioStreamPlayer.new()
		audio.name = item.name
		audio.stream = item.stream
		bgm.add_child(audio)
		print("Loaded BGM: %s" % item.name)
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
