class_name EnvSetter
extends Control
@onready var panel=$CanvasLayer/FrostedPanel
signal env_time_changed(mode: int)
signal env_weather_changed(mode: int)
func _ready() -> void:
	panel.visible=false
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
		GuiTransitions.show("setter")
