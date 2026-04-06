class_name EnvSetter
extends Control

# ============ 节点引用 ============
@onready var canvas_layer: CanvasLayer = %CanvasLayer
@onready var panel = %FrostedPanel
@onready var _msaa_dropdown: MaterialDropdown = %MsaaDropdown
@onready var _ssaa_dropdown: MaterialDropdown = %SsaaDropdown
@onready var _render_scale_dropdown: MaterialDropdown = %RenderScaleDropdown
@onready var _camera_dropdown: MaterialDropdown = %CameraDropDown
@onready var _time_button: MaterialToggleButton = %TimeButton
@onready var _weather_button: MaterialToggleButton = %WeatherButton
@onready var _orientation_toggle: MaterialToggleButton = %OrientationToggle
@onready var _rain_slider: MaterialSlider = %RainMaterialSlider
@onready var _snow_slider: MaterialSlider = %SnowMaterialSlider
@onready var _full_screen_checkbox: CheckBox = %FullScreenCheckbox
@onready var _settings_vbox: VBoxContainer = $CanvasLayer/FrostedPanel/VBoxContainer/MarginContainer/SmoothScrollContainer/VBoxContainer

var _mic_dropdown: MaterialDropdown
var _speaker_dropdown: MaterialDropdown
var _record_preview_toggle: MaterialToggleButton
var _chat_backend_dropdown: MaterialDropdown

# ============ 生命周期 ============

func _ready() -> void:
	panel.visible = false
	# 设置 CanvasLayer 的初始层级
	canvas_layer.layer = 10
	_connect_state_signals()
	_setup_audio_debug_controls()
	_setup_chat_backend_dropdown()
	_sync_all_controls_from_state()
	_init_dropdowns_from_state()
	_sync_chat_backend_dropdown_from_state()

# ============ 状态监听与 UI 同步 ============

# 统一连接 SettingState 信号，避免重复连接
func _connect_state_signals() -> void:
	if not SettingState:
		return
	if is_instance_valid(ChatState) and not ChatState.chat_backend_mode_changed.is_connected(_on_chat_state_chat_backend_mode_changed):
		ChatState.chat_backend_mode_changed.connect(_on_chat_state_chat_backend_mode_changed)
	_connect_if_needed(SettingState, "env_time_changed", _on_state_env_time_changed)
	_connect_if_needed(SettingState, "env_weather_changed", _on_state_env_weather_changed)
	_connect_if_needed(SettingState, "screen_orientation_mode_changed", _on_state_screen_orientation_mode_changed)
	_connect_if_needed(SettingState, "rain_changed", _on_state_rain_changed)
	_connect_if_needed(SettingState, "snow_changed", _on_state_snow_changed)
	_connect_if_needed(SettingState, "render_scale_changed", _on_state_render_scale_changed)
	_connect_if_needed(SettingState, "audio_input_device_changed", _on_state_audio_input_device_changed)
	_connect_if_needed(SettingState, "audio_output_device_changed", _on_state_audio_output_device_changed)
	_connect_if_needed(SettingState, "talk_record_preview_changed", _on_state_talk_record_preview_changed)
	# _connect_if_needed(SettingState, "outdoor_1_changed", _on_state_outdoor_1_changed)
	# _connect_if_needed(SettingState, "outdoor_2_changed", _on_state_outdoor_2_changed)

# 工具方法：若信号存在且未连接，则连接
func _connect_if_needed(emitter: Object, signal_name: StringName, callback: Callable) -> void:
	if emitter.has_signal(signal_name) and not emitter.is_connected(signal_name, callback):
		emitter.connect(signal_name, callback)

