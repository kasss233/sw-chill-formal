class_name PomodoroTechniqueModule
extends Control
## UI 引用（用于层级管理）
@export var _ui: UI = null

@onready var canvas_layer: CanvasLayer = $CanvasLayer
@onready var pomodoro_technique = $CanvasLayer/PomodoroTechnique
@onready var pomodoro_button = $pomodoro_button


func _ready() -> void:
	pomodoro_technique.visible = false
	# 设置 CanvasLayer 的初始层级
	canvas_layer.layer = 10
	# 连接 pomodoro_technique 的信号
	_connect_pomodoro_signals()

## 连接 pomodoro_technique 的信号
func _connect_pomodoro_signals() -> void:
	if pomodoro_technique:
		if not pomodoro_technique.work_started.is_connected(_on_pomodoro_technique_work_started):
			pomodoro_technique.work_started.connect(_on_pomodoro_technique_work_started)
		if not pomodoro_technique.work_completed.is_connected(_on_pomodoro_technique_work_completed):
			pomodoro_technique.work_completed.connect(_on_pomodoro_technique_work_completed)
		if not pomodoro_technique.work_paused.is_connected(_on_pomodoro_technique_work_paused):
			pomodoro_technique.work_paused.connect(_on_pomodoro_technique_work_paused)
		if not pomodoro_technique.work_stopped.is_connected(_on_pomodoro_technique_work_stopped):
			pomodoro_technique.work_stopped.connect(_on_pomodoro_technique_work_stopped)
		if not pomodoro_technique.work_continued.is_connected(_on_pomodoro_technique_work_continued):
			pomodoro_technique.work_continued.connect(_on_pomodoro_technique_work_continued)

## 请求新的顶层层级
func _request_top_layer() -> void:
	if _ui:
		canvas_layer.layer = _ui.request_top_layer()
	else:
		# 降级方案：使用固定的高层级
		canvas_layer.layer = 100


func _on_pomodoro_button_state_changed(_old_state: int, new_state: int) -> void:
	_request_top_layer()
	if new_state==0:
		GuiTransitions.hide("pomodorotechnique")
	else:
		# 请求新的顶层层级
		_request_top_layer()
		GuiTransitions.show("pomodorotechnique")

signal work_started
func _on_pomodoro_technique_work_started() -> void:
	PomodoroState.notify_work_started()


signal work_completed
func _on_pomodoro_technique_work_completed() -> void:
	PomodoroState.notify_work_completed()

signal work_paused
func _on_pomodoro_technique_work_paused() -> void:
	PomodoroState.notify_work_paused()

signal work_stopped
func _on_pomodoro_technique_work_stopped() -> void:
	PomodoroState.notify_work_stopped()

signal work_continued
func _on_pomodoro_technique_work_continued() -> void:
	PomodoroState.notify_work_continued()

# ====== Agent API ======
## Agent API: 启动番茄钟
## @param work_duration: 工作时间（分钟）
## @param rest_duration: 休息时间（分钟）
## @param loop_times: 循环次数（默认1次）
## @return: 是否成功启动
func show_module():
	if !pomodoro_technique.visible:
		_request_top_layer()
		pomodoro_button.set_state_no_signal(1)
func agent_start_pomodoro(work_duration: int, rest_duration: int, loop_times: int = 1) -> bool:
	if pomodoro_technique == null:
		print("[Pomodoro Module] 错误: pomodoro_technique 节点未找到")
		return false
	
	# 确保参数有效
	work_duration = max(1, work_duration)
	rest_duration = max(1, rest_duration)
	loop_times = max(1, loop_times)
	# 启动番茄钟
	pomodoro_technique.pomodoro_start(work_duration, rest_duration, loop_times)
	
	print("[Pomodoro Module] Agent启动番茄钟: 工作%d分钟, 休息%d分钟, %d次循环" % [work_duration, rest_duration, loop_times])
	return true

