class_name TTSPlayer extends Node
## [STUB] TTS 播放器 -- 核心函数（_play_audio / _download_audio / _decode_audio）未实现
## 保留文件结构和 ChatController 引用，等待后续接入真实 TTS 服务
##
## TTS 语音播放器
## 负责播放 AI 返回的语音合成音频
##
## 功能:
##   1. 接收 TTS 音频数据（URL 或 Base64）
##   2. 下载/解码音频并播放
##   3. 支持队列播放（多段语音连续播放）
##   4. 与角色口型动画同步
##
## 使用流程:
##   1. ChatController 收到 TTS 响应
##   2. 调用 play() 播放语音
##   3. 播放时触发 playback_started 信号
##   4. 播放完成触发 playback_finished 信号
##
## 音频格式支持:
##   - MP3 (通过 AudioStreamMP3)
##   - WAV (通过 AudioStreamWAV)
##   - OGG (通过 AudioStreamOggVorbis)

## 播放开始
signal playback_started()
## 播放完成
signal playback_finished()
## 播放队列清空
signal queue_finished()
## 播放进度更新（用于口型同步）
signal playback_progress(position: float, duration: float)
## 播放错误
signal playback_error(error: String)

## 音量（0-1）
@export_range(0.0, 1.0, 0.05) var volume: float = 1.0:
	set(value):
		volume = value
		if _audio_player:
			_audio_player.volume_db = linear_to_db(value)

## 是否启用队列模式（多段语音连续播放）
@export var queue_enabled: bool = true

## 音频播放器
var _audio_player: AudioStreamPlayer = null

## 播放队列 [{ url: String, data: PackedByteArray, format: String }]
var _play_queue: Array = []

## 当前是否正在播放
var _is_playing: bool = false

## 缓存的角色引用
var _character: Node = null


func _ready() -> void:
	_setup_audio_player()
	_apply_tts_state()
	if TTSState:
		TTSState.volume_changed.connect(_on_tts_state_volume)
		TTSState.audio_bus_changed.connect(_on_tts_state_bus)
		TTSState.queue_enabled_changed.connect(_on_tts_state_queue)


func _apply_tts_state() -> void:
	if not TTSState or not _audio_player:
		return
	volume = TTSState.get_volume()
	_audio_player.bus = TTSState.get_audio_bus()
	queue_enabled = TTSState.is_queue_enabled()


func _on_tts_state_volume(v: float) -> void:
	volume = v


func _on_tts_state_bus(bus_name: String) -> void:
	if _audio_player:
		_audio_player.bus = bus_name


func _on_tts_state_queue(enabled: bool) -> void:
	queue_enabled = enabled


func _setup_audio_player() -> void:
	_audio_player = AudioStreamPlayer.new()
	_audio_player.bus = "Master"  # TODO: 可配置音频总线
	_audio_player.finished.connect(_on_audio_finished)
	add_child(_audio_player)


## 设置角色节点引用（由 3D 场景主动调用）
func set_character(node: Node) -> void:
	_character = node


func _process(_delta: float) -> void:
	if _is_playing and _audio_player.playing:
		var position = _audio_player.get_playback_position()
		var duration = _get_stream_duration()
		if duration > 0:
			playback_progress.emit(position, duration)


## 播放 TTS 音频
## @param url 音频 URL（如果服务端返回 URL）
## @param data 音频二进制数据（如果服务端返回 base64 或直接二进制）
## @param format 音频格式 ("mp3", "wav", "ogg")
func play(url: String = "", data: PackedByteArray = [], format: String = "mp3") -> void:
	if queue_enabled:
		_play_queue.append({
			"url": url,
			"data": data,
			"format": format
		})
		if not _is_playing:
			_play_next()
	else:
		_play_audio(url, data, format)


## 停止播放
func stop() -> void:
	_audio_player.stop()
	_is_playing = false
	_play_queue.clear()
	_stop_character_animation()


## 暂停播放
func pause() -> void:
	_audio_player.stream_paused = true


## 继续播放
func resume() -> void:
	_audio_player.stream_paused = false


## 清空播放队列
func clear_queue() -> void:
	_play_queue.clear()


## 是否正在播放
func is_playing() -> bool:
	return _is_playing


## 获取队列长度
func get_queue_size() -> int:
	return _play_queue.size()


## 播放下一个队列项
func _play_next() -> void:
	if _play_queue.is_empty():
		queue_finished.emit()
		return

	var item = _play_queue.pop_front()
	_play_audio(item.get("url", ""), item.get("data", []), item.get("format", "mp3"))


## 实际播放音频
func _play_audio(url: String, data: PackedByteArray, format: String) -> void:
	# TODO: 实现音频加载和播放
	# 1. 如果有 URL，下载音频
	# 2. 如果有 data，直接解码
	# 3. 根据 format 创建对应的 AudioStream
	# 4. 设置到 _audio_player 并播放

	_is_playing = true
	playback_started.emit()
	_start_character_animation()

	# 占位：直接触发完成
	push_warning("TTSPlayer: play_audio 尚未实现")
	call_deferred("_on_audio_finished")


## 从 URL 下载音频
## @param url 音频 URL
## @param format 音频格式
## @return 音频二进制数据
func _download_audio(_url: String) -> PackedByteArray:
	# TODO: 实现 HTTP 下载
	return []


## 解码音频数据为 AudioStream
## @param data 音频二进制数据
## @param format 音频格式
## @return AudioStream 对象
func _decode_audio(_data: PackedByteArray, _format: String) -> AudioStream:
	# TODO: 实现音频解码
	# MP3: AudioStreamMP3.new(), set data
	# WAV: 使用 AudioStreamWAV 加载
	# OGG: AudioStreamOggVorbis.load_from_buffer()
	return null


## 获取当前音频流时长
func _get_stream_duration() -> float:
	if _audio_player.stream:
		return _audio_player.stream.get_length()
	return 0.0


## 播放完成回调
func _on_audio_finished() -> void:
	_is_playing = false
	_stop_character_animation()
	playback_finished.emit()

	# 继续播放队列
	if queue_enabled and not _play_queue.is_empty():
		_play_next()


## 启动角色口型动画
func _start_character_animation() -> void:
	if _character and _character.has_method("start_saying"):
		_character.start_saying()


## 停止角色口型动画
func _stop_character_animation() -> void:
	if _character and _character.has_method("stop_saying"):
		_character.stop_saying()
