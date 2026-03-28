extends VBoxContainer

## 个人中心 - "我的" Tab
## 展示用户身份、等级、今日概览、同步状态

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

# 用户卡片
@onready var _username_label: Label = $UserPanel/UserVBox/UsernameLabel
@onready var _login_btn: MaterialButton = $UserPanel/UserVBox/AuthButtonsBox/LoginBtn
@onready var _register_btn: MaterialButton = $UserPanel/UserVBox/AuthButtonsBox/RegisterBtn
@onready var _logout_btn: MaterialButton = $UserPanel/UserVBox/AuthButtonsBox/LogoutBtn

# 等级面板
@onready var _level_label: Label = $LevelPanel/LevelVBox/LevelLabel
@onready var _xp_progress: MaterialProgressIndicator = $LevelPanel/LevelVBox/XpProgress
@onready var _xp_label: Label = $LevelPanel/LevelVBox/XpLabel

# 今日概览
@onready var _focus_value: Label = $OverviewGrid/FocusCard/FocusVBox/FocusValueLabel
@onready var _task_done_value: Label = $OverviewGrid/TaskDoneCard/TaskDoneVBox/TaskDoneValueLabel
@onready var _task_overdue_value: Label = $OverviewGrid/TaskOverdueCard/TaskOverdueVBox/TaskOverdueValueLabel
@onready var _daily_task_value: Label = $OverviewGrid/DailyTaskCard/DailyTaskVBox/DailyTaskValueLabel

# 同步状态
@onready var _sync_status_label: Label = $SyncPanel/SyncHBox/SyncStatusLabel
@onready var _sync_btn: MaterialButton = $SyncPanel/SyncHBox/SyncBtn


func _ready() -> void:
	_login_btn.set_filled_style(Color(0.35, 0.65, 0.95))
	_sync_btn.set_filled_style(Color(0.35, 0.65, 0.95))
	_xp_progress.progress_color = Color(0.35, 0.65, 0.95)
	_create_login_dialog()
	_create_register_dialog()
	_create_logout_dialog()
	_connect_signals()
	_refresh()


# ======================== 信号连接 ========================

func _connect_signals() -> void:
	_login_btn.pressed.connect(_on_login_btn_pressed)
	_register_btn.pressed.connect(_on_register_btn_pressed)
	_logout_btn.pressed.connect(_on_logout_btn_pressed)
	_sync_btn.pressed.connect(_on_sync_btn_pressed)

	AuthState.auth_state_changed.connect(func(_logged_in): _refresh())
	AuthState.login_succeeded.connect(_on_login_succeeded)
	AuthState.login_failed.connect(_on_login_failed)
	AuthState.register_succeeded.connect(_on_register_succeeded)
	AuthState.register_failed.connect(_on_register_failed)
	AuthState.logout_completed.connect(func(): _refresh())

	LevelState.level_state_changed.connect(func(_data): _refresh_level())
	LevelState.data_loaded.connect(_refresh_level)

	TaskState.task_added.connect(func(_t): _refresh_overview())
	TaskState.task_removed.connect(func(_id): _refresh_overview())
	TaskState.task_state_changed.connect(func(_t): _refresh_overview())
	TaskState.data_loaded.connect(_refresh_overview)

	AchievementState.daily_task_state_updated.connect(func(_d): _refresh_overview())
	AchievementState.daily_task_completed.connect(func(_d): _refresh_overview())
	AchievementState.data_loaded.connect(_refresh_overview)

	if StatsState:
		StatsState.record_added.connect(func(_r): _refresh_overview())
		StatsState.record_removed.connect(func(_id): _refresh_overview())
		StatsState.data_loaded.connect(_refresh_overview)

	SyncState.sync_started.connect(func(): _refresh_sync())
	SyncState.sync_completed.connect(func(_s, _sum): _refresh_sync())
	SyncState.sync_error.connect(func(_msg): _refresh_sync())


# ======================== 数据刷新 ========================

func _refresh() -> void:
	_refresh_auth()
	_refresh_level()
	_refresh_overview()
	_refresh_sync()


func _refresh_auth() -> void:
	var logged_in := AuthState.is_logged_in()
	if logged_in:
		_username_label.text = AuthState.get_username()
		_login_btn.visible = false
		_register_btn.visible = false
		_logout_btn.visible = true
	else:
		_username_label.text = "未登录"
		_login_btn.visible = true
		_register_btn.visible = true
		_logout_btn.visible = false


func _refresh_level() -> void:
	_level_label.text = "Lv.%d" % LevelState.level
	var xp_next := LevelState.get_xp_for_next_level()
	_xp_progress.set_progress_value(LevelState.get_progress())
	_xp_label.text = "%d/%d XP" % [LevelState.xp, xp_next]


func _refresh_overview() -> void:
	# 今日专注
	if StatsState:
		var seconds := StatsState.get_today_focus_seconds()
		_focus_value.text = DateUtil.format_duration(seconds)
	else:
		_focus_value.text = "0 分钟"

	# 完成任务
	_task_done_value.text = str(TaskState.get_completed_count())

	# 逾期任务
	_task_overdue_value.text = str(TaskState.get_overdue_tasks().size())

	# 每日任务进度
	var daily_tasks := AchievementState.get_daily_tasks()
	var daily_total := daily_tasks.size()
	var daily_done := 0
	for task in daily_tasks:
		if task.get("is_completed", false):
			daily_done += 1
	_daily_task_value.text = "%d/%d" % [daily_done, daily_total]


func _refresh_sync() -> void:
	if not AuthState.is_logged_in():
		_sync_status_label.text = "登录后可同步数据"
		_sync_btn.disabled = true
		return

	_sync_btn.disabled = false
	_sync_status_label.text = "数据同步已就绪"


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

	_login_dialog.add_button("取消").pressed.connect(func(): _login_dialog.hide_dialog())
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
	AuthState.login(username, password)


func _on_login_succeeded(_user_data: Dictionary) -> void:
	_login_dialog.hide_dialog()
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

	_register_dialog.add_button("取消").pressed.connect(func(): _register_dialog.hide_dialog())
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
	AuthState.register(username, password)


func _on_register_succeeded(_user_data: Dictionary) -> void:
	_register_dialog.hide_dialog()
	_register_confirm_btn.disabled = false


func _on_register_failed(_code: int, msg: String) -> void:
	_register_error_label.text = msg
	_register_error_label.visible = true
	_register_confirm_btn.disabled = false


# ======================== 登出 Dialog ========================

func _create_logout_dialog() -> void:
	_logout_dialog = MaterialDialog.new()
	add_child(_logout_dialog)
	_logout_dialog.dialog_confirmed.connect(func(): AuthState.logout())


func _on_logout_btn_pressed() -> void:
	_logout_dialog.show_confirm_dialog("登出", "确定要退出登录吗？")


# ======================== 同步 ========================

func _on_sync_btn_pressed() -> void:
	SyncState.trigger_sync()
