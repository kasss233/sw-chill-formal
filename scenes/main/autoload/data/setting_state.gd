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
## 3D 渲染分辨率缩放变化
signal render_scale_changed(scale: float)
## AI 回复流光开关变化
signal ai_response_glow_changed(enabled: bool)
## 麦克风设备变化
signal audio_input_device_changed(device_name: String)
## 扬声器设备变化
signal audio_output_device_changed(device_name: String)
## 录音后回放开关变化
signal talk_record_preview_changed(enabled: bool)
## 环境雨声音量变化（0-100）
signal rain_sound_volume_changed(value: int)
## 环境风声音量变化（0-100）
signal wind_sound_volume_changed(value: int)
## 环境车声音量变化（0-100）
signal car_sound_volume_changed(value: int)
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
## 3D 渲染分辨率缩放（0.5-1.0）
var _render_scale: float = 1.0
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
## 当前麦克风设备名称
var _audio_input_device: String = ""
## 当前扬声器设备名称
var _audio_output_device: String = ""
## 是否播放录音回放（便于调试）
var _talk_record_preview_enabled: bool = true
## 环境雨声音量（0-100）
var _rain_sound_volume: int = 50
## 环境风声音量（0-100）
var _wind_sound_volume: int = 50
## 环境车声音量（0-100）
var _car_sound_volume: int = 50


const SAVE_PATH = "user://settings.cfg"
const SAVE_DEBOUNCE_SEC := 0.25
const RAIN_MIN_AMOUNT := 300
const SNOW_MIN_AMOUNT := 500
const RENDER_SCALE_MIN := 0.5
const RENDER_SCALE_MAX := 1.0

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


## 设置 3D 渲染分辨率缩放并立即应用到视口
func set_render_scale(scale: float) -> void:
	scale = clampf(scale, RENDER_SCALE_MIN, RENDER_SCALE_MAX)
	if is_equal_approx(_render_scale, scale):
		return
	_render_scale = scale
	get_viewport().scaling_3d_scale = _render_scale
	render_scale_changed.emit(_render_scale)
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


func get_audio_input_device_list() -> PackedStringArray:
	return AudioServer.get_input_device_list()


func get_audio_output_device_list() -> PackedStringArray:
	return AudioServer.get_output_device_list()


func set_audio_input_device(device_name: String) -> bool:
	var devices := AudioServer.get_input_device_list()
	if not devices.has(device_name):
		return false
	if _audio_input_device == device_name:
		return true
	_audio_input_device = device_name
	AudioServer.set_input_device(device_name)
	audio_input_device_changed.emit(device_name)
	_save_settings()
	return true


func set_audio_output_device(device_name: String) -> bool:
	var devices := AudioServer.get_output_device_list()
	if not devices.has(device_name):
		return false
	if _audio_output_device == device_name:
		return true
	_audio_output_device = device_name
	AudioServer.set_output_device(device_name)
	audio_output_device_changed.emit(device_name)
	_save_settings()
	return true


func get_audio_input_device() -> String:
	return _audio_input_device


func get_audio_output_device() -> String:
	return _audio_output_device


func set_talk_record_preview_enabled(enabled: bool) -> void:
	if _talk_record_preview_enabled == enabled:
		return
	_talk_record_preview_enabled = enabled
	talk_record_preview_changed.emit(enabled)
	_save_settings()


func get_talk_record_preview_enabled() -> bool:
	return _talk_record_preview_enabled


func set_rain_sound_volume(value: int) -> void:
	value = clampi(value, 0, 100)
	if _rain_sound_volume == value:
		return
	_rain_sound_volume = value
	rain_sound_volume_changed.emit(value)
	_queue_save_settings()


func set_wind_sound_volume(value: int) -> void:
	value = clampi(value, 0, 100)
	if _wind_sound_volume == value:
		return
	_wind_sound_volume = value
	wind_sound_volume_changed.emit(value)
	_queue_save_settings()


