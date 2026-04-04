extends Node

@export var ui_scene: PackedScene
@export var ui_mobile_scene: PackedScene
@export var main3d: Main3d
var ui: UI
var ui_mobile: UI
var _pending_orientation_mode: int = -1
var _orientation_switch_in_progress: bool = false

func _ready() -> void:
	_connect_signal()
	_init_ui()


func _connect_signal() -> void:
	if not is_instance_valid(TransitionAnimation):
		return
	if not TransitionAnimation.startup_transition_finished.is_connected(_on_transition_animation_finished):
		TransitionAnimation.startup_transition_finished.connect(_on_transition_animation_finished)
	if not SettingState:
		return
	if not SettingState.screen_orientation_mode_changed.is_connected(_on_screen_orientation_mode_changed):
		SettingState.screen_orientation_mode_changed.connect(_on_screen_orientation_mode_changed)

func _init_ui():
	var mode := _get_initial_orientation_mode()
	_apply_orientation_mode_immediately(mode)
func _get_initial_orientation_mode() -> int:
	if SettingState:
		return SettingState.get_screen_orientation_mode()
	return 1 if OS.has_feature("mobile") else 0


func _exit_tree() -> void:
	if SettingState and SettingState.screen_orientation_mode_changed.is_connected(_on_screen_orientation_mode_changed):
		SettingState.screen_orientation_mode_changed.disconnect(_on_screen_orientation_mode_changed)


func _on_screen_orientation_mode_changed(mode: int) -> void:
	_request_orientation_mode_change(mode)
func _request_orientation_mode_change(mode: int) -> void:
	_pending_orientation_mode = mode
	if _orientation_switch_in_progress:
		return
	if not is_instance_valid(TransitionAnimation):
		_apply_pending_orientation_mode()
		return
	_orientation_switch_in_progress = true
	TransitionAnimation.play_startup_transition()
func _on_transition_animation_finished() -> void:
	if not _orientation_switch_in_progress:
		return
	_apply_pending_orientation_mode()
	_orientation_switch_in_progress = false
func _apply_pending_orientation_mode() -> void:
	if _pending_orientation_mode == -1:
		return
	var mode := _pending_orientation_mode
	_pending_orientation_mode = -1
	_apply_orientation_mode_immediately(mode)

func _apply_orientation_mode_immediately(mode: int) -> void:
	# mode: 0=横屏, 1=竖屏
	if OS.has_feature("mobile") and DisplayServer.has_feature(DisplayServer.FEATURE_ORIENTATION):
		var screen_orientation := DisplayServer.SCREEN_PORTRAIT if mode == 1 else DisplayServer.SCREEN_LANDSCAPE
		DisplayServer.screen_set_orientation(screen_orientation)

	_switch_ui_instance(mode)

	if mode == 1:
		get_window().size = Vector2i(648, 1152)
		get_window().content_scale_size = Vector2i(648, 1152)
		get_tree().root.content_scale_factor = 1.5
		if is_instance_valid(main3d):
			main3d.set_camera_fov(60)
		return

	get_window().size = Vector2i(1152, 648)
	get_window().content_scale_size = Vector2i(1152, 648)
	get_tree().root.content_scale_factor = 1.0
	if is_instance_valid(main3d):
		main3d.set_camera_fov(45)


func _switch_ui_instance(mode: int) -> void:
	if mode == 1:
		_replace_ui_instance(true)
		return
	_replace_ui_instance(false)


func _replace_ui_instance(use_mobile_ui: bool) -> void:
	if use_mobile_ui:
		if is_instance_valid(ui):
			ui.free()
			ui = null
		if not is_instance_valid(ui_mobile):
			ui_mobile = _create_ui_instance(ui_mobile_scene)
		if is_instance_valid(ui_mobile):
			ui_mobile.visible = true
		return

	if is_instance_valid(ui_mobile):
		ui_mobile.free()
		ui_mobile = null
	if not is_instance_valid(ui):
		ui = _create_ui_instance(ui_scene)
	if is_instance_valid(ui):
		ui.visible = true


func _create_ui_instance(packed_scene: PackedScene) -> UI:
	if packed_scene == null:
		return null
	var instance := packed_scene.instantiate()
	if instance == null:
		return null
	add_child(instance)
	return instance as UI
