extends VBoxContainer

@onready var _rain_slider: MaterialSlider = $HBoxContainer/RainSlider
@onready var _wind_slider: MaterialSlider = $HBoxContainer2/WindSlider
@onready var _car_slider: MaterialSlider = $HBoxContainer3/CarSlider


func _ready() -> void:
	if not SettingState:
		push_warning("[SoundSettings] SettingState 不存在，无法持久化环境音设置")
		return

	if not SettingState.rain_sound_volume_changed.is_connected(_on_state_rain_sound_volume_changed):
		SettingState.rain_sound_volume_changed.connect(_on_state_rain_sound_volume_changed)
	if not SettingState.wind_sound_volume_changed.is_connected(_on_state_wind_sound_volume_changed):
		SettingState.wind_sound_volume_changed.connect(_on_state_wind_sound_volume_changed)
	if not SettingState.car_sound_volume_changed.is_connected(_on_state_car_sound_volume_changed):
		SettingState.car_sound_volume_changed.connect(_on_state_car_sound_volume_changed)

	_sync_from_state()


func _exit_tree() -> void:
	if not SettingState:
		return
	if SettingState.rain_sound_volume_changed.is_connected(_on_state_rain_sound_volume_changed):
		SettingState.rain_sound_volume_changed.disconnect(_on_state_rain_sound_volume_changed)
	if SettingState.wind_sound_volume_changed.is_connected(_on_state_wind_sound_volume_changed):
		SettingState.wind_sound_volume_changed.disconnect(_on_state_wind_sound_volume_changed)
	if SettingState.car_sound_volume_changed.is_connected(_on_state_car_sound_volume_changed):
		SettingState.car_sound_volume_changed.disconnect(_on_state_car_sound_volume_changed)


func _sync_from_state() -> void:
	_on_state_rain_sound_volume_changed(SettingState.get_rain_sound_volume())
	_on_state_wind_sound_volume_changed(SettingState.get_wind_sound_volume())
	_on_state_car_sound_volume_changed(SettingState.get_car_sound_volume())


func _normalize_slider_percent(value: float) -> int:
	if value <= 1.0:
		return int(round(clampf(value, 0.0, 1.0) * 100.0))
	return int(round(clampf(value, 0.0, 100.0)))


func _to_linear_volume(percent: int) -> float:
	return clampf(float(percent) / 100.0, 0.0, 1.0)


func _apply_rain_volume(percent: int) -> void:
	AudioPlayer.set_sound_effect_volume("rain", _to_linear_volume(percent))


func _apply_wind_volume(percent: int) -> void:
	AudioPlayer.set_sound_effect_volume("wind", _to_linear_volume(percent))


func _apply_car_volume(percent: int) -> void:
	AudioPlayer.set_sound_effect_volume("car", _to_linear_volume(percent))


func _on_state_rain_sound_volume_changed(value: int) -> void:
	if _rain_slider:
		_rain_slider.set_value_no_signal(float(value))
	_apply_rain_volume(value)


func _on_state_wind_sound_volume_changed(value: int) -> void:
	if _wind_slider:
		_wind_slider.set_value_no_signal(float(value))
	_apply_wind_volume(value)


func _on_state_car_sound_volume_changed(value: int) -> void:
	if _car_slider:
		_car_slider.set_value_no_signal(float(value))
	_apply_car_volume(value)


func _on_rain_slider_value_changed(value: float) -> void:
	var percent := _normalize_slider_percent(value)
	SettingState.set_rain_sound_volume(percent)
	AudioPlayer.play_sound_effect("rain")


func _on_wind_slider_value_changed(value: float) -> void:
	var percent := _normalize_slider_percent(value)
	SettingState.set_wind_sound_volume(percent)
	AudioPlayer.play_sound_effect("wind")


func _on_car_slider_value_changed(value: float) -> void:
	var percent := _normalize_slider_percent(value)
	SettingState.set_car_sound_volume(percent)
	AudioPlayer.play_sound_effect("car")
