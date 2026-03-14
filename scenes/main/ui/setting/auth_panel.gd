class_name AuthPanel
extends VBoxContainer

@onready var _server_row: HBoxContainer = $ServerRow
@onready var _server_url_input: LineEdit = $ServerRow/ServerUrlInput
@onready var _logged_out_row: HBoxContainer = $LoggedOutRow
@onready var _logged_in_row: HBoxContainer = $LoggedInRow
@onready var _user_label: Label = $LoggedInRow/UserLabel
@onready var _login_btn: MaterialButton = $LoggedOutRow/LoginButton
@onready var _register_btn: MaterialButton = $LoggedOutRow/RegisterButton
@onready var _logout_btn: MaterialButton = $LoggedInRow/LogoutButton

# Dialog
var _login_dialog: MaterialDialog
var _register_dialog: MaterialDialog
var _logout_dialog: MaterialDialog

# 登录 dialog 控件
var _login_username_input: LineEdit
var _login_password_input: LineEdit
var _login_error_label: Label
var _login_confirm_btn: MaterialButton

# 注册 dialog 控件
var _register_username_input: LineEdit
var _register_password_input: LineEdit
var _register_confirm_password_input: LineEdit
var _register_error_label: Label
var _register_confirm_btn: MaterialButton


func _ready() -> void:
	_server_url_input.text = AuthState.get_base_url()

	_create_login_dialog()
	_create_register_dialog()
	_create_logout_dialog()

	# 连接 AuthState 信号
	AuthState.auth_state_changed.connect(_on_auth_state_changed)
	AuthState.login_succeeded.connect(_on_login_succeeded)
	AuthState.login_failed.connect(_on_login_failed)
	AuthState.register_succeeded.connect(_on_register_succeeded)
	AuthState.register_failed.connect(_on_register_failed)
	AuthState.logout_completed.connect(_on_logout_completed)

	# 连接按钮信号
	_login_btn.pressed.connect(_on_login_btn_pressed)
	_register_btn.pressed.connect(_on_register_btn_pressed)
	_logout_btn.pressed.connect(_on_logout_btn_pressed)
	_server_url_input.focus_exited.connect(_on_server_url_focus_exited)

	_update_ui()


# ======================== UI 状态 ========================

func _on_auth_state_changed(_is_logged_in: bool) -> void:
	_update_ui()


func _update_ui() -> void:
	var logged_in := AuthState.is_logged_in()
	_logged_out_row.visible = not logged_in
	_logged_in_row.visible = logged_in
	_server_row.visible = not logged_in
	if logged_in:
		_user_label.text = "已登录: %s" % AuthState.get_username()


# ======================== 登录 Dialog ========================

func _create_login_dialog() -> void:
	_login_dialog = MaterialDialog.new()
	_login_dialog.dialog_title = "登录"
	_login_dialog.dialog_size = MaterialDialog.DialogSize.SMALL
	add_child(_login_dialog)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)

	_login_username_input = LineEdit.new()
	_login_username_input.placeholder_text = "用户名"
	_login_username_input.custom_minimum_size = Vector2(200, 36)
	vbox.add_child(_login_username_input)

	_login_password_input = LineEdit.new()
	_login_password_input.placeholder_text = "密码"
	_login_password_input.secret = true
	_login_password_input.custom_minimum_size = Vector2(200, 36)
	vbox.add_child(_login_password_input)

	_login_error_label = Label.new()
	_login_error_label.add_theme_color_override("font_color", Color(1, 0.3, 0.3))
	_login_error_label.add_theme_font_size_override("font_size", 12)
	_login_error_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_login_error_label.visible = false
	vbox.add_child(_login_error_label)

	_login_dialog.set_custom_content(vbox)

	_login_dialog.add_button("取消").pressed.connect(_on_login_cancel)
	_login_confirm_btn = _login_dialog.add_button("登录")
	_login_confirm_btn.pressed.connect(_on_login_confirm)


func _on_login_btn_pressed() -> void:
	_login_username_input.text = ""
	_login_password_input.text = ""
	_login_error_label.visible = false
	_login_confirm_btn.disabled = false
	_login_dialog.show_dialog()


func _on_login_confirm() -> void:
	var username := _login_username_input.text.strip_edges()
	var password := _login_password_input.text

	if username.is_empty() or password.is_empty():
		_login_error_label.text = "用户名和密码不能为空"
		_login_error_label.visible = true
		return

	_login_error_label.visible = false
	_login_confirm_btn.disabled = true
	_save_server_url()
	AuthState.login(username, password)