func _exit_tree() -> void:
	if is_instance_valid(ChatState) and ChatState.chat_backend_mode_changed.is_connected(_on_chat_state_chat_backend_mode_changed):
		ChatState.chat_backend_mode_changed.disconnect(_on_chat_state_chat_backend_mode_changed)
	if not SettingState:
		return
	if SettingState.env_time_changed.is_connected(_on_state_env_time_changed):
		SettingState.env_time_changed.disconnect(_on_state_env_time_changed)
	if SettingState.env_weather_changed.is_connected(_on_state_env_weather_changed):
		SettingState.env_weather_changed.disconnect(_on_state_env_weather_changed)
	if SettingState.screen_orientation_mode_changed.is_connected(_on_state_screen_orientation_mode_changed):
		SettingState.screen_orientation_mode_changed.disconnect(_on_state_screen_orientation_mode_changed)
	if SettingState.rain_changed.is_connected(_on_state_rain_changed):
		SettingState.rain_changed.disconnect(_on_state_rain_changed)
	if SettingState.snow_changed.is_connected(_on_state_snow_changed):
		SettingState.snow_changed.disconnect(_on_state_snow_changed)
	if SettingState.render_scale_changed.is_connected(_on_state_render_scale_changed):
		SettingState.render_scale_changed.disconnect(_on_state_render_scale_changed)
	if SettingState.audio_input_device_changed.is_connected(_on_state_audio_input_device_changed):
		SettingState.audio_input_device_changed.disconnect(_on_state_audio_input_device_changed)
	if SettingState.audio_output_device_changed.is_connected(_on_state_audio_output_device_changed):
		SettingState.audio_output_device_changed.disconnect(_on_state_audio_output_device_changed)
	if SettingState.talk_record_preview_changed.is_connected(_on_state_talk_record_preview_changed):
		SettingState.talk_record_preview_changed.disconnect(_on_state_talk_record_preview_changed)

# 启动时从状态单例回填 UI，使用无信号 API 避免回写
func _sync_all_controls_from_state() -> void:
	_time_button.set_state_no_signal(SettingState.get_time_mode())
	_weather_button.set_state_no_signal(SettingState.get_weather_mode())
	_rain_slider.set_value_no_signal(float(SettingState.get_rain_amount()))
	_snow_slider.set_value_no_signal(float(SettingState.get_snow_amount()))
	if _orientation_toggle != null:
		_orientation_toggle.set_state_no_signal(SettingState.get_screen_orientation_mode())
	if _full_screen_checkbox != null:
		_full_screen_checkbox.set_pressed_no_signal(_is_full_screen_enabled())
	# _outdoor_1_button.set_state_no_signal(SettingState.get_outdoor_1_state())
	# _outdoor_2_button.set_state_no_signal(SettingState.get_outdoor_2_state())
	# _outdoor_2_row.visible = true
	_sync_audio_controls_from_state()
func _setup_audio_debug_controls() -> void:
	if _mic_dropdown != null:
		return

	# 麦克风选择
	var mic_row := _create_setting_row("麦克风设备")
	_mic_dropdown = MaterialDropdown.new()
	_mic_dropdown.custom_minimum_size = Vector2(170, 36)
	_mic_dropdown.placeholder = "选择麦克风"
	mic_row.add_child(_mic_dropdown)
	_mic_dropdown.selection_changed.connect(_on_mic_dropdown_changed)

	# 扬声器选择
	var speaker_row := _create_setting_row("扬声器设备")
	_speaker_dropdown = MaterialDropdown.new()
	_speaker_dropdown.custom_minimum_size = Vector2(170, 36)
	_speaker_dropdown.placeholder = "选择扬声器"
	speaker_row.add_child(_speaker_dropdown)
	_speaker_dropdown.selection_changed.connect(_on_speaker_dropdown_changed)

	# 录音回放开关
	var preview_row := _create_setting_row("播放录音回放")
	_record_preview_toggle = MaterialToggleButton.new()
	_record_preview_toggle.custom_minimum_size = Vector2(56, 36)
	_record_preview_toggle.auto_cycle = true
	_record_preview_toggle.states = [
		ToggleButtonState.create_text_state("关"),
		ToggleButtonState.create_text_state("开")
	]
	preview_row.add_child(_record_preview_toggle)
	_record_preview_toggle.state_changed.connect(_on_record_preview_toggle_changed)

	_refresh_audio_device_options()


