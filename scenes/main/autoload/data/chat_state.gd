extends Node

## 聊天状态单例
## 纯内存状态（不持久化），管理聊天会话的运行时状态

## 聊天状态枚举
enum Status { IDLE, GENERATING, EXECUTING_FUNCTION, ERROR }

# ============ 状态变化信号 ============
## 聊天状态变化（IDLE/GENERATING/EXECUTING_FUNCTION/ERROR）
signal chat_status_changed(new_status: Status)

# ============ 响应内容信号 ============
## 新响应开始（UI 应清空并显示对话框）
signal response_started()
## 响应文本增量（流式追加）
signal response_text_delta(delta: String)
## 响应文本整体替换
signal response_text_set(text: String)
## 响应完成
signal response_completed(full_text: String)
## 响应内容清空
signal response_cleared()
## 响应错误
signal response_error(message: String)

# ============ 函数调用信号（为 DialogueBox 扩展预留）============
## 函数调用开始
signal function_call_started(call_id: String, name: String)
## 函数调用完成
signal function_call_completed(call_id: String, name: String, success: bool)

# ============ 用户输入信号（InputBox -> ChatController）============
## 用户提交文本（由 InputBox 发出，ChatController 监听）
signal text_submitted(text: String, attachments: Array)
## 用户请求停止生成（由 InputBox 发出，ChatController 监听）
signal generation_stop_requested()

# ============ 输入控制信号（Agent -> InputBox）============
## 请求设置输入框文本
signal input_text_requested(text: String)
## 请求清空输入框
signal input_clear_requested()

# ============ 状态 ============
var status: Status = Status.IDLE
var current_response_text: String = ""

# ============ 状态管理 API（供 ChatController 调用）============

func set_status(new_status: Status) -> void:
	if status != new_status:
		var old_name = Status.keys()[status]
		var new_name = Status.keys()[new_status]
		print("[ChatState] 状态变更: %s -> %s" % [old_name, new_name])
		status = new_status
		chat_status_changed.emit(new_status)


func start_response() -> void:
	print("[ChatState] start_response()")
	current_response_text = ""
	set_status(Status.GENERATING)
	response_started.emit()


func append_response_text(delta: String) -> void:
	current_response_text += delta
	response_text_delta.emit(delta)


func set_response_text(text: String) -> void:
	print("[ChatState] set_response_text() len=%d" % text.length())
	current_response_text = text
	response_text_set.emit(text)


func complete_response(full_text: String) -> void:
	print("[ChatState] complete_response() len=%d" % full_text.length())
	current_response_text = full_text
	set_status(Status.IDLE)
	response_completed.emit(full_text)


func fail_response(error: String) -> void:
	print("[ChatState] fail_response(): %s" % error)
	set_status(Status.ERROR)
	response_error.emit(error)


func clear_response() -> void:
	print("[ChatState] clear_response()")
	current_response_text = ""
	response_cleared.emit()


func notify_function_call_started(call_id: String, fname: String) -> void:
	print("[ChatState] function_call_started: %s (call_id: %s)" % [fname, call_id])
	set_status(Status.EXECUTING_FUNCTION)
	function_call_started.emit(call_id, fname)


func notify_function_call_completed(call_id: String, fname: String, success: bool) -> void:
	print("[ChatState] function_call_completed: %s success=%s" % [fname, success])
	set_status(Status.GENERATING)
	function_call_completed.emit(call_id, fname, success)

# ============ Agent API（供 AgentExecutor 调用）============

func agent_get_chat_status() -> Dictionary:
	print("[ChatState] agent_get_chat_status() -> %s" % Status.keys()[status])
	return {
		"status": Status.keys()[status],
		"is_generating": status == Status.GENERATING,
		"is_idle": status == Status.IDLE,
		"current_response_length": current_response_text.length()
	}


func agent_set_input_text(text: String) -> bool:
	print("[ChatState] agent_set_input_text(): '%s'" % text)
	input_text_requested.emit(text)
	return true


func agent_clear_input() -> bool:
	print("[ChatState] agent_clear_input()")
	input_clear_requested.emit()
	return true

# ============ 用户输入 API（供 InputBox 调用）============

func submit_text(text: String, attachments: Array) -> void:
	print("[ChatState] submit_text(): '%s' attachments=%d" % [text.left(20), attachments.size()])
	text_submitted.emit(text, attachments)


func request_stop_generation() -> void:
	print("[ChatState] request_stop_generation()")
	generation_stop_requested.emit()
