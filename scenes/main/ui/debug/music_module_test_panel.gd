extends Control

## MusicModule测试页 - 测试MusicModule的Agent API

# UI节点引用
var music_module: MusicModule = null  # 需要从外部设置

@onready var info_label: RichTextLabel = $MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/InfoLabel
@onready var music_name_input: LineEdit = $MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/InputSection/MusicNameInput
@onready var playlist_name_input: LineEdit = $MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/InputSection/PlaylistNameInput
@onready var play_mode_input: LineEdit = $MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/InputSection/PlayModeInput

# 测试按钮 - 播放控制
@onready var play_music_btn: Button = $MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/PlaybackSection/PlayMusicBtn
@onready var pause_btn: Button = $MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/PlaybackSection/PauseBtn
@onready var resume_btn: Button = $MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/PlaybackSection/ResumeBtn
@onready var play_next_btn: Button = $MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/PlaybackSection/PlayNextBtn
@onready var play_previous_btn: Button = $MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/PlaybackSection/PlayPreviousBtn
@onready var set_mode_btn: Button = $MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/PlaybackSection/SetModeBtn

# 测试按钮 - 歌单管理
@onready var switch_list_btn: Button = $MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/PlaylistSection/SwitchListBtn
@onready var create_playlist_btn: Button = $MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/PlaylistSection/CreatePlaylistBtn
@onready var add_music_btn: Button = $MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/PlaylistSection/AddMusicBtn
@onready var remove_music_btn: Button = $MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/PlaylistSection/RemoveMusicBtn
@onready var delete_playlist_btn: Button = $MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/PlaylistSection/DeletePlaylistBtn

# 测试按钮 - 查询信息
@onready var get_current_info_btn: Button = $MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/QuerySection/GetCurrentInfoBtn
@onready var get_all_playlists_btn: Button = $MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/QuerySection/GetAllPlaylistsBtn
@onready var get_playlist_music_btn: Button = $MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/QuerySection/GetPlaylistMusicBtn
@onready var get_all_music_btn: Button = $MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/QuerySection/GetAllMusicBtn

func _ready() -> void:
	# 连接播放控制按钮
	play_music_btn.pressed.connect(_on_play_music_pressed)
	pause_btn.pressed.connect(_on_pause_pressed)
	resume_btn.pressed.connect(_on_resume_pressed)
	play_next_btn.pressed.connect(_on_play_next_pressed)
	play_previous_btn.pressed.connect(_on_play_previous_pressed)
	set_mode_btn.pressed.connect(_on_set_mode_pressed)

	# 连接歌单管理按钮
	switch_list_btn.pressed.connect(_on_switch_list_pressed)
	create_playlist_btn.pressed.connect(_on_create_playlist_pressed)
	add_music_btn.pressed.connect(_on_add_music_pressed)
	remove_music_btn.pressed.connect(_on_remove_music_pressed)
	delete_playlist_btn.pressed.connect(_on_delete_playlist_pressed)

	# 连接查询按钮
	get_current_info_btn.pressed.connect(_on_get_current_info_pressed)
	get_all_playlists_btn.pressed.connect(_on_get_all_playlists_pressed)
	get_playlist_music_btn.pressed.connect(_on_get_playlist_music_pressed)
	get_all_music_btn.pressed.connect(_on_get_all_music_pressed)

	_log_info("MusicModule测试面板已就绪")
	_log_info("请先设置music_module引用")

## 设置要测试的MusicModule实例
func set_music_module(module: MusicModule) -> void:
	music_module = module
	_log_info("已连接到MusicModule: %s" % module.name)

# --- 播放控制测试 ---

## 测试: 播放指定音乐
func _on_play_music_pressed() -> void:
	if not _check_module():
		return

	var music_name = music_name_input.text
	if music_name.is_empty():
		_log_error("✗ 请输入音乐名称")
		return

	_log_info("调用 agent_play_music(music_name='%s')" % music_name)
	var success = music_module.agent_play_music(music_name)

	if success:
		_log_success("✓ 开始播放: %s" % music_name)
	else:
		_log_error("✗ 播放失败，音乐不存在或不在当前歌单")

