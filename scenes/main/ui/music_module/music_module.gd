class_name MusicModule
extends Control

## 音乐模块主控制器，负责管理多个音乐列表和播放控制 UI
## 状态管理由 MusicState 单例负责
## 播放列表管理委托给 PlaylistManager
## 文件导入委托给 MusicImporter

# --- 导出变量 ---
## 音乐列表场景 (MusicList)
@export var music_list_scene: PackedScene
## 音乐选项面板场景 (MusicOptionBoard)
@export var option_board_scene: PackedScene
## 音乐资源
@export var audio_res: AudioRes

# --- 节点引用 ---
## 歌单面板
@onready var frosted_panel: FrostedPanel = $CanvasLayer/FrostedPanel
## 歌单切换菜单按钮
@onready var list_menu_button: MaterialMenuButton = $CanvasLayer/FrostedPanel/VBoxContainer/HBoxContainer/ListMenuButton
## 添加菜单按钮（导入音乐/添加歌单）
@onready var add_menu_button: MaterialMenuButton = $CanvasLayer/FrostedPanel/VBoxContainer/HBoxContainer/AddMenuButton
## 音乐列表容器（用于存放所有 MusicList 实例，同时只显示一个）
@onready var list_container: MarginContainer = $CanvasLayer/FrostedPanel/VBoxContainer/ListContainer
@onready var canvas_layer: CanvasLayer = $CanvasLayer
@onready var status_button = $PanelContainer/VBoxContainer/HBoxContainer/StatusButton
@onready var mode_button = $PanelContainer/VBoxContainer/HBoxContainer/ModeButton
@onready var tab_button: MaterialButton = $PanelContainer/VBoxContainer/HBoxContainer/TabButton

# --- 辅助类实例 ---
var _playlist_manager: PlaylistManager
var _music_importer: MusicImporter

# --- 对话框 ---
var _delete_dialog: MaterialDialog
var _add_playlist_dialog: MaterialDialog
var _playlist_name_input: LineEdit
var _delete_submenu: MaterialMenu

# --- 成员变量 ---
## 当前选中的音乐列表索引
var current_list_index: int = 0
## 是否弹出了选项面板
var option_board_opened: bool = false
## 防止按钮状态更新时触发重入
var _updating_button_state: bool = false

func _ready() -> void:
	_init_managers()
	_setup_initial_music()
	_setup_list_menu()
	_setup_add_menu()
	_setup_delete_dialog()
	_setup_add_playlist_dialog()
	_connect_music_state()
	frosted_panel.visible=false
	# 延迟初始化
	var timer = get_tree().create_timer(0.1)
	timer.timeout.connect(_deferred_init)

## 初始化管理器
func _init_managers() -> void:
	# 初始化 PlaylistManager
	_playlist_manager = PlaylistManager.new()
	_playlist_manager.initialize(list_container, music_list_scene, audio_res)
	_playlist_manager.playlist_added.connect(_on_playlist_added)
	_playlist_manager.playlist_removed.connect(_on_playlist_removed)

	# 初始化 MusicImporter
	_music_importer = MusicImporter.new()
	_music_importer.initialize(self, audio_res)
	_music_importer.music_imported.connect(_on_music_imported)

	print("[Music Module] Managers initialized")

## 连接 MusicState 信号
func _connect_music_state() -> void:
	if MusicState:
		MusicState.track_changed.connect(_on_track_changed)
		MusicState.playback_state_changed.connect(_on_playback_state_changed)
		MusicState.play_mode_changed.connect(_on_play_mode_changed)
		MusicState.playlist_created.connect(_on_state_playlist_created)
		MusicState.playlist_deleted.connect(_on_state_playlist_deleted)
		MusicState.track_added_to_playlist.connect(_on_state_track_added)
		MusicState.track_removed_from_playlist.connect(_on_state_track_removed)
		MusicState.imported_track_added.connect(_on_state_imported_track_added)
		MusicState.imported_track_removed.connect(_on_state_imported_track_removed)
		MusicState.builtin_track_removed.connect(_on_state_builtin_track_removed)
		MusicState.playlist_changed.connect(_on_state_playlist_changed)
		MusicState.data_loaded.connect(_on_state_data_loaded)
	if status_button:
		status_button.state_changed.connect(_on_status_button_state_changed)

