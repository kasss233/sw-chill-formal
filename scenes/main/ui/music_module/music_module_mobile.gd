extends MarginContainer

## 音乐模块移动端控制器

@export var music_list_scene: PackedScene
@export var option_board_scene: PackedScene
@export var audio_res: AudioRes

# --- 迷你播放器（FrostedPanel2）---
@onready var time_label: Label = %TimeLabel
@onready var date_label: Label = %DateLabel
@onready var mini_panel: PanelContainer = %FrostedPanel2
@onready var mini_status_button = %MaterialToggleButton
@onready var mini_progress = %MaterialProgressIndicator
@onready var visualizer = %Visualizer
@onready var mini_label: MaterialButton = %MaterialButton

# --- 歌单面板 ---
@onready var canvas_layer: CanvasLayer = $CanvasLayer
@onready var panel: PanelContainer = $CanvasLayer/FrostedPanel
@onready var list_menu_button: MaterialMenuButton = $CanvasLayer/FrostedPanel/VBoxContainer/HBoxContainer/ListMenuButton
@onready var add_menu_button: MaterialMenuButton = $CanvasLayer/FrostedPanel/VBoxContainer/HBoxContainer/AddMenuButton
@onready var list_container: MarginContainer = $CanvasLayer/FrostedPanel/VBoxContainer/ListContainer
@onready var panel_label: Label = $CanvasLayer/FrostedPanel/VBoxContainer/HBoxContainer2/VBoxContainer/Label
@onready var mode_button = $CanvasLayer/FrostedPanel/VBoxContainer/HBoxContainer2/VBoxContainer/HBoxContainer/ModeButton
@onready var last_button = $CanvasLayer/FrostedPanel/VBoxContainer/HBoxContainer2/VBoxContainer/HBoxContainer/LastButton
@onready var status_button = $CanvasLayer/FrostedPanel/VBoxContainer/HBoxContainer2/VBoxContainer/HBoxContainer/StatusButton
@onready var next_button = $CanvasLayer/FrostedPanel/VBoxContainer/HBoxContainer2/VBoxContainer/HBoxContainer/NextButton

# --- 辅助类 ---
var _playlist_manager: PlaylistManager
var _music_importer: MusicImporter
var _delete_dialog: MaterialDialog
var _add_playlist_dialog: MaterialDialog
var _playlist_name_input: LineEdit
var _delete_submenu: MaterialMenu

# --- 状态 ---
var current_list_index: int = 0
var option_board_opened: bool = false
var _updating_button_state: bool = false
const WEEKDAY_NAMES := ["周日", "周一", "周二", "周三", "周四", "周五", "周六"]

func _ready() -> void:
	_init_managers()
	_setup_initial_music()
	_setup_list_menu()
	_setup_add_menu()
	_setup_delete_dialog()
	_setup_add_playlist_dialog()
	_connect_music_state()
	_connect_buttons()
	_setup_mini_panel()
	panel.visible = false
	_update_time()
	var time_timer = Timer.new()
	time_timer.wait_time = 1.0
	time_timer.autostart = true
	time_timer.timeout.connect(_update_time)
	add_child(time_timer)
	get_tree().create_timer(0.1).timeout.connect(_deferred_init)

func _process(_delta: float) -> void:
	if MusicState and MusicState.is_playing:
		_update_progress()

func _setup_mini_panel() -> void:
	if mini_status_button:
		mini_status_button.state_changed.connect(_on_status_button_state_changed)
	if mini_label:
		mini_label.pressed.connect(_toggle_panel)
	if visualizer:
		visualizer.set_playing(false)

func _toggle_panel() -> void:
	LayerManager.bring_to_front(canvas_layer)
	if panel.visible:
		GuiTransitions.hide("musiclist")
	else:
		GuiTransitions.show("musiclist")

func _update_time() -> void:
	var dt = Time.get_datetime_dict_from_system()
	if time_label:
		time_label.text = "%02d:%02d" % [dt.hour, dt.minute]
	if date_label:
		date_label.text = "%d/%d/%d %s" % [dt.year, dt.month, dt.day, WEEKDAY_NAMES[dt.weekday]]

