class_name MusicOptionItem
extends Control

## 音乐选项项，通常用于在选项面板中表示一个音乐列表

# --- 信号 ---
## 当选项状态改变时发出
signal option_toggled(p_list_name: String, p_toggled_on: bool)

# --- 节点引用 ---
## 选项名称标签
@onready var label: Label = $HBoxContainer/Label
## 选项复选框
@onready var check_box: CheckBox = $HBoxContainer/CheckBox

# --- 公有 API ---
## 设置选项名称
func set_option_name(p_name: String) -> void:
	if label:
		label.text = p_name
	
	# 如果是“全部音乐”列表，通常不允许从此处移除
	if p_name == "全部音乐":
		check_box.disabled = true

## 获取选项名称
func get_option_name() -> String:
	return label.text if label else ""

## 切换选项为开启状态
func toggle_on() -> void:
	if check_box:
		check_box.button_pressed = true

# --- 信号回调 ---
func _on_check_box_toggled(p_toggled_on: bool) -> void:
	option_toggled.emit(get_option_name(), p_toggled_on)
