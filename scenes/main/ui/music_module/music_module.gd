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
## icon 
@export var play_icon:Texture
@export var pause_icon:Texture
##顺序播放icon
@export var order_icon:Texture
##随机播放icon
@export var random_icon:Texture
##单曲循环icon
@export var single_icon:Texture
# --- 节点引用 ---
## 列表 Tab 容器，管理多个音乐列表
@onready var tab_container: TabContainer =$TabPanel/TabContainer
@onready var label=$VBoxContainer/Label
@onready var status_button=$VBoxContainer/HBoxContainer/StatusButton
@onready var tab_panel=$TabPanel
@onready var mode_button=$VBoxContainer/HBoxContainer/ModeButton
# --- 成员变量 ---
## 当前选中的音乐列表索引
var current_list_index: int = 0
## 是否弹出了选项面板
var option_board_opened: bool = false
## 当前的icon
var is_playing: bool=false
## 播放下一首的选择方式
var next_play_mode: int = 0 # 0: 顺序播放, 1: 随机播放, 2: 单曲循环
func _ready() -> void:
	_setup_initial_music()

# --- 内部处理函数 ---
## 初始化默认列表并加载音乐
func _setup_initial_music() -> void:
	add_music_list("全部音乐")
	add_music_list("收藏")
	
	var all_music_list = tab_container.get_node_or_null("全部音乐") as MusicList
	if all_music_list and audio_res:
		for item in audio_res.BGM:
			all_music_list.add_music(item.name)
			print("[Music Module] Loaded music item: %s" % item.name)

# --- 公有 API ---
## 添加一个新的音乐列表
func add_music_list(p_name: String) -> void:
	if not music_list_scene:
		return
		
	var music_list_instance = music_list_scene.instantiate() as MusicList
	music_list_instance.name = p_name
	tab_container.add_child(music_list_instance)
	# 连接列表信号
	music_list_instance.music_changed.connect(_on_music_changed)
	music_list_instance.music_options_requested.connect(_on_music_options_requested)
## 向指定音乐列表添加一首音乐
func add_music(p_list_name: String, p_music_name: String) -> void:
	var target_list = tab_container.get_node_or_null(p_list_name) as MusicList
	if target_list:
		target_list.add_music(p_music_name)



## 获得当前列表
func get_current_list() -> MusicList:
	if tab_container.get_child_count() > current_list_index:
		var current_list = tab_container.get_child(current_list_index) as MusicList
		return current_list
	return null
## 获取当前所有音乐列表的名称
func get_music_list_names() -> Array[String]:
	var names: Array[String] = []
	for child in tab_container.get_children():
		if child is MusicList:
			names.append(child.name)
	return names
## 获取当前列表中的所有音乐名称
func get_current_list_music_names() -> Array[String]:
	var names: Array[String] = []
	if tab_container.get_child_count() > current_list_index:
		var current_list = tab_container.get_child(current_list_index) as MusicList
		if current_list:
			for i in range(current_list.get_music_count()):
				var child = current_list.vbox.get_child(i)
				if child is MusicItem:
					names.append(child.get_music_name())
	return names
## 获取列表中的音乐名称
func get_list_music_names(p_list_name: String) -> Array[String]:
	var names: Array[String] = []
	var target_list = tab_container.get_node_or_null(p_list_name) as MusicList
	if target_list:
		for i in range(target_list.get_music_count()):
			var child = target_list.vbox.get_child(i)
			if child is MusicItem:
				names.append(child.get_music_name())
	return names
## 获取所有列表的音乐名称
func get_all_lists_music_names() -> Dictionary:
	var result: Dictionary = {}
	for child in tab_container.get_children():
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
	if next_play_mode==0:
		current_list.play_next_music()
	elif next_play_mode==1:
		current_list.play_random_music()
	elif next_play_mode==2:
		current_list.play_single_music()
	change_play_status(true)

# --- 信号回调 ---
## 更换当前播放的音乐，更新 UI 并发出信号
func _on_music_changed(p_name: String) -> void:
	print("[Music Module] Changing music to: %s" % p_name)
	music_changed.emit(p_name)
	change_play_status(true)
	label.text=p_name
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
		change_play_status(true)


## 播放/暂停
func _on_status_button_pressed() -> void:
	music_status_changed.emit()
	change_play_status(not is_playing)
	print("[Music Module] music_status_changed emitted")

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
				current_list.play_next_music()#单曲循环切换按顺序播放下一首
		change_play_status(true)

## 切换 Tab 列表
func _on_tab_container_tab_changed(p_tab_index: int) -> void:
	current_list_index = p_tab_index

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
		var target_list = tab_container.get_node_or_null(p_list_name) as MusicList
		if target_list:
			target_list.remove_music(p_music_name)

func _on_tab_button_pressed() -> void:
	tab_panel.visible=not tab_panel.visible


func _on_mode_button_pressed() -> void:
	next_play_mode = (next_play_mode + 1) % 3
	match next_play_mode:
		0:
			mode_button.icon= order_icon
		1:
			mode_button.icon= random_icon
		2:
			mode_button.icon= single_icon
#----辅助函数
##切换播放状态
func change_play_status(_is_playing: bool) -> void:
	is_playing = _is_playing
	match is_playing:
		true:
			status_button.icon= play_icon
		false:
			status_button.icon= pause_icon
## 检查指定音乐是否已存在于某个列表中
func is_music_in_list(p_list_name: String, p_music_name: String) -> bool:
	var target_list = tab_container.get_node_or_null(p_list_name) as MusicList
	if target_list:
		for i in range(target_list.get_music_count()):
			var child = target_list.vbox.get_child(i)
			if child is MusicItem and child.get_music_name() == p_music_name:
				return true
	return false
