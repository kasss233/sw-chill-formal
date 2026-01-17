class_name MusicList
extends Control

## 音乐列表容器，管理多个 MusicItem 并处理播放逻辑

# --- 信号 ---
## 当列表中的音乐被触发更改时发出
signal music_changed(p_name: String)
## 当列表中的音乐被收藏时发出
signal music_favoured(p_name: String)
## 当请求显示特定音乐的选项菜单时发出
signal music_options_requested(music_name: String, list_name: String)
## 当请求删除特定音乐时发出
signal music_remove_requested(music_name: String)
# --- 导出项与节点引用 ---
## 音乐列表项场景
@export var music_item_scene: PackedScene
## 垂直容器，用于存放音乐项
@onready var vbox: VBoxContainer = $ScrollContainer/VBoxContainer

# --- 成员变量 ---
## 当前播放的索引
var current_playing_index: int = -1
## 当前播放的音乐名称
var current_playing_name: String = ""

# --- 公有 API ---
## 获取列表中音乐的数量
func get_music_count() -> int:
	return vbox.get_child_count()

## 获取当前正在播放的索引
func get_playing_index() -> int:
	return current_playing_index
## 获取当前正在播放的音乐名称
func get_playing_name() -> String:
	return current_playing_name
## 设置音乐列表的名称
func set_music_list_name(p_name: String) -> void:
	self.name = p_name

## 向列表中添加一首音乐
func add_music(p_name: String) -> void:
	if p_name == "":
		push_warning("MusicList.add_music: empty name")
		return
		
	# 检查是否已存在
	for child in vbox.get_children():
		if child is MusicItem and child.get_music_name() == p_name:
			print("MusicList.add_music: music %s already exists in list %s" % [p_name, self.name])
			return
	# 实例化
	var m = music_item_scene.instantiate() as MusicItem
	m.set_music_name(p_name)
	vbox.add_child(m)
	
	# 连接信号
	m.music_changed.connect(_on_music_changed)
	m.music_options_requested.connect(_on_music_options_requested)
	m.music_removed.connect(_on_music_removed)
## 从列表中移除一首音乐
func remove_music(p_name: String) -> void:
	for child in vbox.get_children():
		if child is MusicItem and child.get_music_name() == p_name:
			vbox.remove_child(child)
			child.queue_free()
			return

## 播放指定索引的音乐
func play_music(p_index: int) -> void:
	if p_index < 0 or p_index >= vbox.get_child_count():
		return
		
	var child = vbox.get_child(p_index)
	if child is MusicItem:
		child.play_music()
		current_playing_index = p_index
		current_playing_name = child.music_name

## 播放下一首
func play_next_music() -> void:
	if current_playing_index == -1 and get_music_count() > 0:
		play_music(0)
		return
	
	if current_playing_index == -1:
		return
		
	var next_index = (current_playing_index + 1) % vbox.get_child_count()
	play_music(next_index)

## 播放上一首
func play_last_music() -> void:
	if current_playing_index == -1 and get_music_count() > 0:
		play_music(vbox.get_child_count() - 1)
		return

	if current_playing_index == -1:
		return
		
	var last_index = (current_playing_index - 1 + vbox.get_child_count()) % vbox.get_child_count()
	play_music(last_index)
## 随机播放下一首，保证不跟当前重复
func play_random_music() -> void:
	if get_music_count() == 0:
		return
	var random_index = randi() % get_music_count()
	while random_index == current_playing_index and get_music_count() > 1:
		random_index = randi() % get_music_count()
	play_music(random_index)
func play_single_music() -> void:
	if current_playing_index != -1:
		play_music(current_playing_index)

# --- 信号回调 ---
func _on_music_changed(p_name: String) -> void:
	music_changed.emit(p_name)
	current_playing_name = p_name
	for i in range(vbox.get_child_count()):
		var child = vbox.get_child(i)
		if child is MusicItem and child.get_music_name() == p_name:
			current_playing_index = i
			return

func _on_music_options_requested(p_name: String) -> void:
	music_options_requested.emit(p_name, self.name)

func _on_music_removed(p_name: String) -> void:
	music_remove_requested.emit(p_name)
