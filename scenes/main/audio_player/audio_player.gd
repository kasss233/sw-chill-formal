extends Node

@onready var sound_effect = $SoundEffect
@onready var bgm=$BGM
@export var audio_res:AudioRes
@export var ui:UI
var current_bgm:String=""
func _ready() -> void:
	setup_audio()
	get_signal()
func get_signal():
	ui.music_changed.connect(change_music)
	ui.music_status_changed.connect(change_music_status)
func change_music_status():
	if current_bgm=="":
		return
	var audio = bgm.get_node(current_bgm) as AudioStreamPlayer
	if audio == null:
		return
	if audio.is_playing():
		audio.stop()
		print("[AudioPlayer] Stopped music [%s]" % current_bgm)
	else:
		audio.play(0)
		print("[AudioPlayer] Resumed music [%s]" % current_bgm)
func change_music(_name:String):
	play_bgm(_name)
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
	current_bgm=_name
	print("[AudioPlayer] play music [%s]" % _name)
