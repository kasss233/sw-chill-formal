extends UI
## 竖屏 UI 控制器
## 管理模块互斥、对话模式切换、更多菜单、点击外部关闭、键盘避让

# --- 节点引用 ---
@onready var _keyboard_spacer: MarginContainer = %KeyboardSpacer
@onready var _bottom_bar: HBoxContainer = $MarginContainer/VBoxContainer/BottomBar
@onready var _dialogue_header: HBoxContainer = $MarginContainer/VBoxContainer/DialogueHeader
@onready var _close_dialogue_button: MaterialButton = $MarginContainer/VBoxContainer/DialogueHeader/CloseDialogueButton
@onready var _dialogue_box = $MarginContainer/VBoxContainer/DialogueBox
@onready var _input_box = $MarginContainer/VBoxContainer/InputBox
@onready var _more_button: MaterialButton = $MarginContainer/VBoxContainer/BottomBar/ModulePanel/FrostedPanel/MarginContainer/HBoxContainer/MoreButton
@onready var _chat_button: MaterialButton = $MarginContainer/VBoxContainer/BottomBar/ChatButtonPanel/MarginContainer/ChatButton
@onready var _more_menu: MaterialMenu = $MoreMenu

# 模块引用
@onready var _task_module = $MarginContainer/VBoxContainer/BottomBar/ModulePanel/FrostedPanel/MarginContainer/HBoxContainer/TaskModule
@onready var _notebook_tab = $MarginContainer/VBoxContainer/BottomBar/ModulePanel/FrostedPanel/MarginContainer/HBoxContainer/NoteBookTab
@onready var _pomodoro_module = $MarginContainer/VBoxContainer/BottomBar/ModulePanel/FrostedPanel/MarginContainer/HBoxContainer/PomodoroTechniqueModule
@onready var _bottom_bar_panel: FrostedPanel = $MarginContainer/VBoxContainer/BottomBar/ModulePanel/FrostedPanel
@onready var _achievement_module = $AchievementModule
@onready var _room_decor_module = $RoomDecorModule
@onready var _calendar_tab = $CalendarTab
@onready var _env_setter = $EnvSetter
@onready var _music_module_mobile = $MusicModuleMobile

# --- 状态 ---
var _last_keyboard_height: int = 0
var _active_module_id: String = ""
var _dialogue_mode: bool = false

# 模块注册表: { layout_id: { node, toggle } }
var _module_registry: Dictionary = {}

# 模块名 → layout_id 映射（供 Agent 调用）
const _MODULE_NAME_MAP: Dictionary = {
	"task": "task",
	"notebook": "notebookmobile",
	"pomodoro": "pomodorotechnique",
	"achievement": "achievement",
	"room_decor": "room_decor",
	"calendar": "calendar",
	"setting": "setter",
	"music": "musiclist",
}


# === 生命周期 ===

func _ready() -> void:
	super._ready()
	# 让空白区域点击穿透到 _unhandled_input
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	$MarginContainer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$MarginContainer/VBoxContainer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_register_modules()
	_setup_chat_button()
	_setup_more_menu()
	_init_dialogue_hidden()
	# 监听 ChatState 自动进入对话模式
	ChatState.response_started.connect(_on_portrait_response_started)
	# 监听 LayerManager 的 Agent 模块控制信号
	LayerManager.module_show_requested.connect(_on_agent_show_module)
	LayerManager.module_hide_requested.connect(_on_agent_hide_module)
	# 监听音乐面板可见性
	_music_module_mobile.panel.visibility_changed.connect(_on_music_panel_visibility_changed)
	# AI 流光信号
	ChatState.ai_glow_started.connect(_on_ai_glow_started)
	ChatState.ai_glow_stopped.connect(_on_ai_glow_stopped)
	ChatState.response_started.connect(_on_ai_response_glow_start)
	ChatState.response_completed.connect(_on_ai_response_glow_stop)


# === 模块注册 + 互斥 ===

func _register_modules() -> void:
	_register("task", _task_module, _task_module.todo_button)
	_register("notebookmobile", _notebook_tab, _notebook_tab.todo_button)
	_register("pomodorotechnique", _pomodoro_module, _pomodoro_module.pomodoro_button)
	_register("achievement", _achievement_module, _achievement_module.button)
	_register("room_decor", _room_decor_module, _room_decor_module.button)
	_register("calendar", _calendar_tab, _calendar_tab.toggle_button)
	_register("setter", _env_setter, null)


