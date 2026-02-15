extends Node

## 环境时间切换信号
signal env_time_changed(mode: int)
## 环境天气切换信号
signal env_weather_changed(mode: int)
signal snow_changed(_value: int)
signal rain_changed(_value: int)
## 时间模式: 0=白天, 1=黄昏, 2=晚上, 3=同步系统
var _time_mode: int = 0
## 天气模式: 0=晴天, 1=雨天, 2=雪天, 3=同步
var _weather_mode: int = 0
## MSAA 3D 抗锯齿等级
var _msaa: int = 0
## Screen Space AA 等级
var _ssaa: int = 0

const SAVE_PATH = "user://settings.cfg"

func _ready() -> void:
	_load_settings()

## 设置时间模式并发出信号
func set_time(mode: int) -> void:
	_time_mode = mode
	env_time_changed.emit(mode)

## 设置天气模式并发出信号
func set_weather(mode: int) -> void:
	_weather_mode = mode
	env_weather_changed.emit(mode)
func set_rain_amount(amount: int) -> void:
	emit_signal("rain_changed", amount)
func set_snow_amount(amount: int) -> void:
	emit_signal("snow_changed", amount)
func get_time_mode() -> int:
	return _time_mode

func get_weather_mode() -> int:
	return _weather_mode

## 设置 MSAA 并应用到视口、持久化
func set_msaa(mode: int) -> void:
	_msaa = mode
	get_viewport().msaa_3d = mode as Viewport.MSAA
	_save_settings()

## 设置 Screen Space AA 并应用到视口、持久化
func set_ssaa(mode: int) -> void:
	_ssaa = mode
	get_viewport().screen_space_aa = mode as Viewport.ScreenSpaceAA
	_save_settings()

func get_msaa() -> int:
	return _msaa

func get_ssaa() -> int:
	return _ssaa

func _save_settings() -> void:
	var config = ConfigFile.new()
	config.set_value("rendering", "msaa_3d", _msaa)
	config.set_value("rendering", "screen_space_aa", _ssaa)
	config.save(SAVE_PATH)

func _load_settings() -> void:
	var config = ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		# 无存档，从当前视口读取默认值
		var vp = get_viewport()
		_msaa = vp.msaa_3d as int
		_ssaa = vp.screen_space_aa as int
		return
	_msaa = int(config.get_value("rendering", "msaa_3d", 0))
	_ssaa = int(config.get_value("rendering", "screen_space_aa", 0))
	get_viewport().msaa_3d = _msaa as Viewport.MSAA
	get_viewport().screen_space_aa = _ssaa as Viewport.ScreenSpaceAA
