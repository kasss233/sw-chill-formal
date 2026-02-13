class_name Main3d
extends Node3D
@export var time_of_day: TimeOfDay
@export var sky3d: Sky3D
@export var rain_particle: Node3D
@export var snow_particle: Node3D
@export var character: Character
@export var camera: Camera3D
@export var TIME_OF_DAYTIME: float = 8
@export var TIME_OF_DUSK: float = 17
@export var TIME_OF_EVENING: float = 21
@export var RAINY_LIGHT_ENERGY := 0.2
@export var SUNNY_LIGHT_ENERGY := 0.7

func _ready() -> void:
	# 在编辑器模式下不初始化，避免信号连接错误
	if Engine.is_editor_hint():
		return
	
	_connect_signals()
	_init_time()
	_init_weather()

func _connect_signals() -> void:
	# 从 State 单例连接信号，而不是从场景文件连接
	if CharacterInteractorState and CharacterInteractorState.has_signal("character_interacted"):
		if not CharacterInteractorState.character_interacted.is_connected(_on_character_interacted):
			CharacterInteractorState.character_interacted.connect(_on_character_interacted)
	
	if SettingState and SettingState.has_signal("env_time_changed"):
		if not SettingState.env_time_changed.is_connected(_on_env_time_changed):
			SettingState.env_time_changed.connect(_on_env_time_changed)
	
	if SettingState and SettingState.has_signal("env_weather_changed"):
		if not SettingState.env_weather_changed.is_connected(_on_env_weather_changed):
			SettingState.env_weather_changed.connect(_on_env_weather_changed)
	
	if PomodoroState and PomodoroState.has_signal("work_phase_started"):
		if not PomodoroState.work_phase_started.is_connected(_on_work_phase_started):
			PomodoroState.work_phase_started.connect(_on_work_phase_started)
	
	if PomodoroState and PomodoroState.has_signal("work_phase_completed"):
		if not PomodoroState.work_phase_completed.is_connected(_on_work_phase_completed):
			PomodoroState.work_phase_completed.connect(_on_work_phase_completed)
	
	if PomodoroState and PomodoroState.has_signal("work_phase_paused"):
		if not PomodoroState.work_phase_paused.is_connected(_on_work_phase_paused):
			PomodoroState.work_phase_paused.connect(_on_work_phase_paused)
	
	if PomodoroState and PomodoroState.has_signal("work_phase_stopped"):
		if not PomodoroState.work_phase_stopped.is_connected(_on_work_phase_stopped):
			PomodoroState.work_phase_stopped.connect(_on_work_phase_stopped)
	
	if PomodoroState and PomodoroState.has_signal("work_phase_continued"):
		if not PomodoroState.work_phase_continued.is_connected(_on_work_phase_continued):
			PomodoroState.work_phase_continued.connect(_on_work_phase_continued)
	if TaskState and TaskState.has_signal("task_completed"):
		if not TaskState.task_completed.is_connected(_on_task_completed):
			TaskState.task_completed.connect(_on_task_completed)
func _init_weather():
	set_env_weather_sunny()
func _init_time():
	time_of_day.system_sync = false
	time_of_day.game_time_enabled = false
	time_of_day.current_time = TIME_OF_DAYTIME

func set_camera_fov(_fov: int):
	camera.fov = _fov
	pass
## 切换天气,0:晴天,1:雨天,2:雪天,3:同步
func set_env_weather_rain():
	rain_particle.visible = true
	snow_particle.visible = false
	sky3d.sun_energy = RAINY_LIGHT_ENERGY
func set_env_weather_sunny():
	rain_particle.visible = false
	snow_particle.visible = false
	sky3d.sun_energy = SUNNY_LIGHT_ENERGY
func set_env_weather_snowy():
	snow_particle.visible = true
	rain_particle.visible = false
	sky3d.sun_energy = RAINY_LIGHT_ENERGY
	pass
func set_env_weather_sync():
	set_env_weather_sunny()

var time_tween: Tween
func _animate_time(target_time: float):
	if time_tween:
		time_tween.kill()
	
	time_of_day.system_sync = false
	time_of_day.game_time_enabled = false
	
	time_tween = create_tween()
	time_tween.set_ease(Tween.EASE_IN_OUT)
	time_tween.set_trans(Tween.TRANS_SINE)
	time_tween.tween_property(time_of_day, "current_time", target_time, 2.0)
func set_env_time_daytime():
	_animate_time(TIME_OF_DAYTIME)
func set_env_time_dusk():
	_animate_time(TIME_OF_DUSK)
func set_env_time_evening():
	_animate_time(TIME_OF_EVENING)
func set_env_time_sync():
	if time_tween:
		time_tween.kill()
	# 获取系统时间
	var now = Time.get_datetime_dict_from_system()
	var hour = now.hour + now.minute / 60.0
	_animate_time(hour)
	await time_tween.finished
	time_of_day.game_time_enabled = true
	time_of_day.system_sync = true
## --- UI 信号回调 ---
func _on_env_time_changed(mode: int) -> void:
	match mode:
		0:
			set_env_time_daytime()
		1:
			set_env_time_dusk()
		2:
			set_env_time_evening()
		3:
			set_env_time_sync()
func _on_env_weather_changed(mode: int) -> void:
	match mode:
		0:
			set_env_weather_sunny()
		1:
			set_env_weather_rain()
		2:
			set_env_weather_snowy()
		3:
			set_env_weather_sync()

func _on_character_interacted() -> void:
	character.set_surprised_pose()
func _on_work_phase_completed() -> void:
	character.set_idle_pose()


func _on_work_phase_started() -> void:
	character.set_typing_pose()


func _on_work_phase_paused() -> void:
	character.set_idle_pose()


func _on_work_phase_stopped() -> void:
	character.set_idle_pose()


func _on_work_phase_continued() -> void:
	character.set_typing_pose()
func _on_task_completed() -> void:
	character.set_cheer_pose()
