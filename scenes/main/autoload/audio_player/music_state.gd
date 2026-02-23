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
## 歌单创建时发出
signal playlist_created(playlist_name: String)
## 歌单删除时发出
signal playlist_deleted(playlist_name: String)
## 曲目被添加到歌单时发出
signal track_added_to_playlist(playlist_name: String, track_name: String)
## 曲目从歌单移除时发出
signal track_removed_from_playlist(playlist_name: String, track_name: String)
## 导入曲目添加时发出
signal imported_track_added(track_name: String)
## 导入曲目移除时发出
signal imported_track_removed(track_name: String)
## 内置曲目被用户删除时发出
signal builtin_track_removed(track_name: String)
## 持久化数据加载完毕时发出
signal data_loaded

# --- 播放模式枚举 ---
enum PlayMode {
	SEQUENTIAL = 0,  # 顺序播放
	RANDOM = 1,      # 随机播放
	SINGLE_LOOP = 2  # 单曲循环
}

# --- 持久化常量 ---
const SAVE_PATH = "user://music_data.json"

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
			_reset_shuffle()
			_save_data()

## 当前播放列表名称
var current_playlist: String = "":
	set(value):
		if current_playlist != value:
			current_playlist = value
			playlist_changed.emit(value)
			_reset_shuffle()
			_save_data()

## 当前播放列表中的曲目索引
var current_track_index: int = -1

# --- 运行时导航状态（不持久化） ---
## 运行时歌单 {name: Array[String]}，由 MusicModule 注册
var _runtime_playlists: Dictionary = {}
## 随机播放顺序
var _shuffled_tracks: Array[String] = []
## 当前随机播放位置
var _shuffle_index: int = -1

# --- 持久化数据 ---
## 用户创建的歌单 {歌单名: Array[String] 曲目名列表}
var _playlists: Dictionary = {}
## 用户导入的曲目 {曲目名: 文件路径}
var _imported_tracks: Dictionary = {}
## 用户删除的内置曲目名称列表
var _removed_builtin_tracks: Array[String] = []
## 上次播放的曲目
var last_track: String = ""
## 加载中标志（避免 setter 触发保存）
var _loading: bool = false

# --- 公有 API ---
## 设置当前曲目（不触发播放，只更新状态）
func set_track(track_name: String, track_index: int = -1) -> void:
	# 自动索引解析：当未传 index 时，从当前歌单中查找
	if track_index == -1 and current_playlist != "":
		var tracks = _get_track_list(current_playlist)
		var found_index = tracks.find(track_name)
		if found_index != -1:
			track_index = found_index
	current_track = track_name
	current_track_index = track_index
	last_track = track_name
	_save_data()

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
	play_next()

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

# ======================== 运行时歌单 API ========================

## 注册/更新运行时歌单（不持久化），由 MusicModule 调用
func register_runtime_playlist(p_name: String, tracks: Array[String]) -> void:
	_runtime_playlists[p_name] = tracks
	# 若为当前歌单则重置 shuffle
	if p_name == current_playlist:
		_reset_shuffle()
	print("[MusicState] Registered runtime playlist '%s' with %d tracks" % [p_name, tracks.size()])

## 获取歌单曲目列表（优先查运行时歌单，再查持久化歌单）
func _get_track_list(playlist_name: String) -> Array[String]:
	if _runtime_playlists.has(playlist_name):
		var result: Array[String] = []
		for track in _runtime_playlists[playlist_name]:
			result.append(track)
		return result
	if _playlists.has(playlist_name):
		var result: Array[String] = []
		for track in _playlists[playlist_name]:
			result.append(track)
		return result
	return [] as Array[String]

# ======================== 播放导航 API ========================

## 播放下一首（根据 play_mode 分发）
func play_next() -> bool:
	var tracks = _get_track_list(current_playlist)
	if tracks.is_empty():
		return false
	match play_mode:
		PlayMode.SEQUENTIAL:
			return _play_next_sequential(tracks)
		PlayMode.RANDOM:
			return _play_next_random(tracks)
		PlayMode.SINGLE_LOOP:
			replay_current()
			return true
		_:
			return false

## 播放上一首（根据 play_mode 分发）
func play_previous() -> bool:
	var tracks = _get_track_list(current_playlist)
	if tracks.is_empty():
		return false
	match play_mode:
		PlayMode.SEQUENTIAL, PlayMode.SINGLE_LOOP:
			return _play_prev_sequential(tracks)
		PlayMode.RANDOM:
			return _play_prev_random(tracks)
		_:
			return false

