extends UI

@onready var _task_module = $TabPanel/FrostedPanel/MarginContainer/VBoxContainer/TaskModule
@onready var _notebook_tab = $TabPanel/FrostedPanel/MarginContainer/VBoxContainer/NoteBookTab
@onready var _pomodoro_module = $TabPanel/FrostedPanel/MarginContainer/VBoxContainer/PomodoroTechniqueModule
@onready var _achievement_module = $TabPanel/FrostedPanel/MarginContainer/VBoxContainer/AchievementModule
@onready var _room_decor_module = $TabPanel/FrostedPanel/MarginContainer/VBoxContainer/RoomDecorModule
@onready var _profile_center_tab = $TabPanel/FrostedPanel/MarginContainer/VBoxContainer/ProfileCenterTab
@onready var _env_setter = $TabPanel/FrostedPanel/MarginContainer/VBoxContainer/EnvSetter
@onready var _dialogue_box = $VBoxContainer/DialogueBox
@onready var _music_module = $MusicModule

const _MIN_GLOW_SEC: float = 1.6
const _MODULE_NAME_MAP: Dictionary = {
	"task": "_task_module",
	"notebook": "_notebook_tab",
	"pomodoro": "_pomodoro_module",
	"achievement": "_achievement_module",
	"room_decor": "_room_decor_module",
	"profile_center": "_profile_center_tab",
	"calendar": "_profile_center_tab",
	"setting": "_env_setter",
	"music": "_music_module",
}

var _glow_start_times: Dictionary = {}


func _ready() -> void:
	super._ready()
	ChatState.ai_glow_started.connect(_on_ai_glow_started)
	ChatState.ai_glow_stopped.connect(_on_ai_glow_stopped)
	ChatState.response_started.connect(_on_ai_response_glow_start)
	ChatState.response_completed.connect(_on_ai_response_glow_stop)
	LayerManager.module_show_requested.connect(_on_agent_show_module)
	LayerManager.module_hide_requested.connect(_on_agent_hide_module)
	AIDemoController.demo_response_requested.connect(_on_demo_response_requested)
	AIDemoController.demo_response_cleared.connect(_on_demo_response_cleared)


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


func _on_demo_response_requested(text: String, append: bool) -> void:
	_dialogue_box.show_demo_response(text, append)


func _on_demo_response_cleared() -> void:
	_dialogue_box.clear_demo_response()


func _on_agent_show_module(module_name: String) -> void:
	var module = _get_module_node(module_name)
	if module == null:
		print("[UI-Landscape] 未知模块名: %s" % module_name)
		return
	if module.has_method("show_module"):
		module.show_module()
		print("[UI-Landscape] 已显示模块: %s" % module_name)


func _on_agent_hide_module(module_name: String) -> void:
	var module = _get_module_node(module_name)
	if module == null:
		print("[UI-Landscape] 未知模块名: %s" % module_name)
		return
	if module.has_method("hide_module"):
		module.hide_module()
		print("[UI-Landscape] 已隐藏模块: %s" % module_name)


func _get_module_node(module_name: String) -> Node:
	var property_name := str(_MODULE_NAME_MAP.get(module_name, ""))
	if property_name.is_empty():
		return null
	return get(property_name) as Node


func _find_module_frosted_panel(module_key: String) -> FrostedPanel:
	match module_key:
		"task":
			return _find_first_frosted_panel(_task_module)
		"notebook":
			return _find_first_frosted_panel(_notebook_tab)
		"pomodoro":
			return _find_first_frosted_panel(_pomodoro_module)
		"achievement":
			return _find_first_frosted_panel(_achievement_module)
		"room_decor":
			return _find_first_frosted_panel(_room_decor_module)
		"profile_center", "calendar":
			return _find_first_frosted_panel(_profile_center_tab)
		"setting":
			return _find_first_frosted_panel(_env_setter)
		"music":
			return _find_first_frosted_panel(_music_module)
		_:
			return null


func _find_first_frosted_panel(node: Node) -> FrostedPanel:
	if node is FrostedPanel:
		return node

	for child in node.get_children():
		var found := _find_first_frosted_panel(child)
		if found:
			return found

	return null
