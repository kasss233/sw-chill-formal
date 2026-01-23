extends Node

## 音乐状态管理单例
## 统一管理所有音乐相关状态，作为唯一的状态源
## UI 和 AudioPlayer 都从这里获取/更新状态

# --- 信号 ---
## 当前曲目改变时发出
signal track_changed(track_name: String)
## 播放状态改变时发出（播放/暂停）
signal playback_state_changed(is_playing: bool)
## 播放模式改变时发出
signal play_mode_changed(mode: int)
## 当前播放列表改变时发出
signal playlist_changed(playlist_name: String)
## 当前曲目播放完毕时发出
signal track_finished

# --- 播放模式枚举 ---
enum PlayMode {
	SEQUENTIAL = 0,  # 顺序播放
	RANDOM = 1,      # 随机播放
	SINGLE_LOOP = 2  # 单曲循环
}

# --- 状态变量 ---
## 当前播放的曲目名称
var current_track: String = "":
	set(value):
		if current_track != value:
			current_track = value
			track_changed.emit(value)

## 是否正在播放
var is_playing: bool = false:
	set(value):
		if is_playing != value:
			is_playing = value
			playback_state_changed.emit(value)

## 当前播放模式
var play_mode: int = PlayMode.SEQUENTIAL:
	set(value):
		if play_mode != value:
			play_mode = clamp(value, 0, 2)
			play_mode_changed.emit(play_mode)

## 当前播放列表名称
var current_playlist: String = "":
	set(value):
		if current_playlist != value:
			current_playlist = value
			playlist_changed.emit(value)

## 当前播放列表中的曲目索引
var current_track_index: int = -1

# --- 公有 API ---
## 设置当前曲目（不触发播放，只更新状态）
func set_track(track_name: String, track_index: int = -1) -> void:
	current_track = track_name
	current_track_index = track_index

## 设置播放状态
func set_playing(playing: bool) -> void:
	is_playing = playing

## 切换播放/暂停状态
func toggle_playback() -> void:
	is_playing = not is_playing

## 设置播放模式
func set_play_mode(mode: int) -> void:
	play_mode = mode

## 循环切换播放模式
func cycle_play_mode() -> void:
	play_mode = (play_mode + 1) % 3

## 设置当前播放列表
func set_playlist(playlist_name: String) -> void:
	current_playlist = playlist_name

## 通知曲目播放完毕
func notify_track_finished() -> void:
	track_finished.emit()

## 获取下一个播放模式的名称（用于 UI 显示）
func get_play_mode_name() -> String:
	match play_mode:
		PlayMode.SEQUENTIAL:
			return "顺序播放"
		PlayMode.RANDOM:
			return "随机播放"
		PlayMode.SINGLE_LOOP:
			return "单曲循环"
		_:
			return "未知"

func _ready() -> void:
	print("[MusicState] Initialized as autoload singleton")
