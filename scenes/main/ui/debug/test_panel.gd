class_name TestPanel
extends Control

## 测试面板 - 用于测试各个UI模块的Agent API
## 使用TabContainer组织不同模块的测试页，方便拓展
## 集成到UI场景中，可以直接访问所有UI模块

@onready var tab_container: TabContainer = $PanelContainer/MarginContainer/VBoxContainer/TabContainer
@onready var title_label: Label = $PanelContainer/MarginContainer/VBoxContainer/HBoxContainer/TitleLabel
@onready var close_button: Button = $PanelContainer/MarginContainer/VBoxContainer/HBoxContainer/CloseButton

# UI模块引用
@export var ui: UI

func _ready() -> void:
	title_label.text = "UI模块测试面板"
	close_button.pressed.connect(_on_close_button_pressed)

	# 延迟初始化所有测试页，确保UI模块的@onready变量已初始化
	await get_tree().process_frame
	_initialize_test_panels()

	print("[TestPanel] 测试面板已就绪，当前包含 %d 个测试页" % tab_container.get_tab_count())

## 处理输入事件（ESC键关闭）
func _input(event: InputEvent) -> void:
	if visible and event is InputEventKey:
		if event.pressed and event.keycode == KEY_ESCAPE:
			_on_close_button_pressed()
			get_viewport().set_input_as_handled()


## 初始化所有测试页，传递模块引用
func _initialize_test_panels() -> void:
	if ui == null:
		print("[TestPanel] 错误: UI未设置，无法初始化测试页")
		return

	# 初始化TaskModule测试页
	for child in tab_container.get_children():
		if child.has_method("set_task_module") and ui.task_module:
			child.set_task_module(ui.task_module)
			print("[TestPanel] 已为 %s 设置TaskModule引用" % child.name)

		# 初始化InputBox测试页
		if child.has_method("set_input_box") and ui.input_box:
			child.set_input_box(ui.input_box)
			print("[TestPanel] 已为 %s 设置InputBox引用" % child.name)

## 公共方法：切换到指定的测试页
## @param tab_name: Tab名称
func switch_to_tab(tab_name: String) -> void:
	for i in range(tab_container.get_tab_count()):
		if tab_container.get_tab_title(i) == tab_name:
			tab_container.current_tab = i
			print("[TestPanel] 切换到测试页: %s" % tab_name)
			return
	print("[TestPanel] 未找到测试页: %s" % tab_name)

## 公共方法：获取当前测试页名称
func get_current_tab_name() -> String:
	return tab_container.get_tab_title(tab_container.current_tab)

## 关闭测试面板
func _on_close_button_pressed() -> void:
	visible = false
	print("[TestPanel] 测试面板已隐藏")
