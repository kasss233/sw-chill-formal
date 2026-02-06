class_name UI
extends Control

## 主 UI 控制器，负责协调各模块信号并与全局服务层交互
## 音乐状态由 MusicState 单例管理
## 任务数据由 TaskState 单例管理

# --- 信号 ---
## 当音乐切换时发出
signal music_changed(p_name: String)
## 当播放状态（播放/暂停）切换时发出
signal music_status_changed()

## 切换环境时间
signal env_time_changed(mode: int)
## 切换天气
signal env_weather_changed(mode: int)
## 角色互动
signal character_interacted

## 任务完成信号
signal task_completed(task_id: int, task_title: String)
## 截止时间到信号
signal task_deadline_reached(task_id: int, task_title: String)
## 截止时间剩余15分钟警告信号
signal task_deadline_warning(task_id: int, task_title: String)

## AI 对话相关信号
signal ai_response_completed(full_response: String)

# --- 节点引用 ---
## 音乐管理模块
@export var music_module: MusicModule
@export var note_module: NoteModule
@export var note_book: NoteBook
@export var task_module: TaskModule
@export var test_panel: TestPanel # 测试面板引用
@export var env_setter: EnvSetter
@export var pomodoro_module: PomodoroTechniqueModule # 番茄钟模块引用
@export var dialogue_box: DialogueBox
@export var input_box: InputBox
@export var chat_controller: ChatController

# --- 层级管理 ---
## 当前最高层级（用于模块 Z-order 管理）
var _current_top_layer: int = 10


# --- 内置函数 ---
func _ready() -> void:
	_connect_signals()
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

# --- 内部处理函数 ---
## 连接各子模块信号
func _connect_signals() -> void:
	# 连接 MusicState 信号
	if MusicState:
		MusicState.track_changed.connect(_on_track_changed)
		MusicState.playback_state_changed.connect(_on_playback_state_changed)

	# 连接 TaskState 信号（数据层）
	if TaskState:
		TaskState.task_state_changed.connect(_on_task_state_changed_from_state)
		TaskState.task_deadline_reached.connect(_on_task_deadline_reached_from_state)
		TaskState.task_deadline_warning.connect(_on_task_deadline_warning_from_state)

	# 连接 ChatController 信号（转发给外部监听者）
	if chat_controller:
		chat_controller.response_completed.connect(_on_chat_response_completed)
		chat_controller.text_submitted.connect(_on_chat_text_submitted)


# --- 公有 API (音乐模块包装) ---
## 添加一个新的音乐列表
func add_music_list(p_name: String) -> void:
	if music_module:
		music_module.add_music_list(p_name)

## 向指定音乐列表添加一首音乐
func add_music(p_list_name: String, p_music_name: String) -> void:
	if music_module:
		music_module.add_music(p_list_name, p_music_name)

## 更换当前播放的音乐
func change_music(p_name: String) -> void:
	if MusicState:
		MusicState.set_track(p_name)
		MusicState.set_playing(true)

## 删除音乐
func remove_music(p_music_name: String, p_list_name: String) -> void:
	if music_module:
		music_module.remove_music(p_music_name, p_list_name)

## 播放下一首音乐
func play_next_music() -> void:
	if music_module:
		music_module._play_next_by_mode()

## 检查指定音乐是否已存在于某个列表中
func is_music_in_list(p_list_name: String, p_music_name: String) -> bool:
	if music_module:
		return music_module.is_music_in_list(p_list_name, p_music_name)
	return false

## 获取当前所有音乐列表的名称
func get_music_list_names() -> Array[String]:
	if music_module:
		return music_module.get_music_list_names()
	return []

## 获取当前列表中的所有音乐名称
func get_current_list_music_names() -> Array[String]:
	if music_module:
		return music_module.get_current_list_music_names()
	return []

## 获取指定列表中的音乐名称
func get_list_music_names(p_list_name: String) -> Array[String]:
	if music_module:
		return music_module.get_list_music_names(p_list_name)
	return []

## 获取所有列表及其对应的音乐名称映射
func get_all_lists_music_names() -> Dictionary:
	if music_module:
		return music_module.get_all_lists_music_names()
	return {}

## 根据名称切换到指定的歌单
func switch_to_list_by_name(p_list_name: String) -> void:
	if music_module:
		music_module.switch_to_list_by_name(p_list_name)

## 设置当前音乐显示（用于初始化时更新 UI）
func set_current_music_display(p_music_name: String) -> void:
	if music_module:
		music_module.tab_button.text = p_music_name

##  添加新的便签(带动画)
func take_note(text: String):
	note_module.take_note(text)

## 添加新的notebook页面
func add_note_in_notebook(_name: String, _content: String):
	note_book.show_module()
	note_book.add_page_and_open(_name, _content)

## 切换天气,0:晴天,1:雨天,2:雪天,3:同步
func set_env_weather(mode: int) -> void:
	if env_setter:
		env_setter.set_weather(mode)

## 切换时间,0:白天,1:黄昏,2:晚上,3:同步
func set_env_time(mode: int) -> void:
	if env_setter:
		env_setter.set_time(mode)

# --- 测试面板控制 ---
## 切换测试面板显示/隐藏
func toggle_test_panel() -> void:
	if test_panel:
		test_panel.visible = !test_panel.visible

# --- 层级管理 ---
## 请求一个新的顶层层级（用于模块打开时自动置顶）
## @return 新的层级值
func request_top_layer() -> int:
	_current_top_layer += 1
	return _current_top_layer

## 重置层级计数器（可选，用于防止层级值过大）
func reset_layer_counter() -> void:
	_current_top_layer = 10

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

# --- MusicState 信号回调 ---
func _on_track_changed(p_name: String) -> void:
	music_changed.emit(p_name)

func _on_playback_state_changed(_is_playing: bool) -> void:
	music_status_changed.emit()

# --- 环境信号回调 ---
func _on_env_setter_env_weather_changed(mode: int) -> void:
	env_weather_changed.emit(mode)
func _on_env_setter_env_time_changed(mode: int) -> void:
	env_time_changed.emit(mode)

func _on_character_interactor_character_interacted() -> void:
	character_interacted.emit()

# --- TaskState 信号回调 ---
func _on_task_state_changed_from_state(task: TaskData) -> void:
	if task.is_completed:
		task_completed.emit(task.id, task.title)

func _on_task_deadline_reached_from_state(task: TaskData) -> void:
	task_deadline_reached.emit(task.id, task.title)

func _on_task_deadline_warning_from_state(task: TaskData) -> void:
	task_deadline_warning.emit(task.id, task.title)

# --- 番茄钟回调 ---
signal work_completed
func _on_pomodoro_technique_module_work_completed() -> void:
	work_completed.emit()

signal work_started
func _on_pomodoro_technique_module_work_started() -> void:
	work_started.emit()

signal work_paused
func _on_pomodoro_technique_module_work_paused() -> void:
	work_paused.emit()

signal work_stopped
func _on_pomodoro_technique_module_work_stopped() -> void:
	work_stopped.emit()

signal work_continued
func _on_pomodoro_technique_module_work_continued() -> void:
	work_continued.emit()

signal text_submitted

# --- ChatController 信号回调 ---
func _on_chat_text_submitted(_text: String, _attachments: Array) -> void:
	text_submitted.emit()

func _on_chat_response_completed(full_response: String) -> void:
	ai_response_completed.emit(full_response)
