extends Control

## 音乐模块主控制器，负责管理多个音乐列表、播放控制和选项面板

# --- 信号 ---
## 当音乐切换时发出，信号与播放节点连接
signal music_changed(p_name: String)
## 当播放/暂停状态切换时发出
signal music_status_changed()

# --- 导出变量 ---
## 音乐列表场景 (MusicList)
@export var music_list_scene: PackedScene
## 音乐选项面板场景 (MusicOptionBoard)
@export var option_board_scene: PackedScene
## 音乐资源
@export var audio_res: AudioRes
# --- 节点引用 ---
## 歌单面板
@onready var frosted_panel: PanelContainer = $FrostedPanel
## 歌单切换菜单按钮
@onready var list_menu_button: MaterialMenuButton = $FrostedPanel/VBoxContainer/HBoxContainer/ListMenuButton
## 添加菜单按钮（导入音乐/添加歌单）
@onready var add_menu_button: MaterialMenuButton = $FrostedPanel/VBoxContainer/HBoxContainer/AddMenuButton
## 音乐列表容器（用于存放所有 MusicList 实例，同时只显示一个）
@onready var list_container: Control = $FrostedPanel/VBoxContainer/ListContainer
#@onready var label=$PanelContainer/VBoxContainer/Label
@onready var status_button = $PanelContainer/VBoxContainer/HBoxContainer/StatusButton
@onready var mode_button = $PanelContainer/VBoxContainer/HBoxContainer/ModeButton
@onready var tab_button: MaterialButton = $PanelContainer/VBoxContainer/HBoxContainer/TabButton


# --- 成员变量 ---
## 当前选中的音乐列表索引
var current_list_index: int = 0
## 是否弹出了选项面板
var option_board_opened: bool = false
## 当前的icon
var is_playing: bool = false
## 播放下一首的选择方式
var next_play_mode: int = 0 # 0: 顺序播放, 1: 随机播放, 2: 单曲循环
func _ready() -> void:
	_setup_initial_music()
	_setup_list_menu()
	_setup_add_menu()
	_sync_play_status()

# --- 内部处理函数 ---
## 初始化默认列表并加载音乐
func _setup_initial_music() -> void:
	add_music_list("全部音乐")
	add_music_list("收藏")
	
	var all_music_list = list_container.get_node_or_null("全部音乐") as MusicList
	if all_music_list and audio_res:
		for item in audio_res.BGM:
			all_music_list.add_music(item.name)
			print("[Music Module] Loaded music item: %s" % item.name)
	audio_res.bgm_added.connect(_on_bgm_added)

## 设置歌单切换菜单
func _setup_list_menu() -> void:
	if not list_menu_button:
		return
	# 连接菜单项点击信号
	print("[%s]Setting up music list menu" % [name])
	list_menu_button.menu_item_pressed.connect(_on_list_menu_item_pressed)
	# 更新菜单项
	_update_list_menu()

## 设置添加菜单（导入音乐/添加歌单）
func _setup_add_menu() -> void:
	if not add_menu_button:
		return
	# 连接菜单项点击信号
	add_menu_button.menu_item_pressed.connect(_on_add_menu_item_pressed)

## 添加菜单项点击处理
func _on_add_menu_item_pressed(p_index: int, _item: MaterialMenuItem) -> void:
	match p_index:
		0: # 导入音乐
			_open_import_music_dialog()
		1: # 添加歌单
			_open_add_playlist_dialog()

## 打开导入音乐对话框
func _open_import_music_dialog() -> void:
	var file_dialog = FileDialog.new()
	file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILES
	file_dialog.display_mode = FileDialog.DISPLAY_LIST
	file_dialog.filters = ["*.ogg ; OGG Audio", "*.wav ; WAV Audio", "*.mp3 ; MP3 Audio"]
	file_dialog.files_selected.connect(_on_files_selected)
	add_child(file_dialog)
	file_dialog.popup_centered()

## 打开添加歌单对话框
func _open_add_playlist_dialog() -> void:
	# TODO: 实现添加歌单的逻辑
	print("[Music Module] Add playlist requested")

