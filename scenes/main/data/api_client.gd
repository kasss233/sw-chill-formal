extends Node

# --- 信号 ---
signal auth_required  # token 刷新失败，需要重新登录

# --- ApiResult 内部类 ---
class ApiResult:
	var success: bool
	var code: int        # 业务错误码
	var message: String
	var data: Variant    # 响应 data 字段
	var http_code: int

	func _init(p_success: bool = false, p_code: int = -1, p_message: String = "", p_data: Variant = null, p_http_code: int = 0) -> void:
		success = p_success
		code = p_code
		message = p_message
		data = p_data
		http_code = p_http_code

	static func ok(p_data: Variant, p_http_code: int = 200) -> ApiResult:
		return ApiResult.new(true, 0, "success", p_data, p_http_code)

	static func error(p_code: int, p_message: String, p_http_code: int = 0) -> ApiResult:
		return ApiResult.new(false, p_code, p_message, null, p_http_code)

# --- HTTPRequest 节点池 ---
var _pool: Array[HTTPRequest] = []
var _pool_in_use: Array[HTTPRequest] = []
const _max_pool_size: int = 4
const _request_timeout: float = 30.0

func _ready() -> void:
	print("[ApiClient] 初始化完成")

# ======================== 公共 API ========================

func api_get(path: String, query_params: Dictionary = {}) -> ApiResult:
	var url = _build_url(path, query_params)
	return await _request(url, HTTPClient.METHOD_GET)

func api_post(path: String, body: Dictionary = {}) -> ApiResult:
	var url = _build_url(path)
	return await _request(url, HTTPClient.METHOD_POST, body)

func api_put(path: String, body: Dictionary = {}) -> ApiResult:
	var url = _build_url(path)
	return await _request(url, HTTPClient.METHOD_PUT, body)

func api_delete(path: String) -> ApiResult:
	var url = _build_url(path)
	return await _request(url, HTTPClient.METHOD_DELETE)

# ======================== 核心请求流程 ========================

func _request(url: String, method: int, body: Dictionary = {}, is_retry: bool = false) -> ApiResult:
	# 1. 检查登录状态
	if not AuthState.is_logged_in():
		return ApiResult.error(-1, "未登录")

	# 2. 如果 token 过期，等待刷新
	if AuthState.is_token_expired():
		var refresh_ok = await _ensure_valid_token()
		if not refresh_ok:
			auth_required.emit()
			return ApiResult.error(-1, "Token 刷新失败，请重新登录")

	# 3. 获取 HTTPRequest 节点
	var http = _acquire_http_request()
	if http == null:
		return ApiResult.error(-1, "请求并发数已达上限，请稍后重试")

	# 4. 构建请求头
	var headers = [
		"Content-Type: application/json",
		"Authorization: Bearer " + AuthState.get_access_token()
	]

	# 5. 发送请求
	var json_body = ""
	if method == HTTPClient.METHOD_POST or method == HTTPClient.METHOD_PUT:
		json_body = JSON.stringify(body)

	var err = http.request(url, headers, method, json_body)
	if err != OK:
		_release_http_request(http)
		return ApiResult.error(-1, "HTTP 请求发送失败: %d" % err)

	# 6. 等待响应
	var response = await http.request_completed
	var result: int = response[0]
	var response_code: int = response[1]
	var _resp_headers: PackedStringArray = response[2]
	var resp_body: PackedByteArray = response[3]

	_release_http_request(http)

	# 7. 处理网络错误
	if result != HTTPRequest.RESULT_SUCCESS:
		return ApiResult.error(-1, "网络请求失败 (result=%d)" % result, response_code)

	# 8. 收到 401 且非重试 → 尝试刷新 Token 后重试
	if response_code == 401 and not is_retry:
		print("[ApiClient] 收到 401，尝试刷新 Token 后重试...")
		var refresh_ok = await _ensure_valid_token()
		if refresh_ok:
			return await _request(url, method, body, true)
		else:
			auth_required.emit()
			return ApiResult.error(-1, "Token 刷新失败，请重新登录", 401)

	# 9. 解析响应
	return _parse_response(resp_body, response_code)

# ======================== Token 刷新等待 ========================

func _ensure_valid_token() -> bool:
	if not AuthState.is_token_expired():
		return true

	if not AuthState.is_refreshing():
		AuthState.refresh_access_token()

	# 等待刷新结果
	var refreshed := false
	var done := false

	var on_refreshed = func():
		refreshed = true
		done = true
	var on_failed = func():
		refreshed = false
		done = true

	AuthState.token_refreshed.connect(on_refreshed, CONNECT_ONE_SHOT)
	AuthState.token_refresh_failed.connect(on_failed, CONNECT_ONE_SHOT)

	# 轮询等待，最多 15 秒
	var elapsed := 0.0
	while not done and elapsed < 15.0:
		await get_tree().process_frame
		elapsed += get_process_delta_time()

	# 清理可能未触发的连接
	if not done:
		if AuthState.token_refreshed.is_connected(on_refreshed):
			AuthState.token_refreshed.disconnect(on_refreshed)
		if AuthState.token_refresh_failed.is_connected(on_failed):
			AuthState.token_refresh_failed.disconnect(on_failed)
		return false

	return refreshed

# ======================== HTTPRequest 节点池 ========================

func _acquire_http_request() -> HTTPRequest:
	# 优先复用空闲节点
	if _pool.size() > 0:
		var http = _pool.pop_back()
		_pool_in_use.append(http)
		return http

	# 检查并发上限
	if _pool_in_use.size() >= _max_pool_size:
		return null

	# 创建新节点
	var http = HTTPRequest.new()
	http.timeout = _request_timeout
	add_child(http)
	_pool_in_use.append(http)
	return http

func _release_http_request(http: HTTPRequest) -> void:
	var idx = _pool_in_use.find(http)
	if idx >= 0:
		_pool_in_use.remove_at(idx)
	_pool.append(http)

# ======================== 内部辅助 ========================

func _build_url(path: String, query_params: Dictionary = {}) -> String:
	var base = AuthState.get_base_url()
	var url = base + path

	if query_params.size() > 0:
		var params: PackedStringArray = []
		for key in query_params:
			var value = str(query_params[key])
			params.append("%s=%s" % [key.uri_encode(), value.uri_encode()])
		url += "?" + "&".join(params)

	return url

func _parse_response(body: PackedByteArray, http_code: int) -> ApiResult:
	var body_str = body.get_string_from_utf8()
	if body_str == "":
		if http_code >= 200 and http_code < 300:
			return ApiResult.ok(null, http_code)
		return ApiResult.error(-1, "空响应 (HTTP %d)" % http_code, http_code)

	var json = JSON.new()
	if json.parse(body_str) != OK:
		return ApiResult.error(-1, "响应 JSON 解析失败", http_code)

	var data = json.get_data()
	if not data is Dictionary:
		return ApiResult.error(-1, "响应格式无效", http_code)

	var code: int = data.get("code", -1)
	var message: String = data.get("message", "")
	var resp_data = data.get("data")

	if code == 0:
		return ApiResult.ok(resp_data, http_code)
	else:
		return ApiResult.error(code, message, http_code)
