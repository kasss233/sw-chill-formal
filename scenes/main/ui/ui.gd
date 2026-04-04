class_name UI
extends Control

# --- 节点引用 ---
@export var test_panel: TestPanel


func _ready() -> void:
	_setup_test_panel_shortcut()


func _setup_test_panel_shortcut() -> void:
	pass


func _input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed):
		return

	if event.keycode == KEY_1:
		AIDemoController.start_demo()
		get_viewport().set_input_as_handled()
		return

	if event.keycode == KEY_KP_2:
		AIDemoController.restore_demo()
		get_viewport().set_input_as_handled()
		return

	if event.keycode == KEY_F12:
		toggle_test_panel()
		get_viewport().set_input_as_handled()


func toggle_test_panel() -> void:
	if test_panel:
		test_panel.visible = not test_panel.visible


func show_test_panel() -> void:
	if test_panel:
		test_panel.visible = true
		print("[UI] 测试面板已显示")


func hide_test_panel() -> void:
	if test_panel:
		test_panel.visible = false
		print("[UI] 测试面板已隐藏")
