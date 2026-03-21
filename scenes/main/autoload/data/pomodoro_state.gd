extends Node

## 番茄钟状态管理单例（Data Autoload）
## 完整的倒计时逻辑、工作/休息阶段切换、循环管理
## 配置持久化到 user://pomodoro_config.json

# --- UI 通知信号 ---
signal pomodoro_started(data: Dictionary)
signal work_phase_stopped
signal work_phase_paused
signal work_phase_continued
signal work_phase_started
signal work_phase_completed
signal rest_phase_stopped
signal rest_phase_paused
signal rest_phase_continued
signal rest_phase_started
signal rest_phase_completed
signal tick(remaining_seconds: int, total_seconds: int, progress: float, is_work_mode: bool)
signal loop_completed(current_loop: int, total_loops: int)
signal all_completed
signal config_changed(work_duration: int, rest_duration: int)
signal data_loaded

# --- 配置参数（分钟，持久化）---
var work_duration: int = 25
var rest_duration: int = 5

# --- 运行时状态（不持久化）---
var total_loops: int = 1
var current_loop: int = 1
var remaining_seconds: int = 0
var current_mode_total: int = 0
var is_running: bool = false
var is_work_mode: bool = true
var _timer: Timer = null

const CONFIG_PATH = "user://pomodoro_config.json"
const SAVE_DEBOUNCE_SEC := 0.5
var _save_config_timer: SceneTreeTimer


func _ready() -> void:
	_timer = Timer.new()
	_timer.wait_time = 1.0
	_timer.one_shot = false
	_timer.timeout.connect(_on_timer_tick)
	add_child(_timer)
	_load_config()
	data_loaded.emit()
	print("[PomodoroState] 初始化完成 (工作: %d分钟, 休息: %d分钟)" % [work_duration, rest_duration])


# ======================== 用户 API ========================

func start_pomodoro(work_min: int, rest_min: int, loops: int) -> void:
	if is_active():
		stop()
	work_duration = max(1, work_min)
	rest_duration = max(1, rest_min)
	total_loops = max(1, loops)
	current_loop = 1
	_queue_save_config()
	_start_work()
	pomodoro_started.emit({
		"work_duration": work_duration,
		"rest_duration": rest_duration,
		"total_loops": total_loops
	})


func toggle_pause() -> void:
	if is_running:
		_timer.stop()
		is_running = false
		if is_work_mode:
			work_phase_paused.emit()
		else:
			rest_phase_paused.emit()
	elif remaining_seconds > 0:
		_timer.start()
		is_running = true
		if is_work_mode:
			work_phase_continued.emit()
		else:
			rest_phase_continued.emit()


func stop() -> void:
	_timer.stop()
	var was_work_mode = is_work_mode
	_reset_state()
	print("[PomodoroState] 已停止")
	if was_work_mode:
		work_phase_stopped.emit()
	else:
		rest_phase_stopped.emit()


func set_work_duration(minutes: int) -> void:
	work_duration = max(1, minutes)
	_queue_save_config()
	config_changed.emit(work_duration, rest_duration)


func set_rest_duration(minutes: int) -> void:
	rest_duration = max(1, minutes)
	_queue_save_config()
	config_changed.emit(work_duration, rest_duration)


# ======================== 查询 API ========================

func get_status() -> Dictionary:
	return {
		"is_running": is_running,
		"is_paused": is_paused(),
		"is_work_mode": is_work_mode,
		"current_loop": current_loop,
		"total_loops": total_loops,
		"work_duration": work_duration,
		"rest_duration": rest_duration,
		"remaining_seconds": remaining_seconds,
		"total_seconds": current_mode_total,
		"progress": get_progress()
	}


func get_remaining_time() -> Dictionary:
	return {
		"hour": remaining_seconds / 3600,
		"minute": (remaining_seconds % 3600) / 60,
		"second": remaining_seconds % 60,
		"is_work_mode": is_work_mode,
		"current_loop": current_loop,
		"total_loops": total_loops
	}


func get_progress() -> float:
	if current_mode_total == 0:
		return 0.0
	return float(remaining_seconds) / float(current_mode_total)


func is_active() -> bool:
	return is_running or remaining_seconds > 0


func is_paused() -> bool:
	return not is_running and remaining_seconds > 0


func is_in_work_mode() -> bool:
	return is_work_mode


# ======================== Agent API ========================

func agent_start_pomodoro(work_min: int, rest_min: int, loops: int = 1) -> bool:
	work_min = max(1, work_min)
	rest_min = max(1, rest_min)
	loops = max(1, loops)
	start_pomodoro(work_min, rest_min, loops)
	print("[PomodoroState] Agent启动番茄钟: 工作%d分钟, 休息%d分钟, %d次循环" % [work_min, rest_min, loops])
	return true