func _exit_tree() -> void:
	if not MusicState:
		return
	if MusicState.track_changed.is_connected(_on_track_changed):
		MusicState.track_changed.disconnect(_on_track_changed)
	if MusicState.playback_state_changed.is_connected(_on_playback_state_changed):
		MusicState.playback_state_changed.disconnect(_on_playback_state_changed)
	if MusicState.play_mode_changed.is_connected(_on_play_mode_changed):
		MusicState.play_mode_changed.disconnect(_on_play_mode_changed)
	if MusicState.playlist_created.is_connected(_on_state_playlist_created):
		MusicState.playlist_created.disconnect(_on_state_playlist_created)
	if MusicState.playlist_deleted.is_connected(_on_state_playlist_deleted):
		MusicState.playlist_deleted.disconnect(_on_state_playlist_deleted)
	if MusicState.track_added_to_playlist.is_connected(_on_state_track_added):
		MusicState.track_added_to_playlist.disconnect(_on_state_track_added)
	if MusicState.track_removed_from_playlist.is_connected(_on_state_track_removed):
		MusicState.track_removed_from_playlist.disconnect(_on_state_track_removed)
	if MusicState.imported_track_added.is_connected(_on_state_imported_track_added):
		MusicState.imported_track_added.disconnect(_on_state_imported_track_added)
	if MusicState.imported_track_removed.is_connected(_on_state_imported_track_removed):
		MusicState.imported_track_removed.disconnect(_on_state_imported_track_removed)
	if MusicState.builtin_track_removed.is_connected(_on_state_builtin_track_removed):
		MusicState.builtin_track_removed.disconnect(_on_state_builtin_track_removed)
	if MusicState.playlist_changed.is_connected(_on_state_playlist_changed):
		MusicState.playlist_changed.disconnect(_on_state_playlist_changed)
	if MusicState.data_loaded.is_connected(_on_state_data_loaded):
		MusicState.data_loaded.disconnect(_on_state_data_loaded)

## 延迟初始化
func _deferred_init() -> void:
	_init_first_music()
	_update_play_button()

## 初始化第一首歌（优先恢复上次播放的曲目）
func _init_first_music() -> void:
	var current_list = get_current_list()
	if not current_list or current_list.get_music_count() == 0:
		return

	# 尝试恢复上次播放的曲目
	if MusicState and MusicState.last_track != "":
		MusicState.set_track(MusicState.last_track)
		tab_button.text = MusicState.last_track
		print("[Music Module] Restored last track: %s" % MusicState.last_track)
		return

	# 回退到第一首
	var first_music_item = current_list.vbox.get_child(0) as MusicItem
	if first_music_item:
		var first_music = first_music_item.get_music_name()
		if MusicState:
			MusicState.set_track(first_music)
		tab_button.text = first_music
		print("[Music Module] Initial music set: %s" % first_music)

# --- 初始化设置 ---

