extends Node
@export var time_of_day: TimeOfDay
@export var TIME_OF_DAYTIME := 8
@export var TIME_OF_DUSK := 17
@export var TIME_OF_EVENING := 21
func _ready() -> void:
	_init_time()
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
