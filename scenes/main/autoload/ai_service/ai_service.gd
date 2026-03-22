extends Node
class_name AIServiceClass
## OpenAI API 网络服务单例
## 支持流式传输（Server-Sent Events）

# ============ 信号 ============
## 流式传输：收到新的文本块
signal stream_chunk_received(chunk: String)
## 流式传输：完成（返回完整响应）
signal stream_completed(full_response: String)
## 请求开始
signal request_started()
## 请求失败
signal request_failed(error: String)
## 连接状态变化
signal connection_state_changed(is_connected: bool)

# ============ 配置 ============
@export_group("API 配置")
## OpenAI API 密钥
@export var api_key: String = ""
## API 基础 URL（支持自定义端点）
@export var api_base_url: String = "https://api.openai.com/v1"
## 使用的模型
@export var model: String = "gpt-4o-mini"
## 最大 token 数
@export var max_tokens: int = 2048
## 温度参数（0-2）
@export_range(0.0, 2.0, 0.1) var temperature: float = 0.7
## 请求超时时间（秒）
@export var request_timeout: float = 60.0

@export_group("系统提示词")
## 系统提示词
@export_multiline var system_prompt: String = "你是一个友好的AI助手。"

@export_group("调试")
## 启用调试输出
@export var debug_enabled: bool = false

# ============ 内部状态 ============
var _http_client: HTTPClient = null
var _is_requesting: bool = false
var _is_streaming: bool = false
var _current_response: String = ""
var _message_history: Array[Dictionary] = []
var _buffer: String = ""  # 用于存储不完整的 SSE 数据
var _stream_thread: Thread = null
var _should_stop: bool = false
var _mutex: Mutex = null


func _ready() -> void:
	_mutex = Mutex.new()


# ============ 线程安全访问器 ============

func _is_stopped() -> bool:
	_mutex.lock()
	var val = _should_stop
	_mutex.unlock()
	return val


func _set_request_state(requesting: bool, streaming: bool) -> void:
	_mutex.lock()
	_is_requesting = requesting
	_is_streaming = streaming
	_mutex.unlock()


## 调试输出
func _debug(message: String, data: Variant = null) -> void:
	if not debug_enabled:
		return
	var timestamp = Time.get_datetime_string_from_system()
	if data != null:
		print("[AIService %s] %s: %s" % [timestamp, message, str(data)])
	else:
		print("[AIService %s] %s" % [timestamp, message])


func _exit_tree() -> void:
	cancel_request()
	if _stream_thread and _stream_thread.is_started():
		_stream_thread.wait_to_finish()


# ============ 公共 API ============

## 发送消息（流式传输）
## @param user_message: 用户消息
## @param images: 图片路径数组（可选，用于视觉模型）
## @param use_history: 是否使用对话历史
func send_message(user_message: String, images: Array = [], use_history: bool = true) -> void:
	_debug("send_message 调用", {"message": user_message.substr(0, 100), "images_count": images.size(), "use_history": use_history})

	if _is_requesting:
		_debug("请求被拒绝: 已有请求正在进行中")
		request_failed.emit("已有请求正在进行中")
		return

	if api_key.is_empty():
		_debug("请求被拒绝: API 密钥未设置")
		request_failed.emit("API 密钥未设置")
		return

	_set_request_state(true, true)
	_current_response = ""
	_buffer = ""
	_mutex.lock()
	_should_stop = false
	_mutex.unlock()

	# 构建用户消息内容
	var user_content = _build_user_content(user_message, images)

	# 添加到历史
	if use_history:
		_message_history.append({"role": "user", "content": user_content})

	# 构建消息数组
	var messages: Array = []
	if not system_prompt.is_empty():
		messages.append({"role": "system", "content": system_prompt})

	if use_history:
		messages.append_array(_message_history)
	else:
		messages.append({"role": "user", "content": user_content})

	_debug("消息数组构建完成", {"messages_count": messages.size()})

	request_started.emit()

	# 在线程中执行请求
	_stream_thread = Thread.new()
	_stream_thread.start(_stream_request.bind(messages))


