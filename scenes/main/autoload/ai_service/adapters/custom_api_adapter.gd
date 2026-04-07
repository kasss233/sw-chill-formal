class_name CustomAPIAdapter extends AIAdapter
## 自定义后端 API 适配器
## 对接后端 AI 服务，支持 SSE 流式传输、Function Calling、TTS
##
## SSE 事件协议:
##   event: session_start / loading_hint / text_delta / text_done / function_call / tts / error / done
##   data: {json}（loading_hint: { "phase": "vision_understanding" | "thinking" }）
##
## 请求端点（相对 AuthState.get_base_url()，通常为 .../api/v1）:
##   POST /agent/chat/messages — 发送消息（SSE 流，chill-backend agent_api）
##   POST /agent/chat/function-results — 回传函数执行结果（JSON）
## 若需直连旧版 LLM 路由，可在 configure 中传入 chat_path_prefix: "/chat"。

## 相对 base_url 的对话前缀；默认质量模式，运行时由 ChatState / ChatController 覆盖
var chat_path_prefix: String = "/agent/chat"

## 最近一次请求使用的 API 根地址（由 AuthState.get_base_url() 在主线程写入，供 worker 线程读取）
var api_url: String = ""
var auth_token: String = ""
var request_timeout: float = 120.0

## 会话管理
var _session_id: String = ""
var _message_id: String = ""

## 内部状态
var _http_client: HTTPClient = null
var _is_requesting: bool = false
var _should_stop: bool = false
var _buffer: String = ""
var _stream_thread: Thread = null
var _fr_thread: Thread = null # function-result 独立线程
var _mutex: Mutex = null
var _full_response: String = ""
var _event_type: String = ""
## function-results 成功回传后发出；ChatController 用于清空续轮前的流式正文，避免多轮拼在同一段里
signal followup_assistant_segment_started


func _init() -> void:
	adapter_name = "custom"
	supports_streaming = true
	supports_tts = true
	supports_function_calling = true
	_mutex = Mutex.new()


# ============ 线程安全访问器 ============

func _set_requesting(value: bool) -> void:
	_mutex.lock()
	_is_requesting = value
	_mutex.unlock()


func _get_requesting() -> bool:
	_mutex.lock()
	var val = _is_requesting
	_mutex.unlock()
	return val


## 配置适配器（对话根地址始终用 AuthState.get_base_url()，不在此缓存，避免早于 AuthState._load_base_url 初始化）
func configure(config: Dictionary) -> void:
	if config.has("auth_token"):
		auth_token = config["auth_token"]
	if config.has("request_timeout"):
		request_timeout = config["request_timeout"]
	if config.has("chat_path_prefix"):
		chat_path_prefix = str(config["chat_path_prefix"]).strip_edges()
		if chat_path_prefix.is_empty():
			chat_path_prefix = "/agent/chat"


## 获取/设置会话 ID
func get_session_id() -> String:
	return _session_id

func set_session_id(id: String) -> void:
	_session_id = id


## 发送请求
func send_request(
	messages: Array,
	context: Dictionary = {},
	stream: bool = true
) -> void:
	if _get_requesting():
		call_deferred("_emit_request_failed", "已有请求正在进行中")
		return

	# 每次请求实时获取最新配置
	api_url = AuthState.get_base_url()
	auth_token = AuthState.get_access_token()

	if api_url.is_empty():
		call_deferred("_emit_request_failed", "API URL 未设置")
		return

	_set_requesting(true)
	_should_stop = false
	_buffer = ""
	_full_response = ""
	_event_type = ""

	var body = _build_request_body(messages, context, stream)

	_stream_thread = Thread.new()
	_stream_thread.start(_execute_request.bind(body, stream))


## 取消请求
func cancel_request() -> void:
	_mutex.lock()
	_should_stop = true
	_mutex.unlock()

	if _http_client:
		_http_client.close()

	if _stream_thread and _stream_thread.is_started():
		_stream_thread.wait_to_finish()

	if _fr_thread and _fr_thread.is_started():
		_fr_thread.wait_to_finish()

	_set_requesting(false)


