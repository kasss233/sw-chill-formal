class_name EnvSetter
extends Control

## UI 引用（用于层级管理）
@export var _ui: UI = null

@onready var canvas_layer: CanvasLayer = $CanvasLayer
@onready var panel = $CanvasLayer/FrostedPanel
@onready var _msaa_dropdown: MaterialDropdown = $CanvasLayer/FrostedPanel/VBoxContainer/MsaaRow/MsaaDropdown
@onready var _ssaa_dropdown: MaterialDropdown = $CanvasLayer/FrostedPanel/VBoxContainer/SsaaRow/SsaaDropdown

signal env_time_changed(mode: int)
signal env_weather_changed(mode: int)

#设置项
const SAVE_PATH = "user://settings.cfg"

func _ready() -> void:
	panel.visible = false
	# 设置 CanvasLayer 的初始层级
	canvas_layer.layer = 10
	_load_settings()

func set_weather(mode: int) -> void:
	env_weather_changed.emit(mode)

func set_time(mode: int) -> void:
	env_time_changed.emit(mode)

## 请求新的顶层层级
func _request_top_layer() -> void:
	if _ui:
		canvas_layer.layer = _ui.request_top_layer()
	else:
		# 降级方案：使用固定的高层级
		canvas_layer.layer = 100

func _on_time_button_state_changed(_old_state: int, new_state: int) -> void:
	match new_state:
		0:
			emit_signal("env_time_changed", 0) # Daytime
		1:
			emit_signal("env_time_changed", 1) # dusk
		2:
			emit_signal("env_time_changed", 2) # evening
		3:
			emit_signal("env_time_changed", 3) # sync with system time


func _on_weather_button_state_changed(_old_state: int, new_state: int) -> void:
	match new_state:
		0:
			emit_signal("env_weather_changed", 0) # sunny
		1:
			emit_signal("env_weather_changed", 1) # rainy
		2:
			emit_signal("env_weather_changed", 2) # snowy
		3:
			emit_signal("env_weather_changed", 3) # sync


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
	var mode := int(value)
	get_viewport().msaa_3d = mode as Viewport.MSAA
	_save_settings()

func _on_ssaa_changed(_index: int, value: Variant) -> void:
	var mode := int(value)
	get_viewport().screen_space_aa = mode as Viewport.ScreenSpaceAA
	_save_settings()

# ============ 持久化 ============

func _save_settings() -> void:
	var config = ConfigFile.new()
	if _msaa_dropdown and _msaa_dropdown.selected_index >= 0:
		config.set_value("rendering", "msaa_3d", _msaa_dropdown.get_selected_value())
	if _ssaa_dropdown and _ssaa_dropdown.selected_index >= 0:
		config.set_value("rendering", "screen_space_aa", _ssaa_dropdown.get_selected_value())
	config.save(SAVE_PATH)

func _load_settings() -> void:
	var config = ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		# 无存档，从当前视口读取默认值
		var vp = get_viewport()
		_msaa_dropdown.set_selected_by_index(vp.msaa_3d as int)
		_ssaa_dropdown.set_selected_by_index(vp.screen_space_aa as int)
		return

	# 读取并应用 MSAA
	var msaa_val = config.get_value("rendering", "msaa_3d", "0")
	_msaa_dropdown.set_selected_by_value(str(msaa_val))
	get_viewport().msaa_3d = int(msaa_val) as Viewport.MSAA

	# 读取并应用 Screen Space AA
	var ssaa_val = config.get_value("rendering", "screen_space_aa", "0")
	_ssaa_dropdown.set_selected_by_value(str(ssaa_val))
	get_viewport().screen_space_aa = int(ssaa_val) as Viewport.ScreenSpaceAA
