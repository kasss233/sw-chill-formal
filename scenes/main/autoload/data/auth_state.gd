extends Node

# --- 信号 ---
signal login_succeeded(user_data: Dictionary) # {user_id, username}
signal login_failed(error_code: int, message: String)
signal register_succeeded(user_data: Dictionary)
signal register_failed(error_code: int, message: String)
signal logout_completed
signal token_refreshed
signal token_refresh_failed
signal auth_state_changed(is_logged_in: bool)

# --- 内部状态 ---
var _access_token: String = ""
var _refresh_token: String = ""
var _user_id: String = ""
var _username: String = ""
var _expires_at: int = 0 # Unix 秒级时间戳

var _refresh_timer: Timer = null
var _is_refreshing: bool = false
var _http_request: HTTPRequest = null
var _pending_action: String = "" # "login" / "register" / "refresh" / "logout"

var _base_url: String = "http://106.54.18.206:8000/api/v1"

const AUTH_SAVE_PATH = "user://auth.json"
const SERVER_CONFIG_PATH = "user://server_config.cfg"
const REFRESH_ADVANCE_SECONDS = 300 # 提前 5 分钟刷新

func _ready() -> void:
	_http_request = HTTPRequest.new()
	_http_request.timeout = 15.0
	_http_request.request_completed.connect(_on_request_completed)
	add_child(_http_request)

	_refresh_timer = Timer.new()
	_refresh_timer.one_shot = true
	_refresh_timer.timeout.connect(_on_refresh_timer_timeout)
	add_child(_refresh_timer)
	
	_load_base_url()
	_load_data()

# ======================== 公共查询 API ========================

func is_logged_in() -> bool:
	return _access_token != "" and _refresh_token != ""

func get_access_token() -> String:
	return _access_token

func get_user_id() -> String:
	return _user_id

func get_username() -> String:
	return _username

func get_base_url() -> String:
	return _base_url

func is_token_expired() -> bool:
	if _expires_at == 0:
		return true
	return Time.get_unix_time_from_system() >= _expires_at

func is_refreshing() -> bool:
	return _is_refreshing

# ======================== 认证操作 API ========================

func register(username: String, password: String, display_name: String = "") -> void:
	if _pending_action != "":
		push_warning("[AuthState] 请求进行中，忽略重复调用")
		return

	var body := {"username": username, "password": password}
	if display_name != "":
		body["display_name"] = display_name

	_pending_action = "register"
	var url = _base_url + "/auth/register"
	var json_body = JSON.stringify(body)
	var headers = ["Content-Type: application/json"]
	var err = _http_request.request(url, headers, HTTPClient.METHOD_POST, json_body)
	if err != OK:
		_pending_action = ""
		register_failed.emit(-1, "HTTP 请求发送失败: %d" % err)
		print("[AuthState] Register request failed: %d" % err)

func login(username: String, password: String) -> void:
	if _pending_action != "":
		push_warning("[AuthState] 请求进行中，忽略重复调用")
		return

	var body := {"username": username, "password": password}
	_pending_action = "login"
	var url = _base_url + "/auth/login"
	var json_body = JSON.stringify(body)
	var headers = ["Content-Type: application/json"]
	var err = _http_request.request(url, headers, HTTPClient.METHOD_POST, json_body)
	if err != OK:
		_pending_action = ""
		login_failed.emit(-1, "HTTP 请求发送失败: %d" % err)
		print("[AuthState] Login request failed: %d" % err)

func logout() -> void:
	if _pending_action != "":
		push_warning("[AuthState] 请求进行中，忽略重复调用")
		return

	if not is_logged_in():
		_clear_auth_data()
		logout_completed.emit()
		auth_state_changed.emit(false)
		return

	_pending_action = "logout"
	var url = _base_url + "/auth/logout"
	var headers = [
		"Content-Type: application/json",
		"Authorization: Bearer " + _access_token
	]
	var err = _http_request.request(url, headers, HTTPClient.METHOD_POST, "")
	if err != OK:
		_pending_action = ""
		# logout 即使请求失败也清除本地数据
		_clear_auth_data()
		logout_completed.emit()
		auth_state_changed.emit(false)
		print("[AuthState] Logout request failed, cleared local data anyway")

