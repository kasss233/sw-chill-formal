extends Node

## 环境时间切换信号
signal env_time_changed(mode: int)
## 环境天气切换信号
signal env_weather_changed(mode: int)
signal snow_changed(_value: int)
signal rain_changed(_value: int)
signal outdoor_1_changed(_state: int)
signal outdoor_2_changed(_state: int)
## 时间模式: 0=白天, 1=黄昏, 2=晚上, 3=同步系统
var _time_mode: int = 0
## 天气模式: 0=晴天, 1=雨天, 2=雪天, 3=同步
var _weather_mode: int = 0
## MSAA 3D 抗锯齿等级
var _msaa: int = 0
## Screen Space AA 等级
var _ssaa: int = 0
## 雨量强度
var _rain_amount: int = 300
## 雪量强度
var _snow_amount: int = 500
## 户外特效 1 开关状态
var _outdoor_1_state: int = 0
## 户外特效 2 开关状态
var _outdoor_2_state: int = 0

const SAVE_PATH = "user://settings.cfg"
const SAVE_DEBOUNCE_SEC := 0.25
const RAIN_MIN_AMOUNT := 300
const SNOW_MIN_AMOUNT := 500

var _save_timer: SceneTreeTimer

func _ready() -> void:
	_load_settings()
	call_deferred("_emit_loaded_settings")

## 设置时间模式并发出信号
func set_time(mode: int) -> void:
	_time_mode = mode
	env_time_changed.emit(mode)
	_save_settings()

## 设置天气模式并发出信号
func set_weather(mode: int) -> void:
	_weather_mode = mode
	env_weather_changed.emit(mode)
	_save_settings()
func set_rain_amount(amount: int) -> void:
	amount = maxi(amount, RAIN_MIN_AMOUNT)
	if _rain_amount == amount:
		return
	_rain_amount = amount
	emit_signal("rain_changed", amount)
	_queue_save_settings()
func set_snow_amount(amount: int) -> void:
	amount = maxi(amount, SNOW_MIN_AMOUNT)
	if _snow_amount == amount:
		return
	_snow_amount = amount
	emit_signal("snow_changed", amount)
	_queue_save_settings()
func get_time_mode() -> int:
	return _time_mode

func get_weather_mode() -> int:
	return _weather_mode

func get_rain_amount() -> int:
	return _rain_amount

func get_snow_amount() -> int:
	return _snow_amount

func get_outdoor_1_state() -> int:
	return _outdoor_1_state

func get_outdoor_2_state() -> int:
	return _outdoor_2_state

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

func set_outdoor_1(state: int) -> void:
	_outdoor_1_state = state
	emit_signal("outdoor_1_changed", state)
	_save_settings()
func set_outdoor_2(state: int) -> void:
	_outdoor_2_state = state
	emit_signal("outdoor_2_changed", state)
	_save_settings()
func _save_settings() -> void:
	var config = ConfigFile.new()
	config.set_value("env", "time_mode", _time_mode)
	config.set_value("env", "weather_mode", _weather_mode)
	config.set_value("env", "rain_amount", _rain_amount)
	config.set_value("env", "snow_amount", _snow_amount)
	config.set_value("env", "outdoor_1_state", _outdoor_1_state)
	config.set_value("env", "outdoor_2_state", _outdoor_2_state)
	config.set_value("rendering", "msaa_3d", _msaa)
	config.set_value("rendering", "screen_space_aa", _ssaa)
	config.save(SAVE_PATH)

func _queue_save_settings() -> void:
	if _save_timer and _save_timer.time_left > 0.0:
		return
	_save_timer = get_tree().create_timer(SAVE_DEBOUNCE_SEC)
	_save_timer.timeout.connect(_save_settings, CONNECT_ONE_SHOT)

func _load_settings() -> void:
	var config = ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		# 无存档，从当前视口读取默认值
		var vp = get_viewport()
		_msaa = vp.msaa_3d as int
		_ssaa = vp.screen_space_aa as int
		_save_settings()
		return
	_time_mode = int(config.get_value("env", "time_mode", 0))
	_weather_mode = int(config.get_value("env", "weather_mode", 0))
	_rain_amount = maxi(int(config.get_value("env", "rain_amount", RAIN_MIN_AMOUNT)), RAIN_MIN_AMOUNT)
	_snow_amount = maxi(int(config.get_value("env", "snow_amount", SNOW_MIN_AMOUNT)), SNOW_MIN_AMOUNT)
	_outdoor_1_state = int(config.get_value("env", "outdoor_1_state", 0))
	_outdoor_2_state = int(config.get_value("env", "outdoor_2_state", 0))
	_msaa = int(config.get_value("rendering", "msaa_3d", 0))
	_ssaa = int(config.get_value("rendering", "screen_space_aa", 0))
	get_viewport().msaa_3d = _msaa as Viewport.MSAA
	get_viewport().screen_space_aa = _ssaa as Viewport.ScreenSpaceAA

func _emit_loaded_settings() -> void:
	env_time_changed.emit(_time_mode)
	env_weather_changed.emit(_weather_mode)
	rain_changed.emit(_rain_amount)
	snow_changed.emit(_snow_amount)
	outdoor_1_changed.emit(_outdoor_1_state)
	outdoor_2_changed.emit(_outdoor_2_state)