## Agent API: 设置工作时间
## @param minutes: 工作时间（分钟）
## @return: 是否成功设置
func agent_set_work_duration(minutes: int) -> bool:
	if pomodoro_technique == null:
		print("[Pomodoro Module] 错误: pomodoro_technique 节点未找到")
		return false
	
	if minutes < 1:
		print("[Pomodoro Module] 警告: 工作时间必须大于0")
		return false
	
	pomodoro_technique.set_work_duration(minutes)
	
	# 同时更新UI显示（如果处于空闲状态）
	if pomodoro_technique.has_method("work_info") and pomodoro_technique.work_info:
		pomodoro_technique.work_info.times = minutes
		pomodoro_technique.work_info.flush_times_text()
	
	print("[Pomodoro Module] Agent设置工作时间: %d分钟" % minutes)
	return true

## Agent API: 设置休息时间
## @param minutes: 休息时间（分钟）
## @return: 是否成功设置
func agent_set_rest_duration(minutes: int) -> bool:
	if pomodoro_technique == null:
		print("[Pomodoro Module] 错误: pomodoro_technique 节点未找到")
		return false
	
	if minutes < 1:
		print("[Pomodoro Module] 警告: 休息时间必须大于0")
		return false
	
	pomodoro_technique.set_rest_duration(minutes)
	
	# 同时更新UI显示（如果处于空闲状态）
	if pomodoro_technique.has_method("rest_info") and pomodoro_technique.rest_info:
		pomodoro_technique.rest_info.times = minutes
		pomodoro_technique.rest_info.flush_times_text()
	
	print("[Pomodoro Module] Agent设置休息时间: %d分钟" % minutes)
	return true

## Agent API: 暂停/继续番茄钟
## @return: 是否成功切换状态
func agent_toggle_pause() -> bool:
	if pomodoro_technique == null:
		print("[Pomodoro Module] 错误: pomodoro_technique 节点未找到")
		return false
	
	# 只有在运行中或暂停时才能切换
	if pomodoro_technique.remaining_seconds <= 0:
		print("[Pomodoro Module] 警告: 番茄钟未运行，无法暂停/继续")
		return false
	
	pomodoro_technique.toggle_pause()
	var status = "暂停" if pomodoro_technique.is_paused() else "继续"
	print("[Pomodoro Module] Agent%s番茄钟" % status)
	return true

## Agent API: 停止番茄钟
## @return: 是否成功停止
func agent_stop() -> bool:
	if pomodoro_technique == null:
		print("[Pomodoro Module] 错误: pomodoro_technique 节点未找到")
		return false
	
	pomodoro_technique.stop_timer()
	pomodoro_technique._idle_view()
	
	print("[Pomodoro Module] Agent停止番茄钟")
	return true

## Agent API: 获取番茄钟状态信息
## @return: 状态信息字典
func agent_get_status() -> Dictionary:
	if pomodoro_technique == null:
		return {
			"error": "pomodoro_technique 节点未找到",
			"is_running": false,
			"is_paused": false,
			"is_work_mode": false
		}
	
	var remaining_time = pomodoro_technique.get_remaining_time()
	
	return {
		"is_running": pomodoro_technique.is_running,
		"is_paused": pomodoro_technique.is_paused(),
		"is_work_mode": pomodoro_technique.is_working(),
		"current_loop": pomodoro_technique.current_loop,
		"total_loops": pomodoro_technique.total_loops,
		"work_duration": pomodoro_technique.work_duration,
		"rest_duration": pomodoro_technique.rest_duration,
		"remaining_seconds": pomodoro_technique.remaining_seconds,
		"remaining_time": remaining_time,
		"progress": pomodoro_technique.get_current_mode_progress()
	}

## Agent API: 获取剩余时间
## @return: 剩余时间字典（包含小时、分钟、秒）
func agent_get_remaining_time() -> Dictionary:
	if pomodoro_technique == null:
		return {
			"error": "pomodoro_technique 节点未找到",
			"hour": 0,
			"minute": 0,
			"second": 0
		}
	
	return pomodoro_technique.get_remaining_time()

## Agent API: 检查是否正在运行
## @return: 是否正在运行
func agent_is_running() -> bool:
	if pomodoro_technique == null:
		return false
	return pomodoro_technique.is_running

## Agent API: 检查是否暂停
## @return: 是否暂停
func agent_is_paused() -> bool:
	if pomodoro_technique == null:
		return false
	return pomodoro_technique.is_paused()

## Agent API: 检查是否在工作模式
## @return: 是否在工作模式
func agent_is_work_mode() -> bool:
	if pomodoro_technique == null:
		return false
	return pomodoro_technique.is_working()
