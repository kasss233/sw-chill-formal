class_name OpenAIAdapter extends AIAdapter
## OpenAI API 适配器
## 实现标准 OpenAI Chat Completions API
##
## 功能:
##   1. 支持流式传输（Server-Sent Events）
##   2. 支持多模态（图片）
##   3. 支持 Function Calling
##
## 配置:
##   通过 configure() 方法设置 API 密钥、端点等
##
## 兼容性:
##   - OpenAI 官方 API
##   - Azure OpenAI
##   - 其他 OpenAI 兼容 API（如 Gemini OpenAI 模式）

## API 配置
var api_key: String = ""
var api_base_url: String = "https://api.openai.com/v1"
var model: String = "gpt-4o-mini"
var max_tokens: int = 2048
var temperature: float = 0.7
var request_timeout: float = 60.0

## 内部状态
var _http_client: HTTPClient = null
var _is_requesting: bool = false
var _should_stop: bool = false
var _current_response: String = ""
var _buffer: String = ""
var _stream_thread: Thread = null
var _mutex: Mutex = null


func _init() -> void:
	adapter_name = "openai"
	supports_streaming = true
	supports_tts = false  # OpenAI TTS 需要单独的端点
	supports_function_calling = true
	_mutex = Mutex.new()


## 配置适配器
func configure(config: Dictionary) -> void:
	if config.has("api_key"):
		api_key = config["api_key"]
	if config.has("api_base_url"):
		api_base_url = config["api_base_url"]
	if config.has("model"):
		model = config["model"]
	if config.has("max_tokens"):
		max_tokens = config["max_tokens"]
	if config.has("temperature"):
		temperature = config["temperature"]
	if config.has("request_timeout"):
		request_timeout = config["request_timeout"]


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

	if api_key.is_empty():
		request_failed.emit("API 密钥未设置")
		return

	_is_requesting = true
	_should_stop = false
	_current_response = ""
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
		"model": model,
		"messages": messages,
		"max_tokens": max_tokens,
		"temperature": temperature,
		"stream": stream
	}

	# 添加 Function Calling（如果有）
	if not functions.is_empty():
		body["tools"] = _format_functions_as_tools(functions)
		body["tool_choice"] = "auto"

	return body


## 将函数定义转换为 OpenAI tools 格式
func _format_functions_as_tools(functions: Array) -> Array:
	var tools: Array = []
	for func_def in functions:
		tools.append({
			"type": "function",
			"function": func_def
		})
	return tools


## 执行 HTTP 请求（在线程中）
func _execute_request(_body: Dictionary, _stream: bool) -> void:
	# TODO: 实现实际的 HTTP 请求逻辑
	# 这里复用 AIService 中的流式请求代码
	# 或者将 AIService 重构为使用此适配器

	push_warning("OpenAIAdapter: execute_request 尚未完全实现")

	# 占位：模拟完成
	_is_requesting = false


## 解析流式响应
func _parse_stream_response(_response: Dictionary) -> AIResponse:
	# TODO: 解析 OpenAI 流式响应格式
	# 处理 delta.content（文本）
	# 处理 delta.tool_calls（函数调用）
	return null


## 解析非流式响应
func _parse_response(_response: Dictionary) -> AIResponse:
	# TODO: 解析 OpenAI 完整响应格式
	return null