## 测试: 暂停播放
func _on_pause_pressed() -> void:
	if not _check_module():
		return

	_log_info("调用 agent_set_playing(false)")
	var success = music_module.agent_set_playing(false)

	if success:
		_log_success("✓ 已暂停播放")
	else:
		_log_error("✗ 暂停失败")

## 测试: 继续播放
func _on_resume_pressed() -> void:
	if not _check_module():
		return

	_log_info("调用 agent_set_playing(true)")
	var success = music_module.agent_set_playing(true)

	if success:
		_log_success("✓ 已继续播放")
	else:
		_log_error("✗ 继续播放失败")

## 测试: 播放下一首
func _on_play_next_pressed() -> void:
	if not _check_module():
		return

	_log_info("调用 agent_play_next()")
	var success = music_module.agent_play_next()

	if success:
		_log_success("✓ 已切换到下一首")
	else:
		_log_error("✗ 切换失败")

## 测试: 播放上一首
func _on_play_previous_pressed() -> void:
	if not _check_module():
		return

	_log_info("调用 agent_play_previous()")
	var success = music_module.agent_play_previous()

	if success:
		_log_success("✓ 已切换到上一首")
	else:
		_log_error("✗ 切换失败")

## 测试: 设置播放模式
func _on_set_mode_pressed() -> void:
	if not _check_module():
		return

	var mode = play_mode_input.text.to_int()
	if mode < 0 or mode > 2:
		_log_error("✗ 播放模式必须是 0(顺序), 1(随机), 2(单曲循环)")
		return

	_log_info("调用 agent_set_play_mode(mode=%d)" % mode)
	var success = music_module.agent_set_play_mode(mode)

	if success:
		var mode_names = ["顺序播放", "随机播放", "单曲循环"]
		_log_success("✓ 播放模式已设置为: %s" % mode_names[mode])
	else:
		_log_error("✗ 设置失败")

# --- 歌单管理测试 ---

## 测试: 切换歌单
func _on_switch_list_pressed() -> void:
	if not _check_module():
		return

	var list_name = playlist_name_input.text
	if list_name.is_empty():
		_log_error("✗ 请输入歌单名称")
		return

	_log_info("调用 agent_switch_to_list(list_name='%s')" % list_name)
	var success = music_module.agent_switch_to_list(list_name)

	if success:
		_log_success("✓ 已切换到歌单: %s" % list_name)
	else:
		_log_error("✗ 切换失败，歌单不存在")

## 测试: 创建新歌单
func _on_create_playlist_pressed() -> void:
	if not _check_module():
		return

	var list_name = playlist_name_input.text
	if list_name.is_empty():
		_log_error("✗ 请输入歌单名称")
		return

	_log_info("调用 agent_create_playlist(list_name='%s')" % list_name)
	var success = music_module.agent_create_playlist(list_name)

	if success:
		_log_success("✓ 已创建歌单: %s" % list_name)
	else:
		_log_error("✗ 创建失败，歌单可能已存在")

## 测试: 添加音乐到歌单
func _on_add_music_pressed() -> void:
	if not _check_module():
		return

	var list_name = playlist_name_input.text
	var music_name = music_name_input.text

	if list_name.is_empty() or music_name.is_empty():
		_log_error("✗ 请输入歌单名称和音乐名称")
		return

	_log_info("调用 agent_add_music_to_list(list_name='%s', music_name='%s')" % [list_name, music_name])
	var success = music_module.agent_add_music_to_list(list_name, music_name)

	if success:
		_log_success("✓ 已将 '%s' 添加到歌单 '%s'" % [music_name, list_name])
	else:
		_log_error("✗ 添加失败，歌单不存在")

## 测试: 从歌单移除音乐
func _on_remove_music_pressed() -> void:
	if not _check_module():
		return

	var list_name = playlist_name_input.text
	var music_name = music_name_input.text

	if list_name.is_empty() or music_name.is_empty():
		_log_error("✗ 请输入歌单名称和音乐名称")
		return

	_log_info("调用 agent_remove_music_from_list(list_name='%s', music_name='%s')" % [list_name, music_name])
	var success = music_module.agent_remove_music_from_list(list_name, music_name)

	if success:
		_log_success("✓ 已从歌单 '%s' 移除 '%s'" % [list_name, music_name])
	else:
		_log_error("✗ 移除失败，歌单不存在")

