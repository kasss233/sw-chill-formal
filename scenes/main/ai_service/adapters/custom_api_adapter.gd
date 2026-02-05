class_name CustomAPIAdapter extends AIAdapter
## 自定义后端 API 适配器
## 用于对接用户自己的 AI 后端服务
##
## 功能:
##   1. 支持自定义请求/响应格式
##   2. 支持 TTS 音频返回
##   3. 支持 Function Calling / Agent 操作
##   4. 支持上下文自动注入
##
## 预期后端响应格式示例:
##   {
##     "type": "text" | "tts" | "function_call" | "done",
##     "content": "文本内容",
##     "tts": {
##       "url": "https://...",      // 或
##       "data": "base64...",
##       "format": "mp3"
##     },
##     "function_call": {
##       "id": "call_xxx",
##       "name": "add_task",
##       "arguments": { "title": "..." }
##     }
##   }
##
## 流式传输:
##   使用 Server-Sent Events，每个事件包含上述格式的 JSON

## API 配置
var api_url: String = ""
var auth_token: String = ""
var request_timeout: float = 120.0

## 是否自动注入上下文
var auto_inject_context: bool = true

## 内部状态
var _http_client: HTTPClient = null
var _is_requesting: bool = false
var _should_stop: bool = false
var _buffer: String = ""
var _stream_thread: Thread = null
var _mutex: Mutex = null


func _init() -> void:
	adapter_name = "custom"
	supports_streaming = true
	supports_tts = true
	supports_function_calling = true
	_mutex = Mutex.new()


## 配置适配器
func configure(config: Dictionary) -> void:
	if config.has("api_url"):
		api_url = config["api_url"]
	if config.has("auth_token"):
		auth_token = config["auth_token"]
	if config.has("request_timeout"):
		request_timeout = config["request_timeout"]
	if config.has("auto_inject_context"):
		auto_inject_context = config["auto_inject_context"]


## 发送请求
func send_request(
	messages: Array,
	context: Dictionary = {},
	functions: Array = [],
	stream: bool = true
) -> void:
	if _is_requesting:
		request_failed.emit("已有请求正在进行中")
		return

	if api_url.is_empty():
		request_failed.emit("API URL 未设置")
		return

	_is_requesting = true
	_should_stop = false
	_buffer = ""

	# 构建请求体
	var body = _build_request_body(messages, context, functions, stream)

	# 在线程中执行请求
	_stream_thread = Thread.new()
	_stream_thread.start(_execute_request.bind(body, stream))


## 取消请求
func cancel_request() -> void:
	_mutex.lock()
	_should_stop = true
	_mutex.unlock()

	if _http_client:
		_http_client.close()

	_is_requesting = false


## 构建请求体
func _build_request_body(
	messages: Array,
	context: Dictionary,
	functions: Array,
	stream: bool
) -> Dictionary:
	var body: Dictionary = {
		"messages": messages,
		"stream": stream
	}

	# 注入上下文
	if auto_inject_context and not context.is_empty():
		body["context"] = context

	# 添加可用函数
	if not functions.is_empty():
		body["functions"] = functions

	return body


## 执行 HTTP 请求（在线程中）
func _execute_request(_body: Dictionary, _stream: bool) -> void:
	# TODO: 实现实际的 HTTP 请求逻辑
	push_warning("CustomAPIAdapter: execute_request 尚未实现")
	_is_requesting = false


## 解析响应数据
## @param data 响应 JSON 数据
## @return AIResponse 对象
func _parse_response_data(data: Dictionary) -> AIResponse:
	var response_type = data.get("type", "text")

	match response_type:
		"text":
			return AIResponse.text(data.get("content", ""), data.get("is_delta", false))

		"tts":
			var tts_data = data.get("tts", {})
			return AIResponse.tts(
				tts_data.get("url", ""),
				_decode_base64(tts_data.get("data", "")),
				tts_data.get("format", "mp3")
			)

		"function_call":
			var fc = data.get("function_call", {})
			return AIResponse.function_call(
				fc.get("id", ""),
				fc.get("name", ""),
				fc.get("arguments", {})
			)

		"done":
			return AIResponse.done()

		_:
			return AIResponse.error("未知响应类型: " + response_type)


## 解码 Base64 字符串
func _decode_base64(base64_string: String) -> PackedByteArray:
	if base64_string.is_empty():
		return []
	return Marshalls.base64_to_raw(base64_string)


## 处理函数调用结果
## 将函数执行结果发送回后端（用于多轮对话）
## @param call_id 调用 ID
## @param name 函数名
## @param result 执行结果
func send_function_result(_call_id: String, _name: String, _result: Variant) -> void:
	# TODO: 实现函数结果回传
	push_warning("CustomAPIAdapter: send_function_result 尚未实现")
