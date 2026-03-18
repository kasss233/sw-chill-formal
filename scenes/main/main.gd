extends Node

@export var ui: UI
@export var ui_mobile: UI
@export var main3d: Main3d
@export_category("项目演示")
@export var animation_player: AnimationPlayer
@export var snack_bar: MaterialSnackbar
func _ready() -> void:
	_init_ui()


#这里根据设备切换ui，视口
#TODO:判断手机pad
func _init_ui():
	if OS.has_feature("mobile"):
	#if OS.has_feature("pc"):
		get_window().size = Vector2i(648, 1152)
		get_window().content_scale_size = Vector2i(648, 1152)
		get_tree().root.content_scale_factor = 1.8
		ui.queue_free()
		ui_mobile.visible = true
		main3d.set_camera_fov(60)
		return
	if OS.has_feature("pc"):
		ui_mobile.queue_free()
		ui.visible = true
		main3d.set_camera_fov(45)
		return