## 回传函数执行结果
func send_function_result(call_id: String, name: String, result: Variant) -> void:
	# 实时获取最新配置
	api_url = AuthState.get_base_url()
	auth_token = AuthState.get_access_token()

	if api_url.is_empty():
		push_warning("[CustomAPIAdapter] API URL 未设置，无法回传函数结果")
		return

	var body = {
		"session_id": _session_id,
		"function_call_id": call_id,
		"function_name": name,
		"result": result
	}

	if _fr_thread and _fr_thread.is_started():
		_fr_thread.wait_to_finish()
	_fr_thread = Thread.new()
	_fr_thread.start(_execute_function_result_request.bind(body))


## 构建请求体
func _build_request_body(
	messages: Array,
	context: Dictionary,
	stream: bool
) -> Dictionary:
	var body: Dictionary = {
		"content": "",
		"stream": stream
	}

	# 从 messages 中提取最新用户消息
	for i in range(messages.size() - 1, -1, -1):
		if messages[i].get("role") == "user":
			body["content"] = messages[i].get("content", "")
			break

	# 附加会话 ID
	if not _session_id.is_empty():
		body["session_id"] = _session_id

	# 处理附件（图片）
	var content = body["content"]
	if content is Array:
		var attachments: Array = []
		var text_content: String = ""
		for part in content:
			if part is Dictionary:
				if part.get("type") == "text":
					text_content = part.get("text", "")
				elif part.get("type") == "image_url":
					var url: String = part.get("image_url", {}).get("url", "")
					if url.begins_with("data:"):
						var parts = url.split(",", true, 1)
						var mime = parts[0].replace("data:", "").replace(";base64", "")
						attachments.append({
							"type": "image",
							"data": parts[1] if parts.size() > 1 else "",
							"mime_type": mime
						})
		body["content"] = text_content
		if not attachments.is_empty():
			body["attachments"] = attachments

	# 注入上下文（作为提示词格式化后附到 body）
	if not context.is_empty():
		body["context"] = context

	return body


## 执行 HTTP 请求（在线程中）
func _execute_request(body: Dictionary, _stream: bool) -> void:
	if auth_token.is_empty():
		call_deferred("_emit_request_failed", "未登录，无法发送请求")
		_set_requesting(false)
		return

	var full_url = api_url + chat_path_prefix + "/messages"
	print("[CustomAPIAdapter][DEBUG] api_url = %s" % api_url)
	print("[CustomAPIAdapter][DEBUG] full_url = %s" % full_url)
	var url_parts = _parse_url(full_url)
	if url_parts.is_empty():
		call_deferred("_emit_request_failed", "API URL 格式无效")
		_set_requesting(false)
		return

	print("[CustomAPIAdapter][DEBUG] host=%s port=%d tls=%s path=%s" % [url_parts["host"], url_parts["port"], url_parts["tls"], url_parts["path"]])

	_http_client = HTTPClient.new()
	var tls_options: TLSOptions = TLSOptions.client_unsafe() if url_parts["tls"] else null
	var err = _http_client.connect_to_host(url_parts["host"], url_parts["port"], tls_options)
	print("[CustomAPIAdapter][DEBUG] connect_to_host 返回: %d" % err)
	if err != OK:
		call_deferred("_emit_request_failed", "连接失败: %d" % err)
		_http_client.close()
		_set_requesting(false)
		return

	# 等待连接
	if not _wait_for_connection():
		_set_requesting(false)
		return

	# 构建请求头
	var headers = PackedStringArray([
		"Content-Type: application/json",
		"Authorization: Bearer " + auth_token,
		"Accept: text/event-stream"
	])

	var body_json = JSON.stringify(body)
	err = _http_client.request(HTTPClient.METHOD_POST, url_parts["path"], headers, body_json)
	print("[CustomAPIAdapter][DEBUG] request() 返回: %d" % err)
	if err != OK:
		call_deferred("_emit_request_failed", "请求发送失败: %d" % err)
		_http_client.close()
		_set_requesting(false)
		return

	# 读取 SSE 响应流
	print("[CustomAPIAdapter][DEBUG] 开始读取 SSE 流...")
	_read_sse_stream()
	print("[CustomAPIAdapter][DEBUG] SSE 流读取结束")

	_http_client.close()
	_set_requesting(false)