func agent_stop() -> bool:
	stop()
	print("[PomodoroState] Agent停止番茄钟")
	return true


func agent_toggle_pause() -> bool:
	if not is_active():
		print("[PomodoroState] 番茄钟未运行，无法暂停/继续")
		return false
	toggle_pause()
	var status_text = "暂停" if is_paused() else "继续"
	print("[PomodoroState] Agent%s番茄钟" % status_text)
	return true


func agent_set_work_duration(minutes: int) -> bool:
	if minutes < 1:
		return false
	set_work_duration(minutes)
	print("[PomodoroState] Agent设置工作时间: %d分钟" % minutes)
	return true


func agent_set_rest_duration(minutes: int) -> bool:
	if minutes < 1:
		return false
	set_rest_duration(minutes)
	print("[PomodoroState] Agent设置休息时间: %d分钟" % minutes)
	return true


func agent_get_status() -> Dictionary:
	return get_status()


func agent_get_remaining_time() -> Dictionary:
	return get_remaining_time()


func agent_is_running() -> bool:
	return is_running


func agent_is_paused() -> bool:
	return is_paused()


func agent_is_work_mode() -> bool:
	return is_work_mode


# ======================== 内部逻辑 ========================

func _on_timer_tick() -> void:
	remaining_seconds -= 1
	var progress = get_progress()
	tick.emit(remaining_seconds, current_mode_total, progress, is_work_mode)
	if remaining_seconds <= 0:
		_on_phase_complete()


func _on_phase_complete() -> void:
	_timer.stop()
	is_running = false
	if is_work_mode:
		work_phase_completed.emit()
		if current_loop < total_loops:
			_start_rest()
		else:
			# 最后一个循环的工作完成，番茄钟结束（不再进入休息）
			all_completed.emit()
			print("[PomodoroState] 番茄钟全部完成！")
			_reset_state()
	else:
		rest_phase_completed.emit()
		current_loop += 1
		loop_completed.emit(current_loop, total_loops)
		_start_work()


func _start_work() -> void:
	is_work_mode = true
	current_mode_total = work_duration * 60
	remaining_seconds = current_mode_total
	is_running = true
	_timer.start()
	work_phase_started.emit()
	tick.emit(remaining_seconds, current_mode_total, get_progress(), is_work_mode)
	print("[PomodoroState] 工作开始 [%d/%d]: %d分钟" % [current_loop, total_loops, work_duration])


func _start_rest() -> void:
	is_work_mode = false
	current_mode_total = rest_duration * 60
	remaining_seconds = current_mode_total
	is_running = true
	_timer.start()
	rest_phase_started.emit()
	tick.emit(remaining_seconds, current_mode_total, get_progress(), is_work_mode)
	print("[PomodoroState] 休息开始 [%d/%d]: %d分钟" % [current_loop, total_loops, rest_duration])


func _reset_state() -> void:
	is_running = false
	is_work_mode = true
	remaining_seconds = 0
	current_mode_total = 0
	current_loop = 1
	total_loops = 1


# ======================== 持久化 ========================

func _queue_save_config() -> void:
	if _save_config_timer and _save_config_timer.time_left > 0.0:
		return
	_save_config_timer = get_tree().create_timer(SAVE_DEBOUNCE_SEC)
	_save_config_timer.timeout.connect(_save_config, CONNECT_ONE_SHOT)

func _save_config() -> void:
	var data = {
		"version": 1,
		"work_duration": work_duration,
		"rest_duration": rest_duration
	}
	var json_string = JSON.stringify(data, "\t")
	var file = FileAccess.open(CONFIG_PATH, FileAccess.WRITE)
	if file:
		file.store_string(json_string)
		file.close()
	else:
		push_error("[PomodoroState] 保存配置失败: %s" % CONFIG_PATH)


func _load_config() -> void:
	if not FileAccess.file_exists(CONFIG_PATH):
		print("[PomodoroState] 无配置文件，使用默认值")
		return
	var file = FileAccess.open(CONFIG_PATH, FileAccess.READ)
	if not file:
		push_error("[PomodoroState] 读取配置失败")
		return
	var json_string = file.get_as_text()
	file.close()
	var json = JSON.new()
	var error = json.parse(json_string)
	if error != OK:
		push_error("[PomodoroState] 配置解析失败: %s" % json.get_error_message())
		return
	var data = json.get_data()
	if not data is Dictionary:
		push_error("[PomodoroState] 配置格式无效")
		return
	work_duration = data.get("work_duration", 25)
	rest_duration = data.get("rest_duration", 5)
	print("[PomodoroState] 已加载配置: 工作%d分钟, 休息%d分钟" % [work_duration, rest_duration])
