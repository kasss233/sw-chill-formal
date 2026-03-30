extends Node

## 音频播放器，只负责音频的加载与播放
## 状态管理由 MusicState 单例负责

# --- 导出变量 ---
## 包含所有音频资源的 Resource
@export var audio_res: AudioRes

@export_group("Volume Settings")
## BGM 主音量（0.0 - 1.0）
@export_range(0.0, 1.0, 0.01) var bgm_volume: float = 1.0:
	set(value):
		bgm_volume = clamp(value, 0.0, 1.0)
		_apply_bgm_volume()
## 音效主音量（0.0 - 1.0）
@export_range(0.0, 1.0, 0.01) var sfx_volume: float = 1.0:
	set(value):
		sfx_volume = clamp(value, 0.0, 1.0)
		_apply_sfx_volume()

@export_group("Fade Settings")
## 是否启用淡入淡出效果
@export var fade_enabled: bool = true
## 淡入时长（秒）
@export_range(0.0, 5.0, 0.1) var fade_in_duration: float = 1.0
## 淡出时长（秒）
@export_range(0.0, 5.0, 0.1) var fade_out_duration: float = 1.0
## 淡入淡出曲线类型
@export_enum("Linear", "Ease In", "Ease Out", "Ease In Out") var fade_curve: int = 3

# --- 节点引用 ---
## 音效容器
@onready var sound_effect_container: Node = $SoundEffect
## 背景音乐容器
@onready var bgm_container: Node = $BGM

# --- 成员变量 ---
## 当前淡入淡出的 Tween 实例
var _fade_tween: Tween = null
## 目标音量（用于淡入淡出计算）
var _target_volume_db: float = 0.0

# --- 内置函数 ---
func _ready() -> void:
	_init_audio_players()
	_connect_music_state()
	print("[AudioPlayer] Initialized as autoload singleton")

# --- 内部初始化 ---
## 根据资源初始化所有的 AudioStreamPlayer
func _init_audio_players() -> void:
	if not audio_res:
		push_warning("[AudioPlayer] audio_res is not assigned!")
		return

	# 加载音效
	for item in audio_res.sound_effect:
		add_sound_effect_from_resource(item)

	# 加载背景音乐
	for item in audio_res.BGM:
		add_bgm_from_resource(item)
	audio_res.bgm_added.connect(_on_bgm_added)

## 连接 MusicState 信号
func _connect_music_state() -> void:
	if MusicState:
		MusicState.track_changed.connect(_on_track_changed)
		MusicState.playback_state_changed.connect(_on_playback_state_changed)

# --- 公有 API ---
## 播放指定名称的音效
func play_sound_effect(p_name: String) -> void:
	var audio = sound_effect_container.get_node_or_null(p_name) as AudioStreamPlayer
	if audio:
		audio.play()
	else:
		push_error("[AudioPlayer] Sound effect not found: %s" % p_name)

## 设置指定音效音量（0.0 - 1.0）
func set_sound_effect_volume(p_name: String, volume: float) -> void:
	var audio = sound_effect_container.get_node_or_null(p_name) as AudioStreamPlayer
	if audio:
		audio.volume_db = _linear_to_target_db(clamp(volume, 0.0, 1.0))
	else:
		push_error("[AudioPlayer] Sound effect not found: %s" % p_name)

## 设置 BGM 音量（0.0 - 1.0）
func set_bgm_volume(volume: float) -> void:
	bgm_volume = volume

## 获取 BGM 音量
func get_bgm_volume() -> float:
	return bgm_volume

## 设置音效音量（0.0 - 1.0）
func set_sfx_volume(volume: float) -> void:
	sfx_volume = volume

## 获取音效音量
func get_sfx_volume() -> float:
	return sfx_volume

# --- MusicState 信号回调 ---
## 当 MusicState 的曲目改变时
func _on_track_changed(track_name: String) -> void:
	if track_name == "":
		return
	_switch_to_track(track_name, MusicState.is_playing)

## 当 MusicState 的播放状态改变时
func _on_playback_state_changed(is_playing: bool) -> void:
	var current_track = MusicState.current_track
	if current_track == "":
		return

	var audio = bgm_container.get_node_or_null(current_track) as AudioStreamPlayer
	if not audio:
		return

	# 如果正在淡入淡出，取消它
	if _fade_tween and _fade_tween.is_valid():
		_fade_tween.kill()
		_fade_tween = null

	if is_playing:
		_play_current_track(audio)
	else:
		_pause_current_track(audio)

## 播放当前曲目
func _play_current_track(audio: AudioStreamPlayer) -> void:
	if audio.stream_paused:
		audio.stream_paused = false
	elif not audio.is_playing():
		audio.play()

	if fade_enabled and fade_in_duration > 0.0:
		audio.volume_db = -80.0
		_fade_tween = create_tween()
		_fade_tween.tween_property(audio, "volume_db", _linear_to_target_db(bgm_volume), fade_in_duration) \
			.set_trans(_get_fade_transition()).set_ease(_get_fade_ease())
		print("[AudioPlayer] Playing BGM with fade: [%s]" % MusicState.current_track)
	else:
		audio.volume_db = _linear_to_target_db(bgm_volume)
		print("[AudioPlayer] Playing BGM: [%s]" % MusicState.current_track)