func _register(layout_id: String, module_node: Node, toggle_btn) -> void:
	_module_registry[layout_id] = { "node": module_node, "toggle": toggle_btn }
	if toggle_btn and toggle_btn is MaterialToggleButton:
		toggle_btn.state_changed.connect(
			_on_module_toggle_changed.bind(layout_id)
		)


func _on_module_toggle_changed(_old: int, new_state: int, layout_id: String) -> void:
	if new_state == 0:
		if _active_module_id == layout_id:
			_active_module_id = ""
		return
	# 打开新模块 → 关闭其他
	_close_other_modules(layout_id)
	_active_module_id = layout_id


func _close_other_modules(except: String) -> void:
	for id in _module_registry:
		if id == except:
			continue
		_module_registry[id]["node"].hide_module()
	# 同时关闭音乐展开面板
	if except != "musiclist":
		_music_module_mobile.hide_module()


func _on_music_panel_visibility_changed() -> void:
	if _music_module_mobile.panel.visible:
		_close_other_modules("musiclist")
		_active_module_id = "musiclist"
	elif _active_module_id == "musiclist":
		_active_module_id = ""


# === 点击外部关闭 ===

func _unhandled_input(event: InputEvent) -> void:
	# Escape / Android 返回键
	if event.is_action_pressed("ui_cancel"):
		if _handle_back():
			get_viewport().set_input_as_handled()
		return
	# 点击外部关闭
	if _active_module_id.is_empty() or _dialogue_mode:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_close_active_module()
		get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_handle_back()


func _handle_back() -> bool:
	if _dialogue_mode:
		_exit_dialogue_mode()
		return true
	if not _active_module_id.is_empty():
		_close_active_module()
		return true
	return false


func _close_active_module() -> void:
	if _active_module_id.is_empty():
		return
	if _active_module_id == "musiclist":
		_music_module_mobile.hide_module()
	else:
		var info = _module_registry.get(_active_module_id)
		if info:
			info["node"].hide_module()
	_active_module_id = ""


# === 对话模式 ===

func _init_dialogue_hidden() -> void:
	_dialogue_header.visible = false
	_dialogue_box.visible = false
	_input_box.visible = false


func _setup_chat_button() -> void:
	_chat_button.pressed.connect(_on_chat_button_pressed)
	_close_dialogue_button.pressed.connect(_on_close_dialogue_pressed)


func _on_chat_button_pressed() -> void:
	_enter_dialogue_mode()


func _on_close_dialogue_pressed() -> void:
	_exit_dialogue_mode()


func _enter_dialogue_mode() -> void:
	if _dialogue_mode:
		return
	_close_active_module()
	_dialogue_mode = true
	_bottom_bar.visible = false
	_dialogue_header.visible = true
	_dialogue_box.visible = true
	_input_box.visible = true
	# 淡入动画
	_dialogue_header.modulate.a = 0.0
	_dialogue_box.modulate.a = 0.0
	_input_box.modulate.a = 0.0
	var tween = create_tween().set_parallel(true)
	tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(_dialogue_header, "modulate:a", 1.0, 0.2)
	tween.tween_property(_dialogue_box, "modulate:a", 1.0, 0.2)
	tween.tween_property(_input_box, "modulate:a", 1.0, 0.2)


func _exit_dialogue_mode() -> void:
	if not _dialogue_mode:
		return
	_dialogue_mode = false
	_dialogue_header.visible = false
	_dialogue_box.visible = false
	_input_box.visible = false
	_bottom_bar.visible = true


# AI 主动响应时自动进入对话模式
func _on_portrait_response_started() -> void:
	if not _dialogue_mode:
		_enter_dialogue_mode()


# === 更多菜单 ===

func _setup_more_menu() -> void:
	_more_menu.add_item("成就")
	_more_menu.add_item("日历")
	_more_menu.add_item("房间装饰")
	_more_menu.add_item("环境设置")
	_more_button.pressed.connect(_on_more_button_pressed)
	_more_menu.item_pressed.connect(_on_more_menu_item_pressed)


func _on_more_button_pressed() -> void:
	_more_menu.popup_above(_more_button, Vector2(0, -4))


func _on_more_menu_item_pressed(index: int, _item) -> void:
	match index:
		0: _open_module("achievement")
		1: _open_module("calendar")
		2: _open_module("room_decor")
		3: _open_module("setter")


func _open_module(layout_id: String) -> void:
	_close_other_modules(layout_id)
	var info = _module_registry.get(layout_id)
	if info:
		info["node"].show_module()
	_active_module_id = layout_id


# === 键盘避让 ===

