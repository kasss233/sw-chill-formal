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
## 随机播放列表（存储打乱后的索引顺序）
var shuffled_playlist: Array[int] = []
## 当前在随机播放列表中的位置
var shuffled_playlist_index: int = -1

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
## 随机播放下一首，使用打乱的播放列表
func play_random_music() -> void:
	if get_music_count() == 0:
		return

	# 如果随机播放列表为空，重新生成
	if shuffled_playlist.is_empty():
		generate_shuffled_playlist()
		# generate_shuffled_playlist() 已经设置了正确的 shuffled_playlist_index
		# 如果当前没有播放歌曲，从第一首开始
		if shuffled_playlist_index == -1 and shuffled_playlist.size() > 0:
			shuffled_playlist_index = 0
		else:
			# 如果当前正在播放歌曲，移动到下一首
			shuffled_playlist_index += 1
			# 如果超出范围，循环到开头
			if shuffled_playlist_index >= shuffled_playlist.size():
				shuffled_playlist_index = 0
	elif shuffled_playlist_index >= shuffled_playlist.size() - 1:
		# 已播放完，重新生成并从头开始
		#generate_shuffled_playlist()
		shuffled_playlist_index = 0
	else:
		# 移动到下一首
		shuffled_playlist_index += 1

	# 播放随机列表中的当前歌曲
	if shuffled_playlist_index >= 0 and shuffled_playlist_index < shuffled_playlist.size():
		var target_index = shuffled_playlist[shuffled_playlist_index]
		play_music(target_index)

## 随机播放上一首，使用打乱的播放列表
func play_random_previous() -> void:
	if get_music_count() == 0:
		return

	# 如果随机播放列表为空，生成一个
	if shuffled_playlist.is_empty():
		generate_shuffled_playlist()
		# generate_shuffled_playlist() 已经设置了正确的 shuffled_playlist_index
		# 如果当前没有播放歌曲，从第一首开始
		if shuffled_playlist_index == -1 and shuffled_playlist.size() > 0:
			shuffled_playlist_index = 0
		else:
			# 如果当前正在播放歌曲，移动到上一首
			shuffled_playlist_index -= 1
			# 如果小于0，循环到末尾
			if shuffled_playlist_index < 0:
				shuffled_playlist_index = shuffled_playlist.size() - 1
	elif shuffled_playlist_index > 0:
		# 移动到上一首
		shuffled_playlist_index -= 1
	else:
		# 已经在第一首，循环到最后一首
		shuffled_playlist_index = shuffled_playlist.size() - 1

	# 播放随机列表中的当前歌曲
	if shuffled_playlist_index >= 0 and shuffled_playlist_index < shuffled_playlist.size():
		var target_index = shuffled_playlist[shuffled_playlist_index]
		play_music(target_index)

## 生成打乱的播放列表
func generate_shuffled_playlist() -> void:
	shuffled_playlist.clear()

	# 创建索引数组
	for i in range(get_music_count()):
		shuffled_playlist.append(i)

	# Fisher-Yates 洗牌算法
	for i in range(shuffled_playlist.size() - 1, 0, -1):
		var j = randi() % (i + 1)
		var temp = shuffled_playlist[i]
		shuffled_playlist[i] = shuffled_playlist[j]
		shuffled_playlist[j] = temp

	# 如果当前正在播放某首歌，找到它在随机列表中的位置并设置为当前索引
	if current_playing_index != -1 and shuffled_playlist.size() > 0:
		var current_pos = shuffled_playlist.find(current_playing_index)
		if current_pos != -1:
			shuffled_playlist_index = current_pos
			print("[MusicList] Generated shuffled playlist, current song at position: ", current_pos)
		else:
			shuffled_playlist_index = 0
	else:
		shuffled_playlist_index = -1

	print("[MusicList] Generated shuffled playlist: ", shuffled_playlist)

## 重置随机播放列表（当歌单内容改变时调用）
func reset_shuffled_playlist() -> void:
	shuffled_playlist.clear()
	shuffled_playlist_index = -1
	print("[MusicList] Reset shuffled playlist")
func play_single_music() -> void:
	if current_playing_index != -1:
		play_music(current_playing_index)

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
