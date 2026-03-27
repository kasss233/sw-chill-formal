class_name Main3d
extends Node3D
@export var time_of_day: TimeOfDay
@export var sky3d: Sky3D
@export var rain_particle: Node3D
@export var snow_particle: Node3D
@export var character: Character
@export var side_camera: Camera3D
@export var central_camera: Camera3D
@export var TIME_OF_DAYTIME: float = 8
@export var TIME_OF_DUSK: float = 17
@export var TIME_OF_EVENING: float = 21
@export var RAINY_LIGHT_ENERGY := 0.2
@export var SUNNY_LIGHT_ENERGY := 0.4
@export var rain: Node3D
@export var snow: Node3D
@export var planet: Node3D
@export var window_side: Node3D
@export var side_desk: Node3D
@export var skybox: Node3D
@export var on_desk: Node3D
var _is_saying: bool = false

func _ready() -> void:
	# 在编辑器模式下不初始化，避免信号连接错误
	if Engine.is_editor_hint():
		return
	
	_connect_signals()
	_init_time()
	_init_weather()


func _input(event: InputEvent) -> void:
	# 小键盘 4 快捷键：播放招手动作
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_KP_4:
			get_tree().root.set_input_as_handled()
			if character:
				character.set_greet_pose()
		elif event.keycode == KEY_KP_5:
			# 小键盘 5 快捷键：切换说话状态
			get_tree().root.set_input_as_handled()
			if character:
				_is_saying = !_is_saying
				if _is_saying:
					character.set_saying()
				else:
					character.set_neutral()
	

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
	if SettingState and SettingState.has_signal("rain_changed"):
		if not SettingState.rain_changed.is_connected(_on_rain_amount_changed):
			SettingState.rain_changed.connect(_on_rain_amount_changed)
	if SettingState and SettingState.has_signal("snow_changed"):
		if not SettingState.snow_changed.is_connected(_on_snow_amount_changed):
			SettingState.snow_changed.connect(_on_snow_amount_changed)
	#if SettingState and SettingState.has_signal("outdoor_1_changed"):
		#if not SettingState.outdoor_1_changed.is_connected(_on_out_door_1_button_state_changed):
			#SettingState.outdoor_1_changed.connect(_on_out_door_1_button_state_changed)
	#if SettingState and SettingState.has_signal("outdoor_2_changed"):
		#if not SettingState.outdoor_2_changed.is_connected(_on_out_door_2_button_state_changed):
			#SettingState.outdoor_2_changed.connect(_on_out_door_2_button_state_changed)
	## fog
	if SettingState and SettingState.has_signal("fog_changed"):
		if not SettingState.fog_changed.is_connected(_on_fog_button_state_changed):
			SettingState.fog_changed.connect(_on_fog_button_state_changed)
	if SettingState and SettingState.has_signal("camera_changed"):
		if not SettingState.camera_changed.is_connected(_on_camera_changed):
			SettingState.camera_changed.connect(_on_camera_changed)
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
	if RoomDecorState and RoomDecorState.has_signal("room_decor_selected"):
		if not RoomDecorState.room_decor_selected.is_connected(_on_room_decor_selected):
			RoomDecorState.room_decor_selected.connect(_on_room_decor_selected)
	## signal room_decor_category_unselected(category: String)
	if RoomDecorState and RoomDecorState.has_signal("room_decor_category_unselected"):
		if not RoomDecorState.room_decor_category_unselected.is_connected(_on_room_decor_category_unselected):
			RoomDecorState.room_decor_category_unselected.connect(_on_room_decor_category_unselected)
	if DialogueState and DialogueState.has_signal("dialogue_started"):
		if not DialogueState.dialogue_started.is_connected(_on_dialogue_started):
			DialogueState.dialogue_started.connect(_on_dialogue_started)
	if DialogueState and DialogueState.has_signal("dialogue_finished"):
		if not DialogueState.dialogue_finished.is_connected(_on_dialogue_finished):
			DialogueState.dialogue_finished.connect(_on_dialogue_finished)
	if DialogueState and DialogueState.has_signal("function_executing"):
		if not DialogueState.function_executing.is_connected(_on_function_executing):
			DialogueState.function_executing.connect(_on_function_executing)
	if DialogueState and DialogueState.has_signal("function_completed"):
		if not DialogueState.function_completed.is_connected(_on_function_completed):
			DialogueState.function_completed.connect(_on_function_completed)
