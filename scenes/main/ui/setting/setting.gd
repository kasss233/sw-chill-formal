class_name EnvSetter
extends Control

## UI 引用（用于层级管理）
@export var _ui: UI = null

@onready var canvas_layer: CanvasLayer = $CanvasLayer
@onready var panel = $CanvasLayer/FrostedPanel
@onready var _msaa_dropdown: MaterialDropdown = $CanvasLayer/FrostedPanel/VBoxContainer/MsaaRow/MsaaDropdown
@onready var _ssaa_dropdown: MaterialDropdown = $CanvasLayer/FrostedPanel/VBoxContainer/SsaaRow/SsaaDropdown

func _ready() -> void:
	panel.visible = false
	# 设置 CanvasLayer 的初始层级
	canvas_layer.layer = 10
	_init_dropdowns_from_state()

func set_weather(mode: int) -> void:
	SettingState.set_weather(mode)

func set_time(mode: int) -> void:
	SettingState.set_time(mode)

## 请求新的顶层层级
func _request_top_layer() -> void:
	if _ui:
		canvas_layer.layer = _ui.request_top_layer()
	else:
		# 降级方案：使用固定的高层级
		canvas_layer.layer = 100

func _on_time_button_state_changed(_old_state: int, new_state: int) -> void:
	SettingState.set_time(new_state)

func _on_weather_button_state_changed(_old_state: int, new_state: int) -> void:
	SettingState.set_weather(new_state)

func _on_setting_button_pressed() -> void:
	if panel.visible:
		GuiTransitions.hide("setter")
	else:
		# 请求新的顶层层级
		_request_top_layer()
		GuiTransitions.show("setter")


func _on_full_screen_checkbox_toggled(toggled_on: bool) -> void:
	pass # Replace with function body.

# ============ 抗锯齿设置 ============

func _on_msaa_changed(_index: int, value: Variant) -> void:
	SettingState.set_msaa(int(value))

func _on_ssaa_changed(_index: int, value: Variant) -> void:
	SettingState.set_ssaa(int(value))

# ============ 从 SettingState 初始化下拉框 ============

func _init_dropdowns_from_state() -> void:
	var msaa_val = SettingState.get_msaa()
	var ssaa_val = SettingState.get_ssaa()
	_msaa_dropdown.set_selected_by_value(str(msaa_val))
	_ssaa_dropdown.set_selected_by_value(str(ssaa_val))