func _process(_delta: float) -> void:
	if Engine.is_editor_hint() or not OS.has_feature("mobile"):
		return

	var keyboard_height := DisplayServer.virtual_keyboard_get_height()
	if keyboard_height == _last_keyboard_height:
		return

	_last_keyboard_height = keyboard_height

	# 将像素高度转换为视口坐标
	var window_height := float(DisplayServer.window_get_size().y)
	var viewport_height := get_viewport().get_visible_rect().size.y
	var scale := viewport_height / window_height if window_height > 0.0 else 1.0
	var scaled_height := keyboard_height * scale

	# 根据当前模式选择底部占用高度
	var bottom_h: float
	if _dialogue_mode:
		bottom_h = _input_box.size.y
	else:
		bottom_h = _bottom_bar.size.y
	_keyboard_spacer.custom_minimum_size.y = maxf(0.0, scaled_height - bottom_h)


# === Agent 模块控制（监听 LayerManager 信号） ===

func _on_agent_show_module(module_name: String) -> void:
	var layout_id: String = _MODULE_NAME_MAP.get(module_name, "")
	if layout_id.is_empty():
		print("[UI] _on_agent_show_module: 未知模块名 ", module_name)
		return
	if layout_id == "musiclist":
		_close_other_modules("musiclist")
		_music_module_mobile.show_module()
		_active_module_id = "musiclist"
	else:
		_open_module(layout_id)
	print("[UI] _on_agent_show_module: 已显示模块 ", module_name)


func _on_agent_hide_module(module_name: String) -> void:
	var layout_id: String = _MODULE_NAME_MAP.get(module_name, "")
	if layout_id.is_empty():
		print("[UI] _on_agent_hide_module: 未知模块名 ", module_name)
		return
	if layout_id == "musiclist":
		_music_module_mobile.hide_module()
	else:
		var info = _module_registry.get(layout_id)
		if info:
			info["node"].hide_module()
	if _active_module_id == layout_id:
		_active_module_id = ""
	print("[UI] _on_agent_hide_module: 已隐藏模块 ", module_name)


# === AI 流光 ===

const _MIN_GLOW_SEC: float = 0.8
# 底栏共享面板的模块 layout_id
const _BOTTOM_BAR_LAYOUTS: Array = ["task", "notebookmobile", "pomodorotechnique"]

var _glow_start_times: Dictionary = {}


func _on_ai_glow_started(module_key: String) -> void:
	_glow_start_times[module_key] = Time.get_ticks_msec()
	var panel := _find_module_frosted_panel(module_key)
	if panel:
		panel.start_ai_glow()


func _on_ai_glow_stopped(module_key: String) -> void:
	var start_time: int = _glow_start_times.get(module_key, 0)
	_glow_start_times.erase(module_key)
	var elapsed: float = (Time.get_ticks_msec() - start_time) / 1000.0
	var remaining: float = maxf(0.0, _MIN_GLOW_SEC - elapsed)

	if remaining > 0.0:
		get_tree().create_timer(remaining).timeout.connect(
			_deferred_stop_glow.bind(module_key)
		)
	else:
		_deferred_stop_glow(module_key)


func _deferred_stop_glow(module_key: String) -> void:
	var panel := _find_module_frosted_panel(module_key)
	if panel:
		panel.stop_ai_glow()


func _on_ai_response_glow_start() -> void:
	if not SettingState.get_ai_response_glow():
		return
	var panel := _dialogue_box.frosted_panel as FrostedPanel
	if panel:
		panel.start_ai_glow()


func _on_ai_response_glow_stop(_full_text: String) -> void:
	var panel := _dialogue_box.frosted_panel as FrostedPanel
	if panel:
		panel.stop_ai_glow()


func _find_module_frosted_panel(module_key: String) -> FrostedPanel:
	var layout_id: String = _MODULE_NAME_MAP.get(module_key, "")
	if layout_id.is_empty():
		return null
	# 底栏模块共享同一个 FrostedPanel（它是模块节点的祖先而非后代）
	if layout_id in _BOTTOM_BAR_LAYOUTS:
		return _bottom_bar_panel
	# 音乐模块特殊处理
	if layout_id == "musiclist":
		return _find_first_frosted_panel(_music_module_mobile)
	var info = _module_registry.get(layout_id)
	if not info:
		return null
	return _find_first_frosted_panel(info["node"])


func _find_first_frosted_panel(node: Node) -> FrostedPanel:
	if node is FrostedPanel:
		return node
	for child in node.get_children():
		var found := _find_first_frosted_panel(child)
		if found:
			return found
	return null
