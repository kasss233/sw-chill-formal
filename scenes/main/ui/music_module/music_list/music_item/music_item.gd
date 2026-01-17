class_name MusicItem
extends Control

## 音乐列表项，显示单首音乐并处理相关交互

# --- 信号 ---
## 当点击播放按钮时发出，传递音乐名称
signal music_changed(p_name: String)
## 当点击选项按钮时发出，传递音乐名称
signal music_options_requested(p_name: String)
## 当点击删除按钮时发出，传递音乐名称
signal music_removed(p_name: String)
# --- 导出变量/节点引用 ---
## 音乐名称
@export var music_name: String
## 播放按钮引用
@onready var button: Button = $HBoxContainer/Button

# --- 内置函数 ---
func _ready() -> void:
	set_music_name(music_name)

# --- 公有 API ---
## 设置显示的音乐名称
func set_music_name(p_name: String) -> void:
	music_name = p_name
	if button:
		button.text = music_name

## 获取当前项的音乐名称
func get_music_name() -> String:
	return music_name

## 触发播放逻辑
func play_music() -> void:
	music_changed.emit(music_name)

# --- 信号回调 ---
func _on_button_pressed() -> void:
	play_music()

func _on_option_button_pressed() -> void:
	music_options_requested.emit(music_name)


func _on_remove_button_pressed() -> void:
	music_removed.emit(music_name)