func refresh_access_token() -> void:
	if _is_refreshing:
		return
	if _refresh_token == "":
		token_refresh_failed.emit()
		return

	_is_refreshing = true
	# 如果有其他操作挂起，需要等待。refresh 使用独立逻辑判断
	if _pending_action != "" and _pending_action != "refresh":
		# 其他操作进行中，等待完成后再刷新
		_is_refreshing = false
		push_warning("[AuthState] 其他请求进行中，延迟刷新")
		# 延迟 1 秒后重试
		get_tree().create_timer(1.0).timeout.connect(func():
			_is_refreshing = false
			refresh_access_token()
		)
		return

	_pending_action = "refresh"
	var body := {"refresh_token": _refresh_token}
	var url = _base_url + "/auth/refresh"
	var json_body = JSON.stringify(body)
	var headers = ["Content-Type: application/json"]
	var err = _http_request.request(url, headers, HTTPClient.METHOD_POST, json_body)
	if err != OK:
		_pending_action = ""
		_is_refreshing = false
		token_refresh_failed.emit()
		print("[AuthState] Refresh request failed: %d" % err)

# ======================== base_url 配置 ========================

func set_base_url(url: String) -> void:
	_base_url = url.rstrip("/")
	_save_base_url()
	print("[AuthState] Base URL 已更新: %s" % _base_url)

func _load_base_url() -> void:
	var config = ConfigFile.new()
	if config.load(SERVER_CONFIG_PATH) == OK:
		_base_url = config.get_value("server", "base_url", _base_url)
	print("[AuthState] Base URL: %s" % _base_url)

func _save_base_url() -> void:
	var config = ConfigFile.new()
	config.set_value("server", "base_url", _base_url)
	config.save(SERVER_CONFIG_PATH)

# ======================== HTTP 回调 ========================

func _on_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	var action = _pending_action
	_pending_action = ""

	if result != HTTPRequest.RESULT_SUCCESS:
		_handle_request_error(action, result, response_code)
		return

	var json = JSON.new()
	var parse_err = json.parse(body.get_string_from_utf8())
	if parse_err != OK:
		_handle_parse_error(action, response_code)
		return

	var data = json.get_data()
	if not data is Dictionary:
		_handle_parse_error(action, response_code)
		return

	var code: int = data.get("code", -1)
	var message: String = data.get("message", "")
	var resp_data = data.get("data")

	match action:
		"register":
			_handle_register_response(code, message, resp_data, response_code)
		"login":
			_handle_login_response(code, message, resp_data, response_code)
		"refresh":
			_handle_refresh_response(code, message, resp_data, response_code)
		"logout":
			_handle_logout_response()

func _handle_register_response(code: int, message: String, data: Variant, http_code: int) -> void:
	if code == 0 and data is Dictionary:
		_apply_auth_data(data)
		var user_data := {"user_id": _user_id, "username": _username}
		register_succeeded.emit(user_data)
		auth_state_changed.emit(true)
		print("[AuthState] 注册成功: %s" % _username)
	else:
		register_failed.emit(code, message)
		print("[AuthState] 注册失败: [%d] %s (HTTP %d)" % [code, message, http_code])

func _handle_login_response(code: int, message: String, data: Variant, http_code: int) -> void:
	if code == 0 and data is Dictionary:
		_apply_auth_data(data)
		var user_data := {"user_id": _user_id, "username": _username}
		login_succeeded.emit(user_data)
		auth_state_changed.emit(true)
		print("[AuthState] 登录成功: %s" % _username)
	else:
		login_failed.emit(code, message)
		print("[AuthState] 登录失败: [%d] %s (HTTP %d)" % [code, message, http_code])

func _handle_refresh_response(code: int, message: String, data: Variant, http_code: int) -> void:
	_is_refreshing = false
	if code == 0 and data is Dictionary:
		_access_token = data.get("access_token", "")
		_refresh_token = data.get("refresh_token", "")
		var expires_in: int = data.get("expires_in", 3600)
		_expires_at = int(Time.get_unix_time_from_system()) + expires_in
		_save_data()
		_schedule_refresh(expires_in)
		token_refreshed.emit()
		print("[AuthState] Token 刷新成功，%d 秒后过期" % expires_in)
	else:
		print("[AuthState] Token 刷新失败: [%d] %s (HTTP %d)" % [code, message, http_code])
		_clear_auth_data()
		token_refresh_failed.emit()
		auth_state_changed.emit(false)

func _handle_logout_response() -> void:
	_clear_auth_data()
	logout_completed.emit()
	auth_state_changed.emit(false)
	print("[AuthState] 登出完成")

