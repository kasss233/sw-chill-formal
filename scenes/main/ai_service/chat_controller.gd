extends Node
class_name ChatController
## 聊天控制器
## 负责协调 InputBox、DialogueBox 和 AIService 之间的交互
## 将聊天逻辑从 ui.gd 中解耦出来
##
## 扩展架构（TODO: 完成实现）:
##   - ContextCollector: 收集上下文附加到请求
##   - AgentExecutor: 执行 AI 请求的函数调用
##   - TTSPlayer: 播放 AI 返回的语音
##   - AIAdapter: 适配不同的 API 后端

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
@export var input_box: InputBox
@export var dialogue_box: DialogueBox

# ============ 扩展组件引用（TODO: 连接） ============
## 上下文收集器
@export var context_collector: ContextCollector
## 函数执行器
@export var agent_executor: AgentExecutor
## TTS 播放器
@export var tts_player: TTSPlayer


func _ready() -> void:
	_connect_signals()


func _connect_signals() -> void:
	# 连接 InputBox 信号
	if input_box:
		input_box.text_submitted.connect(_on_text_submitted)
		input_box.generation_stopped.connect(_on_generation_stopped)

	# 连接 AIService 信号
	if AIService:
		AIService.request_started.connect(_on_ai_request_started)
		AIService.stream_chunk_received.connect(_on_ai_stream_chunk)
		AIService.stream_completed.connect(_on_ai_stream_completed)
		AIService.request_failed.connect(_on_ai_request_failed)


# ============ InputBox 信号回调 ============

func _on_text_submitted(text: String, attachments: Array) -> void:
	# 转发信号
	text_submitted.emit(text, attachments)

	# 显示对话框并清空
	if dialogue_box:
		dialogue_box.show_module()
		dialogue_box.clear_dialogue()

	# 发送到 AI
	if AIService:
		AIService.send_message(text, attachments)


func _on_generation_stopped() -> void:
	if AIService:
		AIService.cancel_request()


# ============ AIService 信号回调 ============

func _on_ai_request_started() -> void:
	response_started.emit()


func _on_ai_stream_chunk(chunk: String) -> void:
	if dialogue_box:
		dialogue_box.append_text(chunk)

	response_chunk.emit(chunk)


func _on_ai_stream_completed(full_response: String) -> void:
	if input_box:
		input_box.agent_reset_to_ready()

	response_completed.emit(full_response)


func _on_ai_request_failed(error: String) -> void:
	# 在对话框显示错误
	if dialogue_box:
		dialogue_box.show_module()
		dialogue_box.set_text("[color=red]错误: " + error + "[/color]")

	# 重置输入框
	if input_box:
		input_box.agent_reset_to_ready()

	response_failed.emit(error)


# ============ 公有 API ============

## 发送 AI 消息
func send_message(text: String, images: Array = []) -> bool:
	if not AIService:
		push_warning("AIService 不可用")
		return false

	if AIService.is_requesting():
		push_warning("AI 请求正在进行中")
		return false

	if dialogue_box:
		dialogue_box.show_module()
		dialogue_box.clear_dialogue()

	AIService.send_message(text, images)
	return true


## 取消请求
func cancel_request() -> void:
	if AIService:
		AIService.cancel_request()

	if input_box:
		input_box.agent_reset_to_ready()


## 清空对话历史
func clear_history() -> void:
	if AIService:
		AIService.clear_history()


## 获取状态
func get_status() -> Dictionary:
	if not AIService:
		return {"error": "AIService 不可用", "is_requesting": false}

	return {
		"is_requesting": AIService.is_requesting(),
		"is_streaming": AIService.is_streaming(),
		"history_count": AIService.get_history().size()
	}


# ============ 扩展功能（TODO: 完成实现） ============

## 处理 AIResponse 对象（统一响应处理入口）
## @param response AIResponse 对象
func _handle_ai_response(_response: AIResponse) -> void:
	# TODO: 根据 response.type 分发处理
	# match response.type:
	#     AIResponse.ResponseType.TEXT:
	#         _handle_text_response(response)
	#     AIResponse.ResponseType.TTS:
	#         _handle_tts_response(response)
	#     AIResponse.ResponseType.FUNCTION_CALL:
	#         _handle_function_call(response)
	#     AIResponse.ResponseType.DONE:
	#         _handle_done()
	pass


## 处理文本响应
func _handle_text_response(_response: AIResponse) -> void:
	# TODO: 显示文本到 DialogueBox
	# if dialogue_box:
	#     if response.is_delta:
	#         dialogue_box.append_text(response.text_content)
	#     else:
	#         dialogue_box.set_text(response.text_content)
	pass


## 处理 TTS 响应
func _handle_tts_response(_response: AIResponse) -> void:
	# TODO: 播放 TTS 音频
	# if tts_player:
	#     tts_player.play(response.tts_url, response.tts_data, response.tts_format)
	#     tts_started.emit()
	pass


## 处理函数调用
func _handle_function_call(_response: AIResponse) -> void:
	# TODO: 执行函数并处理结果
	# if agent_executor:
	#     var result = agent_executor.execute(
	#         response.function_call_id,
	#         response.function_name,
	#         response.function_args
	#     )
	#     function_call_executed.emit(response.function_name, result)
	#     # 可选：将结果发送回 AI
	pass


## 收集上下文并附加到请求
## @return 上下文字典
func _collect_context() -> Dictionary:
	if context_collector:
		return context_collector.collect()
	return {}


## 获取可用函数定义（用于发送给 AI）
## @return 函数定义数组
func _get_function_definitions() -> Array[Dictionary]:
	if agent_executor:
		return agent_executor.get_function_definitions()
	return []


## 发送带上下文的消息（扩展版）
## @param text 用户消息
## @param images 图片附件
## @param include_context 是否包含上下文
## @param include_functions 是否包含函数定义
func send_message_extended(
	text: String,
	images: Array = [],
	include_context: bool = true,
	include_functions: bool = true
) -> bool:
	# TODO: 实现扩展版消息发送
	# 1. 收集上下文
	# 2. 获取函数定义
	# 3. 调用适配器发送请求
	push_warning("ChatController.send_message_extended() 尚未实现")
	return send_message(text, images)
