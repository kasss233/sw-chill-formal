extends Node
@export var time_of_day: TimeOfDay
@export var sky3d:Sky3D
@export var rain_particle:Node3D
@export var TIME_OF_DAYTIME := 8
@export var TIME_OF_DUSK := 17
@export var TIME_OF_EVENING := 21
@export var RAINY_LIGHT_ENERGY:=0.1
@export var SUNNY_LIGHT_ENERGY:=0.7
func _ready() -> void:
	_init_time()
	_init_weather()
func _init_weather():
	set_sunny()
func _init_time():
	time_of_day.system_sync=false
	time_of_day.game_time_enabled=false
	time_of_day.current_time=TIME_OF_DAYTIME
func _on_ui_env_time_changed(mode: int) -> void:
	match mode:
		0:
			time_of_day.system_sync=false
			time_of_day.game_time_enabled=false
			time_of_day.current_time = TIME_OF_DAYTIME
		1:	
			time_of_day.system_sync=false
			time_of_day.game_time_enabled=false
			time_of_day.current_time = TIME_OF_DUSK
		2:	
			time_of_day.system_sync=false
			time_of_day.game_time_enabled=false
			time_of_day.current_time = TIME_OF_EVENING
		3:	
			time_of_day.game_time_enabled=true
			time_of_day.system_sync=true
func set_rain():
	sky3d.sky_enabled=false
	rain_particle.visible=true
	sky3d.sun_energy=RAINY_LIGHT_ENERGY
func set_sunny():
	sky3d.sky_enabled=true
	rain_particle.visible=false
	sky3d.sun_energy=SUNNY_LIGHT_ENERGY


func _on_ui_env_weather_changed(mode: int) -> void:
	match mode:
		0:
			set_sunny()
		1:
			set_rain()
