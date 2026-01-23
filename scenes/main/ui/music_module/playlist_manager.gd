class_name PlaylistManager
extends RefCounted

## 播放列表管理器
## 负责播放列表的创建、删除、音乐添加/移除等操作

# --- 信号 ---
signal playlist_added(playlist_name: String)
signal playlist_removed(playlist_name: String)
signal music_added_to_playlist(playlist_name: String, music_name: String)
signal music_removed_from_playlist(playlist_name: String, music_name: String)

# --- 成员变量 ---
## 播放列表容器的引用
var list_container: MarginContainer
## 音乐列表场景
var music_list_scene: PackedScene
## 音频资源
var audio_res: AudioRes

## 初始化
func initialize(p_list_container: MarginContainer, p_music_list_scene: PackedScene, p_audio_res: AudioRes) -> void:
	list_container = p_list_container
	music_list_scene = p_music_list_scene
	audio_res = p_audio_res

# --- 播放列表管理 ---

## 添加一个新的音乐列表
func add_playlist(p_name: String) -> MusicList:
	if not music_list_scene or not list_container:
		push_error("[PlaylistManager] Not initialized properly")
		return null

	# 检查是否已存在
	if list_container.get_node_or_null(p_name):
		push_warning("[PlaylistManager] Playlist '%s' already exists" % p_name)
		return list_container.get_node(p_name)

	var music_list_instance = music_list_scene.instantiate() as MusicList
	music_list_instance.name = p_name
	list_container.add_child(music_list_instance)

	# 默认隐藏，只显示当前选中的列表
	music_list_instance.visible = (list_container.get_child_count() == 1)

	playlist_added.emit(p_name)
	print("[PlaylistManager] Added playlist: %s" % p_name)
	return music_list_instance

## 删除播放列表
func remove_playlist(p_name: String) -> bool:
	if not list_container:
		return false

	var target_list = list_container.get_node_or_null(p_name)
	if not target_list:
		push_warning("[PlaylistManager] Playlist '%s' not found" % p_name)
		return false

	# 从容器中移除并释放
	list_container.remove_child(target_list)
	target_list.queue_free()

	playlist_removed.emit(p_name)
	print("[PlaylistManager] Removed playlist: %s" % p_name)
	return true

## 获取播放列表
func get_playlist(p_name: String) -> MusicList:
	if not list_container:
		return null
	return list_container.get_node_or_null(p_name) as MusicList

## 获取所有播放列表名称
func get_all_playlist_names() -> Array[String]:
	var names: Array[String] = []
	if not list_container:
		return names

	for child in list_container.get_children():
		if child is MusicList:
			names.append(child.name)
	return names

## 获取播放列表数量
func get_playlist_count() -> int:
	if not list_container:
		return 0
	return list_container.get_child_count()

## 根据索引获取播放列表
func get_playlist_by_index(index: int) -> MusicList:
	if not list_container:
		return null
	if index < 0 or index >= list_container.get_child_count():
		return null
	return list_container.get_child(index) as MusicList

# --- 音乐管理 ---

## 向指定播放列表添加音乐
func add_music_to_playlist(playlist_name: String, music_name: String, init_categories: bool = true) -> bool:
	var target_list = get_playlist(playlist_name)
	if not target_list:
		push_warning("[PlaylistManager] Playlist '%s' not found" % playlist_name)
		return false

	# 检查音乐是否已存在
	if is_music_in_playlist(playlist_name, music_name):
		print("[PlaylistManager] Music '%s' already in playlist '%s'" % [music_name, playlist_name])
		return true

	target_list.add_music(music_name)
	# 重置随机播放列表
	target_list.reset_shuffled_playlist()

	# 初始化新添加音乐的分类选项
	if init_categories:
		init_music_item_categories(playlist_name, music_name)

	music_added_to_playlist.emit(playlist_name, music_name)
	print("[PlaylistManager] Added music '%s' to playlist '%s'" % [music_name, playlist_name])
	return true

