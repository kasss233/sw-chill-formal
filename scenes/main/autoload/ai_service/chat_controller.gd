extends Node
## 聊天控制器
## 负责协调 ChatState 与 CustomAPIAdapter（后端 SSE）之间的交互

# ============ 信号 ============
## 用户提交文本
signal text_submitted(text: String, attachments: Array)
## AI 响应开始
signal response_started
## AI 收到流式文本块
signal response_chunk(chunk: String)
## AI 响应完成
signal response_completed(full_response: String)
## AI 请求失败
signal response_failed(error: String)
## 函数调用执行（用于 UI 反馈）
signal function_call_executed(name: String, result: Dictionary)
## TTS 播放开始
signal tts_started()
## TTS 播放完成
signal tts_finished()

# ============ 扩展组件引用 ============
## 上下文收集器
@onready var context_collector: ContextCollector = $ContextCollector
## 函数执行器
@onready var agent_executor: AgentExecutor = $AgentExecutor
## TTS 播放器
@onready var tts_player: TTSPlayer = $TTSPlayer

## 当前使用的适配器
var _adapter: CustomAPIAdapter = null
## 当前会话 ID
var _session_id: String = ""


func _ready() -> void:
	_init_adapter()
	_connect_signals()


func _init_adapter() -> void:
	_adapter = CustomAPIAdapter.new()
	_adapter.configure({
		"api_url": AuthState.get_base_url(),
		"auth_token": AuthState.get_access_token()
	})
	_adapter.stream_chunk.connect(_on_adapter_stream_chunk)
	_adapter.stream_completed.connect(_on_adapter_stream_completed)
	_adapter.request_failed.connect(_on_adapter_request_failed)
	print("[ChatController] 后端模式: %s" % AuthState.get_base_url())


func _connect_signals() -> void:
	ChatState.text_submitted.connect(_on_text_submitted)
	ChatState.generation_stop_requested.connect(_on_generation_stopped)

	if tts_player:
		tts_player.playback_finished.connect(_on_tts_finished)


# ============ ChatState 用户输入回调 ============

func _on_text_submitted(text: String, attachments: Array) -> void:
	text_submitted.emit(text, attachments)
	ChatState.start_response()
	_send_via_adapter(text, attachments)


func _on_generation_stopped() -> void:
	_adapter.cancel_request()
	ChatState.set_status(ChatState.Status.IDLE)


# ============ 适配器请求 ============

func _send_via_adapter(text: String, attachments: Array) -> void:
	var messages = [{"role": "user", "content": _build_user_content(text, attachments)}]

	var context: Dictionary = {}
	if context_collector:
		context = context_collector.collect()#TODO:这里默认收集所有数据，更改为ai call function或更灵活

	_adapter.send_request(messages, context)
	response_started.emit()


## 构建用户消息内容（支持文本+图片混合）
func _build_user_content(text: String, images: Array) -> Variant:
	if images.is_empty():
		return text

	var content: Array = [{"type": "text", "text": text}]
	for img_path in images:
		var img_data = _encode_image(img_path)
		if not img_data.is_empty():
			content.append({
				"type": "image_url",
				"image_url": {"url": img_data}
			})
	return content


## 编码图片为 base64 data URL
func _encode_image(path: String) -> String:
	if not FileAccess.file_exists(path):
		return ""
	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		return ""
	var data = file.get_buffer(file.get_length())
	file.close()
	var base64 = Marshalls.raw_to_base64(data)
	var ext = path.get_extension().to_lower()
	var mime = "image/png"
	match ext:
		"jpg", "jpeg":
			mime = "image/jpeg"
		"webp":
			mime = "image/webp"
		"gif":
			mime = "image/gif"
	return "data:%s;base64,%s" % [mime, base64]


# ============ 适配器信号回调 ============

func _on_adapter_stream_chunk(ai_response: AIResponse) -> void:
	match ai_response.type:
		AIResponse.ResponseType.TEXT:
			_handle_text_response(ai_response)
		AIResponse.ResponseType.FUNCTION_CALL:
			_handle_function_call(ai_response)
		AIResponse.ResponseType.TTS:
			_handle_tts_response(ai_response)
		AIResponse.ResponseType.ERROR:
			_handle_error_response(ai_response)


func _on_adapter_stream_completed(full_response: String) -> void:
	ChatState.complete_response(full_response)
	_session_id = _adapter.get_session_id()
	response_completed.emit(full_response)


func _on_adapter_request_failed(error: String) -> void:
	ChatState.fail_response(error)
	response_failed.emit(error)


# ============ AIResponse 处理 ============

func _handle_text_response(ai_response: AIResponse) -> void:
	if ai_response.is_delta:
		ChatState.append_response_text(ai_response.text_content)
	else:
		ChatState.set_response_text(ai_response.text_content)
	response_chunk.emit(ai_response.text_content)


func _handle_function_call(ai_response: AIResponse) -> void:
	if not agent_executor:
		print("[ChatController] AgentExecutor 不可用，跳过函数调用: %s" % ai_response.function_name)
		return

	ChatState.notify_function_call_started(ai_response.function_call_id, ai_response.function_name)

	var result = agent_executor.execute(
		ai_response.function_call_id,
		ai_response.function_name,
		ai_response.function_args
	)

	ChatState.notify_function_call_completed(ai_response.function_call_id, ai_response.function_name, result.get("success", false))
	function_call_executed.emit(ai_response.function_name, result)

	_adapter.send_function_result(
		ai_response.function_call_id,
		ai_response.function_name,
		result
	)


func _handle_tts_response(ai_response: AIResponse) -> void:
	if not TTSState.is_tts_enabled():
		return
	if not tts_player:
		return
	tts_player.queue_enabled = TTSState.is_queue_enabled()
	if TTSState.get_interrupt_on_new_reply():
		tts_player.stop()
	tts_player.play(ai_response.tts_url, ai_response.tts_data, ai_response.tts_format)
	tts_started.emit()


func _handle_error_response(ai_response: AIResponse) -> void:
	ChatState.fail_response(ai_response.error_message)
	response_failed.emit(ai_response.error_message)


func _on_tts_finished() -> void:
	tts_finished.emit()


# ============ 公有 API ============

## 发送 AI 消息
func send_message(text: String, images: Array = []) -> bool:
	ChatState.start_response()
	_send_via_adapter(text, images)
	return true


## 发送带上下文的消息
func send_message_extended(
	text: String,
	images: Array = [],
	include_context: bool = true
) -> bool:
	ChatState.start_response()

	var messages = [{"role": "user", "content": _build_user_content(text, images)}]
	var context = context_collector.collect() if include_context and context_collector else {}

	_adapter.send_request(messages, context)
	response_started.emit()
	return true


## 取消请求
func cancel_request() -> void:
	_adapter.cancel_request()
	ChatState.set_status(ChatState.Status.IDLE)


## 清空对话历史（重置会话 ID，开始新会话）
func clear_history() -> void:
	_session_id = ""
	_adapter.set_session_id("")


## 获取状态
func get_status() -> Dictionary:
	return {
		"mode": "backend",
		"session_id": _session_id,
		"api_url": AuthState.get_base_url()
	}