func _update_progress() -> void:
	if not mini_progress or not MusicState or MusicState.current_track == "":
		return
	var audio = AudioPlayer.bgm_container.get_node_or_null(MusicState.current_track) as AudioStreamPlayer
	if not audio or not audio.stream or not audio.is_playing():
		return
	var length = audio.stream.get_length()
	if length > 0.0:
		mini_progress.set_progress_value(audio.get_playback_position() / length)

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

func _connect_buttons() -> void:
	if status_button:
		status_button.state_changed.connect(_on_status_button_state_changed)
	if last_button:
		last_button.pressed.connect(_on_last_button_pressed)
	if next_button:
		next_button.pressed.connect(_on_next_button_pressed)
	if mode_button:
		mode_button.pressed.connect(_on_mode_button_pressed)

func _deferred_init() -> void:
	_init_first_music()
	_update_play_button()
	if visualizer and MusicState:
		visualizer.set_playing(MusicState.is_playing)

func _init_first_music() -> void:
	var current_list = get_current_list()
	if not current_list or current_list.get_music_count() == 0:
		return
	if MusicState and MusicState.last_track != "":
		MusicState.set_track(MusicState.last_track)
		_update_track_labels(MusicState.last_track)
		return
	var first_item = current_list.vbox.get_child(0) as MusicItem
	if first_item:
		var name = first_item.get_music_name()
		if MusicState:
			MusicState.set_track(name)
		_update_track_labels(name)

# ======================== MusicState 信号回调 ========================

func _on_track_changed(track_name: String) -> void:
	_update_track_labels(track_name)
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
	if visualizer:
		visualizer.set_playing(_is_playing)

func _on_play_mode_changed(mode: int) -> void:
	mode_button.set_state_no_signal(mode)

func _on_state_playlist_created(playlist_name: String) -> void:
	if not _playlist_manager.get_playlist(playlist_name):
		_playlist_manager.add_playlist(playlist_name)

func _on_state_playlist_deleted(playlist_name: String) -> void:
	if not _playlist_manager.get_playlist(playlist_name):
		return
	_playlist_manager.remove_playlist(playlist_name)
	if current_list_index >= _playlist_manager.get_playlist_count():
		current_list_index = 0
		if _playlist_manager.get_playlist_count() > 0:
			_switch_to_list(0)
	_update_list_menu()
	_update_delete_submenu()
	_playlist_manager.remove_category_from_all_music_items(playlist_name)

func _on_state_track_added(playlist_name: String, track_name: String) -> void:
	_playlist_manager.add_music_to_playlist(playlist_name, track_name)
	_playlist_manager.sync_music_category_state(track_name, playlist_name, true)

func _on_state_track_removed(playlist_name: String, track_name: String) -> void:
	_playlist_manager.remove_music_from_playlist(playlist_name, track_name)
	_playlist_manager.sync_music_category_state(track_name, playlist_name, false)

func _on_state_imported_track_added(track_name: String) -> void:
	_playlist_manager.add_music_to_playlist("全部音乐", track_name)
	MusicState.register_runtime_playlist("全部音乐", _build_all_music_track_names())

func _on_state_imported_track_removed(track_name: String) -> void:
	_playlist_manager.remove_music_from_all_playlists(track_name)
	MusicState.register_runtime_playlist("全部音乐", _build_all_music_track_names())

func _on_state_builtin_track_removed(track_name: String) -> void:
	_playlist_manager.remove_music_from_all_playlists(track_name)
	MusicState.register_runtime_playlist("全部音乐", _build_all_music_track_names())

func _on_state_playlist_changed(playlist_name: String) -> void:
	var names = _playlist_manager.get_all_playlist_names()
	for i in range(names.size()):
		if names[i] == playlist_name:
			if i != current_list_index:
				_switch_to_list(i)
			break

func _on_state_data_loaded() -> void:
	pass

# ======================== 按钮回调 ========================

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

# ======================== UI 更新 ========================