# --- 公有 API ---
## 添加一个新的音乐列表
func add_music_list(p_name: String) -> void:
	if not music_list_scene:
		return
		
	var music_list_instance = music_list_scene.instantiate() as MusicList
	music_list_instance.name = p_name
	list_container.add_child(music_list_instance)
	# 连接列表信号
	music_list_instance.music_changed.connect(_on_music_changed)
	music_list_instance.music_options_requested.connect(_on_music_options_requested)
	music_list_instance.music_remove_requested.connect(_on_music_removed.bind(p_name))
	music_list_instance.music_category_changed.connect(_on_music_category_changed)
	# 默认隐藏，只显示当前选中的列表
	music_list_instance.visible = (list_container.get_child_count() == 1)
	# 更新菜单按钮文本
	if list_container.get_child_count() == 1:
		list_menu_button.text = p_name
		current_list_index = 0
	# 更新菜单项
	_update_list_menu()
## 向指定音乐列表添加一首音乐
func add_music(p_list_name: String, p_music_name: String) -> void:
	var target_list = list_container.get_node_or_null(p_list_name) as MusicList
	if target_list:
		target_list.add_music(p_music_name)
		# 如果是收藏列表，同步所有列表中该音乐的勾选状态
		if p_list_name == "收藏":
			_sync_music_category_state(p_music_name, p_list_name, true)
## 从指定音乐列表移除一首音乐,如果是全部音乐列表，则从每个列表中删除，并从资源中删除
func remove_music(p_list_name: String, p_music_name: String) -> void:
	var target_list = list_container.get_node_or_null(p_list_name) as MusicList
	#如果列表是全部音乐，则从每个列表中删除，并从资源中删除
	if p_list_name == "全部音乐":
		#从所有列表中移除该音乐
		for child in list_container.get_children():
			if child is MusicList:
				child.remove_music(p_music_name)
		#从资源中移除该音乐
		var item = audio_res.get_bgm_item_by_name(p_music_name)
		if item:
			audio_res.remove_bgm(p_music_name)
		return
	if target_list:
		target_list.remove_music(p_music_name)


## 获得当前列表
func get_current_list() -> MusicList:
	if list_container.get_child_count() > current_list_index:
		var current_list = list_container.get_child(current_list_index) as MusicList
		return current_list
	return null
## 获取当前所有音乐列表的名称
func get_music_list_names() -> Array[String]:
	var names: Array[String] = []
	for child in list_container.get_children():
		if child is MusicList:
			names.append(child.name)
	return names

## 根据名称切换到指定的歌单
func switch_to_list_by_name(p_list_name: String) -> void:
	for i in range(list_container.get_child_count()):
		var child = list_container.get_child(i)
		if child is MusicList and child.name == p_list_name:
			_switch_to_list(i)
			return

## 设置当前音乐显示（用于初始化时更新 UI）
func set_current_music_display(p_music_name: String) -> void:
	tab_button.text = p_music_name
## 获取当前列表中的所有音乐名称
func get_current_list_music_names() -> Array[String]:
	var names: Array[String] = []
	if list_container.get_child_count() > current_list_index:
		var current_list = list_container.get_child(current_list_index) as MusicList
		if current_list:
			for i in range(current_list.get_music_count()):
				var child = current_list.vbox.get_child(i)
				if child is MusicItem:
					names.append(child.get_music_name())
	return names
## 获取列表中的音乐名称
func get_list_music_names(p_list_name: String) -> Array[String]:
	var names: Array[String] = []
	var target_list = list_container.get_node_or_null(p_list_name) as MusicList
	if target_list:
		for i in range(target_list.get_music_count()):
			var child = target_list.vbox.get_child(i)
			if child is MusicItem:
				names.append(child.get_music_name())
	return names
