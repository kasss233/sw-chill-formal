extends Node

## 音频管理器，负责全局背景音乐（BGM）和音效（SFX）的加载与播放

# --- 导出变量 ---
## 包含所有音频资源的 Resource
@export var audio_res: AudioRes
## UI 节点引用，用于连接播放指令信号
@export var ui: UI

# --- 节点引用 ---
## 音效容器
@onready var sound_effect_container: Node = $SoundEffect
## 背景音乐容器
@onready var bgm_container: Node = $BGM

# --- 成员变量 ---
## 当前正在播放的 BGM 名称
var current_bgm_name: String = ""

# --- 内置函数 ---
func _ready() -> void:
	_init_audio_players()
	_connect_ui_signals()

# --- 内部初始化 ---
## 根据资源初始化所有的 AudioStreamPlayer
func _init_audio_players() -> void:
	if not audio_res:
		push_warning("[AudioPlayer] audio_res is not assigned!")
		return
		
	# 加载音效
	for item in audio_res.sound_effect:
		var audio = AudioStreamPlayer.new()
		audio.name = item.name
		audio.stream = item.stream
		sound_effect_container.add_child(audio)
		print("[AudioPlayer] Loaded sound effect: %s" % item.name)
		
	# 加载背景音乐
	for item in audio_res.BGM:
		var audio = AudioStreamPlayer.new()
		audio.name = item.name
		audio.stream = item.stream
		bgm_container.add_child(audio)
		print("[AudioPlayer] Loaded BGM: %s" % item.name)

## 连接来自 UI 的播放控制信号
func _connect_ui_signals() -> void:
	if ui:
		ui.music_changed.connect(_on_music_changed)
		ui.music_status_changed.connect(_on_music_status_changed)

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
	# 停止当前正在播放的所有 BGM 并重置暂停状态
	for child in bgm_container.get_children():
		if child is AudioStreamPlayer:
			child.stop()
			child.stream_paused = false
	
	var audio = bgm_container.get_node_or_null(p_name) as AudioStreamPlayer
	if audio:
		audio.play()
		current_bgm_name = p_name
		print("[AudioPlayer] Started BGM: [%s]" % p_name)
	else:
		push_error("[AudioPlayer] BGM not found: %s" % p_name)

## 切换当前 BGM 的播放/暂停状态（从停止位置恢复）
func toggle_bgm_playback() -> void:
	if current_bgm_name == "":
		return
		
	var audio = bgm_container.get_node_or_null(current_bgm_name) as AudioStreamPlayer
	if not audio:
		return
		
	# 如果正在播放且未暂停 -> 则暂停
	if audio.is_playing() and not audio.stream_paused:
		audio.stream_paused = true
		print("[AudioPlayer] Paused BGM: [%s]" % current_bgm_name)
	# 如果已暂停 -> 则恢复播放
	elif audio.stream_paused:
		audio.stream_paused = false
		print("[AudioPlayer] Resumed BGM: [%s]" % current_bgm_name)
	# 如果完全没在播放 -> 则从头开始
	else:
		audio.play()
		print("[AudioPlayer] Started BGM from beginning: [%s]" % current_bgm_name)

# --- 信号回调 ---
func _on_music_changed(p_name: String) -> void:
	play_bgm(p_name)

func _on_music_status_changed() -> void:
	toggle_bgm_playback()