## 重新播放当前曲目（绕过 setter 的相同值守卫）
func replay_current() -> void:
	if current_track != "":
		track_changed.emit(current_track)

# --- 导航内部实现 ---

func _play_next_sequential(tracks: Array[String]) -> bool:
	if current_track_index == -1 and tracks.size() > 0:
		set_track(tracks[0], 0)
		return true
	var next_index = (current_track_index + 1) % tracks.size()
	set_track(tracks[next_index], next_index)
	return true

func _play_prev_sequential(tracks: Array[String]) -> bool:
	if current_track_index == -1 and tracks.size() > 0:
		set_track(tracks[tracks.size() - 1], tracks.size() - 1)
		return true
	var prev_index = (current_track_index - 1 + tracks.size()) % tracks.size()
	set_track(tracks[prev_index], prev_index)
	return true

func _play_next_random(tracks: Array[String]) -> bool:
	if tracks.is_empty():
		return false
	# 如果 shuffle 列表为空或与当前歌单不匹配，重新生成
	if _shuffled_tracks.is_empty() or _shuffled_tracks.size() != tracks.size():
		_generate_shuffled_tracks(tracks)
		# 已在播放某首歌，移到下一首
		if _shuffle_index >= 0:
			_shuffle_index += 1
			if _shuffle_index >= _shuffled_tracks.size():
				_shuffle_index = 0
		else:
			_shuffle_index = 0
	else:
		_shuffle_index += 1
		if _shuffle_index >= _shuffled_tracks.size():
			_shuffle_index = 0
	var target_name = _shuffled_tracks[_shuffle_index]
	var target_index = tracks.find(target_name)
	set_track(target_name, target_index)
	return true

func _play_prev_random(tracks: Array[String]) -> bool:
	if tracks.is_empty():
		return false
	if _shuffled_tracks.is_empty() or _shuffled_tracks.size() != tracks.size():
		_generate_shuffled_tracks(tracks)
		if _shuffle_index >= 0:
			_shuffle_index -= 1
			if _shuffle_index < 0:
				_shuffle_index = _shuffled_tracks.size() - 1
		else:
			_shuffle_index = 0
	else:
		_shuffle_index -= 1
		if _shuffle_index < 0:
			_shuffle_index = _shuffled_tracks.size() - 1
	var target_name = _shuffled_tracks[_shuffle_index]
	var target_index = tracks.find(target_name)
	set_track(target_name, target_index)
	return true

## Fisher-Yates 洗牌生成随机播放顺序
func _generate_shuffled_tracks(tracks: Array[String]) -> void:
	_shuffled_tracks.clear()
	for track in tracks:
		_shuffled_tracks.append(track)
	# Fisher-Yates 洗牌
	for i in range(_shuffled_tracks.size() - 1, 0, -1):
		var j = randi() % (i + 1)
		var temp = _shuffled_tracks[i]
		_shuffled_tracks[i] = _shuffled_tracks[j]
		_shuffled_tracks[j] = temp
	# 如果当前正在播放某首歌，找到它在随机列表中的位置
	if current_track != "":
		var pos = _shuffled_tracks.find(current_track)
		if pos != -1:
			_shuffle_index = pos
		else:
			_shuffle_index = -1
	else:
		_shuffle_index = -1
	print("[MusicState] Generated shuffled tracks, size: %d" % _shuffled_tracks.size())

## 重置 shuffle 状态
func _reset_shuffle() -> void:
	_shuffled_tracks.clear()
	_shuffle_index = -1

# ======================== 歌单管理 API ========================

## 创建歌单
func create_playlist(p_name: String) -> bool:
	if _playlists.has(p_name):
		push_warning("[MusicState] Playlist '%s' already exists" % p_name)
		return false
	_playlists[p_name] = [] as Array[String]
	_save_data()
	playlist_created.emit(p_name)
	print("[MusicState] Created playlist: %s" % p_name)
	return true

## 删除歌单（"收藏"歌单受保护，不可删除）
func delete_playlist(p_name: String) -> bool:
	if p_name == "收藏":
		push_warning("[MusicState] Cannot delete protected playlist '收藏'")
		return false
	if not _playlists.has(p_name):
		push_warning("[MusicState] Playlist '%s' not found" % p_name)
		return false
	_playlists.erase(p_name)
	_save_data()
	playlist_deleted.emit(p_name)
	print("[MusicState] Deleted playlist: %s" % p_name)
	return true