func _update_track_labels(track_name: String) -> void:
	if mini_label:
		mini_label.text = track_name
	if panel_label:
		panel_label.text = track_name

func _update_play_button() -> void:
	_updating_button_state = true
	var playing = MusicState.is_playing if MusicState else false
	var state = 1 if playing else 0
	status_button.set_state(state)
	if mini_status_button:
		mini_status_button.set_state(state)
	_updating_button_state = false

func _update_list_menu() -> void:
	if not list_menu_button:
		return
	list_menu_button.clear_menu()
	for n in _playlist_manager.get_all_playlist_names():
		list_menu_button.add_menu_item(n)

# ======================== 歌单初始化 ========================

func _init_managers() -> void:
	_playlist_manager = PlaylistManager.new()
	_playlist_manager.initialize(list_container, music_list_scene, audio_res)
	_playlist_manager.playlist_added.connect(_on_playlist_added)
	_playlist_manager.playlist_removed.connect(_on_playlist_removed)
	_music_importer = MusicImporter.new()
	_music_importer.initialize(self, audio_res)
	_music_importer.music_imported.connect(_on_music_imported)

func _setup_initial_music() -> void:
	var imported_tracks = MusicState.get_imported_tracks()
	for track_name in imported_tracks.keys():
		var file_path: String = imported_tracks[track_name]
		if FileAccess.file_exists(file_path):
			if audio_res and audio_res.get_bgm_item_by_name(track_name) == null:
				audio_res.add_bgm(track_name, file_path)
		else:
			MusicState.remove_imported_track(track_name)
	var all_music_list = _playlist_manager.add_playlist("全部音乐")
	if all_music_list and audio_res:
		var removed_builtins = MusicState.get_removed_builtin_tracks()
		for item in audio_res.BGM:
			if item.name not in removed_builtins:
				all_music_list.add_music(item.name)
	_playlist_manager.add_playlist("收藏")
	for track_name in MusicState.get_playlist_tracks("收藏"):
		if audio_res and audio_res.get_bgm_item_by_name(track_name):
			_playlist_manager.add_music_to_playlist("收藏", track_name)
	for playlist_name in MusicState.get_all_playlist_names():
		if playlist_name == "收藏":
			continue
		_playlist_manager.add_playlist(playlist_name)
		for track_name in MusicState.get_playlist_tracks(playlist_name):
			if audio_res and audio_res.get_bgm_item_by_name(track_name):
				_playlist_manager.add_music_to_playlist(playlist_name, track_name)
	for pname in _playlist_manager.get_all_playlist_names():
		if pname == "全部音乐":
			continue
		for tname in MusicState.get_playlist_tracks(pname):
			_playlist_manager.sync_music_category_state(tname, pname, true)
	if MusicState:
		mode_button.set_state_no_signal(MusicState.play_mode)
	MusicState.register_runtime_playlist("全部音乐", _build_all_music_track_names())
	if MusicState and MusicState.current_playlist != "":
		var names = _playlist_manager.get_all_playlist_names()
		for i in range(names.size()):
			if names[i] == MusicState.current_playlist:
				_switch_to_list(i)
				break
	else:
		_switch_to_list(0)

func _setup_list_menu() -> void:
	if list_menu_button:
		list_menu_button.menu_item_pressed.connect(_on_list_menu_item_pressed)
		_update_list_menu()

func _setup_add_menu() -> void:
	if not add_menu_button or not canvas_layer:
		return
	add_menu_button.menu_item_pressed.connect(_on_add_menu_item_pressed)
	_delete_submenu = MaterialMenu.new()
	_delete_submenu.name = "DeleteSubmenu"
	_delete_submenu.item_pressed.connect(_on_delete_submenu_item_pressed)
	canvas_layer.add_child(_delete_submenu)
	var delete_icon = preload("res://assets/ui/icons/delete_forever_24dp_FFFFFF_FILL0_wght400_GRAD0_opsz24.svg")
	add_menu_button.menu.add_submenu("删除歌单", _delete_submenu, delete_icon)
	if add_menu_button.menu:
		add_menu_button.menu.menu_opened.connect(_on_add_menu_opened)

