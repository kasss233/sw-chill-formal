class_name MusicList
extends Control

## 音乐列表容器，管理多个 MusicItem 并处理播放逻辑

# --- 信号 ---
## 当列表中的音乐被选中时发出
signal music_selected(p_name: String)
## 当列表中的音乐被收藏时发出
signal music_favoured(p_name: String)
## 当请求显示特定音乐的选项菜单时发出
signal music_options_requested(music_name: String, list_name: String)
## 当请求删除特定音乐时发出
signal music_remove_requested(music_name: String)
## 当音乐分类改变时发出
signal music_category_changed(music_name: String, category: String, checked: bool)
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
	m.music_selected.connect(_on_music_selected)
	m.music_options_requested.connect(_on_music_options_requested)
	m.music_removed.connect(_on_music_removed)
	m.music_category_changed.connect(_on_music_category_changed)
## 从列表中移除一首音乐
func remove_music(p_name: String) -> void:
	for child in vbox.get_children():
		if child is MusicItem and child.get_music_name() == p_name:
			vbox.remove_child(child)
			child.queue_free()
			return

## 设置指定音乐的分类勾选状态
func set_music_category_checked(p_music_name: String, category: String, checked: bool) -> void:
	for child in vbox.get_children():
		if child is MusicItem and child.get_music_name() == p_music_name:
			child.set_category_checked(category, checked)
			return

## 获取指定音乐的分类勾选状态
func get_music_category_checked(p_music_name: String, category: String) -> bool:
	for child in vbox.get_children():
		if child is MusicItem and child.get_music_name() == p_music_name:
			return child.get_category_checked(category)
	return false

# --- 信号回调 ---
func _on_music_selected(p_name: String) -> void:
	music_selected.emit(p_name)
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

func _on_music_category_changed(p_name: String, category: String, checked: bool) -> void:
	music_category_changed.emit(p_name, category, checked)