func _handle_request_error(action: String, result: int, http_code: int) -> void:
	var err_msg = "网络请求失败 (result=%d, http=%d)" % [result, http_code]
	print("[AuthState] %s 失败: %s" % [action, err_msg])

	match action:
		"register":
			register_failed.emit(-1, err_msg)
		"login":
			login_failed.emit(-1, err_msg)
		"refresh":
			_is_refreshing = false
			token_refresh_failed.emit()
		"logout":
			# logout 即使失败也清除本地数据
			_clear_auth_data()
			logout_completed.emit()
			auth_state_changed.emit(false)

func _handle_parse_error(action: String, http_code: int) -> void:
	var err_msg = "响应解析失败 (HTTP %d)" % http_code
	print("[AuthState] %s: %s" % [action, err_msg])

	match action:
		"register":
			register_failed.emit(-1, err_msg)
		"login":
			login_failed.emit(-1, err_msg)
		"refresh":
			_is_refreshing = false
			token_refresh_failed.emit()
		"logout":
			_clear_auth_data()
			logout_completed.emit()
			auth_state_changed.emit(false)

# ======================== 内部辅助 ========================

func _apply_auth_data(data: Dictionary) -> void:
	_access_token = data.get("access_token", "")
	_refresh_token = data.get("refresh_token", "")
	_user_id = str(data.get("user_id", ""))
	_username = data.get("username", "")
	var expires_in: int = data.get("expires_in", 3600)
	_expires_at = int(Time.get_unix_time_from_system()) + expires_in

	_save_data()
	_schedule_refresh(expires_in)

func _schedule_refresh(expires_in: int) -> void:
	_refresh_timer.stop()
	var delay = max(expires_in - REFRESH_ADVANCE_SECONDS, 30)
	_refresh_timer.wait_time = delay
	_refresh_timer.start()
	print("[AuthState] 已安排 %d 秒后刷新 Token" % delay)

func _on_refresh_timer_timeout() -> void:
	print("[AuthState] 定时刷新 Token")
	refresh_access_token()

func _clear_auth_data() -> void:
	_access_token = ""
	_refresh_token = ""
	_user_id = ""
	_username = ""
	_expires_at = 0
	_refresh_timer.stop()
	_save_data()

# ======================== 持久化 ========================

func _save_data() -> void:
	var data := {
		"version": 1,
		"access_token": _access_token,
		"refresh_token": _refresh_token,
		"user_id": _user_id,
		"username": _username,
		"expires_at": _expires_at,
	}
	var json_string = JSON.stringify(data, "\t")
	var file = FileAccess.open(AUTH_SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(json_string)
		file.close()
	else:
		push_error("[AuthState] 保存认证数据失败: %s" % AUTH_SAVE_PATH)

func _load_data() -> void:
	if not FileAccess.file_exists(AUTH_SAVE_PATH):
		print("[AuthState] 无本地认证数据，保持未登录状态")
		return

	var file = FileAccess.open(AUTH_SAVE_PATH, FileAccess.READ)
	if not file:
		push_error("[AuthState] 无法打开认证文件")
		return

	var json_string = file.get_as_text()
	file.close()

	var json = JSON.new()
	if json.parse(json_string) != OK:
		push_error("[AuthState] 认证数据解析失败: %s" % json.get_error_message())
		return

	var data = json.get_data()
	if not data is Dictionary:
		push_error("[AuthState] 认证数据格式无效")
		return

	_access_token = data.get("access_token", "")
	_refresh_token = data.get("refresh_token", "")
	_user_id = str(data.get("user_id", ""))
	_username = data.get("username", "")
	_expires_at = data.get("expires_at", 0)

	# 冷启动检查 token 状态
	if _access_token == "" or _refresh_token == "":
		print("[AuthState] 本地无有效 Token，保持未登录状态")
		return

	var now = Time.get_unix_time_from_system()
	if now < _expires_at:
		# token 仍有效，安排定时刷新
		var remaining = _expires_at - int(now)
		_schedule_refresh(remaining)
		auth_state_changed.emit(true)
		print("[AuthState] Token 有效，%d 秒后过期，用户: %s" % [remaining, _username])
	elif _refresh_token != "":
		# token 已过期但有 refresh_token，立即刷新
		print("[AuthState] Token 已过期，尝试刷新...")
		refresh_access_token()
	else:
		print("[AuthState] 无有效 Token，保持未登录状态")
