extends Node

## 音频管理器，负责全局背景音乐（BGM）和音效（SFX）的加载与播放

# --- 信号 ---
## 当音乐改变时发出
signal music_changed(p_name: String)
## 当音乐播放完毕时发出
signal music_finished()

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
## 当前正在播放的 BGM 名称
var current_bgm_name: String = ""
## 当前是否处于暂停状态（用于切换歌曲时保持状态）
var is_paused: bool = true
## 当前淡入淡出的 Tween 实例
var _fade_tween: Tween = null
## 目标音量（用于淡入淡出计算）
var _target_volume_db: float = 0.0

# --- 内置函数 ---
func _ready() -> void:
	_init_audio_players()
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

# --- 公有 API ---
## 播放指定名称的音效
func play_sound_effect(p_name: String) -> void:
	var audio = sound_effect_container.get_node_or_null(p_name) as AudioStreamPlayer
	if audio:
		audio.play()
	else:
		push_error("[AudioPlayer] Sound effect not found: %s" % p_name)

## 播放指定名称的背景音乐（会自动停止当前播放的 BGM）
func play_bgm(p_name: String) -> void:
	set_bgm(p_name, true)
	is_paused = false

## 设置背景音乐，可选择是否立即播放
func set_bgm(p_name: String, p_play: bool = true) -> void:
	# 停止当前正在播放的所有 BGM 并重置暂停状态
	for child in bgm_container.get_children():
		if child is AudioStreamPlayer:
			child.stop()
			child.stream_paused = false
	
	var audio = bgm_container.get_node_or_null(p_name) as AudioStreamPlayer
	if audio:
		current_bgm_name = p_name
		music_changed.emit(p_name)
		if p_play:
			audio.play()
			print("[AudioPlayer] Started BGM: [%s]" % p_name)
		else:
			print("[AudioPlayer] Set BGM (paused): [%s]" % p_name)
	else:
		push_error("[AudioPlayer] BGM not found: %s" % p_name)

## 切换到指定的背景音乐，保持当前的播放/暂停状态
func switch_bgm(p_name: String) -> void:
	if not is_paused and fade_enabled:
		# 使用淡入淡出切换
		_fade_to_bgm(p_name, fade_out_duration, false)
	else:
		set_bgm(p_name, not is_paused)

## 切换当前 BGM 的播放/暂停状态（从停止位置恢复）
func toggle_bgm_playback() -> void:
	if current_bgm_name == "":
		return
		
	var audio = bgm_container.get_node_or_null(current_bgm_name) as AudioStreamPlayer
	if not audio:
		return
	
	# 如果正在淡入淡出，取消它并立即同步状态
	if _fade_tween and _fade_tween.is_valid():
		_fade_tween.kill()
		_fade_tween = null
		# 根据当前 is_paused 状态立即同步音频状态
		if is_paused:
			audio.stream_paused = true
			audio.volume_db = _linear_to_target_db(bgm_volume)
		else:
			audio.stream_paused = false
			audio.volume_db = _linear_to_target_db(bgm_volume)
	
	# 立即切换状态（先更新状态，再执行动作）
	var new_paused_state = not is_paused
	is_paused = new_paused_state
	
	if new_paused_state:
		# 需要暂停
		if fade_enabled and fade_out_duration > 0.0 and audio.is_playing() and not audio.stream_paused:
			_fade_tween = create_tween()
			_fade_tween.tween_property(audio, "volume_db", -80.0, fade_out_duration) \
				.set_trans(_get_fade_transition()).set_ease(_get_fade_ease())
			_fade_tween.tween_callback(func():
				if is_paused:  # 再次检查状态，防止在淡出过程中被取消
					audio.stream_paused = true
					audio.volume_db = _linear_to_target_db(bgm_volume)
				print("[AudioPlayer] Paused BGM with fade: [%s]" % current_bgm_name)
			)
		else:
			audio.stream_paused = true
			print("[AudioPlayer] Paused BGM: [%s]" % current_bgm_name)
	else:
		# 需要播放
		if audio.stream_paused:
			audio.stream_paused = false
		elif not audio.is_playing():
			audio.play()
		
		if fade_enabled and fade_in_duration > 0.0:
			audio.volume_db = -80.0
			_fade_tween = create_tween()
			_fade_tween.tween_property(audio, "volume_db", _linear_to_target_db(bgm_volume), fade_in_duration) \
				.set_trans(_get_fade_transition()).set_ease(_get_fade_ease())
			print("[AudioPlayer] Playing BGM with fade: [%s]" % current_bgm_name)
		else:
			audio.volume_db = _linear_to_target_db(bgm_volume)
			print("[AudioPlayer] Playing BGM: [%s]" % current_bgm_name)