## 暂停当前曲目
func _pause_current_track(audio: AudioStreamPlayer) -> void:
	if fade_enabled and fade_out_duration > 0.0 and audio.is_playing() and not audio.stream_paused:
		_fade_tween = create_tween()
		_fade_tween.tween_property(audio, "volume_db", -80.0, fade_out_duration) \
			.set_trans(_get_fade_transition()).set_ease(_get_fade_ease())
		_fade_tween.tween_callback(func():
			audio.stream_paused = true
			audio.volume_db = _linear_to_target_db(bgm_volume)
			print("[AudioPlayer] Paused BGM with fade: [%s]" % MusicState.current_track)
		)
	else:
		audio.stream_paused = true
		print("[AudioPlayer] Paused BGM: [%s]" % MusicState.current_track)

## 切换到指定曲目
func _switch_to_track(track_name: String, should_play: bool) -> void:
	# 停止当前正在播放的所有 BGM
	for child in bgm_container.get_children():
		if child is AudioStreamPlayer:
			child.stop()
			child.stream_paused = false

	var audio = bgm_container.get_node_or_null(track_name) as AudioStreamPlayer
	if not audio:
		push_error("[AudioPlayer] BGM not found: %s" % track_name)
		return

	if should_play:
		if fade_enabled and fade_in_duration > 0.0:
			audio.volume_db = -80.0
			audio.play()
			_fade_tween = create_tween()
			_fade_tween.tween_property(audio, "volume_db", _linear_to_target_db(bgm_volume), fade_in_duration) \
				.set_trans(_get_fade_transition()).set_ease(_get_fade_ease())
			print("[AudioPlayer] Started BGM with fade: [%s]" % track_name)
		else:
			audio.volume_db = _linear_to_target_db(bgm_volume)
			audio.play()
			print("[AudioPlayer] Started BGM: [%s]" % track_name)
	else:
		print("[AudioPlayer] Set BGM (paused): [%s]" % track_name)

# --- 信号回调 ---
func _on_music_finished() -> void:
	MusicState.notify_track_finished()

func _on_bgm_added(_name: String) -> void:
	var item = audio_res.get_bgm_item_by_name(_name)
	if item:
		add_bgm_from_resource(item)

## ---辅助函数---
func add_bgm_from_resource(audio_item: AudioItem) -> void:
	var audio = AudioStreamPlayer.new()
	audio.name = audio_item.name
	audio.stream = audio_item.stream
	audio.volume_db = _linear_to_target_db(bgm_volume)
	audio.finished.connect(_on_music_finished)
	bgm_container.add_child(audio)
	print("[AudioPlayer] Added BGM from resource: %s" % audio_item.name)

func add_sound_effect_from_resource(audio_item: AudioItem) -> void:
	if not audio_item:
		push_error("[%s]Audio item is null" % [name])
		return
	var audio = AudioStreamPlayer.new()
	audio.name = audio_item.name
	audio.stream = audio_item.stream
	audio.volume_db = linear_to_db(sfx_volume)
	sound_effect_container.add_child(audio)
	print("[AudioPlayer] Added sound effect from resource: %s" % audio_item.name)

# --- 内部淡入淡出函数 ---
## 将线性音量转换为目标 dB 值
func _linear_to_target_db(linear_volume: float) -> float:
	if linear_volume <= 0.0:
		return -80.0
	return linear_to_db(linear_volume)

## 获取淡入淡出的过渡类型
func _get_fade_transition() -> Tween.TransitionType:
	match fade_curve:
		0: return Tween.TRANS_LINEAR
		1: return Tween.TRANS_SINE
		2: return Tween.TRANS_SINE
		3: return Tween.TRANS_SINE
		_: return Tween.TRANS_LINEAR

## 获取淡入淡出的缓动类型
func _get_fade_ease() -> Tween.EaseType:
	match fade_curve:
		0: return Tween.EASE_IN_OUT
		1: return Tween.EASE_IN
		2: return Tween.EASE_OUT
		3: return Tween.EASE_IN_OUT
		_: return Tween.EASE_IN_OUT

## 应用 BGM 音量到所有 BGM 播放器
func _apply_bgm_volume() -> void:
	if not is_inside_tree():
		return
	_target_volume_db = _linear_to_target_db(bgm_volume)
	var current_track = MusicState.current_track if MusicState else ""
	for child in bgm_container.get_children():
		if child is AudioStreamPlayer:
			# 只更新当前播放的 BGM，避免干扰淡入淡出
			if child.name == current_track and (not _fade_tween or not _fade_tween.is_valid()):
				child.volume_db = _target_volume_db

## 应用音效音量到所有音效播放器
func _apply_sfx_volume() -> void:
	if not is_inside_tree():
		return
	var target_db = _linear_to_target_db(sfx_volume)
	for child in sound_effect_container.get_children():
		if child is AudioStreamPlayer:
			child.volume_db = target_db
