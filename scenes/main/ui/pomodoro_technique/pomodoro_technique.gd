extends PanelContainer

@onready var hh = $running/VBoxContainer/hh_mm_dd/hh
@onready var mm = $running/VBoxContainer/hh_mm_dd/mm
@onready var ss = $running/VBoxContainer/hh_mm_dd/ss

@onready var progress_bar = $MaterialProgressIndicator
@onready var loop_info = $idle/VBoxContainer/loop
@onready var work_info = $idle/VBoxContainer/HBoxContainer/work
@onready var rest_info = $idle/VBoxContainer/HBoxContainer/rest

@onready var loop_progress_label = $running/VBoxContainer/numbers         # n/N
@onready var status_label = $running/VBoxContainer/status                	# 工作中/休息中

@onready var idle_view = $idle
@onready var running_view = $running

# 信号定义
signal work_started()        
signal rest_started()        
signal work_completed()      
signal rest_completed()      
signal work_tick(remaining_seconds: int, total_seconds: int, progress: float)  
signal rest_tick(remaining_seconds: int, total_seconds: int, progress: float)  
signal loop_completed(current_loop: int, total_loops: int)  # 完成一个工作+休息循环
signal all_completed()  # 所有循环完成

# 配置参数（分钟）
@export var work_duration: int = 1    
@export var rest_duration: int = 1     

# 循环相关
var total_loops: int = 1       # 总循环次数
var current_loop: int = 1      # 当前循环（从1开始）

# 内部状态
var remaining_seconds: int = 0         
var current_mode_total: int = 0        
var is_running: bool = false
var is_work_mode: bool = true
var timer: Timer

func _ready() -> void:
	timer = Timer.new()
	timer.wait_time = 1.0
	timer.one_shot = false
	timer.timeout.connect(_on_timer_tick)
	add_child(timer)
	
	# 初始化显示
	_update_loop_display()
	_update_status_display()
	
	_idle_view()
	
func _running_view() -> void:
	idle_view.visible = false;
	running_view.visible = true;

func _idle_view() -> void:
	idle_view.visible = true;
	running_view.visible = false;


func _on_timer_tick() -> void:
	if remaining_seconds > 0:
		remaining_seconds -= 1
		_update_display()
		_emit_tick_signal()
	else:
		_on_timer_complete()

func _on_timer_complete() -> void:
	timer.stop()
	is_running = false
	
	if is_work_mode:
		work_completed.emit()
		# 工作完成，进入休息（同一次循环内）
		start_rest()
	else:
		rest_completed.emit()
		# 休息完成，检查是否继续下一个循环
		if current_loop < total_loops:
			current_loop += 1
			loop_completed.emit(current_loop, total_loops)
			_update_loop_display()
			# 开始下一个循环的工作
			is_work_mode = true
			start_work()
		else:
			# 所有循环完成
			all_completed.emit()
			print("番茄钟全部完成！")
			stop_timer()

func _emit_tick_signal() -> void:
	var progress = _get_progress()
	if is_work_mode:
		work_tick.emit(remaining_seconds, current_mode_total, progress)
	else:
		rest_tick.emit(remaining_seconds, current_mode_total, progress)

func _get_progress() -> float:
	if current_mode_total == 0:
		return 0.0
	return float(remaining_seconds) / float(current_mode_total)

# 更新循环显示 n/N
func _update_loop_display() -> void:
	if loop_progress_label:
		loop_progress_label.text = "%d/%d" % [current_loop, total_loops]

# 更新状态标签
func _update_status_display() -> void:
	if status_label:
		status_label.text = "工作中" if is_work_mode else "休息中"

# 开始工作倒计时
func start_work() -> void:
	is_work_mode = true
	current_mode_total = work_duration * 60
	remaining_seconds = current_mode_total
	is_running = true
	timer.start()
	_update_display()
	_update_status_display()
	work_started.emit()
	print("工作开始 [", current_loop, "/", total_loops, "]: ", work_duration, "分钟")

# 开始休息倒计时  
func start_rest() -> void:
	is_work_mode = false
	current_mode_total = rest_duration * 60
	remaining_seconds = current_mode_total
	is_running = true
	timer.start()
	_update_display()
	_update_status_display()
	rest_started.emit()
	print("休息开始 [", current_loop, "/", total_loops, "]: ", rest_duration, "分钟")

func toggle_pause() -> void:
	if is_running:
		timer.stop()
		is_running = false
	else:
		if remaining_seconds > 0:
			timer.start()
			is_running = true

func stop_timer() -> void:
	timer.stop()
	is_running = false
	is_work_mode = true  # 重置为工作模式
	remaining_seconds = 0
	_update_display()

# 更新显示和进度条
func _update_display() -> void:
	var hours = remaining_seconds / 3600
	var minutes = (remaining_seconds % 3600) / 60
	var seconds = remaining_seconds % 60
	
	hh.text = "%02d" % hours
	mm.text = "%02d" % minutes
	ss.text = "%02d" % seconds
	
	if progress_bar:
		progress_bar.set_progress_value(_get_progress())

# 设置时长
func set_work_duration(minutes: int) -> void:
	work_duration = minutes
	if not is_running and is_work_mode:
		current_mode_total = work_duration * 60
		remaining_seconds = current_mode_total
		_update_display()

func set_rest_duration(minutes: int) -> void:
	rest_duration = minutes
	if not is_running and not is_work_mode:
		current_mode_total = rest_duration * 60
		remaining_seconds = current_mode_total
		_update_display()

# 获取状态
func get_remaining_time() -> Dictionary:
	return {
		"hour": remaining_seconds / 3600,
		"minute": (remaining_seconds % 3600) / 60,
		"second": remaining_seconds % 60,
		"is_work_mode": is_work_mode,
		"current_loop": current_loop,
		"total_loops": total_loops
	}

func is_working() -> bool:
	return is_work_mode

func is_paused() -> bool:
	return not is_running and remaining_seconds > 0

func get_current_mode_progress() -> float:
	return _get_progress()

# 按钮回调
func _on_pause_button_state_changed(old_state: int, new_state: int) -> void:
	toggle_pause()

func _on_stop_button_pressed() -> void:
	stop_timer()
	_idle_view();
	
	print("计时器已停止")

# 启动番茄钟（带循环次数）
func pomodoro_start(_work_duration: int, _rest_duration: int, _loop_times: int) -> void:
	# 停止当前计时
	stop_timer()
	
	# 重置循环计数
	current_loop = 1
	total_loops = max(1, _loop_times)  # 至少1次循环
	
	# 设置时长
	work_duration = _work_duration
	rest_duration = _rest_duration
	
	# 更新显示
	_update_loop_display()
	
	# 开始第一个工作周期
	is_work_mode = true
	start_work()
	_running_view()

func _on_start_button_pressed() -> void:
	# 从UI获取参数启动
	pomodoro_start(work_info.times, rest_info.times, loop_info.times)


func _on_all_completed() -> void:
	_idle_view();
	pass # Replace with function body.
