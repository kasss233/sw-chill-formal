class_name UI
extends Control

# --- 节点引用 ---
## 音乐管理模块
@export var music_module: MusicModule
@export var note_module: NoteModule
@export var note_book: NoteBook
@export var task_module: TaskModule
@export var test_panel: TestPanel # 测试面板引用
@export var pomodoro_module: PomodoroTechniqueModule # 番茄钟模块引用
@export var dialogue_box: DialogueBox
@export var input_box: InputBox


# --- 内置函数 ---
func _ready() -> void:
	_setup_test_panel_shortcut()

## 设置测试面板快捷键（F12）
func _setup_test_panel_shortcut() -> void:
	pass # 快捷键在_input中处理

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		# F12 切换测试面板
		if event.keycode == KEY_F12:
			toggle_test_panel()
			get_viewport().set_input_as_handled()

# --- 测试面板控制 ---
## 切换测试面板显示/隐藏
func toggle_test_panel() -> void:
	if test_panel:
		test_panel.visible = !test_panel.visible

## 显示测试面板
func show_test_panel() -> void:
	if test_panel:
		test_panel.visible = true
		print("[UI] 测试面板已显示")

## 隐藏测试面板
func hide_test_panel() -> void:
	if test_panel:
		test_panel.visible = false
		print("[UI] 测试面板已隐藏")
