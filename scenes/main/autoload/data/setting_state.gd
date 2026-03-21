extends Node

## SettingState
## - 设置模块的唯一数据源（Autoload）
## - 负责环境参数与抗锯齿参数的读写、持久化与信号广播
## - UI 层只通过公开 API 改值，并监听本脚本信号更新显示

## 环境时间切换信号
signal env_time_changed(mode: int)
## 环境天气切换信号
signal env_weather_changed(mode: int)
## 雪量强度变化
signal snow_changed(_value: int)
## 雨量强度变化
signal rain_changed(_value: int)
## 摄像头切换
signal camera_changed(_value: int)
## AI 回复流光开关变化
signal ai_response_glow_changed(enabled: bool)
## 户外特效 1 状态变化
# signal outdoor_1_changed(_state: int)
## 户外特效 2 状态变化
# signal outdoor_2_changed(_state: int)
## 雾效状态变化
signal fog_changed(_state: int)
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
# var _outdoor_1_state: int = 0
## 户外特效 2 开关状态
# var _outdoor_2_state: int = 0
## 雾效开关状态
var _fog_state: int = 0
## 摄像头模式
var _camera_mode: int = 0
## AI 回复时对话框流光开关
var _ai_response_glow: bool = true


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
	if _time_mode == mode:
		return
	_time_mode = mode
	env_time_changed.emit(mode)
	_save_settings()

## 设置天气模式并发出信号
func set_weather(mode: int) -> void:
	if _weather_mode == mode:
		return
	_weather_mode = mode
	env_weather_changed.emit(mode)
	_save_settings()

## 设置雨量（下限 300），高频调整走防抖保存
func set_rain_amount(amount: int) -> void:
	amount = maxi(amount, RAIN_MIN_AMOUNT)
	if _rain_amount == amount:
		return
	_rain_amount = amount
	rain_changed.emit(amount)
	_queue_save_settings()

## 设置雪量（下限 500），高频调整走防抖保存
func set_snow_amount(amount: int) -> void:
	amount = maxi(amount, SNOW_MIN_AMOUNT)
	if _snow_amount == amount:
		return
	_snow_amount = amount
	snow_changed.emit(amount)
	_queue_save_settings()

func get_time_mode() -> int:
	return _time_mode

func get_weather_mode() -> int:
	return _weather_mode

func get_rain_amount() -> int:
	return _rain_amount

func get_snow_amount() -> int:
	return _snow_amount

#func get_outdoor_1_state() -> int:
	#return 0

#func get_outdoor_2_state() -> int:
	#return 0

func get_fog_state() -> int:
	return _fog_state

## 设置 MSAA 并应用到视口、持久化
func set_msaa(mode: int) -> void:
	if _msaa == mode:
		return
	_msaa = mode
	get_viewport().msaa_3d = mode as Viewport.MSAA
	_save_settings()

## 设置 Screen Space AA 并应用到视口、持久化
func set_ssaa(mode: int) -> void:
	if _ssaa == mode:
		return
	_ssaa = mode
	get_viewport().screen_space_aa = mode as Viewport.ScreenSpaceAA
	_save_settings()

func set_camera(mode: int) -> void:
	if _camera_mode == mode:
		return
	_camera_mode = mode
	camera_changed.emit(mode)
	_save_settings()

func get_camera_mode() -> int:
	return _camera_mode

func set_ai_response_glow(enabled: bool) -> void:
	if _ai_response_glow == enabled:
		return
	_ai_response_glow = enabled
	ai_response_glow_changed.emit(enabled)
	_save_settings()

func get_ai_response_glow() -> bool:
	return _ai_response_glow

func get_msaa() -> int:
	return _msaa

func get_ssaa() -> int:
	return _ssaa

## 设置户外特效 1 开关状态
func set_outdoor_1(_state: int) -> void:
	# outdoor_1 功能暂时停用
	# if _outdoor_1_state == state:
	# 	return
	# _outdoor_1_state = state
	# outdoor_1_changed.emit(state)
	# _save_settings()
	pass

## 设置户外特效 2 开关状态
func set_outdoor_2(_state: int) -> void:
	# outdoor_2 功能暂时停用
	# if _outdoor_2_state == state:
	# 	return
	# _outdoor_2_state = state
	# outdoor_2_changed.emit(state)
	# _save_settings()
	pass

## 设置雾效开关状态
func set_fog(state: int) -> void:
	if _fog_state == state:
		return
	_fog_state = state
	fog_changed.emit(state)
	_save_settings()

## 立即写盘（离散操作）
func _save_settings() -> void:
	var config = ConfigFile.new()
	config.set_value("env", "time_mode", _time_mode)
	config.set_value("env", "weather_mode", _weather_mode)
	config.set_value("env", "rain_amount", _rain_amount)
	config.set_value("env", "snow_amount", _snow_amount)
	# outdoor_1/outdoor_2 功能暂时停用，不写入存档
	# config.set_value("env", "outdoor_1_state", _outdoor_1_state)
	# config.set_value("env", "outdoor_2_state", _outdoor_2_state)
	config.set_value("env", "fog_state", _fog_state)
	config.set_value("env", "camera_mode", _camera_mode)
	config.set_value("rendering", "msaa_3d", _msaa)
	config.set_value("rendering", "screen_space_aa", _ssaa)
	config.set_value("ai", "response_glow", _ai_response_glow)
	config.save(SAVE_PATH)

## 防抖写盘（滑条等高频操作）
func _queue_save_settings() -> void:
	if _save_timer and _save_timer.time_left > 0.0:
		return
	_save_timer = get_tree().create_timer(SAVE_DEBOUNCE_SEC)
	_save_timer.timeout.connect(_save_settings, CONNECT_ONE_SHOT)

## 读取本地配置；无配置时回退当前视口默认值并生成配置文件
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
	# outdoor_1/outdoor_2 功能已停用
	# _outdoor_1_state = int(config.get_value("env", "outdoor_1_state", 0))
	# _outdoor_2_state = int(config.get_value("env", "outdoor_2_state", 0))
	_fog_state = int(config.get_value("env", "fog_state", 0))
	_camera_mode = int(config.get_value("env", "camera_mode", 0))
	_msaa = int(config.get_value("rendering", "msaa_3d", 0))
	_ssaa = int(config.get_value("rendering", "screen_space_aa", 0))
	_ai_response_glow = config.get_value("ai", "response_glow", true) as bool
	get_viewport().msaa_3d = _msaa as Viewport.MSAA
	get_viewport().screen_space_aa = _ssaa as Viewport.ScreenSpaceAA

## 启动后统一广播当前状态，驱动 UI 首帧同步
func _emit_loaded_settings() -> void:
	env_time_changed.emit(_time_mode)
	env_weather_changed.emit(_weather_mode)
	rain_changed.emit(_rain_amount)
	snow_changed.emit(_snow_amount)
	# outdoor_1/outdoor_2 功能已停用（信号已注释）
	fog_changed.emit(_fog_state)
	camera_changed.emit(_camera_mode)
	ai_response_glow_changed.emit(_ai_response_glow)