## 初始化默认列表并加载音乐（从 MusicState 恢复持久化数据）
func _setup_initial_music() -> void:
	# MusicState.load_data() 已在 MusicState._ready() 中完成

	# 1. 重新加载导入的音乐到 AudioRes
	var imported_tracks = MusicState.get_imported_tracks()
	for track_name in imported_tracks.keys():
		var file_path: String = imported_tracks[track_name]
		if FileAccess.file_exists(file_path):
			# 加载音频流到 AudioRes（但暂时断开 bgm_added 信号，避免重复添加到全部音乐）
			if audio_res and audio_res.get_bgm_item_by_name(track_name) == null:
				audio_res.add_bgm(track_name, file_path)
		else:
			push_warning("[Music Module] Imported track file missing, removing: %s -> %s" % [track_name, file_path])
			MusicState.remove_imported_track(track_name)

	# 2. 创建"全部音乐"歌单，过滤掉用户删除的内置曲目
	var all_music_list = _playlist_manager.add_playlist("全部音乐")
	if all_music_list and audio_res:
		var removed_builtins = MusicState.get_removed_builtin_tracks()
		for item in audio_res.BGM:
			if item.name not in removed_builtins:
				all_music_list.add_music(item.name)

	# 3. 创建"收藏"歌单并恢复曲目
	_playlist_manager.add_playlist("收藏")
	var favorite_tracks = MusicState.get_playlist_tracks("收藏")
	for track_name in favorite_tracks:
		# 验证曲目存在于 AudioRes 中
		if audio_res and audio_res.get_bgm_item_by_name(track_name):
			_playlist_manager.add_music_to_playlist("收藏", track_name)
		else:
			push_warning("[Music Module] Track '%s' in playlist '收藏' not found in AudioRes, skipping" % track_name)

	# 4. 创建用户自建歌单并恢复曲目
	var saved_playlist_names = MusicState.get_all_playlist_names()
	for playlist_name in saved_playlist_names:
		if playlist_name == "收藏":
			continue  # 已在第 3 步处理
		_playlist_manager.add_playlist(playlist_name)
		var tracks = MusicState.get_playlist_tracks(playlist_name)
		for track_name in tracks:
			if audio_res and audio_res.get_bgm_item_by_name(track_name):
				_playlist_manager.add_music_to_playlist(playlist_name, track_name)
			else:
				push_warning("[Music Module] Track '%s' in playlist '%s' not found in AudioRes, skipping" % [track_name, playlist_name])

	# 5. 同步所有歌单的分类勾选状态（恢复曲目后，回写到"全部音乐"等列表的 MusicItem 上）
	var all_playlist_names = _playlist_manager.get_all_playlist_names()
	for pname in all_playlist_names:
		if pname == "全部音乐":
			continue
		var tracks_in_list = MusicState.get_playlist_tracks(pname)
		for tname in tracks_in_list:
			_playlist_manager.sync_music_category_state(tname, pname, true)

	# 6. 恢复播放模式
	if MusicState:
		mode_button.set_state_no_signal(MusicState.play_mode)

	# 7. 恢复当前歌单选择
	if MusicState and MusicState.current_playlist != "":
		var names = _playlist_manager.get_all_playlist_names()
		for i in range(names.size()):
			if names[i] == MusicState.current_playlist:
				_switch_to_list(i)
				break

	# 8. 注册"全部音乐"运行时歌单
	MusicState.register_runtime_playlist("全部音乐", _build_all_music_track_names())

	print("[Music Module] Setup initial music completed (with persistence restore)")

## 设置歌单切换菜单
func _setup_list_menu() -> void:
	if not list_menu_button:
		return
	list_menu_button.menu_item_pressed.connect(_on_list_menu_item_pressed)
	_update_list_menu()

## 设置添加菜单
func _setup_add_menu() -> void:
	if not add_menu_button or not canvas_layer:
		return

	add_menu_button.menu_item_pressed.connect(_on_add_menu_item_pressed)

	# 创建删除歌单子菜单
	_delete_submenu = MaterialMenu.new()
	_delete_submenu.name = "DeleteSubmenu"
	_delete_submenu.item_pressed.connect(_on_delete_submenu_item_pressed)
	canvas_layer.add_child(_delete_submenu)

	# 添加删除歌单子菜单到主菜单
	var delete_icon = preload("res://assets/ui/icons/delete_forever_24dp_FFFFFF_FILL0_wght400_GRAD0_opsz24.svg")
	add_menu_button.menu.add_submenu("删除歌单", _delete_submenu, delete_icon)

	# 连接主菜单的打开信号
	if add_menu_button.menu:
		add_menu_button.menu.menu_opened.connect(_on_add_menu_opened)