## 发送单次消息（不保存历史）
func send_single_message(user_message: String, images: Array = []) -> void:
	send_message(user_message, images, false)


## 取消当前请求
func cancel_request() -> void:
	_mutex.lock()
	_should_stop = true
	_mutex.unlock()

	if _http_client:
		_http_client.close()

	if _stream_thread and _stream_thread.is_started():
		_stream_thread.wait_to_finish()

	_set_request_state(false, false)


## 清空对话历史
func clear_history() -> void:
	_message_history.clear()


## 获取对话历史
func get_history() -> Array[Dictionary]:
	return _message_history.duplicate()


## 设置对话历史
func set_history(history: Array[Dictionary]) -> void:
	_message_history = history.duplicate()


## 添加助手消息到历史（用于手动添加响应）
func add_assistant_message(content: String) -> void:
	_message_history.append({"role": "assistant", "content": content})


## 是否正在请求
func is_requesting() -> bool:
	_mutex.lock()
	var val = _is_requesting
	_mutex.unlock()
	return val


## 是否正在流式传输
func is_streaming() -> bool:
	_mutex.lock()
	var val = _is_streaming
	_mutex.unlock()
	return val


# ============ 内部方法 ============

## 构建用户消息内容（支持图片）
func _build_user_content(text: String, images: Array) -> Variant:
	if images.is_empty():
		return text

	# 多模态消息格式
	var content: Array = []
	content.append({
		"type": "text",
		"text": text
	})

	for image_path in images:
		var base64_image = _encode_image_to_base64(image_path)
		if not base64_image.is_empty():
			var ext = image_path.get_extension().to_lower()
			var mime_type = "image/jpeg"
			if ext == "png":
				mime_type = "image/png"
			elif ext == "gif":
				mime_type = "image/gif"
			elif ext == "webp":
				mime_type = "image/webp"

			content.append({
				"type": "image_url",
				"image_url": {
					"url": "data:%s;base64,%s" % [mime_type, base64_image]
				}
			})

	return content


## 将图片编码为 Base64
func _encode_image_to_base64(path: String) -> String:
	if not FileAccess.file_exists(path):
		push_warning("AIService: 图片文件不存在 - " + path)
		return ""

	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		push_warning("AIService: 无法打开图片文件 - " + path)
		return ""

	var data = file.get_buffer(file.get_length())
	file.close()

	return Marshalls.raw_to_base64(data)