## 添加曲目到歌单
func add_track_to_playlist(playlist_name: String, track_name: String) -> bool:
	if not _playlists.has(playlist_name):
		push_warning("[MusicState] Playlist '%s' not found" % playlist_name)
		return false
	var tracks: Array = _playlists[playlist_name]
	if track_name in tracks:
		return true
	tracks.append(track_name)
	_playlists[playlist_name] = tracks
	if playlist_name == current_playlist:
		_reset_shuffle()
	_save_data()
	track_added_to_playlist.emit(playlist_name, track_name)
	return true

## 从歌单移除曲目
func remove_track_from_playlist(playlist_name: String, track_name: String) -> bool:
	if not _playlists.has(playlist_name):
		push_warning("[MusicState] Playlist '%s' not found" % playlist_name)
		return false
	var tracks: Array = _playlists[playlist_name]
	if track_name not in tracks:
		return false
	tracks.erase(track_name)
	_playlists[playlist_name] = tracks
	if playlist_name == current_playlist:
		_reset_shuffle()
	_save_data()
	track_removed_from_playlist.emit(playlist_name, track_name)
	return true

## 从所有歌单移除曲目
func remove_track_from_all_playlists(track_name: String) -> void:
	var changed := false
	for playlist_name in _playlists.keys():
		var tracks: Array = _playlists[playlist_name]
		if track_name in tracks:
			tracks.erase(track_name)
			_playlists[playlist_name] = tracks
			changed = true
	if changed:
		_save_data()

## 歌单是否存在
func has_playlist(p_name: String) -> bool:
	return _playlists.has(p_name)

## 曲目是否在歌单中
func is_track_in_playlist(playlist_name: String, track_name: String) -> bool:
	if not _playlists.has(playlist_name):
		return false
	return track_name in _playlists[playlist_name]

## 获取歌单中的所有曲目
func get_playlist_tracks(playlist_name: String) -> Array[String]:
	if not _playlists.has(playlist_name):
		return [] as Array[String]
	var result: Array[String] = []
	for track in _playlists[playlist_name]:
		result.append(track)
	return result

## 获取所有用户创建的歌单名称
func get_all_playlist_names() -> Array[String]:
	var result: Array[String] = []
	for key in _playlists.keys():
		result.append(key)
	return result

## 获取所有歌单数据的副本
func get_all_playlists_data() -> Dictionary:
	return _playlists.duplicate(true)

# ======================== 导入/删除音乐管理 ========================

## 记录导入曲目路径
func add_imported_track(p_name: String, file_path: String) -> void:
	_imported_tracks[p_name] = file_path
	_save_data()
	imported_track_added.emit(p_name)
	print("[MusicState] Added imported track: %s -> %s" % [p_name, file_path])

## 移除导入记录
func remove_imported_track(p_name: String) -> void:
	if _imported_tracks.has(p_name):
		_imported_tracks.erase(p_name)
		_save_data()
		imported_track_removed.emit(p_name)
		print("[MusicState] Removed imported track: %s" % p_name)

## 记录删除的内置曲目
func add_removed_builtin(p_name: String) -> void:
	if p_name not in _removed_builtin_tracks:
		_removed_builtin_tracks.append(p_name)
		_save_data()
		builtin_track_removed.emit(p_name)
		print("[MusicState] Added removed builtin: %s" % p_name)

## 检查内置曲目是否已被删除
func is_builtin_removed(p_name: String) -> bool:
	return p_name in _removed_builtin_tracks

## 获取所有导入曲目 {name: path}
func get_imported_tracks() -> Dictionary:
	return _imported_tracks.duplicate()

## 获取已删除的内置曲目列表
func get_removed_builtin_tracks() -> Array[String]:
	return _removed_builtin_tracks.duplicate()

## 检查曲目是否为导入曲目
func is_imported_track(p_name: String) -> bool:
	return _imported_tracks.has(p_name)

# ======================== 持久化 ========================

func _save_data() -> void:
	if _loading:
		return
	var data = {
		"version": 1,
		"imported_tracks": _imported_tracks,
		"removed_builtin_tracks": _removed_builtin_tracks,
		"playlists": {},
		"play_mode": play_mode,
		"current_playlist": current_playlist,
		"last_track": last_track
	}

	# 将歌单中的 Array 转为普通 Array 以便 JSON 序列化
	for key in _playlists.keys():
		var tracks: Array = []
		for track in _playlists[key]:
			tracks.append(track)
		data["playlists"][key] = tracks

	var json_string = JSON.stringify(data, "\t")
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(json_string)
		file.close()
	else:
		push_error("[MusicState] Failed to save data to %s" % SAVE_PATH)

