extends Node
@export var time_of_day: TimeOfDay
@export var sky3d: Sky3D
@export var rain_particle: Node3D
@export var snow_particle: Node3D
@export var character: Character
@export var TIME_OF_DAYTIME: float = 8
@export var TIME_OF_DUSK: float = 17
@export var TIME_OF_EVENING: float = 21
@export var RAINY_LIGHT_ENERGY := 0.2
@export var SUNNY_LIGHT_ENERGY := 0.7
@export_category("项目演示")
@export var animation_player: AnimationPlayer
@export var snack_bar:MaterialSnackbar
@onready var ui: UI = $UI
@onready var ui_mobile: UI = $UI_mobile
func _ready() -> void:
	_init_ui()
	_init_time()
	_init_weather() 
func _init_weather():
	set_env_weather_sunny()
func _init_time():
	time_of_day.system_sync = false
	time_of_day.game_time_enabled = false
	time_of_day.current_time = TIME_OF_DAYTIME
#这里根据设备切换ui，视口
#TODO:判断手机pad
func _init_ui():
	if OS.has_feature("mobile"):
	#if OS.has_feature("pc"):
		get_window().size = Vector2i(648, 1152) 
		get_window().content_scale_size = Vector2i(648, 1152)
		get_tree().root.content_scale_factor = 1.8
		ui.queue_free()
		ui_mobile.visible = true
		return
	if OS.has_feature("pc"):
		ui_mobile.queue_free()
		ui.visible = true
		return
	
	
		
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
func _on_ui_env_time_changed(mode: int) -> void:
	match mode:
		0:
			set_env_time_daytime()
		1:
			set_env_time_dusk()
		2:
			set_env_time_evening()
		3:
			set_env_time_sync()
func _on_ui_env_weather_changed(mode: int) -> void:
	match mode:
		0:
			set_env_weather_sunny()
		1:
			set_env_weather_rain()
		2:
			set_env_weather_snowy()
		3:
			set_env_weather_sync()

var cur_pose = 4;
func _on_ui_character_interacted() -> void:
	# rand2
	#var rand = randi() % 7
	match cur_pose:
		0:
			character.set_watch_pose()
		1:
			character.set_dodge_pose()
		2:
			character.set_laughing_pose()
		3:
			character.set_clap_pose()
		4:
			character.set_cheer_pose()
		5:
			character.set_angry_pose()
		6:
			character.set_disbelief_pose()
	#cur_pose = (cur_pose + 1) % 7


func _on_ui_work_completed() -> void:
	character.set_typing_pose(false)


func _on_ui_work_started() -> void:
	character.set_typing_pose(true)


func _on_ui_work_paused() -> void:
	character.set_typing_pose(false)


func _on_ui_work_stopped() -> void:
	character.set_typing_pose(false)


func _on_ui_work_continued() -> void:
	character.set_typing_pose(true)


func _on_ui_text_submitted() -> void:
	#snack_bar.display_position = MaterialSnackbar.POS_TOP_CENTER
	snack_bar.show_warning("DEMO未连接服务器，agent暂不可用")
