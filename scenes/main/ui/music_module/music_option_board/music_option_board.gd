class_name MusicOptionBoard
extends Control

## 音乐选项面板，用于管理单首音乐所属的列表

# --- 信号 ---
## 当某个列表选项的状态改变时发出
signal option_changed(p_list_name: String, p_music_name: String, p_toggled_on: bool)
## 当关闭按钮被按下时发出
signal board_closed()
# --- 导出变量 ---
## 选项项场景
@export var option_scene: PackedScene

# --- 节点引用 ---
## 选项容器
@onready var vbox: VBoxContainer =$PanelContainer/VBoxContainer
## 标题标签（显示当前操作的音乐名）
@onready var title_label: Label = $PanelContainer/VBoxContainer/HBoxContainer2/Label

# --- 公有 API ---
## 设置当前操作的音乐名称
func set_music_name(p_name: String) -> void:
	if title_label:
		title_label.text = p_name

## 添加一个列表选项
func add_option(p_list_name: String) -> void:
	if not option_scene:
		return
		
	var option_instance = option_scene.instantiate() as MusicOptionItem
	vbox.add_child(option_instance)
	option_instance.set_option_name(p_list_name)
	option_instance.option_toggled.connect(_on_option_toggled)

## 将指定列表的选项设置为勾选状态
func toggle_option(p_list_name: String) -> void:
	for child in vbox.get_children():
		if child is MusicOptionItem and child.get_option_name() == p_list_name:
			child.toggle_on()
			return

# --- 信号回调 ---
func _on_close_button_pressed() -> void:
	board_closed.emit()
	queue_free()

func _on_option_toggled(p_list_name: String, p_toggled_on: bool) -> void:
	option_changed.emit(p_list_name, title_label.text if title_label else "", p_toggled_on)