func load_data() -> void:
	_loading = true
	if not FileAccess.file_exists(SAVE_PATH):
		print("[MusicState] No save file found, starting fresh")
		_loading = false
		data_loaded.emit()
		return

	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		push_error("[MusicState] Failed to open save file")
		_loading = false
		data_loaded.emit()
		return

	var json_string = file.get_as_text()
	file.close()

	var json = JSON.new()
	var error = json.parse(json_string)
	if error != OK:
		push_error("[MusicState] Failed to parse save file: %s" % json.get_error_message())
		# 重命名损坏文件为 .bak
		var dir = DirAccess.open("user://")
		if dir:
			dir.rename("music_data.json", "music_data.json.bak")
			print("[MusicState] Corrupted file renamed to music_data.json.bak")
		_loading = false
		data_loaded.emit()
		return

	var data = json.get_data()
	if not data is Dictionary:
		push_error("[MusicState] Invalid save data format")
		var dir = DirAccess.open("user://")
		if dir:
			dir.rename("music_data.json", "music_data.json.bak")
			print("[MusicState] Corrupted file renamed to music_data.json.bak")
		_loading = false
		data_loaded.emit()
		return

	# 恢复导入曲目（验证文件是否存在）
	_imported_tracks.clear()
	var imported_data = data.get("imported_tracks", {})
	var invalid_imports: Array[String] = []
	for track_name in imported_data.keys():
		var file_path: String = imported_data[track_name]
		if FileAccess.file_exists(file_path):
			_imported_tracks[track_name] = file_path
		else:
			push_warning("[MusicState] Imported track file not found, skipping: %s -> %s" % [track_name, file_path])
			invalid_imports.append(track_name)

	# 恢复已删除的内置曲目
	_removed_builtin_tracks.clear()
	var removed_data = data.get("removed_builtin_tracks", [])
	for track_name in removed_data:
		_removed_builtin_tracks.append(track_name)

	# 恢复歌单
	_playlists.clear()
	var playlists_data = data.get("playlists", {})
	for playlist_name in playlists_data.keys():
		var tracks: Array[String] = []
		for track_name in playlists_data[playlist_name]:
			tracks.append(track_name)
		_playlists[playlist_name] = tracks

	# 恢复播放模式
	play_mode = clamp(data.get("play_mode", PlayMode.SEQUENTIAL), 0, 2)

	# 恢复当前歌单
	current_playlist = data.get("current_playlist", "")

	# 恢复上次播放曲目
	last_track = data.get("last_track", "")

	_loading = false

	# 如果有无效的导入曲目，重新保存以清理
	if invalid_imports.size() > 0:
		_save_data()

	print("[MusicState] Loaded data: %d imported tracks, %d removed builtins, %d playlists" % [
		_imported_tracks.size(), _removed_builtin_tracks.size(), _playlists.size()
	])
	data_loaded.emit()

## 导出数据（用于云同步）
func export_data() -> Dictionary:
	var data = {
		"version": 1,
		"imported_tracks": _imported_tracks.duplicate(),
		"removed_builtin_tracks": _removed_builtin_tracks.duplicate(),
		"playlists": {},
		"play_mode": play_mode,
		"current_playlist": current_playlist,
		"last_track": last_track
	}
	for key in _playlists.keys():
		var tracks: Array = []
		for track in _playlists[key]:
			tracks.append(track)
		data["playlists"][key] = tracks
	return data

## 导入数据（用于云同步）
func import_data(data: Dictionary) -> void:
	if not data is Dictionary:
		push_error("[MusicState] Invalid import data")
		return

	_imported_tracks.clear()
	var imported_data = data.get("imported_tracks", {})
	for track_name in imported_data.keys():
		_imported_tracks[track_name] = imported_data[track_name]

	_removed_builtin_tracks.clear()
	var removed_data = data.get("removed_builtin_tracks", [])
	for track_name in removed_data:
		_removed_builtin_tracks.append(track_name)

	_playlists.clear()
	var playlists_data = data.get("playlists", {})
	for playlist_name in playlists_data.keys():
		var tracks: Array[String] = []
		for track_name in playlists_data[playlist_name]:
			tracks.append(track_name)
		_playlists[playlist_name] = tracks

	play_mode = clamp(data.get("play_mode", PlayMode.SEQUENTIAL), 0, 2)
	current_playlist = data.get("current_playlist", "")
	last_track = data.get("last_track", "")

	_save_data()
	print("[MusicState] Imported music data")
	data_loaded.emit()

func _ready() -> void:
	load_data()
	print("[MusicState] Initialized as autoload singleton")
