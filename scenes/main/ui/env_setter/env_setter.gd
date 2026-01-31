class_name EnvSetter
extends Control

## UI 引用（用于层级管理）
@export var _ui: UI = null

@onready var canvas_layer: CanvasLayer = $CanvasLayer
@onready var panel = $CanvasLayer/FrostedPanel

signal env_time_changed(mode: int)
signal env_weather_changed(mode: int)

func _ready() -> void:
	panel.visible = false
	# 设置 CanvasLayer 的初始层级
	canvas_layer.layer = 10
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