## 设置删除确认对话框
func _setup_delete_dialog() -> void:
	_delete_dialog = MaterialDialog.new()
	_delete_dialog.dialog_type = MaterialDialog.DialogType.QUESTION
	_delete_dialog.dialog_size = MaterialDialog.DialogSize.MEDIUM
	add_child(_delete_dialog)

## 设置添加歌单对话框
func _setup_add_playlist_dialog() -> void:
	_add_playlist_dialog = MaterialDialog.new()
	add_child(_add_playlist_dialog)
	_add_playlist_dialog.dialog_title = "创建新歌单"

	var vbox = VBoxContainer.new()
	vbox.name = "InputContent"

	var hint_label = Label.new()
	hint_label.text = "请输入歌单名称："
	hint_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	vbox.add_child(hint_label)

	_playlist_name_input = LineEdit.new()
	_playlist_name_input.placeholder_text = "在此输入..."
	_playlist_name_input.custom_minimum_size = Vector2(200, 36)
	vbox.add_child(_playlist_name_input)

	_add_playlist_dialog.set_custom_content(vbox)
	var cancel_btn = _add_playlist_dialog.add_button("取消")
	cancel_btn.pressed.connect(func():
		_add_playlist_dialog.hide_dialog()
	)
	var confirm_btn = _add_playlist_dialog.add_button("确定")
	confirm_btn.pressed.connect(func():
		_on_add_playlist_confirmed()
		_add_playlist_dialog.hide_dialog()
	)

# --- 菜单回调 ---

## 添加菜单项点击处理
func _on_add_menu_item_pressed(p_index: int, _item: MaterialMenuItem) -> void:
	match p_index:
		0:  # 导入音乐
			_music_importer.open_import_dialog()
		1:  # 添加歌单
			_open_add_playlist_dialog()

## 删除歌单子菜单项点击处理
func _on_delete_submenu_item_pressed(p_index: int, item: MaterialMenuItem) -> void:
	var playlist_name = item.label_text
	_show_delete_playlist_dialog(playlist_name)

## 当添加菜单打开时
func _on_add_menu_opened() -> void:
	_update_delete_submenu()

## 更新删除歌单子菜单
func _update_delete_submenu() -> void:
	if _delete_submenu and is_instance_valid(_delete_submenu):
		_delete_submenu.queue_free()
		_delete_submenu = null

	_delete_submenu = MaterialMenu.new()
	_delete_submenu.name = "DeleteSubmenu"
	_delete_submenu.item_pressed.connect(_on_delete_submenu_item_pressed)
	canvas_layer.add_child(_delete_submenu)

	var list_names = _playlist_manager.get_all_playlist_names()
	var has_deletable_playlists = false

	for list_name in list_names:
		if list_name != "全部音乐" and list_name != "收藏":
			_delete_submenu.add_item(list_name)
			has_deletable_playlists = true

	if not has_deletable_playlists:
		_delete_submenu.add_item("(无可删除的歌单)")

	# 重新关联子菜单
	if add_menu_button and add_menu_button.menu:
		var menu_items = add_menu_button.menu.get_item_count()
		for i in range(menu_items):
			var item = add_menu_button.menu.get_item(i)
			if item is MaterialMenuItem and item.label_text == "删除歌单":
				item.submenu = _delete_submenu
				break

## 显示删除歌单确认对话框
func _show_delete_playlist_dialog(playlist_name: String) -> void:
	if not _delete_dialog:
		return

	_delete_dialog.dialog_title = "删除歌单"
	_delete_dialog.dialog_text = "确定要删除歌单 \"%s\" 吗？\n歌单中的音乐不会被删除。" % playlist_name
	_delete_dialog.clear_buttons()

	var cancel_btn = _delete_dialog.add_button("取消")
	cancel_btn.pressed.connect(func(): _delete_dialog.hide_dialog())

	var confirm_btn = _delete_dialog.add_button("确定")
	confirm_btn.pressed.connect(func():
		_delete_playlist(playlist_name)
		_delete_dialog.hide_dialog()
	)

	_delete_dialog.show_dialog()