func _init_weather():
	set_env_weather_sunny()
func _init_time():
	time_of_day.system_sync = false
	time_of_day.game_time_enabled = false
	time_of_day.current_time = TIME_OF_DAYTIME

func set_camera_fov(_fov: int):
	side_camera.fov = _fov
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
## 设置粒子
func set_rain_amount(amount: int):
	if rain and rain.has_method("set_amount"):
		rain.call("set_amount", amount)
func set_snow_amount(amount: int):
	if snow and snow.has_method("set_amount"):
		snow.call("set_amount", amount)
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
func _on_rain_amount_changed(amount: int) -> void:
	set_rain_amount(amount)
func _on_snow_amount_changed(amount: int) -> void:
	set_snow_amount(amount)
#func _on_out_door_1_button_state_changed(state: int) -> void:
	#if state == 0:
		#cherry_blossom.visible = true
	#elif state == 1:
		#cherry_blossom.visible = false
#func _on_out_door_2_button_state_changed(state: int) -> void:
	#if state == 0:
		#planet.visible = true
	#elif state == 1:
		#planet.visible = false
func _on_fog_button_state_changed(state: int) -> void:
	if state == 0:
		sky3d.fog_enabled = true
	elif state == 1:
		sky3d.fog_enabled = false
func _on_room_decor_selected(item_name: String, item_category: String) -> void:
	print("Selected decor item: %s (Category: %s)" % [item_name, item_category])
	if item_category == "星球":
		match item_name:
			"黑洞":
				planet.call("show_black_hole")
			"紫色星球":
				planet.call("show_purple_planet")
			"火星":
				planet.call("show_fire_planet")
	if item_category == "窗边":
		match item_name:
			"樱花树":
				window_side.call("show_cherry")
			"鲸鱼":
				window_side.call("show_whale")
	if item_category == "侧柜":
		match item_name:
			"猫":
				side_desk.call("show_cat")
			"花":
				side_desk.call("show_flowers")
	if item_category == "wall":
		match item_name:
			pass
	if item_category == "桌搭":
		match item_name:
			"闹钟":
				on_desk.call("show_alarm_clock")
			"夜灯":
				on_desk.call("show_night_light")
	if item_category == "天空盒":
		match item_name:
			"海上":
				skybox.call("show_sea")
			"宇宙":
				skybox.call("show_universe")
			"雪山":
				skybox.call("show_snow")
func _on_room_decor_category_unselected(category: String) -> void:
	print("Unselected decor category: %s" % category)
	match category:
		"星球":
			planet.call("hide_all")
		"窗边":
			window_side.call("hide_all")
		"侧柜":
			side_desk.call("hide_all")
		"桌搭":
			on_desk.call("hide_all")
		"天空盒":
			skybox.call("hide_all")

func _on_camera_changed(value: int) -> void:
	## 输出调试信息
	print("Cameramodechangedto: %d" % value)
	match value:
		0:
			side_camera.current = true
		1:
			central_camera.current = true
func _on_dialogue_started(text: String) -> void:
	print("[main3d]Dialoguestarted, textlength: %d" % text.length())
	character.set_saying()
	# 根据文本长度调整说话动画持续时间，最长不超过5秒
	var duration = min(2.0 + text.length() * 0.03, 5.0)
	var tween = create_tween()
	tween.tween_interval(duration)
	tween.tween_callback(character.set_neutral)
func _on_dialogue_finished() -> void:
	print("[main3d]Dialoguefinished")


func _on_function_executing(func_name: String, call_id: String) -> void:
	print("[main3d]Functionexecuting: %s(id: %s)" % [func_name, call_id])
	character.set_typing_pose()


func _on_function_completed(func_name: String, call_id: String, success: bool) -> void:
	print("[main3d]Functioncompleted: %s(id: %s, success: %s)" % [func_name, call_id, success])
	character.set_idle_pose()