func _setup_chat_backend_dropdown() -> void:
	if _chat_backend_dropdown != null:
		return
	var row := _create_setting_row("AI 对话模式")
	_chat_backend_dropdown = MaterialDropdown.new()
	_chat_backend_dropdown.custom_minimum_size = Vector2(200, 36)
	_chat_backend_dropdown.placeholder = "选择模式"
	_chat_backend_dropdown.add_option("性能（更快）", ChatState.CHAT_PATH_PERFORMANCE)
	_chat_backend_dropdown.add_option("质量（Agent）", ChatState.CHAT_PATH_QUALITY)
	row.add_child(_chat_backend_dropdown)
	_chat_backend_dropdown.selection_changed.connect(_on_chat_backend_dropdown_changed)


func _sync_chat_backend_dropdown_from_state() -> void:
	if _chat_backend_dropdown == null:
		return
	_chat_backend_dropdown.set_selected_by_value(ChatState.get_chat_path_prefix())


func _on_chat_backend_dropdown_changed(_index: int, value: Variant) -> void:
	var path := str(value)
	if path == ChatState.get_chat_path_prefix():
		return
	ChatState.set_chat_backend_mode_from_path(path)


func _on_chat_state_chat_backend_mode_changed(_mode: int) -> void:
	_sync_chat_backend_dropdown_from_state()


func _create_setting_row(title: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.layout_mode = 2
	_settings_vbox.add_child(row)

	var label := Label.new()
	label.text = title
	row.add_child(label)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)

	return row


func _refresh_audio_device_options() -> void:
	if _mic_dropdown == null or _speaker_dropdown == null:
		return

	_mic_dropdown.clear_options()
	for device_name in SettingState.get_audio_input_device_list():
		_mic_dropdown.add_option(device_name, device_name)

	_speaker_dropdown.clear_options()
	for device_name in SettingState.get_audio_output_device_list():
		_speaker_dropdown.add_option(device_name, device_name)


# ============ UI 事件 -> State ============

func _on_time_button_state_changed(_old_state: int, new_state: int) -> void:
	SettingState.set_time(new_state)

func _on_weather_button_state_changed(_old_state: int, new_state: int) -> void:
	SettingState.set_weather(new_state)

func _on_setting_button_pressed() -> void:
	if panel.visible:
		GuiTransitions.hide("setter")
	else:
		LayerManager.bring_to_front(canvas_layer)
		GuiTransitions.show("setter")


func show_module() -> void:
	if not panel.visible:
		LayerManager.bring_to_front(canvas_layer)
		GuiTransitions.show("setter")


func hide_module() -> void:
	if panel.visible:
		GuiTransitions.hide("setter")


func _on_full_screen_checkbox_toggled(toggled_on: bool) -> void:
	if toggled_on:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)


func _is_full_screen_enabled() -> bool:
	var mode := DisplayServer.window_get_mode()
	return mode == DisplayServer.WINDOW_MODE_FULLSCREEN or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN

# ============ 抗锯齿设置 ============

func _on_msaa_changed(_index: int, value: Variant) -> void:
	SettingState.set_msaa(int(value))

func _on_ssaa_changed(_index: int, value: Variant) -> void:
	SettingState.set_ssaa(int(value))


func _on_render_scale_changed(_index: int, value: Variant) -> void:
	SettingState.set_render_scale(float(str(value)))

# ============ 从 SettingState 初始化下拉框 ============