## 删除歌单（仅调 MusicState，UI 由 _on_state_playlist_deleted 信号驱动）
func _delete_playlist(playlist_name: String) -> void:
	MusicState.delete_playlist(playlist_name)

## 打开添加歌单对话框
func _open_add_playlist_dialog() -> void:
	if _add_playlist_dialog and _playlist_name_input:
		_playlist_name_input.text = ""
		_add_playlist_dialog.show_dialog()
		await get_tree().process_frame
		_playlist_name_input.grab_focus()

## 添加歌单确认回调
func _on_add_playlist_confirmed() -> void:
	if not _playlist_name_input:
		return

	var playlist_name = _playlist_name_input.text.strip_edges()
	if playlist_name.is_empty():
		return

	if MusicState.has_playlist(playlist_name) or _playlist_manager.get_playlist(playlist_name):
		print("[Music Module] Playlist '%s' already exists" % playlist_name)
		return

	MusicState.create_playlist(playlist_name)

# --- 播放列表管理信号回调 ---

## 当播放列表被添加时
func _on_playlist_added(playlist_name: String) -> void:
	var playlist = _playlist_manager.get_playlist(playlist_name)
	if playlist:
		# 连接列表信号
		playlist.music_selected.connect(_on_music_selected)
		playlist.music_options_requested.connect(_on_music_options_requested)
		playlist.music_remove_requested.connect(_on_music_removed.bind(playlist_name))
		playlist.music_category_changed.connect(_on_music_category_changed)

	# 更新菜单
	_update_list_menu()
	if _playlist_manager.get_playlist_count() == 1:
		list_menu_button.text = playlist_name
		current_list_index = 0

	# 通知所有 MusicItem 添加新分类
	_playlist_manager.add_category_to_all_music_items(playlist_name)

## 当播放列表被移除时
func _on_playlist_removed(playlist_name: String) -> void:
	print("[Music Module] Playlist removed: %s" % playlist_name)

## 当音乐被导入时
func _on_music_imported(music_name: String, file_path: String) -> void:
	MusicState.add_imported_track(music_name, file_path)
	print("[Music Module] Music imported: %s" % music_name)

# --- MusicState 信号回调 ---

func _on_track_changed(track_name: String) -> void:
	tab_button.text = track_name
	# 更新当前 MusicList 的播放高亮
	var current_list = get_current_list()
	if current_list:
		for i in range(current_list.get_music_count()):
			var child = current_list.vbox.get_child(i)
			if child is MusicItem and child.get_music_name() == track_name:
				current_list.current_playing_index = i
				current_list.current_playing_name = track_name
				break

func _on_playback_state_changed(_is_playing: bool) -> void:
	_update_play_button()

func _on_play_mode_changed(mode: int) -> void:
	mode_button.set_state_no_signal(mode)

# --- MusicState 响应式信号处理器 ---

## 歌单创建 → 创建 UI 节点、更新菜单、添加分类选项
func _on_state_playlist_created(playlist_name: String) -> void:
	if _playlist_manager.get_playlist(playlist_name):
		return  # UI 节点已存在（初始化阶段创建的）
	_playlist_manager.add_playlist(playlist_name)

## 歌单删除 → 销毁 UI 节点、更新菜单、移除分类选项、调整索引
func _on_state_playlist_deleted(playlist_name: String) -> void:
	if not _playlist_manager.get_playlist(playlist_name):
		return
	_playlist_manager.remove_playlist(playlist_name)
	# 调整 current_list_index
	if current_list_index >= _playlist_manager.get_playlist_count():
		current_list_index = 0
		if _playlist_manager.get_playlist_count() > 0:
			_switch_to_list(0)
	_update_list_menu()
	_update_delete_submenu()
	_playlist_manager.remove_category_from_all_music_items(playlist_name)