## 执行函数结果回传请求（在线程中）
func _execute_function_result_request(body: Dictionary) -> void:
	if auth_token.is_empty():
		call_deferred("_emit_request_failed", "未登录，无法回传函数结果")
		return

	var url_parts = _parse_url(api_url + chat_path_prefix + "/function-results")
	if url_parts.is_empty():
		call_deferred("_emit_request_failed", "API URL 格式无效")
		return

	var client = HTTPClient.new()
	var tls_options: TLSOptions = TLSOptions.client_unsafe() if url_parts["tls"] else null
	var err = client.connect_to_host(url_parts["host"], url_parts["port"], tls_options)
	if err != OK:
		call_deferred("_emit_request_failed", "连接失败: %d" % err)
		client.close()
		return

	# 等待连接
	var timeout_ms = int(request_timeout * 1000)
	var elapsed = 0
	while client.get_status() == HTTPClient.STATUS_CONNECTING or \
		  client.get_status() == HTTPClient.STATUS_RESOLVING:
		client.poll()
		OS.delay_msec(50)
		elapsed += 50
		if elapsed > timeout_ms:
			call_deferred("_emit_request_failed", "函数结果回传连接超时")
			client.close()
			return

	if client.get_status() != HTTPClient.STATUS_CONNECTED:
		call_deferred("_emit_request_failed", "函数结果回传连接失败")
		client.close()
		return

	var headers = PackedStringArray([
		"Content-Type: application/json",
		"Authorization: Bearer " + auth_token,
		"Accept: application/json"
	])

	var body_json = JSON.stringify(body)
	err = client.request(HTTPClient.METHOD_POST, url_parts["path"], headers, body_json)
	if err != OK:
		call_deferred("_emit_request_failed", "函数结果回传请求失败: %d" % err)
		client.close()
		return

	# 等待请求完成
	while client.get_status() == HTTPClient.STATUS_REQUESTING:
		client.poll()
		OS.delay_msec(10)

	if not client.has_response():
		client.close()
		return

	var response_code = client.get_response_code()
	if response_code != 200:
		call_deferred("_emit_request_failed", "函数结果回传 HTTP 错误: %d" % response_code)
		client.close()
		return

	# 读取完整 JSON 响应体
	var response_body = ""
	while client.get_status() == HTTPClient.STATUS_BODY:
		client.poll()
		var chunk = client.read_response_body_chunk()
		if chunk.size() > 0:
			response_body += chunk.get_string_from_utf8()
		OS.delay_msec(10)

	client.close()

	# 解析 JSON（成功后再通知 UI 进入「续轮」段落，避免与上一轮流式正文拼接）
	if response_body.is_empty():
		call_deferred("_emit_followup_segment_started")
		return

	var json = JSON.new()
	if json.parse(response_body) != OK:
		call_deferred("_emit_request_failed", "函数结果响应解析失败")
		return
	var result = json.get_data()
	if result is Dictionary:
		# 与 ApiResponse 一致：code==0 成功；缺省视为成功（避免误把缺省当失败）
		var c = int(result.get("code", 0))
		if c != 0:
			call_deferred("_emit_request_failed",
				"函数结果回传失败: %s" % str(result.get("message", "")))
			return
	call_deferred("_emit_followup_segment_started")


func _emit_followup_segment_started() -> void:
	_full_response = ""
	followup_assistant_segment_started.emit()


## 等待连接建立
func _wait_for_connection() -> bool:
	var timeout_ms = int(request_timeout * 1000)
	var elapsed = 0
	print("[CustomAPIAdapter][DEBUG] 等待连接... 初始状态: %d" % _http_client.get_status())
	while _http_client.get_status() == HTTPClient.STATUS_CONNECTING or \
		  _http_client.get_status() == HTTPClient.STATUS_RESOLVING:
		_http_client.poll()
		OS.delay_msec(50)
		elapsed += 50

		if elapsed % 1000 == 0:
			print("[CustomAPIAdapter][DEBUG] 等待中... %dms 状态: %d" % [elapsed, _http_client.get_status()])

		_mutex.lock()
		var stopped = _should_stop
		_mutex.unlock()
		if stopped:
			call_deferred("_emit_request_failed", "请求已取消")
			_http_client.close()
			return false

		if elapsed > timeout_ms:
			call_deferred("_emit_request_failed", "连接超时")
			_http_client.close()
			return false

	var final_status = _http_client.get_status()
	print("[CustomAPIAdapter][DEBUG] 连接循环结束，最终状态: %d (5=CONNECTED, 4=CANT_CONNECT, 2=CANT_RESOLVE, 9=TLS_ERROR)" % final_status)
	if final_status != HTTPClient.STATUS_CONNECTED:
		call_deferred("_emit_request_failed", "连接失败，状态: %d" % final_status)
		_http_client.close()
		return false

	return true


