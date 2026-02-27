extends Control

## Auth测试页 - 测试 AuthState 单例

# UI节点引用
@onready var info_label: RichTextLabel = $MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/InfoLabel
@onready var base_url_input: LineEdit = $MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/InputSection/BaseUrlInput
@onready var username_input: LineEdit = $MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/InputSection/UsernameInput
@onready var password_input: LineEdit = $MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/InputSection/PasswordInput
@onready var display_name_input: LineEdit = $MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/InputSection/DisplayNameInput

# 测试按钮
@onready var set_base_url_btn: Button = $MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/ButtonSection/SetBaseUrlBtn
@onready var register_btn: Button = $MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/ButtonSection/RegisterBtn
@onready var login_btn: Button = $MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/ButtonSection/LoginBtn
@onready var logout_btn: Button = $MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/ButtonSection/LogoutBtn
@onready var refresh_token_btn: Button = $MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/ButtonSection/RefreshTokenBtn
@onready var check_status_btn: Button = $MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/ButtonSection/CheckStatusBtn

func _ready() -> void:
	# 连接按钮信号
	set_base_url_btn.pressed.connect(_on_set_base_url_pressed)
	register_btn.pressed.connect(_on_register_pressed)
	login_btn.pressed.connect(_on_login_pressed)
	logout_btn.pressed.connect(_on_logout_pressed)
	refresh_token_btn.pressed.connect(_on_refresh_token_pressed)
	check_status_btn.pressed.connect(_on_check_status_pressed)

	# 监听 AuthState 信号
	AuthState.login_succeeded.connect(_on_login_succeeded)
	AuthState.login_failed.connect(_on_login_failed)
	AuthState.register_succeeded.connect(_on_register_succeeded)
	AuthState.register_failed.connect(_on_register_failed)
	AuthState.logout_completed.connect(_on_logout_completed)
	AuthState.token_refreshed.connect(_on_token_refreshed)
	AuthState.token_refresh_failed.connect(_on_token_refresh_failed)
	AuthState.auth_state_changed.connect(_on_auth_state_changed)

	# 显示当前 base_url 到 placeholder
	base_url_input.placeholder_text = "服务器地址 (当前: %s)" % AuthState.get_base_url()

	_log_info("Auth测试面板已就绪")
	_log_info("所有操作通过 AuthState 单例执行")

# ======================== 按钮回调 ========================

## 设置服务器地址
func _on_set_base_url_pressed() -> void:
	var url = base_url_input.text.strip_edges()
	if url.is_empty():
		_log_error("请输入服务器地址")
		return

	_log_info("调用 AuthState.set_base_url('%s')" % url)
	AuthState.set_base_url(url)
	base_url_input.placeholder_text = "服务器地址 (当前: %s)" % AuthState.get_base_url()
	_log_success("服务器地址已更新: %s" % AuthState.get_base_url())

## 注册
func _on_register_pressed() -> void:
	var username = username_input.text.strip_edges()
	var password = password_input.text
	var display_name = display_name_input.text.strip_edges()

	if username.is_empty() or password.is_empty():
		_log_error("用户名和密码不能为空")
		return

	_log_info("调用 AuthState.register('%s', '***', '%s')" % [username, display_name])
	AuthState.register(username, password, display_name)

## 登录
func _on_login_pressed() -> void:
	var username = username_input.text.strip_edges()
	var password = password_input.text

	if username.is_empty() or password.is_empty():
		_log_error("用户名和密码不能为空")
		return

	_log_info("调用 AuthState.login('%s', '***')" % username)
	AuthState.login(username, password)

## 登出
func _on_logout_pressed() -> void:
	_log_info("调用 AuthState.logout()")
	AuthState.logout()

## 刷新 Token
func _on_refresh_token_pressed() -> void:
	_log_info("调用 AuthState.refresh_access_token()")
	AuthState.refresh_access_token()

## 查看认证状态
func _on_check_status_pressed() -> void:
	_log_info("当前认证状态:")
	_log_data("  is_logged_in: %s" % AuthState.is_logged_in())
	_log_data("  username: %s" % AuthState.get_username())
	_log_data("  user_id: %s" % AuthState.get_user_id())
	_log_data("  token_expired: %s" % AuthState.is_token_expired())
	_log_data("  is_refreshing: %s" % AuthState.is_refreshing())
	_log_data("  base_url: %s" % AuthState.get_base_url())

# ======================== AuthState 信号回调 ========================

func _on_login_succeeded(user_data: Dictionary) -> void:
	_log_success("登录成功! user_id=%s, username=%s" % [user_data.get("user_id", ""), user_data.get("username", "")])

func _on_login_failed(error_code: int, message: String) -> void:
	_log_error("登录失败: [%d] %s" % [error_code, message])

func _on_register_succeeded(user_data: Dictionary) -> void:
	_log_success("注册成功! user_id=%s, username=%s" % [user_data.get("user_id", ""), user_data.get("username", "")])

func _on_register_failed(error_code: int, message: String) -> void:
	_log_error("注册失败: [%d] %s" % [error_code, message])

func _on_logout_completed() -> void:
	_log_success("登出完成")

func _on_token_refreshed() -> void:
	_log_success("Token 刷新成功")

func _on_token_refresh_failed() -> void:
	_log_error("Token 刷新失败")

func _on_auth_state_changed(is_logged_in: bool) -> void:
	_log_info("认证状态变更: is_logged_in=%s" % is_logged_in)

# ======================== 日志输出 ========================

func _log_info(message: String) -> void:
	info_label.append_text("[color=white]%s[/color]\n" % message)
	print("[AuthTest] %s" % message)

func _log_success(message: String) -> void:
	info_label.append_text("[color=green]%s[/color]\n" % message)
	print("[AuthTest] %s" % message)

func _log_error(message: String) -> void:
	info_label.append_text("[color=red]%s[/color]\n" % message)
	print("[AuthTest] ERROR: %s" % message)

func _log_data(message: String) -> void:
	info_label.append_text("[color=cyan]%s[/color]\n" % message)
	print("[AuthTest] %s" % message)