## 曲目被添加到歌单 → 在对应 MusicList 添加 MusicItem
func _on_state_track_added(playlist_name: String, track_name: String) -> void:
	_playlist_manager.add_music_to_playlist(playlist_name, track_name)
	_playlist_manager.sync_music_category_state(track_name, playlist_name, true)

## 曲目从歌单移除 → 从对应 MusicList 移除 MusicItem
func _on_state_track_removed(playlist_name: String, track_name: String) -> void:
	_playlist_manager.remove_music_from_playlist(playlist_name, track_name)
	_playlist_manager.sync_music_category_state(track_name, playlist_name, false)

## 导入曲目添加 → 将新导入曲目添加到"全部音乐" MusicList
func _on_state_imported_track_added(track_name: String) -> void:
	_playlist_manager.add_music_to_playlist("全部音乐", track_name)
	MusicState.register_runtime_playlist("全部音乐", _build_all_music_track_names())

## 导入曲目移除 → 从"全部音乐" MusicList 移除
func _on_state_imported_track_removed(track_name: String) -> void:
	_playlist_manager.remove_music_from_all_playlists(track_name)
	MusicState.register_runtime_playlist("全部音乐", _build_all_music_track_names())

## 内置曲目被删除 → 从"全部音乐" MusicList 移除
func _on_state_builtin_track_removed(track_name: String) -> void:
	_playlist_manager.remove_music_from_all_playlists(track_name)
	MusicState.register_runtime_playlist("全部音乐", _build_all_music_track_names())

## 当前播放列表改变 → 切换可见的 MusicList
func _on_state_playlist_changed(playlist_name: String) -> void:
	var names = _playlist_manager.get_all_playlist_names()
	for i in range(names.size()):
		if names[i] == playlist_name:
			if i != current_list_index:
				_switch_to_list(i)
			break

## 持久化数据重新加载（云同步等场景）
func _on_state_data_loaded() -> void:
	pass  # 初始化阶段已由 _setup_initial_music 处理

# --- UI 按钮回调 ---

func _on_last_button_pressed() -> void:
	if MusicState:
		MusicState.play_previous()
		if not MusicState.is_playing:
			MusicState.set_playing(true)

func _on_status_button_state_changed(_old_state: int, new_state: int) -> void:
	if _updating_button_state:
		return
	if MusicState:
		MusicState.set_playing(new_state == 1)

func _on_next_button_pressed() -> void:
	if MusicState:
		MusicState.play_next()
		if not MusicState.is_playing:
			MusicState.set_playing(true)

func _on_mode_button_pressed() -> void:
	if MusicState:
		MusicState.cycle_play_mode()

func _on_tab_button_pressed() -> void:
	LayerManager.bring_to_front(canvas_layer)

	if frosted_panel.visible:
		GuiTransitions.hide("musiclist")
	else:
		GuiTransitions.show("musiclist")
	

# --- UI 更新函数 ---

func _update_play_button() -> void:
	_updating_button_state = true
	var is_playing = MusicState.is_playing if MusicState else false
	if is_playing:
		status_button.set_state(1)
	else:
		status_button.set_state(0)
	_updating_button_state = false

func _update_list_menu() -> void:
	if not list_menu_button:
		return
	list_menu_button.clear_menu()
	var names = _playlist_manager.get_all_playlist_names()
	for name in names:
		list_menu_button.add_menu_item(name)

# --- 列表信号回调 ---

func _on_music_selected(p_name: String) -> void:
	print("[Music Module] Music selected: %s" % p_name)
	if MusicState:
		MusicState.set_track(p_name)
		MusicState.set_playing(true)

func _on_list_menu_item_pressed(p_index: int, _item: MaterialMenuItem) -> void:
	_switch_to_list(p_index)

