extends Node

# ===== 配置 =====
var log_interval := 0.5 # 记录间隔（秒）
var file_name := "user://performance.csv"

# ===== 内部变量 =====
var _file: FileAccess
var _time_passed := 0.0
var _timer := 0.0

func _ready():
	# 打开文件
	_file = FileAccess.open(file_name, FileAccess.WRITE)
	
	# 写表头
	_file.store_line("time,fps,frame_time(ms),memory(MB),draw_calls,objects")
	
	print("Performance Logger started → ", file_name)

func _process(delta):
	_time_passed += delta
	_timer += delta

	if _timer >= log_interval:
		_timer = 0.0
		_log_data()

func _log_data():
	var fps = Performance.get_monitor(Performance.TIME_FPS)
	var frame_time = Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
	
	var memory = Performance.get_monitor(Performance.MEMORY_STATIC) / (1024.0 * 1024.0)
	
	var draw_calls = Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	var objects = Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)

	var line = "%f,%d,%f,%f,%d,%d" % [
		_time_passed,
		fps,
		frame_time,
		memory,
		draw_calls,
		objects
	]

	_file.store_line(line)

func _notification(what):
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_close_file()

func _exit_tree():
	_close_file()

func _close_file():
	if _file:
		_file.flush()
		_file.close()
		print("Performance Logger saved → ", file_name)