func set_car_sound_volume(value: int) -> void:
	value = clampi(value, 0, 100)
	if _car_sound_volume == value:
		return
	_car_sound_volume = value
	car_sound_volume_changed.emit(value)
	_queue_save_settings()


func get_rain_sound_volume() -> int:
	return _rain_sound_volume


func get_wind_sound_volume() -> int:
	return _wind_sound_volume


func get_car_sound_volume() -> int:
	return _car_sound_volume

func get_ai_response_glow() -> bool:
	return _ai_response_glow

func get_msaa() -> int:
	return _msaa

func get_ssaa() -> int:
	return _ssaa


func get_render_scale() -> float:
	return _render_scale

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
	config.set_value("rendering", "scale_3d", _render_scale)
	config.set_value("ai", "response_glow", _ai_response_glow)
	config.set_value("audio", "input_device", _audio_input_device)
	config.set_value("audio", "output_device", _audio_output_device)
	config.set_value("audio", "talk_record_preview", _talk_record_preview_enabled)
	config.set_value("audio", "rain_sound_volume", _rain_sound_volume)
	config.set_value("audio", "wind_sound_volume", _wind_sound_volume)
	config.set_value("audio", "car_sound_volume", _car_sound_volume)
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
		_render_scale = clampf(vp.scaling_3d_scale, RENDER_SCALE_MIN, RENDER_SCALE_MAX)
		_audio_input_device = AudioServer.get_input_device()
		_audio_output_device = AudioServer.get_output_device()
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
	_render_scale = clampf(float(config.get_value("rendering", "scale_3d", get_viewport().scaling_3d_scale)), RENDER_SCALE_MIN, RENDER_SCALE_MAX)
	_ai_response_glow = config.get_value("ai", "response_glow", true) as bool
	_audio_input_device = str(config.get_value("audio", "input_device", AudioServer.get_input_device()))
	_audio_output_device = str(config.get_value("audio", "output_device", AudioServer.get_output_device()))
	_talk_record_preview_enabled = bool(config.get_value("audio", "talk_record_preview", true))
	_rain_sound_volume = clampi(int(config.get_value("audio", "rain_sound_volume", 50)), 0, 100)
	_wind_sound_volume = clampi(int(config.get_value("audio", "wind_sound_volume", 50)), 0, 100)
	_car_sound_volume = clampi(int(config.get_value("audio", "car_sound_volume", 50)), 0, 100)
	get_viewport().msaa_3d = _msaa as Viewport.MSAA
	get_viewport().screen_space_aa = _ssaa as Viewport.ScreenSpaceAA
	get_viewport().scaling_3d_scale = _render_scale

	# 回放并应用存档中的音频设备；设备不存在时保持当前系统默认
	if AudioServer.get_input_device_list().has(_audio_input_device):
		AudioServer.set_input_device(_audio_input_device)
	else:
		_audio_input_device = AudioServer.get_input_device()

	if AudioServer.get_output_device_list().has(_audio_output_device):
		AudioServer.set_output_device(_audio_output_device)
	else:
		_audio_output_device = AudioServer.get_output_device()

## 启动后统一广播当前状态，驱动 UI 首帧同步
func _emit_loaded_settings() -> void:
	env_time_changed.emit(_time_mode)
	env_weather_changed.emit(_weather_mode)
	rain_changed.emit(_rain_amount)
	snow_changed.emit(_snow_amount)
	# outdoor_1/outdoor_2 功能已停用（信号已注释）
	fog_changed.emit(_fog_state)
	camera_changed.emit(_camera_mode)
	render_scale_changed.emit(_render_scale)
	ai_response_glow_changed.emit(_ai_response_glow)
	audio_input_device_changed.emit(_audio_input_device)
	audio_output_device_changed.emit(_audio_output_device)
	talk_record_preview_changed.emit(_talk_record_preview_enabled)
	rain_sound_volume_changed.emit(_rain_sound_volume)
	wind_sound_volume_changed.emit(_wind_sound_volume)
	car_sound_volume_changed.emit(_car_sound_volume)