## 获取当前是否处于暂停状态
func get_is_paused() -> bool:
	return is_paused

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

## 根据名称切换BGM（保持播放/暂停状态）
func change_bgm(p_name: String) -> void:
	switch_bgm(p_name)

## 切换播放/暂停状态
func toggle_playback() -> void:
	toggle_bgm_playback()

## 带淡入效果播放 BGM
func play_bgm_with_fade(p_name: String, custom_fade_duration: float = -1.0) -> void:
	var duration = custom_fade_duration if custom_fade_duration >= 0 else fade_in_duration
	_fade_to_bgm(p_name, duration, true)

## 带淡出效果停止当前 BGM
func stop_bgm_with_fade(custom_fade_duration: float = -1.0) -> void:
	var duration = custom_fade_duration if custom_fade_duration >= 0 else fade_out_duration
	_fade_out_current_bgm(duration, true)

## 带交叉淡入淡出效果切换 BGM
func crossfade_to_bgm(p_name: String, custom_fade_duration: float = -1.0) -> void:
	if p_name == current_bgm_name:
		return
	var duration = custom_fade_duration if custom_fade_duration >= 0 else fade_out_duration
	_fade_to_bgm(p_name, duration, false)

# --- 信号回调 ---
func _on_music_finished() -> void:
	music_finished.emit()
	
func _on_bgm_added(_name: String) -> void:
	var item = audio_res.get_bgm_item_by_name(_name)
	if item:
		add_bgm_from_resource(item)

## ---辅助函数---
func add_bgm_from_resource(audio_item:AudioItem):
	var audio = AudioStreamPlayer.new()
	audio.name = audio_item.name
	audio.stream = audio_item.stream
	audio.volume_db = _linear_to_target_db(bgm_volume)
	audio.finished.connect(_on_music_finished)
	bgm_container.add_child(audio)
	print("[AudioPlayer] Added BGM from resource: %s" % audio_item.name)
func add_sound_effect_from_resource(audio_item:AudioItem):
	if not audio_item:
		push_error("[%s]Audio item is null"%[name])
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

## 淡入淡出切换到新的 BGM
func _fade_to_bgm(p_name: String, duration: float, stop_immediately: bool = false) -> void:
	# 取消之前的淡入淡出
	if _fade_tween and _fade_tween.is_valid():
		_fade_tween.kill()
	
	var old_audio = bgm_container.get_node_or_null(current_bgm_name) as AudioStreamPlayer
	var new_audio = bgm_container.get_node_or_null(p_name) as AudioStreamPlayer
	
	if not new_audio:
		push_error("[AudioPlayer] BGM not found: %s" % p_name)
		return
	
	_target_volume_db = _linear_to_target_db(bgm_volume)
	
	# 如果没有启用淡入淡出或时长为0，直接切换
	if not fade_enabled or duration <= 0.0:
		if old_audio and old_audio != new_audio:
			old_audio.stop()
			old_audio.stream_paused = false
		current_bgm_name = p_name
		music_changed.emit(p_name)
		new_audio.volume_db = _target_volume_db
		new_audio.play()
		is_paused = false
		print("[AudioPlayer] Started BGM (no fade): [%s]" % p_name)
		return
	
	_fade_tween = create_tween()
	_fade_tween.set_parallel(true)
	
	# 淡出旧的 BGM
	if old_audio and old_audio.is_playing() and old_audio != new_audio:
		if stop_immediately:
			old_audio.stop()
			old_audio.stream_paused = false
		else:
			_fade_tween.tween_property(old_audio, "volume_db", -80.0, duration) \
				.set_trans(_get_fade_transition()).set_ease(_get_fade_ease())
			_fade_tween.tween_callback(old_audio.stop).set_delay(duration)
	
	# 淡入新的 BGM
	current_bgm_name = p_name
	music_changed.emit(p_name)
	new_audio.volume_db = -80.0
	new_audio.play()
	is_paused = false
	
	_fade_tween.tween_property(new_audio, "volume_db", _target_volume_db, duration) \
		.set_trans(_get_fade_transition()).set_ease(_get_fade_ease())
	
	print("[AudioPlayer] Fading to BGM: [%s] over %.1fs" % [p_name, duration])