func _setup_delete_dialog() -> void:
	_delete_dialog = MaterialDialog.new()
	_delete_dialog.dialog_type = MaterialDialog.DialogType.QUESTION
	_delete_dialog.dialog_size = MaterialDialog.DialogSize.MEDIUM
	add_child(_delete_dialog)

func _setup_add_playlist_dialog() -> void:
	_add_playlist_dialog = MaterialDialog.new()
	add_child(_add_playlist_dialog)
	_add_playlist_dialog.dialog_title = "创建新歌单"
	var vbox = VBoxContainer.new()
	var hint_label = Label.new()
	hint_label.text = "请输入歌单名称："
	hint_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	vbox.add_child(hint_label)
	_playlist_name_input = LineEdit.new()
	_playlist_name_input.placeholder_text = "在此输入..."
	_playlist_name_input.custom_minimum_size = Vector2(200, 36)
	vbox.add_child(_playlist_name_input)
	_add_playlist_dialog.set_custom_content(vbox)
	_add_playlist_dialog.add_button("取消").pressed.connect(func(): _add_playlist_dialog.hide_dialog())
	_add_playlist_dialog.add_button("确定").pressed.connect(func():
		_on_add_playlist_confirmed()
		_add_playlist_dialog.hide_dialog()
	)

# ======================== 菜单回调 ========================

func _on_add_menu_item_pressed(p_index: int, _item: MaterialMenuItem) -> void:
	match p_index:
		0: _music_importer.open_import_dialog()
		1: _open_add_playlist_dialog()

func _on_delete_submenu_item_pressed(_p_index: int, item: MaterialMenuItem) -> void:
	_show_delete_playlist_dialog(item.label_text)

func _on_add_menu_opened() -> void:
	_update_delete_submenu()

func _update_delete_submenu() -> void:
	if _delete_submenu and is_instance_valid(_delete_submenu):
		_delete_submenu.queue_free()
	_delete_submenu = MaterialMenu.new()
	_delete_submenu.name = "DeleteSubmenu"
	_delete_submenu.item_pressed.connect(_on_delete_submenu_item_pressed)
	canvas_layer.add_child(_delete_submenu)
	var has_deletable := false
	for list_name in _playlist_manager.get_all_playlist_names():
		if list_name != "全部音乐" and list_name != "收藏":
			_delete_submenu.add_item(list_name)
			has_deletable = true
	if not has_deletable:
		_delete_submenu.add_item("(无可删除的歌单)")
	if add_menu_button and add_menu_button.menu:
		for i in range(add_menu_button.menu.get_item_count()):
			var item = add_menu_button.menu.get_item(i)
			if item is MaterialMenuItem and item.label_text == "删除歌单":
				item.submenu = _delete_submenu
				break

func _show_delete_playlist_dialog(playlist_name: String) -> void:
	if not _delete_dialog:
		return
	_delete_dialog.dialog_title = "删除歌单"
	_delete_dialog.dialog_text = "确定要删除歌单 \"%s\" 吗？\n歌单中的音乐不会被删除。" % playlist_name
	_delete_dialog.clear_buttons()
	_delete_dialog.add_button("取消").pressed.connect(func(): _delete_dialog.hide_dialog())
	_delete_dialog.add_button("确定").pressed.connect(func():
		MusicState.delete_playlist(playlist_name)
		_delete_dialog.hide_dialog()
	)
	_delete_dialog.show_dialog()

func _open_add_playlist_dialog() -> void:
	if _add_playlist_dialog and _playlist_name_input:
		_playlist_name_input.text = ""
		_add_playlist_dialog.show_dialog()
		await get_tree().process_frame
		_playlist_name_input.grab_focus()

func _on_add_playlist_confirmed() -> void:
	if not _playlist_name_input:
		return
	var pname = _playlist_name_input.text.strip_edges()
	if pname.is_empty() or MusicState.has_playlist(pname) or _playlist_manager.get_playlist(pname):
		return
	MusicState.create_playlist(pname)

# ======================== PlaylistManager 信号 ========================

