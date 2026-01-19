class_name EnvTimeSetter
extends Control
signal env_time_changed(mode: int)
func _on_material_toggle_button_state_changed(_old_state: int, new_state: int) -> void:
	match new_state:
		0:
			emit_signal("env_time_changed", 0) # Daytime
		1:
			emit_signal("env_time_changed", 1) # afternoon
		2:
			emit_signal("env_time_changed", 2) # dusk
		3:
			emit_signal("env_time_changed", 3) # evening
		4:
			emit_signal("env_time_changed", 4) # sync with system time
