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
## 列表 Tab 容器，管理多个音乐列表
@onready var tab_container: TabContainer = $FoldableContainer/TabContainer
## 折叠容器
@onready var folder: Control = $FoldableContainer

# --- 成员变量 ---
## 当前选中的音乐列表索引
var current_list_index: int = 0
## 是否弹出了选项面板
var option_board_opened: bool = false
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
	music_list_instance.music_changed.connect(change_music)
	music_list_instance.music_options_requested.connect(_on_music_options_requested)
## 向指定音乐列表添加一首音乐
func add_music(p_list_name: String, p_music_name: String) -> void:
	var target_list = tab_container.get_node_or_null(p_list_name) as MusicList
	if target_list:
		target_list.add_music(p_music_name)

## 更换当前播放的音乐，更新 UI 并发出信号
func change_music(p_name: String) -> void:
	print("[Music Module] Changing music to: %s" % p_name)
	music_changed.emit(p_name)
	if folder:
		folder.set("title", p_name)
## 检查指定音乐是否已存在于某个列表中
func is_music_in_list(p_list_name: String, p_music_name: String) -> bool:
	var target_list = tab_container.get_node_or_null(p_list_name) as MusicList
	if target_list:
		for i in range(target_list.get_music_count()):
			var child = target_list.vbox.get_child(i)
			if child is MusicItem and child.get_music_name() == p_music_name:
				return true
	return false

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



# --- 信号回调 ---
## 播放上一首
func _on_last_button_pressed() -> void:
	if tab_container.get_child_count() > current_list_index:
		var current_list = tab_container.get_child(current_list_index) as MusicList
		if current_list:
			current_list.play_last_music()

## 播放/暂停
func _on_status_button_pressed() -> void:
	music_status_changed.emit()
	print("[Music Module] music_status_changed emitted")

## 播放下一首
func _on_next_button_pressed() -> void:
	if tab_container.get_child_count() > current_list_index:
		var current_list = tab_container.get_child(current_list_index) as MusicList
		if current_list:
			current_list.play_next_music()

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