## 淡出当前 BGM
func _fade_out_current_bgm(duration: float, stop_after: bool = true) -> void:
	if current_bgm_name == "":
		return
	
	var audio = bgm_container.get_node_or_null(current_bgm_name) as AudioStreamPlayer
	if not audio or not audio.is_playing():
		return
	
	# 取消之前的淡入淡出
	if _fade_tween and _fade_tween.is_valid():
		_fade_tween.kill()
	
	# 如果没有启用淡入淡出或时长为0，直接停止
	if not fade_enabled or duration <= 0.0:
		if stop_after:
			audio.stop()
			is_paused = true
		print("[AudioPlayer] Stopped BGM (no fade): [%s]" % current_bgm_name)
		return
	
	_fade_tween = create_tween()
	_fade_tween.tween_property(audio, "volume_db", -80.0, duration) \
		.set_trans(_get_fade_transition()).set_ease(_get_fade_ease())
	
	if stop_after:
		_fade_tween.tween_callback(func():
			audio.stop()
			audio.volume_db = _linear_to_target_db(bgm_volume)
			is_paused = true
			print("[AudioPlayer] Fade out complete, BGM stopped: [%s]" % current_bgm_name)
		)
	else:
		_fade_tween.tween_callback(func():
			print("[AudioPlayer] Fade out complete: [%s]" % current_bgm_name)
		)

## 淡入当前 BGM（用于暂停恢复）
func _fade_in_current_bgm(duration: float) -> void:
	if current_bgm_name == "":
		return
	
	var audio = bgm_container.get_node_or_null(current_bgm_name) as AudioStreamPlayer
	if not audio:
		return
	
	# 取消之前的淡入淡出
	if _fade_tween and _fade_tween.is_valid():
		_fade_tween.kill()
	
	_target_volume_db = _linear_to_target_db(bgm_volume)
	
	# 如果没有启用淡入淡出或时长为0，直接恢复
	if not fade_enabled or duration <= 0.0:
		audio.volume_db = _target_volume_db
		if audio.stream_paused:
			audio.stream_paused = false
		elif not audio.is_playing():
			audio.play()
		is_paused = false
		return
	
	audio.volume_db = -80.0
	if audio.stream_paused:
		audio.stream_paused = false
	elif not audio.is_playing():
		audio.play()
	is_paused = false
	
	_fade_tween = create_tween()
	_fade_tween.tween_property(audio, "volume_db", _target_volume_db, duration) \
		.set_trans(_get_fade_transition()).set_ease(_get_fade_ease())
	
	print("[AudioPlayer] Fading in BGM: [%s] over %.1fs" % [current_bgm_name, duration])

## 应用 BGM 音量到所有 BGM 播放器
func _apply_bgm_volume() -> void:
	if not is_inside_tree():
		return
	_target_volume_db = _linear_to_target_db(bgm_volume)
	for child in bgm_container.get_children():
		if child is AudioStreamPlayer:
			# 只更新当前播放的 BGM，避免干扰淡入淡出
			if child.name == current_bgm_name and (not _fade_tween or not _fade_tween.is_valid()):
				child.volume_db = _target_volume_db

## 应用音效音量到所有音效播放器
func _apply_sfx_volume() -> void:
	if not is_inside_tree():
		return
	var target_db = _linear_to_target_db(sfx_volume)
	for child in sound_effect_container.get_children():
		if child is AudioStreamPlayer:
			child.volume_db = target_db
