extends Node

## 统计采集适配层
## 只监听业务 State 信号，并调用 StatsState 的统一 API

const FLUSH_INTERVAL: float = 300.0

var _flush_timer: Timer = null
var _current_focus_session_id: String = ""


func _ready() -> void:
	_setup_flush_timer()
	_connect_signals()
	print("[EventTracker] 初始化完成")


func flush() -> void:
	StatsState.flush_pending_events()


func track_task_start(task_id: int, title: String) -> void:
	StatsState.record_custom_event("task_started", {
		"task_id": task_id,
		"title": title,
	})


func track_task_pause(task_id: int) -> void:
	StatsState.record_custom_event("task_paused", {
		"task_id": task_id,
	})


func track_ai_suggestion_rejected(name: String) -> void:
	StatsState.record_ai_function_rejected(name)


func _connect_signals() -> void:
	if PomodoroState:
		PomodoroState.work_phase_started.connect(_on_work_phase_started)
		PomodoroState.work_phase_paused.connect(_on_work_phase_paused)
		PomodoroState.work_phase_continued.connect(_on_work_phase_continued)
		PomodoroState.work_phase_completed.connect(_on_work_phase_completed)
		PomodoroState.work_phase_stopped.connect(_on_work_phase_stopped)

	if TaskState:
		TaskState.task_state_changed.connect(_on_task_state_changed)

	if HabitState:
		HabitState.execution_updated.connect(_on_execution_updated)

	var agent_executor = ChatController.agent_executor
	if agent_executor:
		_connect_agent_executor(agent_executor)
	else:
		ChatController.ready.connect(func():
			if ChatController.agent_executor:
				_connect_agent_executor(ChatController.agent_executor)
		, CONNECT_ONE_SHOT)


func _connect_agent_executor(agent_executor) -> void:
	if not agent_executor.function_executed.is_connected(_on_function_executed):
		agent_executor.function_executed.connect(_on_function_executed)
	if not agent_executor.function_failed.is_connected(_on_function_failed):
		agent_executor.function_failed.connect(_on_function_failed)


func _on_work_phase_started() -> void:
	if not _current_focus_session_id.is_empty():
		StatsState.record_focus_finished(_current_focus_session_id, false, {
			"reason": "replaced_by_new_session",
		})

	_current_focus_session_id = StatsState.generate_session_id()
	StatsState.record_focus_started(_current_focus_session_id, {
		"session_type": "pomodoro",
		"initiated_by": "user",
		"work_duration": PomodoroState.work_duration,
		"rest_duration": PomodoroState.rest_duration,
		"total_loops": PomodoroState.total_loops,
		"loop_index": PomodoroState.current_loop,
	})


func _on_work_phase_paused() -> void:
	if _current_focus_session_id.is_empty():
		return
	StatsState.record_focus_paused(_current_focus_session_id, "work")


func _on_work_phase_continued() -> void:
	if _current_focus_session_id.is_empty():
		return
	StatsState.record_focus_resumed(_current_focus_session_id, "work")


func _on_work_phase_completed() -> void:
	if _current_focus_session_id.is_empty():
		return
	StatsState.record_focus_finished(_current_focus_session_id, true)
	_current_focus_session_id = ""


func _on_work_phase_stopped() -> void:
	if _current_focus_session_id.is_empty():
		return
	StatsState.record_focus_finished(_current_focus_session_id, false)
	_current_focus_session_id = ""


func _on_task_state_changed(task) -> void:
	if task.is_completed:
		StatsState.record_task_completed(task.id, {
			"title": task.title,
			"due_timestamp": task.due_timestamp,
			"finish_timestamp": task.finish_timestamp,
		})


func _on_execution_updated(record) -> void:
	StatsState.record_habit_execution(record)


func _on_function_executed(call_id: String, func_name: String, result: Variant) -> void:
	var meta := {}
	if result is Dictionary:
		meta["result_keys"] = result.keys()
	StatsState.record_ai_function_result(call_id, func_name, true, meta)


func _on_function_failed(call_id: String, func_name: String, error: String) -> void:
	StatsState.record_ai_function_result(call_id, func_name, false, {
		"error": error,
	})


func _setup_flush_timer() -> void:
	_flush_timer = Timer.new()
	_flush_timer.wait_time = FLUSH_INTERVAL
	_flush_timer.autostart = true
	_flush_timer.timeout.connect(func(): StatsState.flush_pending_events())
	add_child(_flush_timer)
