class_name EnvSetter
extends Control

# ============ 节点引用 ============
@onready var canvas_layer: CanvasLayer = %CanvasLayer
@onready var panel = %FrostedPanel
@onready var _msaa_dropdown: MaterialDropdown = %MsaaDropdown
@onready var _ssaa_dropdown: MaterialDropdown = %SsaaDropdown
@onready var _camera_dropdown: MaterialDropdown = %CameraDropDown
@onready var _time_button: MaterialToggleButton = %TimeButton
@onready var _weather_button: MaterialToggleButton = %WeatherButton
@onready var _rain_slider: MaterialSlider = %RainMaterialSlider
@onready var _snow_slider: MaterialSlider = %SnowMaterialSlider

# ============ 生命周期 ============

func _ready() -> void:
	panel.visible = false
	# 设置 CanvasLayer 的初始层级
	canvas_layer.layer = 10
	_connect_state_signals()
	_sync_all_controls_from_state()
	_init_dropdowns_from_state()

# ============ 状态监听与 UI 同步 ============

# 统一连接 SettingState 信号，避免重复连接
func _connect_state_signals() -> void:
	if not SettingState:
		return
	_connect_if_needed(SettingState, "env_time_changed", _on_state_env_time_changed)
	_connect_if_needed(SettingState, "env_weather_changed", _on_state_env_weather_changed)
	_connect_if_needed(SettingState, "rain_changed", _on_state_rain_changed)
	_connect_if_needed(SettingState, "snow_changed", _on_state_snow_changed)
	# _connect_if_needed(SettingState, "outdoor_1_changed", _on_state_outdoor_1_changed)
	# _connect_if_needed(SettingState, "outdoor_2_changed", _on_state_outdoor_2_changed)

# 工具方法：若信号存在且未连接，则连接
func _connect_if_needed(emitter: Object, signal_name: StringName, callback: Callable) -> void:
	if emitter.has_signal(signal_name) and not emitter.is_connected(signal_name, callback):
		emitter.connect(signal_name, callback)

func _exit_tree() -> void:
	if not SettingState:
		return
	if SettingState.env_time_changed.is_connected(_on_state_env_time_changed):
		SettingState.env_time_changed.disconnect(_on_state_env_time_changed)
	if SettingState.env_weather_changed.is_connected(_on_state_env_weather_changed):
		SettingState.env_weather_changed.disconnect(_on_state_env_weather_changed)
	if SettingState.rain_changed.is_connected(_on_state_rain_changed):
		SettingState.rain_changed.disconnect(_on_state_rain_changed)
	if SettingState.snow_changed.is_connected(_on_state_snow_changed):
		SettingState.snow_changed.disconnect(_on_state_snow_changed)

# 启动时从状态单例回填 UI，使用无信号 API 避免回写
func _sync_all_controls_from_state() -> void:
	_time_button.set_state_no_signal(SettingState.get_time_mode())
	_weather_button.set_state_no_signal(SettingState.get_weather_mode())
	_rain_slider.set_value_no_signal(float(SettingState.get_rain_amount()))
	_snow_slider.set_value_no_signal(float(SettingState.get_snow_amount()))
	# _outdoor_1_button.set_state_no_signal(SettingState.get_outdoor_1_state())
	# _outdoor_2_button.set_state_no_signal(SettingState.get_outdoor_2_state())
	# _outdoor_2_row.visible = true


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
	pass # Replace with function body.

# ============ 抗锯齿设置 ============

func _on_msaa_changed(_index: int, value: Variant) -> void:
	SettingState.set_msaa(int(value))

func _on_ssaa_changed(_index: int, value: Variant) -> void:
	SettingState.set_ssaa(int(value))

# ============ 从 SettingState 初始化下拉框 ============

func _init_dropdowns_from_state() -> void:
	var msaa_val = SettingState.get_msaa()
	var ssaa_val = SettingState.get_ssaa()
	var camera_val = SettingState.get_camera_mode()
	_msaa_dropdown.set_selected_by_value(str(msaa_val))
	_ssaa_dropdown.set_selected_by_value(str(ssaa_val))
	_camera_dropdown.set_selected_by_value(str(camera_val))


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

func _on_state_rain_changed(amount: int) -> void:
	_rain_slider.set_value_no_signal(float(amount))

func _on_state_snow_changed(amount: int) -> void:
	_snow_slider.set_value_no_signal(float(amount))

# func _on_state_outdoor_1_changed(state: int) -> void:
# 	_outdoor_1_button.set_state_no_signal(state)

# func _on_state_outdoor_2_changed(state: int) -> void:
# 	_outdoor_2_button.set_state_no_signal(state)


func _on_fog_button_state_changed(_old_state: int, new_state: int) -> void:
	SettingState.set_fog(new_state)


func _on_camera_drop_down_selection_changed(_index: int, value: Variant) -> void:
	SettingState.set_camera(int(value))