## 测试: 删除歌单
func _on_delete_playlist_pressed() -> void:
	if not _check_module():
		return

	var list_name = playlist_name_input.text

	if list_name.is_empty():
		_log_error("✗ 请输入歌单名称")
		return

	_log_info("调用 agent_delete_playlist(list_name='%s')" % list_name)
	var success = music_module.agent_delete_playlist(list_name)

	if success:
		_log_success("✓ 已删除歌单: %s" % list_name)
	else:
		_log_error("✗ 删除失败，歌单不存在或为受保护歌单")

# --- 查询信息测试 ---

## 测试: 获取当前播放信息
func _on_get_current_info_pressed() -> void:
	if not _check_module():
		return

	_log_info("调用 agent_get_current_music_info()")
	var info = music_module.agent_get_current_music_info()

	if info.is_empty():
		_log_error("✗ 无法获取播放信息")
	else:
		_log_success("✓ 当前播放信息:")
		_log_data("  曲目: %s" % info.track_name)
		_log_data("  播放状态: %s" % ("播放中" if info.is_playing else "已暂停"))
		var mode_names = ["顺序播放", "随机播放", "单曲循环"]
		_log_data("  播放模式: %s" % mode_names[info.play_mode])
		_log_data("  当前歌单: %s" % info.playlist)

## 测试: 获取所有歌单
func _on_get_all_playlists_pressed() -> void:
	if not _check_module():
		return

	_log_info("调用 agent_get_all_playlists()")
	var playlists = music_module.agent_get_all_playlists()

	_log_success("✓ 共有 %d 个歌单:" % playlists.size())
	for playlist in playlists:
		_log_data("  - %s" % playlist)

## 测试: 获取指定歌单的音乐
func _on_get_playlist_music_pressed() -> void:
	if not _check_module():
		return

	var list_name = playlist_name_input.text
	if list_name.is_empty():
		_log_error("✗ 请输入歌单名称")
		return

	_log_info("调用 agent_get_playlist_music(list_name='%s')" % list_name)
	var music_list = music_module.agent_get_playlist_music(list_name)

	_log_success("✓ 歌单 '%s' 包含 %d 首音乐:" % [list_name, music_list.size()])
	for music in music_list:
		_log_data("  - %s" % music)

## 测试: 获取所有歌单及其音乐
func _on_get_all_music_pressed() -> void:
	if not _check_module():
		return

	_log_info("调用 agent_get_all_playlists_music()")
	var all_data = music_module.agent_get_all_playlists_music()

	_log_success("✓ 所有歌单及其音乐:")
	for list_name in all_data:
		var music_list = all_data[list_name]
		_log_data("  [%s] (%d首)" % [list_name, music_list.size()])
		for music in music_list:
			_log_data("    - %s" % music)

# --- 辅助方法 ---

## 检查MusicModule是否已设置
func _check_module() -> bool:
	if music_module == null:
		_log_error("✗ MusicModule未设置，请先调用set_music_module()")
		return false
	return true

## 日志输出 - 普通信息
func _log_info(message: String) -> void:
	info_label.append_text("[color=white]%s[/color]\n" % message)
	print("[MusicModuleTest] %s" % message)

## 日志输出 - 成功信息
func _log_success(message: String) -> void:
	info_label.append_text("[color=green]%s[/color]\n" % message)
	print("[MusicModuleTest] %s" % message)

## 日志输出 - 错误信息
func _log_error(message: String) -> void:
	info_label.append_text("[color=red]%s[/color]\n" % message)
	print("[MusicModuleTest] ERROR: %s" % message)

## 日志输出 - 数据信息
func _log_data(message: String) -> void:
	info_label.append_text("[color=cyan]%s[/color]\n" % message)
	print("[MusicModuleTest] %s" % message)
