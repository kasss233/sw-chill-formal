extends Node

@export var ui: UI
@export var ui_mobile: UI
@export var main3d: Main3d
@export_category("项目演示")
@export var animation_player: AnimationPlayer
@export var snack_bar: MaterialSnackbar


func _ready() -> void:
	_connect_setting_signals()
	_init_ui()


#这里根据设备切换ui，视口
#TODO:判断手机pad
func _init_ui():
	var mode := _get_initial_orientation_mode()
	_apply_orientation_mode(mode)


func _connect_setting_signals() -> void:
	if not SettingState:
		return
	if not SettingState.screen_orientation_mode_changed.is_connected(_on_screen_orientation_mode_changed):
		SettingState.screen_orientation_mode_changed.connect(_on_screen_orientation_mode_changed)


func _exit_tree() -> void:
	if SettingState and SettingState.screen_orientation_mode_changed.is_connected(_on_screen_orientation_mode_changed):
		SettingState.screen_orientation_mode_changed.disconnect(_on_screen_orientation_mode_changed)


func _get_initial_orientation_mode() -> int:
	if SettingState:
		return SettingState.get_screen_orientation_mode()
	return 1 if OS.has_feature("mobile") else 0


func _on_screen_orientation_mode_changed(mode: int) -> void:
	_apply_orientation_mode(mode)


func _apply_orientation_mode(mode: int) -> void:
	# mode: 0=横屏, 1=竖屏
	if mode == 1:
		get_window().size = Vector2i(648, 1152)
		get_window().content_scale_size = Vector2i(648, 1152)
		get_tree().root.content_scale_factor = 1.5
		if is_instance_valid(ui):
			ui.visible = false
		if is_instance_valid(ui_mobile):
			ui_mobile.visible = true
		if is_instance_valid(main3d):
			main3d.set_camera_fov(60)
		return

	get_window().size = Vector2i(1152, 648)
	get_window().content_scale_size = Vector2i(1152, 648)
	get_tree().root.content_scale_factor = 1.0
	if is_instance_valid(ui_mobile):
		ui_mobile.visible = false
	if is_instance_valid(ui):
		ui.visible = true
	if is_instance_valid(main3d):
		main3d.set_camera_fov(45)
