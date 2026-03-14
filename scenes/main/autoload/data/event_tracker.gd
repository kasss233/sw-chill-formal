extends Node
## 行为事件追踪系统
## 采集用户行为事件，定时批量上传到后端

const FLUSH_INTERVAL: float = 300.0  # 5 分钟
const FLUSH_THRESHOLD: int = 50       # 满 50 条立即上传
const DEVICE_ID_PATH: String = "user://device_id.txt"

var _event_queue: Array[Dictionary] = []
var _device_id: String = ""
var _flush_timer: Timer = null


func _ready() -> void:
	_device_id = _load_or_create_device_id()
	_setup_flush_timer()
	_connect_signals()
	print("[EventTracker] 初始化完成, device_id: %s" % _device_id)


## ===== 公共 API =====

## 手动刷新队列
func flush() -> void:
	_do_flush()


## 记录任务开始（预留，当前架构无对应信号）
func track_task_start(task_id: int, title: String) -> void:
	_enqueue("task_start", {
		"task_id": task_id,
		"title": title
	})


## 记录任务暂停（预留，当前架构无对应信号）
func track_task_pause(task_id: int) -> void:
	_enqueue("task_pause", {
		"task_id": task_id
	})


## 记录 AI 建议被拒绝（预留，当前架构无对应信号）
func track_ai_suggestion_rejected(name: String) -> void:
	_enqueue("ai_suggestion_rejected", {
		"function_name": name
	})


## ===== 信号连接 =====

func _connect_signals() -> void:
	# 番茄钟信号
	PomodoroState.pomodoro_started.connect(_on_pomodoro_started)
	PomodoroState.work_phase_stopped.connect(_on_work_phase_stopped)
	PomodoroState.rest_phase_stopped.connect(_on_rest_phase_stopped)
	PomodoroState.work_phase_paused.connect(_on_work_phase_paused)
	PomodoroState.rest_phase_paused.connect(_on_rest_phase_paused)
	PomodoroState.all_completed.connect(_on_all_completed)

	# 任务信号
	TaskState.task_state_changed.connect(_on_task_state_changed)

	# AI 函数调用信号（通过 ChatController 的 AgentExecutor 子节点）
	var agent_executor = ChatController.agent_executor
	if agent_executor:
		agent_executor.function_executed.connect(_on_function_executed)
	else:
		# ChatController 可能还未 ready，延迟连接
		ChatController.ready.connect(func():
			if ChatController.agent_executor:
				ChatController.agent_executor.function_executed.connect(_on_function_executed)
		, CONNECT_ONE_SHOT)


## ===== 番茄钟事件处理 =====

func _on_pomodoro_started(data: Dictionary) -> void:
	# 记录启动时间戳到 PomodoroState 的 meta
	PomodoroState.set_meta("et_start_time", Time.get_unix_time_from_system())
	PomodoroState.set_meta("et_pause_count", 0)

	_enqueue("focus_start", {
		"work_duration": data.get("work_duration", 0),
		"rest_duration": data.get("rest_duration", 0),
		"total_loops": data.get("total_loops", 0)
	})


func _on_work_phase_stopped() -> void:
	_emit_focus_end(false)


func _on_rest_phase_stopped() -> void:
	_emit_focus_end(false)


func _on_work_phase_paused() -> void:
	var count: int = PomodoroState.get_meta("et_pause_count", 0)
	PomodoroState.set_meta("et_pause_count", count + 1)
	_enqueue("focus_interrupt", {
		"phase": "work"
	})


func _on_rest_phase_paused() -> void:
	var count: int = PomodoroState.get_meta("et_pause_count", 0)
	PomodoroState.set_meta("et_pause_count", count + 1)
	_enqueue("focus_interrupt", {
		"phase": "rest"
	})


func _on_all_completed() -> void:
	_emit_focus_end(true)


func _emit_focus_end(completed: bool) -> void:
	var start_time: float = PomodoroState.get_meta("et_start_time", 0.0)
	var pause_count: int = PomodoroState.get_meta("et_pause_count", 0)
	var duration: float = 0.0
	if start_time > 0:
		duration = Time.get_unix_time_from_system() - start_time

	_enqueue("focus_end", {
		"completed": completed,
		"duration_seconds": int(duration),
		"pause_count": pause_count
	})

	# 清理 meta
	if PomodoroState.has_meta("et_start_time"):
		PomodoroState.remove_meta("et_start_time")
	if PomodoroState.has_meta("et_pause_count"):
		PomodoroState.remove_meta("et_pause_count")


## ===== 任务事件处理 =====

func _on_task_state_changed(task) -> void:
	if task.is_completed:
		_enqueue("task_complete", {
			"task_id": task.id
		})


## ===== AI 事件处理 =====

func _on_function_executed(_call_id: String, func_name: String, _result: Variant) -> void:
	_enqueue("ai_suggestion_accepted", {
		"function_name": func_name
	})


## ===== 队列管理 =====

func _enqueue(event_type: String, data: Dictionary = {}) -> void:
	var event := {
		"event_type": event_type,
		"timestamp": int(Time.get_unix_time_from_system()),
		"device_id": _device_id,
		"data": data
	}
	_event_queue.append(event)

	if _event_queue.size() >= FLUSH_THRESHOLD:
		_do_flush()


func _do_flush() -> void:
	if _event_queue.is_empty():
		return

	if not AuthState.is_logged_in():
		print("[EventTracker] 未登录，跳过上传")
		return

	# 取出当前队列，清空以便继续收集
	var events_to_send := _event_queue.duplicate()
	_event_queue.clear()

	var body := {
		"device_id": _device_id,
		"events": events_to_send
	}

	var result = await ApiClient.api_post("/sync/events", body)
	if not result.success:
		print("[EventTracker] 上传失败: %s，事件放回队列" % result.message)
		# 失败时放回队列头部
		for i in range(events_to_send.size() - 1, -1, -1):
			_event_queue.insert(0, events_to_send[i])
	else:
		print("[EventTracker] 上传成功，已发送 %d 条事件" % events_to_send.size())


## ===== 定时器 =====

func _setup_flush_timer() -> void:
	_flush_timer = Timer.new()
	_flush_timer.wait_time = FLUSH_INTERVAL
	_flush_timer.autostart = true
	_flush_timer.timeout.connect(_do_flush)
	add_child(_flush_timer)


## ===== 设备 ID =====

func _load_or_create_device_id() -> String:
	if FileAccess.file_exists(DEVICE_ID_PATH):
		var file = FileAccess.open(DEVICE_ID_PATH, FileAccess.READ)
		if file:
			var id = file.get_as_text().strip_edges()
			if not id.is_empty():
				return id

	# 生成新的 UUID v4
	var id = _generate_uuid_v4()
	var file = FileAccess.open(DEVICE_ID_PATH, FileAccess.WRITE)
	if file:
		file.store_string(id)
	return id


func _generate_uuid_v4() -> String:
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	var bytes: PackedByteArray = []
	for i in 16:
		bytes.append(rng.randi() % 256)
	# 设置 version 4
	bytes[6] = (bytes[6] & 0x0F) | 0x40
	# 设置 variant
	bytes[8] = (bytes[8] & 0x3F) | 0x80
	return "%02x%02x%02x%02x-%02x%02x-%02x%02x-%02x%02x-%02x%02x%02x%02x%02x%02x" % [
		bytes[0], bytes[1], bytes[2], bytes[3],
		bytes[4], bytes[5],
		bytes[6], bytes[7],
		bytes[8], bytes[9],
		bytes[10], bytes[11], bytes[12], bytes[13], bytes[14], bytes[15]
	]