## 获取所有列表的音乐名称
func get_all_lists_music_names() -> Dictionary:
	var result: Dictionary = {}
	for child in list_container.get_children():
		if child is MusicList:
			var music_names: Array[String] = []
			for i in range(child.get_music_count()):
				var music_item = child.vbox.get_child(i)
				if music_item is MusicItem:
					music_names.append(music_item.get_music_name())
			result[child.name] = music_names
	return result
## 播放下一首，在结束时调用
func play_next_music() -> void:
	var current_list = get_current_list()
	if not current_list:
		return
	if next_play_mode == 0:
		current_list.play_next_music()
	elif next_play_mode == 1:
		current_list.play_random_music()
	elif next_play_mode == 2:
		current_list.play_single_music()

# --- 信号回调 ---
## 更换当前播放的音乐，更新 UI 并发出信号
func _on_music_changed(p_name: String) -> void:
	print("[Music Module] Changing music to: %s" % p_name)
	music_changed.emit(p_name)
	#label.text=p_name
	tab_button.text = p_name
## 播放上一首
func _on_last_button_pressed() -> void:
	var current_list = get_current_list()
	if current_list:
		match next_play_mode:
			0:
				current_list.play_last_music()
			1:
				current_list.play_random_music()
			2:
				current_list.play_last_music()
		status_button.set_checked_no_signal(false)

## 播放/暂停
func _on_status_button_pressed() -> void:
	music_status_changed.emit()
	print("[Music Module] music_status_changed emitted")
	# 延迟一帧后同步图标，确保 audio_player 状态已更新
	await get_tree().process_frame
	_sync_play_status()

## 同步播放/暂停按钮图标
func _sync_play_status() -> void:
	if audio_player and audio_player.has_method("get_is_paused"):
		is_playing = not audio_player.get_is_paused()
	if is_playing:
		status_button.set_state(0)
	else:
		status_button.set_state(1)

## 播放下一首
func _on_next_button_pressed() -> void:
	var current_list = get_current_list()
	if current_list:
		match next_play_mode:
			0:
				current_list.play_next_music()
			1:
				current_list.play_random_music()
			2:
				current_list.play_next_music() # 单曲循环切换按顺序播放下一首
	#TODO:补充切换checkbox逻辑
	status_button.set_checked_no_signal(false)
## 当菜单选中一个歌单时的处理
func _on_list_menu_item_pressed(p_index: int, _item: MaterialMenuItem) -> void:
	print("[%s]Switch music list to %d" % [self.name, p_index])
	_switch_to_list(p_index)

## 切换到指定索引的列表
func _switch_to_list(p_index: int) -> void:
	if p_index < 0 or p_index >= list_container.get_child_count():
		return
	# 隐藏所有列表
	for child in list_container.get_children():
		child.visible = false
	# 显示选中的列表
	var selected_list = list_container.get_child(p_index)
	if selected_list:
		selected_list.visible = true
		current_list_index = p_index
		list_menu_button.text = selected_list.name

## 更新歌单切换菜单项
func _update_list_menu() -> void:
	if not list_menu_button:
		return
	# 清空并重建菜单
	list_menu_button.clear_menu()
	for child in list_container.get_children():
		if child is MusicList:
			list_menu_button.add_menu_item(child.name)
			print("[%s]Added %s to music list menu" % [name, child.name])

## 当点击音乐项的选项按钮时，弹出选项面板
func _on_music_options_requested(p_music_name: String, p_list_name: String) -> void:
	if not option_board_scene:
		return
	if option_board_opened:
		print("[Music Module] Options board is already opened.")
		return
	# 实例化选项面板
	var option_board_instance = option_board_scene.instantiate() as MusicOptionBoard
	add_child(option_board_instance)
	
	# 设置为顶级节点并居中
	option_board_instance.set_as_top_level(true)
	option_board_instance.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	
	# 设置当前音乐名称
	option_board_instance.set_music_name(p_music_name)
	# 连接选项改变信号
	option_board_instance.option_changed.connect(_on_music_option_changed)
	option_board_instance.board_closed.connect(func():
		option_board_opened = false
	)
	option_board_opened = true
	# 添加所有列表选项
	var list_names = get_music_list_names()
	for l_name in list_names:
		option_board_instance.add_option(l_name)
		# 如果当前音乐已在该列表中，设置为勾选状态
		if is_music_in_list(l_name, p_music_name):
			option_board_instance.toggle_option(l_name)
	
	print("[Music Module] Options board opened for: %s in list: %s" % [p_music_name, p_list_name])

