class_name UI
extends Control

## 主 UI 控制器，负责协调各模块信号并与全局服务层（如 AudioPlayer）交互

# --- 信号 ---
## 当音乐切换时发出
signal music_changed(p_name: String)
## 当播放状态（播放/暂停）切换时发出
signal music_status_changed()

## 切换环境时间
signal env_time_changed(mode: int)
## 切换天气
signal env_weather_changed(mode:int)
## 角色互动 
signal character_interacted
# --- 节点引用 ---
## 音乐管理模块
@onready var music_module: Control = $MusicModule

# --- 内置函数 ---
func _ready() -> void:
	_connect_signals()

# --- 内部处理函数 ---
## 连接各子模块信号
func _connect_signals() -> void:
	if music_module:
		music_module.music_changed.connect(_on_music_changed)
		music_module.music_status_changed.connect(_on_music_status_changed)

# --- 公有 API (音乐模块包装) ---
## 添加一个新的音乐列表
func add_music_list(p_name: String) -> void:
	if music_module:
		music_module.add_music_list(p_name)

## 向指定音乐列表添加一首音乐
func add_music(p_list_name: String, p_music_name: String) -> void:
	if music_module:
		music_module.add_music(p_list_name, p_music_name)

## 更换当前播放的音乐
func change_music(p_name: String) -> void:
	if music_module:
		music_module.change_music(p_name)
## 删除音乐
func remove_music(p_music_name: String, p_list_name: String) -> void:
	if music_module:
		music_module.remove_music(p_music_name, p_list_name)
## 播放下一首音乐
func play_next_music() -> void:
	if music_module:
		music_module.play_next_music()
## 检查指定音乐是否已存在于某个列表中
func is_music_in_list(p_list_name: String, p_music_name: String) -> bool:
	if music_module:
		return music_module.is_music_in_list(p_list_name, p_music_name)
	return false

## 获取当前所有音乐列表的名称
func get_music_list_names() -> Array[String]:
	if music_module:
		return music_module.get_music_list_names()
	return []

## 获取当前列表中的所有音乐名称
func get_current_list_music_names() -> Array[String]:
	if music_module:
		return music_module.get_current_list_music_names()
	return []

## 获取指定列表中的音乐名称
func get_list_music_names(p_list_name: String) -> Array[String]:
	if music_module:
		return music_module.get_list_music_names(p_list_name)
	return []

## 获取所有列表及其对应的音乐名称映射
func get_all_lists_music_names() -> Dictionary:
	if music_module:
		return music_module.get_all_lists_music_names()
	return {}

## 根据名称切换到指定的歌单
func switch_to_list_by_name(p_list_name: String) -> void:
	if music_module:
		music_module.switch_to_list_by_name(p_list_name)

## 设置当前音乐显示（用于初始化时更新 UI）
func set_current_music_display(p_music_name: String) -> void:
	if music_module:
		music_module.set_current_music_display(p_music_name)

# --- 信号转发回调 ---
func _on_music_changed(p_name: String) -> void:
	music_changed.emit(p_name)

func _on_music_status_changed() -> void:
	music_status_changed.emit()


func _on_env_time_setter_env_time_changed(mode: int) -> void:
	env_time_changed.emit(mode)


func _on_env_setter_env_weather_changed(mode: int) -> void:
	env_weather_changed.emit(mode)


func _on_character_interactor_character_interacted() -> void:
	character_interacted.emit()