## 读取 SSE 事件流
func _read_sse_stream() -> void:
	# 等待请求发送完成
	var req_elapsed = 0
	while _http_client.get_status() == HTTPClient.STATUS_REQUESTING:
		_http_client.poll()
		OS.delay_msec(10)
		req_elapsed += 10
		if req_elapsed > int(request_timeout * 1000):
			call_deferred("_emit_request_failed", "等待服务器响应超时")
			return

	print("[CustomAPIAdapter][DEBUG] 请求发送完成，状态: %d has_response: %s" % [_http_client.get_status(), _http_client.has_response()])

	if not _http_client.has_response():
		call_deferred("_emit_request_failed", "服务端无响应")
		return

	var response_code = _http_client.get_response_code()
	print("[CustomAPIAdapter][DEBUG] HTTP 响应码: %d" % response_code)
	if response_code != 200:
		# 尝试读取错误体
		var error_body = ""
		while _http_client.get_status() == HTTPClient.STATUS_BODY:
			_http_client.poll()
			var chunk = _http_client.read_response_body_chunk()
			if chunk.size() > 0:
				error_body += chunk.get_string_from_utf8()
			else:
				break
		call_deferred("_emit_request_failed", "HTTP 错误 %d: %s" % [response_code, error_body])
		return

	# 读取 SSE 数据流
	# 网关模式下首轮可能无 done，服务端会挂起等待 function-results，仅周期性发 :keepalive。
	# 若空闲阈值与「整次请求超时」相同，易在工具执行/回传前误触发「SSE 流读取超时」并断开。
	var idle_elapsed = 0
	var idle_timeout_ms = int(max(request_timeout * 3.0, 300.0) * 1000.0)
	while _http_client.get_status() == HTTPClient.STATUS_BODY:
		_mutex.lock()
		var stopped = _should_stop
		_mutex.unlock()
		if stopped:
			break

		_http_client.poll()
		var chunk = _http_client.read_response_body_chunk()
		if chunk.size() > 0:
			idle_elapsed = 0
			_process_sse_chunk(chunk.get_string_from_utf8())
		else:
			idle_elapsed += 10
			if idle_elapsed > idle_timeout_ms:
				print("[CustomAPIAdapter][DEBUG] SSE 空闲超时 %ds，中断" % int(idle_timeout_ms / 1000))
				call_deferred("_emit_request_failed", "SSE 流读取超时（服务器长时间无数据）")
				return
		OS.delay_msec(10)


## 处理 SSE 数据块
func _process_sse_chunk(chunk: String) -> void:
	_buffer += chunk
	var lines = _buffer.split("\n")

	# 如果最后没有换行，说明最后一行不完整，保留到 buffer
	if not _buffer.ends_with("\n"):
		_buffer = lines[-1]
		lines = lines.slice(0, -1)
	else:
		_buffer = ""

	for line in lines:
		line = line.strip_edges()

		if line.is_empty():
			# 空行 = 事件分隔符
			_event_type = ""
			continue

		if line.begins_with(":"):
			# 注释行（心跳 :keepalive）
			continue

		if line.begins_with("event: "):
			_event_type = line.substr(7).strip_edges()
		elif line.begins_with("data: "):
			var data_str = line.substr(6)
			var json = JSON.new()
			if json.parse(data_str) == OK:
				_dispatch_event(_event_type, json.get_data())
			else:
				print("[CustomAPIAdapter] JSON 解析失败: %s" % data_str)