## 流式请求（在线程中执行）
func _stream_request(messages: Array) -> void:
	_http_client = HTTPClient.new()

	# 解析 URL
	var full_url = api_base_url + "/chat/completions"
	var url_parts = _parse_url(full_url)
	var host = url_parts["host"]
	var port = url_parts["port"]
	var path = url_parts["path"]
	var use_ssl = url_parts["use_ssl"]

	call_deferred("_debug", "开始请求", {
		"url": full_url,
		"host": host,
		"port": port,
		"path": path,
		"use_ssl": use_ssl
	})

	# 连接到服务器（HTTPS 需要 TLS）
	var err: int
	if use_ssl:
		err = _http_client.connect_to_host(host, port, TLSOptions.client())
	else:
		err = _http_client.connect_to_host(host, port)

	if err != OK:
		call_deferred("_debug", "连接失败", {"error_code": err})
		call_deferred("_emit_error", "无法连接到服务器: " + str(err))
		_http_client.close()
		return

	# 等待连接
	call_deferred("_debug", "等待连接...")
	var timeout_start = Time.get_ticks_msec()
	while _http_client.get_status() == HTTPClient.STATUS_CONNECTING or \
		  _http_client.get_status() == HTTPClient.STATUS_RESOLVING:
		_http_client.poll()
		if _is_stopped():
			call_deferred("_debug", "请求被用户取消")
			_http_client.close()
			return
		if Time.get_ticks_msec() - timeout_start > request_timeout * 1000:
			call_deferred("_debug", "连接超时")
			call_deferred("_emit_error", "连接超时")
			_http_client.close()
			return
		OS.delay_msec(100)

	if _http_client.get_status() != HTTPClient.STATUS_CONNECTED:
		call_deferred("_debug", "连接状态异常", {"status": _http_client.get_status()})
		call_deferred("_emit_error", "连接失败: " + str(_http_client.get_status()))
		_http_client.close()
		return

	call_deferred("_debug", "连接成功")
	call_deferred("_emit_connection_state", true)

	# 构建请求体
	var body = {
		"model": model,
		"messages": messages,
		"max_tokens": max_tokens,
		"temperature": temperature,
		"stream": true
	}
	var body_json = JSON.stringify(body)

	call_deferred("_debug", "请求体构建完成", {
		"model": model,
		"max_tokens": max_tokens,
		"temperature": temperature,
		"body_length": body_json.length()
	})

	# 构建请求头
	var headers = [
		"Content-Type: application/json",
		"Authorization: Bearer " + api_key.substr(0, 8) + "...",  # 隐藏大部分密钥
		"Accept: text/event-stream"
	]

	call_deferred("_debug", "发送 POST 请求", {"path": path, "headers_count": headers.size()})

	# 发送请求（使用完整的 api_key）
	var real_headers = [
		"Content-Type: application/json",
		"Authorization: Bearer " + api_key,
		"Accept: text/event-stream"
	]
	err = _http_client.request(HTTPClient.METHOD_POST, path, real_headers, body_json)
	if err != OK:
		call_deferred("_debug", "请求发送失败", {"error_code": err})
		call_deferred("_emit_error", "请求发送失败: " + str(err))
		_http_client.close()
		return

	# 等待响应
	call_deferred("_debug", "等待响应...")
	timeout_start = Time.get_ticks_msec()
	while _http_client.get_status() == HTTPClient.STATUS_REQUESTING:
		_http_client.poll()
		if _is_stopped():
			call_deferred("_debug", "请求被用户取消")
			_http_client.close()
			return
		if Time.get_ticks_msec() - timeout_start > request_timeout * 1000:
			call_deferred("_debug", "请求超时")
			call_deferred("_emit_error", "请求超时")
			_http_client.close()
			return
		OS.delay_msec(100)

	var status_after_request = _http_client.get_status()
	call_deferred("_debug", "请求阶段结束", {
		"http_status": status_after_request,
		"has_response": _http_client.has_response(),
		"status_name": _get_status_name(status_after_request)
	})

	# 检查响应状态
	if not _http_client.has_response():
		call_deferred("_debug", "无响应", {"http_status": status_after_request, "status_name": _get_status_name(status_after_request)})
		call_deferred("_emit_error", "无响应 (HTTP 状态: %s)" % _get_status_name(status_after_request))
		_http_client.close()
		return

	var response_code = _http_client.get_response_code()
	var response_headers = _http_client.get_response_headers_as_dictionary()
	call_deferred("_debug", "收到响应", {
		"status_code": response_code,
		"headers": response_headers
	})

	if response_code != 200:
		# 读取错误响应
		var error_body = PackedByteArray()
		while _http_client.get_status() == HTTPClient.STATUS_BODY:
			_http_client.poll()
			var chunk = _http_client.read_response_body_chunk()
			if chunk.size() > 0:
				error_body.append_array(chunk)
			OS.delay_msec(10)
		var error_text = error_body.get_string_from_utf8()
		call_deferred("_debug", "API 错误响应", {"status_code": response_code, "body": error_text})
		call_deferred("_emit_error", "API 错误 (%d): %s" % [response_code, error_text])
		_http_client.close()
		return

	# 读取流式响应
	call_deferred("_debug", "开始读取流式响应...")
	_buffer = ""
	var chunk_count = 0
	while _http_client.get_status() == HTTPClient.STATUS_BODY:
		if _is_stopped():
			call_deferred("_debug", "流式读取被用户取消")
			_http_client.close()
			return

		_http_client.poll()
		var chunk = _http_client.read_response_body_chunk()

		if chunk.size() > 0:
			chunk_count += 1
			var chunk_text = chunk.get_string_from_utf8()
			_process_sse_chunk(chunk_text)

		OS.delay_msec(10)

	# 完成
	call_deferred("_debug", "流式响应完成", {
		"total_chunks": chunk_count,
		"response_length": _current_response.length()
	})
	_http_client.close()
	call_deferred("_emit_connection_state", false)
	call_deferred("_finish_stream")