func _on_playlist_added(playlist_name: String) -> void:
	var playlist = _playlist_manager.get_playlist(playlist_name)
	if playlist:
		playlist.music_selected.connect(_on_music_selected)
		playlist.music_options_requested.connect(_on_music_options_requested)
		playlist.music_remove_requested.connect(_on_music_removed.bind(playlist_name))
		playlist.music_category_changed.connect(_on_music_category_changed)
	_update_list_menu()
	if _playlist_manager.get_playlist_count() == 1:
		list_menu_button.text = playlist_name
		current_list_index = 0
	_playlist_manager.add_category_to_all_music_items(playlist_name)

func _on_playlist_removed(_p: String) -> void:
	pass

func _on_music_imported(music_name: String, file_path: String) -> void:
	MusicState.add_imported_track(music_name, file_path)

# ======================== 列表操作 ========================

func _on_music_selected(p_name: String) -> void:
	if MusicState:
		MusicState.set_track(p_name)
		MusicState.set_playing(true)

func _on_list_menu_item_pressed(p_index: int, _item: MaterialMenuItem) -> void:
	_switch_to_list(p_index)

func _switch_to_list(p_index: int) -> void:
	if p_index < 0 or p_index >= _playlist_manager.get_playlist_count():
		return
	for i in range(_playlist_manager.get_playlist_count()):
		var pl = _playlist_manager.get_playlist_by_index(i)
		if pl:
			pl.visible = false
	var selected = _playlist_manager.get_playlist_by_index(p_index)
	if selected:
		selected.visible = true
		current_list_index = p_index
		list_menu_button.text = selected.name
		if MusicState:
			MusicState.set_playlist(selected.name)

func _on_music_options_requested(p_music_name: String, _p_list_name: String) -> void:
	if not option_board_scene or option_board_opened:
		return
	var board = option_board_scene.instantiate() as MusicOptionBoard
	add_child(board)
	board.set_as_top_level(true)
	board.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	board.set_music_name(p_music_name)
	board.option_changed.connect(_on_music_option_changed)
	board.board_closed.connect(func(): option_board_opened = false)
	option_board_opened = true
	for l_name in _playlist_manager.get_all_playlist_names():
		board.add_option(l_name)
		if MusicState.is_track_in_playlist(l_name, p_music_name):
			board.toggle_option(l_name)

func _on_music_option_changed(p_list: String, p_music: String, toggled: bool) -> void:
	if toggled:
		MusicState.add_track_to_playlist(p_list, p_music)
	else:
		MusicState.remove_track_from_playlist(p_list, p_music)

func _on_music_category_changed(p_music: String, category: String, checked: bool) -> void:
	if checked:
		MusicState.add_track_to_playlist(category, p_music)
	else:
		MusicState.remove_track_from_playlist(category, p_music)

func _on_music_removed(p_music_name: String, p_list_name: String) -> void:
	if p_list_name == "全部音乐":
		if not _delete_dialog:
			return
		_delete_dialog.dialog_title = "删除音乐"
		_delete_dialog.dialog_text = "确定要删除音乐 %s 吗？\n这将彻底移除该音乐。" % p_music_name
		_delete_dialog.clear_buttons()
		_delete_dialog.add_button("取消").pressed.connect(func(): _delete_dialog.hide_dialog())
		_delete_dialog.add_button("确定").pressed.connect(func():
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

# ======================== 公有 API ========================

func get_current_list() -> MusicList:
	return _playlist_manager.get_playlist_by_index(current_list_index)

func _build_all_music_track_names() -> Array[String]:
	var result: Array[String] = []
	var all_list = _playlist_manager.get_playlist("全部音乐")
	if all_list:
		for i in range(all_list.get_music_count()):
			var child = all_list.vbox.get_child(i)
			if child is MusicItem:
				result.append(child.get_music_name())
	return result

func show_module():
	if !panel.visible:
		LayerManager.bring_to_front(canvas_layer)
		GuiTransitions.show("musiclist")

func hide_module():
	if panel.visible:
		GuiTransitions.hide("musiclist")