## 当在选项面板中勾选/取消列表时的处理
func _on_music_option_changed(p_list_name: String, p_music_name: String, p_toggled_on: bool) -> void:
	print("[Music Module] Option changed: %s -> %s (%s)" % [p_music_name, p_list_name, p_toggled_on])
	if p_toggled_on:
		add_music(p_list_name, p_music_name)
	else:
		var target_list = list_container.get_node_or_null(p_list_name) as MusicList
		if target_list:
			target_list.remove_music(p_music_name)
	# 同步所有列表中该音乐的分类勾选状态
	_sync_music_category_state(p_music_name, p_list_name, p_toggled_on)

## 当音乐分类改变时的处理
func _on_music_category_changed(p_music_name: String, category: String, checked: bool) -> void:
	print("[Music Module] Category changed: %s -> %s (%s)" % [p_music_name, category, checked])
	if checked:
		add_music(category, p_music_name)
	else:
		var target_list = list_container.get_node_or_null(category) as MusicList
		if target_list:
			target_list.remove_music(p_music_name)
	# 同步所有列表中该音乐的分类勾选状态
	_sync_music_category_state(p_music_name, category, checked)

## 同步所有列表中指定音乐的分类勾选状态
func _sync_music_category_state(p_music_name: String, category: String, checked: bool) -> void:
	for child in list_container.get_children():
		if child is MusicList:
			child.set_music_category_checked(p_music_name, category, checked)

func _on_tab_button_pressed() -> void:
	frosted_panel.visible = not frosted_panel.visible


func _on_mode_button_pressed() -> void:
	next_play_mode = (next_play_mode + 1) % 3
			
func _on_add_button_pressed() -> void:
	_open_import_music_dialog()
func _on_files_selected(p_files: Array) -> void:
	for file_path in p_files:
		var file = FileAccess.open(file_path, FileAccess.READ)
		if file:
			var music_name = file.get_path().get_file().get_basename()
			audio_res.add_bgm(music_name, file_path)
##当有新的 BGM 被添加到资源时的回调
func _on_bgm_added(_name: String) -> void:
	var all_music_list = list_container.get_node_or_null("全部音乐") as MusicList
	if all_music_list:
		all_music_list.add_music(_name)
## 当请求删除特定音乐时的回调
func _on_music_removed(p_music_name: String, p_list_name: String) -> void:
	var target_list = list_container.get_node_or_null(p_list_name) as MusicList
	#如果列表是全部音乐，则弹出确认对话框
	if p_list_name == "全部音乐":
		var confirm_dialog = ConfirmationDialog.new()
		confirm_dialog.dialog_text = "确定要删除音乐%s吗？这将彻底移除该音乐。" % p_music_name
		confirm_dialog.confirmed.connect(func():
			#从所有列表中移除该音乐
			for child in list_container.get_children():
				if child is MusicList:
					child.remove_music(p_music_name)
			#从资源中移除该音乐
			var item = audio_res.get_bgm_item_by_name(p_music_name)
			if item:
				audio_res.remove_bgm(p_music_name)
		)
		add_child(confirm_dialog)
		confirm_dialog.popup_centered()
		return
	if target_list:
		target_list.remove_music(p_music_name)

#----辅助函数
	
## 检查指定音乐是否已存在于某个列表中
func is_music_in_list(p_list_name: String, p_music_name: String) -> bool:
	var target_list = list_container.get_node_or_null(p_list_name) as MusicList
	if target_list:
		for i in range(target_list.get_music_count()):
			var child = target_list.vbox.get_child(i)
			if child is MusicItem and child.get_music_name() == p_music_name:
				return true
	return false