## 处理 SSE 数据块
func _process_sse_chunk(chunk: String) -> void:
	_buffer += chunk

	# 按行分割处理
	var lines = _buffer.split("\n")

	# 保留最后一个可能不完整的行
	if not _buffer.ends_with("\n"):
		_buffer = lines[-1]
		lines = lines.slice(0, -1)
	else:
		_buffer = ""

	for line in lines:
		line = line.strip_edges()

		if line.is_empty():
			continue

		if line.begins_with("data: "):
			var data = line.substr(6)  # 去掉 "data: " 前缀

			if data == "[DONE]":
				# 流式传输完成
				continue

			# 解析 JSON
			var json = JSON.new()
			var parse_result = json.parse(data)
			if parse_result == OK:
				var response = json.get_data()
				_process_stream_response(response)


## 处理流式响应数据
func _process_stream_response(response: Dictionary) -> void:
	if not response.has("choices") or response["choices"].is_empty():
		return

	var choice = response["choices"][0]

	if choice.has("delta") and choice["delta"].has("content"):
		var content = choice["delta"]["content"]
		if content and not content.is_empty():
			_current_response += content
			call_deferred("_emit_chunk", content)


## 解析 URL
func _parse_url(url: String) -> Dictionary:
	var result = {
		"host": "",
		"port": 443,
		"path": "/",
		"use_ssl": true
	}

	# 移除协议前缀
	if url.begins_with("https://"):
		url = url.substr(8)
		result["use_ssl"] = true
		result["port"] = 443
	elif url.begins_with("http://"):
		url = url.substr(7)
		result["use_ssl"] = false
		result["port"] = 80

	# 分离路径
	var path_start = url.find("/")
	if path_start != -1:
		result["path"] = url.substr(path_start)
		url = url.substr(0, path_start)

	# 分离端口
	var port_start = url.find(":")
	if port_start != -1:
		result["port"] = url.substr(port_start + 1).to_int()
		url = url.substr(0, port_start)

	result["host"] = url

	return result


## 获取 HTTPClient 状态名称
func _get_status_name(status: int) -> String:
	match status:
		HTTPClient.STATUS_DISCONNECTED:
			return "DISCONNECTED"
		HTTPClient.STATUS_RESOLVING:
			return "RESOLVING"
		HTTPClient.STATUS_CANT_RESOLVE:
			return "CANT_RESOLVE"
		HTTPClient.STATUS_CONNECTING:
			return "CONNECTING"
		HTTPClient.STATUS_CANT_CONNECT:
			return "CANT_CONNECT"
		HTTPClient.STATUS_CONNECTED:
			return "CONNECTED"
		HTTPClient.STATUS_REQUESTING:
			return "REQUESTING"
		HTTPClient.STATUS_BODY:
			return "BODY"
		HTTPClient.STATUS_CONNECTION_ERROR:
			return "CONNECTION_ERROR"
		HTTPClient.STATUS_TLS_HANDSHAKE_ERROR:
			return "TLS_HANDSHAKE_ERROR"
		_:
			return "UNKNOWN(%d)" % status


# ============ 延迟调用方法（线程安全） ============

func _emit_chunk(chunk: String) -> void:
	stream_chunk_received.emit(chunk)


func _emit_error(error: String) -> void:
	_set_request_state(false, false)
	request_failed.emit(error)


func _emit_connection_state(is_connected: bool) -> void:
	connection_state_changed.emit(is_connected)


func _finish_stream() -> void:
	_set_request_state(false, false)

	# 将助手响应添加到历史
	if not _current_response.is_empty():
		_message_history.append({"role": "assistant", "content": _current_response})

	stream_completed.emit(_current_response)