## 分发 SSE 事件
func _dispatch_event(event_type: String, data: Variant) -> void:
	if not data is Dictionary:
		return

	match event_type:
		"session_start":
			_session_id = data.get("session_id", _session_id)

		"loading_hint":
			var phase: String = str(data.get("phase", "thinking"))
			var response_lh = AIResponse.loading_hint(phase)
			call_deferred("_emit_stream_chunk", response_lh)

		"text_delta":
			var content = str(data.get("content", ""))
			_full_response += content
			var response = AIResponse.text(content, true)
			call_deferred("_emit_stream_chunk", response)

		"text_done":
			# 与直连 OpenAI/Gemini 流式不同：后端可能只发 text_done、不发 text_delta（例如整段生成后一次下发）。
			# 若不处理，ChatState 永远收不到正文，对话框只有框没有字。
			var full: String = str(data.get("content", data.get("text", "")))
			if not full.is_empty():
				_full_response = full
				var response = AIResponse.text(full, false)
				call_deferred("_emit_stream_chunk", response)

		"function_call":
			var raw_args = data.get("arguments", data.get("args", data.get("parameters", {})))
			var normalized_args := _normalize_function_arguments(raw_args)
			var fc_id: String = _coalesce_str_first([
				data.get("id", ""),
				data.get("call_id", ""),
				data.get("function_call_id", "")
			])
			var fc_name: String = _coalesce_str_first([
				data.get("name", ""),
				data.get("function", ""),
				data.get("function_name", ""),
				data.get("tool_name", "")
			])
			print("[CustomAPIAdapter][DEBUG] function_call name=%s id=%s args_type=%s" % [fc_name, fc_id, typeof(raw_args)])
			var response = AIResponse.function_call(fc_id, fc_name, normalized_args)
			call_deferred("_emit_stream_chunk", response)

		"environment":
			if data is Dictionary:
				var env_resp = AIResponse.environment_payload(data)
				call_deferred("_emit_stream_chunk", env_resp)

		"action":
			if data is Dictionary:
				var act_resp = AIResponse.action_payload(data)
				call_deferred("_emit_stream_chunk", act_resp)

		"tts":
			var response: AIResponse
			if data.has("url"):
				response = AIResponse.tts(data.get("url", ""), [], data.get("format", "mp3"))
			elif data.has("data"):
				response = AIResponse.tts("", _decode_base64(data.get("data", "")), data.get("format", "mp3"))
			else:
				return
			call_deferred("_emit_stream_chunk", response)

		"error":
			var response = AIResponse.error(data.get("message", "未知错误"), int(data.get("code", 0)))
			call_deferred("_emit_stream_chunk", response)

		"done":
			_session_id = data.get("session_id", _session_id)
			_message_id = data.get("message_id", "")
			call_deferred("_emit_stream_done")

		_:
			print("[CustomAPIAdapter] 未知 SSE 事件: %s" % event_type)


## 线程安全的信号发射辅助方法
func _emit_stream_chunk(response: AIResponse) -> void:
	stream_chunk.emit(response)

func _emit_stream_done() -> void:
	stream_completed.emit(_full_response)

func _emit_request_failed(error: String) -> void:
	print("[CustomAPIAdapter] 错误: %s" % error)
	request_failed.emit(error)


## 解析 URL
func _parse_url(url: String) -> Dictionary:
	var tls = url.begins_with("https://")
	var clean_url = url.replace("https://", "").replace("http://", "")

	var path_start = clean_url.find("/")
	var host_port: String
	var path: String

	if path_start == -1:
		host_port = clean_url
		path = "/"
	else:
		host_port = clean_url.substr(0, path_start)
		path = clean_url.substr(path_start)

	var port = 443 if tls else 80
	var host = host_port

	var colon = host_port.rfind(":")
	if colon != -1:
		host = host_port.substr(0, colon)
		port = int(host_port.substr(colon + 1))

	return {
		"host": host,
		"port": port,
		"path": path,
		"tls": tls
	}


## 解码 Base64 字符串
func _decode_base64(base64_string: String) -> PackedByteArray:
	if base64_string.is_empty():
		return []
	return Marshalls.base64_to_raw(base64_string)


## 取第一个非空字符串（兼容 OpenAI/Gemini/后端不同字段名）
func _coalesce_str_first(parts: Array) -> String:
	for v in parts:
		var s := str(v).strip_edges()
		if not s.is_empty():
			return s
	return ""


## 兼容后端 function_call.arguments 为 Dictionary / JSON 字符串
func _normalize_function_arguments(raw_args: Variant) -> Dictionary:
	if raw_args is Dictionary:
		return raw_args

	if raw_args is String:
		var args_text := String(raw_args).strip_edges()
		if args_text.is_empty():
			return {}
		var json := JSON.new()
		if json.parse(args_text) != OK:
			push_warning("[CustomAPIAdapter] function_call arguments JSON 解析失败: %s" % json.get_error_message())
			return {}
		var parsed = json.get_data()
		if parsed is Dictionary:
			return parsed
		push_warning("[CustomAPIAdapter] function_call arguments 解析后不是 Dictionary")
		return {}

	if raw_args == null:
		return {}

	push_warning("[CustomAPIAdapter] function_call arguments 类型不支持: %s" % typeof(raw_args))
	return {}