## 从指定播放列表移除音乐
func remove_music_from_playlist(playlist_name: String, music_name: String) -> bool:
	var target_list = get_playlist(playlist_name)
	if not target_list:
		push_warning("[PlaylistManager] Playlist '%s' not found" % playlist_name)
		return false

	target_list.remove_music(music_name)
	# 重置随机播放列表
	target_list.reset_shuffled_playlist()

	music_removed_from_playlist.emit(playlist_name, music_name)
	print("[PlaylistManager] Removed music '%s' from playlist '%s'" % [music_name, playlist_name])
	return true

## 从所有播放列表移除音乐（用于彻底删除音乐）
func remove_music_from_all_playlists(music_name: String) -> void:
	if not list_container:
		return

	for child in list_container.get_children():
		if child is MusicList:
			child.remove_music(music_name)
			child.reset_shuffled_playlist()

	print("[PlaylistManager] Removed music '%s' from all playlists" % music_name)

## 检查音乐是否在播放列表中
func is_music_in_playlist(playlist_name: String, music_name: String) -> bool:
	var target_list = get_playlist(playlist_name)
	if not target_list:
		return false

	for i in range(target_list.get_music_count()):
		var child = target_list.vbox.get_child(i)
		if child is MusicItem and child.get_music_name() == music_name:
			return true
	return false

## 获取播放列表中的所有音乐名称
func get_playlist_music_names(playlist_name: String) -> Array[String]:
	var names: Array[String] = []
	var target_list = get_playlist(playlist_name)
	if not target_list:
		return names

	for i in range(target_list.get_music_count()):
		var child = target_list.vbox.get_child(i)
		if child is MusicItem:
			names.append(child.get_music_name())
	return names

## 获取所有播放列表及其音乐
func get_all_playlists_music() -> Dictionary:
	var result: Dictionary = {}
	if not list_container:
		return result

	for child in list_container.get_children():
		if child is MusicList:
			var music_names: Array[String] = []
			for i in range(child.get_music_count()):
				var music_item = child.vbox.get_child(i)
				if music_item is MusicItem:
					music_names.append(music_item.get_music_name())
			result[child.name] = music_names
	return result

# --- 分类管理 ---

## 通知所有 MusicItem 添加新的分类选项
func add_category_to_all_music_items(category: String) -> void:
	if not list_container:
		return

	for list_child in list_container.get_children():
		if list_child is MusicList:
			for i in range(list_child.get_music_count()):
				var music_item = list_child.vbox.get_child(i)
				if music_item is MusicItem:
					# 检查音乐是否在该分类中
					var is_in_category = is_music_in_playlist(category, music_item.get_music_name())
					music_item.add_category(category, is_in_category)

	print("[PlaylistManager] Added category '%s' to all music items" % category)

## 通知所有 MusicItem 移除分类选项
func remove_category_from_all_music_items(category: String) -> void:
	if not list_container:
		return

	for list_child in list_container.get_children():
		if list_child is MusicList:
			for i in range(list_child.get_music_count()):
				var music_item = list_child.vbox.get_child(i)
				if music_item is MusicItem:
					music_item.remove_category(category)

	print("[PlaylistManager] Removed category '%s' from all music items" % category)

## 初始化 MusicItem 的所有分类选项
func init_music_item_categories(playlist_name: String, music_name: String) -> void:
	var music_list = get_playlist(playlist_name)
	if not music_list:
		return

	# 查找刚创建的 MusicItem
	var music_item: MusicItem = null
	for i in range(music_list.get_music_count()):
		var child = music_list.vbox.get_child(i)
		if child is MusicItem and child.get_music_name() == music_name:
			music_item = child
			break

	if not music_item:
		return

	# 获取所有播放列表名称（除了"全部音乐"）
	var list_names = get_all_playlist_names()
	for list_name in list_names:
		if list_name == "全部音乐":
			continue
		# 检查音乐是否在该播放列表中
		var is_in_list = is_music_in_playlist(list_name, music_name)
		music_item.add_category(list_name, is_in_list)

	print("[PlaylistManager] Initialized categories for music '%s'" % music_name)

## 同步所有播放列表中指定音乐的分类勾选状态
func sync_music_category_state(music_name: String, category: String, checked: bool) -> void:
	if not list_container:
		return

	for child in list_container.get_children():
		if child is MusicList:
			child.set_music_category_checked(music_name, category, checked)

	print("[PlaylistManager] Synced category state for music '%s', category '%s': %s" % [music_name, category, checked])