func _switch_to_list(p_index: int) -> void:
	if p_index < 0 or p_index >= _playlist_manager.get_playlist_count():
		return

	# 隐藏所有列表
	for i in range(_playlist_manager.get_playlist_count()):
		var playlist = _playlist_manager.get_playlist_by_index(i)
		if playlist:
			playlist.visible = false

	# 显示选中的列表
	var selected_list = _playlist_manager.get_playlist_by_index(p_index)
	if selected_list:
		selected_list.visible = true
		current_list_index = p_index
		list_menu_button.text = selected_list.name

		if MusicState:
			MusicState.set_playlist(selected_list.name)

func _on_music_options_requested(p_music_name: String, p_list_name: String) -> void:
	if not option_board_scene or option_board_opened:
		return

	var option_board_instance = option_board_scene.instantiate() as MusicOptionBoard
	add_child(option_board_instance)
	option_board_instance.set_as_top_level(true)
	option_board_instance.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	option_board_instance.set_music_name(p_music_name)
	option_board_instance.option_changed.connect(_on_music_option_changed)
	option_board_instance.board_closed.connect(func(): option_board_opened = false)
	option_board_opened = true

	var list_names = _playlist_manager.get_all_playlist_names()
	for l_name in list_names:
		option_board_instance.add_option(l_name)
		if MusicState.is_track_in_playlist(l_name, p_music_name):
			option_board_instance.toggle_option(l_name)

func _on_music_option_changed(p_list_name: String, p_music_name: String, p_toggled_on: bool) -> void:
	if p_toggled_on:
		MusicState.add_track_to_playlist(p_list_name, p_music_name)
	else:
		MusicState.remove_track_from_playlist(p_list_name, p_music_name)

func _on_music_category_changed(p_music_name: String, category: String, checked: bool) -> void:
	if checked:
		MusicState.add_track_to_playlist(category, p_music_name)
	else:
		MusicState.remove_track_from_playlist(category, p_music_name)

func _on_music_removed(p_music_name: String, p_list_name: String) -> void:
	if p_list_name == "全部音乐":
		if not _delete_dialog:
			return

		_delete_dialog.dialog_title = "删除音乐"
		_delete_dialog.dialog_text = "确定要删除音乐 %s 吗？\n这将彻底移除该音乐。" % p_music_name
		_delete_dialog.clear_buttons()

		var cancel_btn = _delete_dialog.add_button("取消")
		cancel_btn.pressed.connect(func(): _delete_dialog.hide_dialog())

		var confirm_btn = _delete_dialog.add_button("确定")
		confirm_btn.pressed.connect(func():
			# 仅调 MusicState，UI 由信号驱动
			MusicState.remove_track_from_all_playlists(p_music_name)
			if MusicState.is_imported_track(p_music_name):
				MusicState.remove_imported_track(p_music_name)
			else:
				MusicState.add_removed_builtin(p_music_name)
			if audio_res:
				audio_res.remove_bgm(p_music_name)
			_delete_dialog.hide_dialog()
		)

		_delete_dialog.show_dialog()
		return

	MusicState.remove_track_from_playlist(p_list_name, p_music_name)

# --- 公有 API ---

func get_current_list() -> MusicList:
	return _playlist_manager.get_playlist_by_index(current_list_index)

## 从"全部音乐" MusicList 中提取所有曲目名，用于注册运行时歌单
func _build_all_music_track_names() -> Array[String]:
	var result: Array[String] = []
	var all_list = _playlist_manager.get_playlist("全部音乐")
	if all_list:
		for i in range(all_list.get_music_count()):
			var child = all_list.vbox.get_child(i)
			if child is MusicItem:
				result.append(child.get_music_name())
	return result

## ---api---

func show_module():
	if !frosted_panel.visible:
		LayerManager.bring_to_front(canvas_layer)
		GuiTransitions.show("musiclist")

func hide_module():
	if frosted_panel.visible:
		GuiTransitions.hide("musiclist")
