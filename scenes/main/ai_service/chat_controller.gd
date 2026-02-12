extends Node
## 聊天控制器
## 负责协调 ChatState、AIService / CustomAPIAdapter 之间的交互
## 支持直连模式（AIService → OpenAI）和后端模式（CustomAPIAdapter → 后端 SSE）

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

# ============ 节点引用 ============

# ============ 扩展组件引用 ============
## 上下文收集器
@onready var context_collector: ContextCollector = $ContextCollector
## 函数执行器
@onready var agent_executor: AgentExecutor = $AgentExecutor
## TTS 播放器
@onready var tts_player: TTSPlayer = $TTSPlayer

# ============ 后端模式配置 ============
## 是否使用后端模式（CustomAPIAdapter）
@export var use_backend: bool = false
## 后端 API URL（从 AuthState 自动获取，也可手动覆盖）
@export var backend_api_url: String = ""

## 当前使用的适配器（后端模式下有效）
var _adapter: CustomAPIAdapter = null
## 当前会话 ID（后端模式）
var _session_id: String = ""


func _ready() -> void:
	_init_adapter()
	_connect_signals()


func _init_adapter() -> void:
	if use_backend:
		# 自动获取后端 URL
		if backend_api_url.is_empty():
			backend_api_url = AuthState.get_base_url()

		if not backend_api_url.is_empty():
			_adapter = CustomAPIAdapter.new()
			_adapter.configure({
				"api_url": backend_api_url,
				"auth_token": AuthState.get_access_token()
			})
			_adapter.stream_chunk.connect(_on_adapter_stream_chunk)
			_adapter.stream_completed.connect(_on_adapter_stream_completed)
			_adapter.request_failed.connect(_on_adapter_request_failed)
			print("[ChatController] 使用后端模式: %s" % backend_api_url)
		else:
			push_warning("[ChatController] 后端模式已启用但 API URL 为空，回退到直连模式")
			use_backend = false

	if not use_backend:
		print("[ChatController] 使用直连模式: AIService")


func _connect_signals() -> void:
	# 监听 ChatState 用户输入信号（由 InputBox 通过 ChatState 中介发出）
	ChatState.text_submitted.connect(_on_text_submitted)
	ChatState.generation_stop_requested.connect(_on_generation_stopped)

	# 直连模式：连接 AIService 信号
	if not use_backend and AIService:
		AIService.request_started.connect(_on_ai_request_started)
		AIService.stream_chunk_received.connect(_on_ai_stream_chunk)
		AIService.stream_completed.connect(_on_ai_stream_completed)
		AIService.request_failed.connect(_on_ai_request_failed)

	# TTS 播放器信号
	if tts_player:
		tts_player.playback_finished.connect(_on_tts_finished)


# ============ ChatState 用户输入回调 ============

func _on_text_submitted(text: String, attachments: Array) -> void:
	text_submitted.emit(text, attachments)

	ChatState.start_response()

	if _adapter:
		_send_via_adapter(text, attachments)
	elif AIService:
		AIService.send_message(text, attachments)


func _on_generation_stopped() -> void:
	if _adapter:
		_adapter.cancel_request()
	elif AIService:
		AIService.cancel_request()

	ChatState.set_status(ChatState.Status.IDLE)


# ============ 后端模式：适配器请求 ============

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

	# 多模态内容
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


# ============ 后端模式：适配器信号回调 ============

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

	if _adapter:
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

	# 后端模式：回传结果给后端
	if _adapter:
		_adapter.send_function_result(
			ai_response.function_call_id,
			ai_response.function_name,
			result
		)


func _handle_tts_response(ai_response: AIResponse) -> void:
	if tts_player:
		tts_player.play(ai_response.tts_url, ai_response.tts_data, ai_response.tts_format)
		tts_started.emit()


func _handle_error_response(ai_response: AIResponse) -> void:
	ChatState.fail_response(ai_response.error_message)
	response_failed.emit(ai_response.error_message)


func _on_tts_finished() -> void:
	tts_finished.emit()


# ============ 直连模式：AIService 信号回调 ============

func _on_ai_request_started() -> void:
	response_started.emit()


func _on_ai_stream_chunk(chunk: String) -> void:
	ChatState.append_response_text(chunk)
	response_chunk.emit(chunk)


func _on_ai_stream_completed(full_response: String) -> void:
	ChatState.complete_response(full_response)
	response_completed.emit(full_response)


func _on_ai_request_failed(error: String) -> void:
	ChatState.fail_response(error)
	response_failed.emit(error)


# ============ 公有 API ============

## 发送 AI 消息（基础版，兼容直连模式）
func send_message(text: String, images: Array = []) -> bool:
	if _adapter:
		ChatState.start_response()
		_send_via_adapter(text, images)
		return true

	if not AIService:
		push_warning("AIService 不可用")
		return false

	if AIService.is_requesting():
		push_warning("AI 请求正在进行中")
		return false

	ChatState.start_response()
	AIService.send_message(text, images)
	return true


## 发送带上下文的消息（扩展版）
func send_message_extended(
	text: String,
	images: Array = [],
	include_context: bool = true
) -> bool:
	if _adapter:
		ChatState.start_response()

		var messages = [{"role": "user", "content": _build_user_content(text, images)}]
		var context = context_collector.collect() if include_context and context_collector else {}

		_adapter.send_request(messages, context)
		response_started.emit()
		return true

	return send_message(text, images)


## 取消请求
func cancel_request() -> void:
	if _adapter:
		_adapter.cancel_request()
	elif AIService:
		AIService.cancel_request()

	ChatState.set_status(ChatState.Status.IDLE)


## 清空对话历史
func clear_history() -> void:
	if AIService:
		AIService.clear_history()
	# 后端模式：重置会话 ID（开始新会话）
	if _adapter:
		_session_id = ""
		_adapter.set_session_id("")


## 获取状态
func get_status() -> Dictionary:
	if _adapter:
		return {
			"mode": "backend",
			"session_id": _session_id,
			"api_url": backend_api_url
		}

	if not AIService:
		return {"error": "AIService 不可用", "is_requesting": false}

	return {
		"mode": "direct",
		"is_requesting": AIService.is_requesting(),
		"is_streaming": AIService.is_streaming(),
		"history_count": AIService.get_history().size()
	}


## 收集上下文并附加到请求
func _collect_context() -> Dictionary:
	if context_collector:
		return context_collector.collect()
	return {}