func _init_dropdowns_from_state() -> void:
	var msaa_val = SettingState.get_msaa()
	var ssaa_val = SettingState.get_ssaa()
	var render_scale_val = SettingState.get_render_scale()
	var camera_val = SettingState.get_camera_mode()
	_msaa_dropdown.set_selected_by_value(str(msaa_val))
	_ssaa_dropdown.set_selected_by_value(str(ssaa_val))
	_render_scale_dropdown.set_selected_by_value(str(render_scale_val))
	_camera_dropdown.set_selected_by_value(str(camera_val))
	_sync_audio_controls_from_state()


func _sync_audio_controls_from_state() -> void:
	if _mic_dropdown != null:
		_mic_dropdown.set_selected_by_value(SettingState.get_audio_input_device())
	if _speaker_dropdown != null:
		_speaker_dropdown.set_selected_by_value(SettingState.get_audio_output_device())
	if _record_preview_toggle != null:
		var state := 1 if SettingState.get_talk_record_preview_enabled() else 0
		_record_preview_toggle.set_state_no_signal(state)


func _on_rain_material_slider_value_changed(value: float) -> void:
	SettingState.set_rain_amount(int(value))


func _on_snow_material_slider_value_changed(value: float) -> void:
	SettingState.set_snow_amount(int(value))


#func _on_out_door_1_button_state_changed(_old_state: int, new_state: int) -> void:
	#SettingState.set_outdoor_1(new_state)


#func _on_out_door_2_button_state_changed(_old_state: int, new_state: int) -> void:
	#SettingState.set_outdoor_2(new_state)

# ============ State -> UI 回调 ============

func _on_state_env_time_changed(mode: int) -> void:
	_time_button.set_state_no_signal(mode)

func _on_state_env_weather_changed(mode: int) -> void:
	_weather_button.set_state_no_signal(mode)


func _on_state_screen_orientation_mode_changed(mode: int) -> void:
	if _orientation_toggle != null:
		_orientation_toggle.set_state_no_signal(mode)

func _on_state_rain_changed(amount: int) -> void:
	_rain_slider.set_value_no_signal(float(amount))

func _on_state_snow_changed(amount: int) -> void:
	_snow_slider.set_value_no_signal(float(amount))


func _on_state_render_scale_changed(scale: float) -> void:
	_render_scale_dropdown.set_selected_by_value(str(scale))


func _on_state_audio_input_device_changed(device_name: String) -> void:
	if _mic_dropdown != null:
		_mic_dropdown.set_selected_by_value(device_name)


func _on_state_audio_output_device_changed(device_name: String) -> void:
	if _speaker_dropdown != null:
		_speaker_dropdown.set_selected_by_value(device_name)


func _on_state_talk_record_preview_changed(enabled: bool) -> void:
	if _record_preview_toggle != null:
		_record_preview_toggle.set_state_no_signal(1 if enabled else 0)


func _on_mic_dropdown_changed(_index: int, value: Variant) -> void:
	var device_name := str(value)
	if not SettingState.set_audio_input_device(device_name):
		_refresh_audio_device_options()
		_sync_audio_controls_from_state()


func _on_speaker_dropdown_changed(_index: int, value: Variant) -> void:
	var device_name := str(value)
	if not SettingState.set_audio_output_device(device_name):
		_refresh_audio_device_options()
		_sync_audio_controls_from_state()


func _on_record_preview_toggle_changed(_old_state: int, new_state: int) -> void:
	SettingState.set_talk_record_preview_enabled(new_state == 1)


func _on_orientation_toggle_changed(_old_state: int, new_state: int) -> void:
	SettingState.set_screen_orientation_mode(new_state)

# func _on_state_outdoor_1_changed(state: int) -> void:
# 	_outdoor_1_button.set_state_no_signal(state)

# func _on_state_outdoor_2_changed(state: int) -> void:
# 	_outdoor_2_button.set_state_no_signal(state)


func _on_fog_button_state_changed(_old_state: int, new_state: int) -> void:
	SettingState.set_fog(new_state)


func _on_camera_drop_down_selection_changed(_index: int, value: Variant) -> void:
	SettingState.set_camera(int(value))