func _on_login_cancel() -> void:
	_login_dialog.hide_dialog()


func _on_login_succeeded(_user_data: Dictionary) -> void:
	_login_dialog.hide_dialog()
	_login_username_input.text = ""
	_login_password_input.text = ""
	_login_confirm_btn.disabled = false


func _on_login_failed(_code: int, msg: String) -> void:
	_login_error_label.text = msg
	_login_error_label.visible = true
	_login_confirm_btn.disabled = false


# ======================== 注册 Dialog ========================

func _create_register_dialog() -> void:
	_register_dialog = MaterialDialog.new()
	_register_dialog.dialog_title = "注册"
	_register_dialog.dialog_size = MaterialDialog.DialogSize.SMALL
	add_child(_register_dialog)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)

	_register_username_input = LineEdit.new()
	_register_username_input.placeholder_text = "用户名"
	_register_username_input.custom_minimum_size = Vector2(200, 36)
	vbox.add_child(_register_username_input)

	_register_password_input = LineEdit.new()
	_register_password_input.placeholder_text = "密码"
	_register_password_input.secret = true
	_register_password_input.custom_minimum_size = Vector2(200, 36)
	vbox.add_child(_register_password_input)

	_register_confirm_password_input = LineEdit.new()
	_register_confirm_password_input.placeholder_text = "确认密码"
	_register_confirm_password_input.secret = true
	_register_confirm_password_input.custom_minimum_size = Vector2(200, 36)
	vbox.add_child(_register_confirm_password_input)

	_register_error_label = Label.new()
	_register_error_label.add_theme_color_override("font_color", Color(1, 0.3, 0.3))
	_register_error_label.add_theme_font_size_override("font_size", 12)
	_register_error_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_register_error_label.visible = false
	vbox.add_child(_register_error_label)

	_register_dialog.set_custom_content(vbox)

	_register_dialog.add_button("取消").pressed.connect(_on_register_cancel)
	_register_confirm_btn = _register_dialog.add_button("注册")
	_register_confirm_btn.pressed.connect(_on_register_confirm)


func _on_register_btn_pressed() -> void:
	_register_username_input.text = ""
	_register_password_input.text = ""
	_register_confirm_password_input.text = ""
	_register_error_label.visible = false
	_register_confirm_btn.disabled = false
	_register_dialog.show_dialog()


func _on_register_confirm() -> void:
	var username := _register_username_input.text.strip_edges()
	var password := _register_password_input.text
	var confirm := _register_confirm_password_input.text

	if username.is_empty() or password.is_empty():
		_register_error_label.text = "用户名和密码不能为空"
		_register_error_label.visible = true
		return

	if password != confirm:
		_register_error_label.text = "两次输入的密码不一致"
		_register_error_label.visible = true
		return

	_register_error_label.visible = false
	_register_confirm_btn.disabled = true
	_save_server_url()
	AuthState.register(username, password)


func _on_register_cancel() -> void:
	_register_dialog.hide_dialog()


func _on_register_succeeded(_user_data: Dictionary) -> void:
	_register_dialog.hide_dialog()
	_register_username_input.text = ""
	_register_password_input.text = ""
	_register_confirm_password_input.text = ""
	_register_confirm_btn.disabled = false


func _on_register_failed(_code: int, msg: String) -> void:
	_register_error_label.text = msg
	_register_error_label.visible = true
	_register_confirm_btn.disabled = false


# ======================== 登出 Dialog ========================

func _create_logout_dialog() -> void:
	_logout_dialog = MaterialDialog.new()
	add_child(_logout_dialog)
	_logout_dialog.dialog_confirmed.connect(_on_logout_confirmed)


func _on_logout_btn_pressed() -> void:
	_logout_dialog.show_confirm_dialog("登出", "确定要退出登录吗？")


func _on_logout_confirmed() -> void:
	AuthState.logout()


func _on_logout_completed() -> void:
	_update_ui()


# ======================== 服务器地址 ========================

func _on_server_url_focus_exited() -> void:
	_save_server_url()


func _save_server_url() -> void:
	var url := _server_url_input.text.strip_edges()
	if not url.is_empty():
		AuthState.set_base_url(url)
