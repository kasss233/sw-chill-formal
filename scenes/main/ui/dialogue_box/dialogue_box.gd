extends MarginContainer
class_name DialogueBox
## AI 对话框组件
## 支持流式传输（逐字显示）、自动高度调整、加载状态反馈、自动/手动退出

# 显示状态枚举
enum DisplayState {HIDDEN, LOADING, EXECUTING_FUNC, SHOWING_TEXT, COMPLETED}

# 函数名 → 友好提示文本
const FUNC_DISPLAY_NAMES: Dictionary = {
	# 任务
	"add_task": "正在添加任务",
	"remove_task": "正在删除任务",
	"update_task_title": "正在更新任务",
	"set_task_completed": "正在更新任务状态",
	"set_task_due_time": "正在设置截止时间",
	"clear_completed_tasks": "正在清理已完成任务",
	"get_all_tasks": "正在获取任务列表",
	"get_incomplete_tasks": "正在获取未完成任务",
	"get_completed_tasks": "正在获取已完成任务",
	"get_overdue_tasks": "正在获取逾期任务",
	"reorder_task": "正在调整任务顺序",
	# 笔记
	"create_note": "正在创建笔记",
	"write_note_content": "正在编辑笔记",
	"open_note": "正在打开笔记",
	"close_note": "正在关闭笔记",
	"remove_note": "正在删除笔记",
	"update_note": "正在更新笔记",
	"search_notes": "正在搜索笔记",
	"get_all_notes": "正在获取笔记列表",
	"get_note_by_id": "正在获取笔记",
	"take_note": "正在记录便签",
	"add_category": "正在添加分类",
	"remove_category": "正在删除分类",
	"toggle_note_category": "正在设置笔记分类",
	"get_categories": "正在获取分类列表",
	# 音乐
	"play_music": "正在播放音乐",
	"pause_music": "正在暂停音乐",
	"toggle_playback": "正在切换播放状态",
	"play_next": "正在播放下一首",
	"play_previous": "正在播放上一首",
	"set_play_mode": "正在设置播放模式",
	"set_bgm_volume": "正在调整音量",
	"get_music_state": "正在获取音乐状态",
	"switch_playlist": "正在切换歌单",
	"create_playlist": "正在创建歌单",
	"delete_playlist": "正在删除歌单",
	"add_track_to_playlist": "正在添加歌曲到歌单",
	"remove_track_from_playlist": "正在从歌单移除歌曲",
	"get_all_playlists": "正在获取歌单列表",
	"get_playlist_tracks": "正在获取歌单曲目",
	"get_all_playlists_data": "正在获取歌单数据",
	# 番茄钟
	"start_pomodoro": "正在启动番茄钟",
	"stop_pomodoro": "正在停止番茄钟",
	"toggle_pomodoro_pause": "正在切换番茄钟暂停",
	"set_work_duration": "正在设置工作时长",
	"set_rest_duration": "正在设置休息时长",
	"get_pomodoro_status": "正在获取番茄钟状态",
	"get_pomodoro_remaining_time": "正在获取剩余时间",
	# 环境设置
	"set_time": "正在设置时间",
	"set_weather": "正在设置天气",
	# 对话控制
	"get_input_status": "正在获取输入状态",
	"set_input_text": "正在设置输入文本",
	"clear_input": "正在清空输入",
	# 房间装饰
	"add_room_decor_item": "正在添加装饰物品",
	"select_room_decor_item": "正在选择装饰物品",
	# 习惯
	"add_habit": "正在添加习惯",
	"remove_habit": "正在删除习惯",
	"update_habit": "正在更新习惯",
	"get_habits": "正在获取习惯列表",
	"get_time_slots": "正在获取时间段",
	"generate_week_schedule": "正在生成周计划",
	"get_week_schedule": "正在获取周计划",
	"set_habit_execution": "正在记录习惯执行",
	"get_habit_stats": "正在获取习惯统计",
	"focus_mode": "正在进入专注模式",
}

# 信号
# 注：所有信号均通过 DialogueState 单例发送，不再使用本地信号

# 配置
@export_group("流式传输设置")
## 每个字符显示的间隔时间（秒）
@export_range(0.01, 0.5, 0.01) var char_display_interval: float = 0.05
## 是否启用流式传输（false 则直接显示全部文本）
@export var enable_streaming: bool = true

@export_group("高度设置")
## 最大高度
@export var max_height: float = 400.0
## 高度调整动画时长
@export var height_transition_duration: float = 0.2

@export_group("按钮设置")
## 按钮文本列表（空数组则隐藏按钮区域）
@export var button_texts: Array[String] = []

@export_group("自动关闭设置")
## 响应完成后自动关闭延迟（秒）
@export var auto_hide_delay: float = 8.0
## 长按触发关闭的持续时间（秒）
@export var long_press_duration: float = 0.5

@export_group("错误提示设置")
## 是否显示报错信息
@export var show_error_message: bool = true

# 节点引用
@onready var vbox_container: VBoxContainer = $VBoxContainer
@onready var frosted_panel: PanelContainer = $VBoxContainer/FrostedPanel
@onready var rich_text_label: RichTextLabel = %RichTextLabel
@onready var button_container: MarginContainer = $VBoxContainer/MarginContainer
@onready var button_hbox: HBoxContainer = $VBoxContainer/MarginContainer/HBoxContainer
@onready var button1: Button = $VBoxContainer/MarginContainer/HBoxContainer/MaterialButton
@onready var button2: Button = $VBoxContainer/MarginContainer/HBoxContainer/MaterialButton2
@onready var button3: Button = $VBoxContainer/MarginContainer/HBoxContainer/MaterialButton3
@onready var loading_container: HBoxContainer = $VBoxContainer/FrostedPanel/MarginContainer/VBoxContainer/HBoxContainer
@onready var progress_indicator = $VBoxContainer/FrostedPanel/MarginContainer/VBoxContainer/HBoxContainer/MaterialProgressIndicator
@onready var loading_label: Label = $VBoxContainer/FrostedPanel/MarginContainer/VBoxContainer/HBoxContainer/Label

# 内部状态
var _full_text: String = "" # 完整文本
var _current_char_index: int = 0 # 当前显示到的字符索引
var _is_streaming: bool = false # 是否正在流式显示
var _stream_timer: Timer = null # 流式显示定时器
var _height_tween: Tween = null # 高度调整动画
var _buttons: Array[Button] = [] # 按钮数组
var _display_state: DisplayState = DisplayState.HIDDEN
var _loading_tween: Tween = null
var _auto_hide_timer: Timer = null
var _long_press_timer: Timer = null
var _func_min_display_timer: Timer = null # 函数执行状态最小显示时间
var _has_received_text: bool = false # 当前响应是否已收到文本
var _current_func_name: String = "" # 当前执行的函数名
var _pending_func_complete: bool = false # 函数已完成但等待最小显示时间


func _ready() -> void:
	# 创建流式显示定时器
	_stream_timer = Timer.new()
	_stream_timer.one_shot = false
	_stream_timer.timeout.connect(_on_stream_timer_timeout)
	add_child(_stream_timer)

	# 创建自动关闭定时器
	_auto_hide_timer = Timer.new()
	_auto_hide_timer.one_shot = true
	_auto_hide_timer.timeout.connect(_on_auto_hide_timeout)
	add_child(_auto_hide_timer)

	# 创建长按检测定时器
	_long_press_timer = Timer.new()
	_long_press_timer.one_shot = true
	_long_press_timer.timeout.connect(_on_long_press_triggered)
	add_child(_long_press_timer)

	# 创建函数执行最小显示定时器（防止同帧内 started/completed 导致用户看不到提示）
	_func_min_display_timer = Timer.new()
	_func_min_display_timer.one_shot = true
	_func_min_display_timer.timeout.connect(_on_func_min_display_timeout)
	add_child(_func_min_display_timer)

	# 收集按钮
	_buttons = [button1, button2, button3]

	# 连接按钮信号
	for i in range(_buttons.size()):
		_buttons[i].pressed.connect(_on_button_pressed.bind(i))

	# 初始化按钮显示
	_update_buttons()

	# 初始化 RichTextLabel
	rich_text_label.bbcode_enabled = true
	rich_text_label.fit_content = false # 禁用自动适应内容，使用固定尺寸
	rich_text_label.scroll_following = true
	rich_text_label.scroll_active = true # 启用滚动
	rich_text_label.clip_contents = true # 裁剪超出内容

	# 监听 RichTextLabel 的尺寸变化
	rich_text_label.resized.connect(_on_rich_text_label_resized)

	# 初始化加载区域（隐藏）
	loading_container.visible = false
	loading_container.custom_minimum_size.y = 0
	loading_container.modulate.a = 0.0

	# 连接 FrostedPanel 的输入事件（长按关闭）
	frosted_panel.gui_input.connect(_on_frosted_panel_gui_input)

	# 监听 ChatState 信号
	ChatState.response_started.connect(_on_response_started)
	ChatState.response_text_delta.connect(_on_response_text_delta)
	ChatState.response_text_set.connect(_on_response_text_set)
	ChatState.response_completed.connect(_on_response_completed)
	ChatState.response_error.connect(_on_response_error)
	ChatState.response_cleared.connect(_on_response_cleared)
	ChatState.function_call_started.connect(_on_function_call_started)
	ChatState.function_call_completed.connect(_on_function_call_completed)


func _exit_tree() -> void:
	if ChatState.response_started.is_connected(_on_response_started):
		ChatState.response_started.disconnect(_on_response_started)
	if ChatState.response_text_delta.is_connected(_on_response_text_delta):
		ChatState.response_text_delta.disconnect(_on_response_text_delta)
	if ChatState.response_text_set.is_connected(_on_response_text_set):
		ChatState.response_text_set.disconnect(_on_response_text_set)
	if ChatState.response_completed.is_connected(_on_response_completed):
		ChatState.response_completed.disconnect(_on_response_completed)
	if ChatState.response_error.is_connected(_on_response_error):
		ChatState.response_error.disconnect(_on_response_error)
	if ChatState.response_cleared.is_connected(_on_response_cleared):
		ChatState.response_cleared.disconnect(_on_response_cleared)
	if ChatState.function_call_started.is_connected(_on_function_call_started):
		ChatState.function_call_started.disconnect(_on_function_call_started)
	if ChatState.function_call_completed.is_connected(_on_function_call_completed):
		ChatState.function_call_completed.disconnect(_on_function_call_completed)


# ============ 显示/隐藏 ============
# 由 agent 模块调用

func show_module() -> void:
	if !visible:
		GuiTransitions.show("dialogue")
		DialogueState.emit_dialogue_shown()


func hide_module() -> void:
	if visible:
		GuiTransitions.hide("dialogue")
		DialogueState.emit_dialogue_hidden()
		# 对话框关闭时发出对话完成信号
		DialogueState.emit_dialogue_finished()


# ============ 显示状态机 ============

func _set_display_state(new_state: DisplayState) -> void:
	if _display_state == new_state:
		return
	var old_state = _display_state
	_display_state = new_state
	# 离开 EXECUTING_FUNC 时清理最小显示定时器
	if old_state == DisplayState.EXECUTING_FUNC and new_state != DisplayState.EXECUTING_FUNC:
		_func_min_display_timer.stop()
		_pending_func_complete = false
	_apply_display_state(old_state, new_state)


func _apply_display_state(old_state: DisplayState, new_state: DisplayState) -> void:
	match new_state:
		DisplayState.HIDDEN:
			_cancel_auto_hide()
			_hide_loading_area()
			hide_module()

		DisplayState.LOADING:
			_cancel_auto_hide()
			if old_state == DisplayState.EXECUTING_FUNC:
				# 从函数执行回来，直接设置文本
				loading_label.text = "正在思考..."
			else:
				_show_loading_area("正在思考...")
			# 无文本时隐藏 RichTextLabel 防止空白
			if !_has_received_text:
				if _height_tween:
					_height_tween.kill()
				rich_text_label.visible = false
				rich_text_label.custom_minimum_size.y = 0

		DisplayState.EXECUTING_FUNC:
			_cancel_auto_hide()
			# 直接设置文本（不用淡入淡出，因为函数执行可能同帧完成）
			var func_text = _get_func_display_text(_current_func_name)
			if loading_container.visible:
				loading_label.text = func_text
			else:
				_show_loading_area(func_text)

		DisplayState.SHOWING_TEXT:
			_cancel_auto_hide()
			_hide_loading_area()
			rich_text_label.visible = true

		DisplayState.COMPLETED:
			_hide_loading_area()
			_start_auto_hide_timer()


# ============ 加载区域动画 ============

func _get_func_display_text(func_name: String) -> String:
	return FUNC_DISPLAY_NAMES.get(func_name, "正在执行 %s" % func_name)


func _show_loading_area(text: String) -> void:
	if _loading_tween:
		_loading_tween.kill()

	loading_label.text = text
	loading_label.modulate.a = 1.0
	loading_container.visible = true
	progress_indicator.start_indeterminate()

	_loading_tween = create_tween()
	_loading_tween.set_ease(Tween.EASE_OUT)
	_loading_tween.set_trans(Tween.TRANS_CUBIC)
	_loading_tween.set_parallel(true)
	_loading_tween.tween_property(loading_container, "modulate:a", 1.0, 0.2)
	_loading_tween.tween_property(loading_container, "custom_minimum_size:y", 24.0, 0.2)


func _hide_loading_area() -> void:
	if !loading_container.visible:
		return

	if _loading_tween:
		_loading_tween.kill()

	_loading_tween = create_tween()
	_loading_tween.set_ease(Tween.EASE_IN)
	_loading_tween.set_trans(Tween.TRANS_CUBIC)
	_loading_tween.set_parallel(true)
	_loading_tween.tween_property(loading_container, "modulate:a", 0.0, 0.2)
	_loading_tween.tween_property(loading_container, "custom_minimum_size:y", 0.0, 0.2)
	_loading_tween.chain().tween_callback(func():
		loading_container.visible = false
		progress_indicator.stop_indeterminate()
	)


# ============ 自动关闭 ============

func _start_auto_hide_timer() -> void:
	_auto_hide_timer.wait_time = auto_hide_delay
	_auto_hide_timer.start()


func _cancel_auto_hide() -> void:
	_auto_hide_timer.stop()


func _on_auto_hide_timeout() -> void:
	_set_display_state(DisplayState.HIDDEN)


# ============ 长按关闭 ============

func _on_frosted_panel_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_long_press_timer.wait_time = long_press_duration
				_long_press_timer.start()
			else:
				_long_press_timer.stop()
	elif event is InputEventScreenTouch:
		if event.pressed:
			_long_press_timer.wait_time = long_press_duration
			_long_press_timer.start()
		else:
			_long_press_timer.stop()


func _on_long_press_triggered() -> void:
	_set_display_state(DisplayState.HIDDEN)


# ============ 对话方法 ============

## 开始显示对话（流式传输）
## @param text: 要显示的文本（支持 BBCode）
## @param speed_override: 可选的速度覆盖（字符间隔时间）
func start_dialogue(text: String, speed_override: float = -1.0) -> void:
	# 停止当前对话
	stop_dialogue()

	_full_text = text
	_current_char_index = 0
	_is_streaming = true

	# 清空当前显示
	rich_text_label.text = ""

	# 通过 DialogueState 发出开始信号（包含文本内容）
	DialogueState.emit_dialogue_started(text)

	if enable_streaming:
		# 启动流式显示
		var interval = speed_override if speed_override > 0 else char_display_interval
		_stream_timer.wait_time = interval
		_stream_timer.start()
	else:
		# 直接显示全部
		skip_to_end()


## 停止对话显示
func stop_dialogue() -> void:
	if not _is_streaming:
		return

	_is_streaming = false
	_stream_timer.stop()
	DialogueState.emit_dialogue_stopped()


## 跳过动画，直接显示全部文本
func skip_to_end() -> void:
	if not _is_streaming:
		return

	_stream_timer.stop()
	_is_streaming = false
	_current_char_index = _full_text.length()
	rich_text_label.text = _full_text

	# 更新高度
	_update_height()

	DialogueState.emit_dialogue_finished()


## 清空对话内容
func clear_dialogue() -> void:
	stop_dialogue()
	_full_text = ""
	_current_char_index = 0
	rich_text_label.text = ""
	_update_height()


## 追加文本（用于流式 API 响应）
## @param text: 要追加的文本
func append_text(text: String) -> void:
	_full_text += text

	# 直接显示追加的文本（用于 API 流式响应）
	rich_text_label.text = _full_text
	_update_height()


## 设置按钮文本
## @param texts: 按钮文本数组（最多3个）
func set_buttons(texts: Array[String]) -> void:
	button_texts = texts
	_update_buttons()


## 获取当前显示的文本
func get_current_text() -> String:
	return rich_text_label.text


## 获取完整文本
func get_full_text() -> String:
	return _full_text


## 是否正在流式显示
func is_streaming() -> bool:
	return _is_streaming


## 手动更新高度（当直接修改 RichTextLabel 内容时调用）
func update_height() -> void:
	_update_height()


## 设置文本内容（会自动更新高度）
## @param text: 要设置的文本
func set_text(text: String) -> void:
	_full_text = text
	rich_text_label.text = text
	_update_height()


func show_demo_response(text: String, append: bool = false) -> void:
	show_module()
	_has_received_text = true
	if append:
		append_text(text)
	else:
		clear_dialogue()
		set_text(text)
		# 演示模式下显示响应文本时发送信号
		DialogueState.emit_dialogue_started(text)
	_set_display_state(DisplayState.SHOWING_TEXT)
	_set_display_state(DisplayState.COMPLETED)


func clear_demo_response() -> void:
	clear_dialogue()
	_set_display_state(DisplayState.HIDDEN)


# ============ 内部方法 ============

## 流式显示定时器回调
func _on_stream_timer_timeout() -> void:
	if _current_char_index >= _full_text.length():
		# 显示完成
		_stream_timer.stop()
		_is_streaming = false
		DialogueState.emit_dialogue_finished()
		return

	# 显示下一个字符
	_current_char_index += 1
	rich_text_label.text = _full_text.substr(0, _current_char_index)

	# 更新高度（每次添加字符时检查）
	_update_height()


## 更新高度
func _update_height() -> void:
	# 等待一帧让 RichTextLabel 计算内容高度
	await get_tree().process_frame

	# RichTextLabel 隐藏时跳过高度更新
	if !rich_text_label.visible:
		return

	# 获取 RichTextLabel 的内容高度
	var content_height = rich_text_label.get_content_height()

	# 直接使用内容高度（MarginContainer 已提供外部 padding，无需重复加 margin）
	var target_height = min(content_height, max_height)

	_tween_rich_text_height(target_height)


## 平滑调整 RichTextLabel 高度
func _tween_rich_text_height(target: float) -> void:
	if _height_tween:
		_height_tween.kill()

	_height_tween = create_tween()
	_height_tween.set_ease(Tween.EASE_OUT)
	_height_tween.set_trans(Tween.TRANS_CUBIC)
	_height_tween.set_parallel(true)

	# 同时设置 custom_minimum_size 和 size 来限制高度
	_height_tween.tween_property(
		rich_text_label,
		"custom_minimum_size:y",
		target,
		height_transition_duration
	)
	_height_tween.tween_property(
		rich_text_label,
		"size:y",
		target,
		height_transition_duration
	)


## RichTextLabel 尺寸变化回调
func _on_rich_text_label_resized() -> void:
	# 当 RichTextLabel 尺寸变化时，可能需要更新滚动
	pass


## 更新按钮显示
func _update_buttons() -> void:
	# 如果没有按钮文本，隐藏按钮容器
	if button_texts.is_empty():
		button_container.visible = false
		return

	button_container.visible = true

	# 更新每个按钮
	for i in range(_buttons.size()):
		if i < button_texts.size():
			_buttons[i].visible = true
			_buttons[i].text = button_texts[i]
		else:
			_buttons[i].visible = false


## 按钮点击回调
func _on_button_pressed(button_index: int) -> void:
	DialogueState.emit_button_pressed(button_index)


# ============ ChatState 响应式回调 ============

func _on_response_started() -> void:
	print("[DialogueBox] _on_response_started")
	_has_received_text = false
	show_module()
	clear_dialogue()
	_set_display_state(DisplayState.LOADING)
	# 对话开始时，文本为空，稍后通过 _on_response_text_set 或 _on_response_text_delta 获取


func _on_response_text_delta(delta: String) -> void:
	if !_has_received_text:
		_has_received_text = true
		_set_display_state(DisplayState.SHOWING_TEXT)
		# 第一段文本到达时发送 dialogue_started 信号
		DialogueState.emit_dialogue_started(delta)
	else:
		append_text(delta)


func _on_response_text_set(text: String) -> void:
	print("[DialogueBox] _on_response_text_set len=%d" % text.length())
	if !_has_received_text and text.length() > 0:
		_has_received_text = true
		_set_display_state(DisplayState.SHOWING_TEXT)
		# 第一次收到文本时，发送 dialogue_started 信号（包含文本内容）
		DialogueState.emit_dialogue_started(text)
	set_text(text)


func _on_response_completed(response_text: String) -> void:
	print("[DialogueBox] _on_response_completed len=%d" % response_text.length())
	if !_has_received_text and response_text.is_empty():
		# 纯函数调用无回复文本 → 直接关闭
		_set_display_state(DisplayState.HIDDEN)
	else:
		_set_display_state(DisplayState.COMPLETED)


func _on_response_error(message: String) -> void:
	print("[DialogueBox] _on_response_error: %s" % message)
	if not show_error_message:
		return
	_has_received_text = true
	show_module()
	_set_display_state(DisplayState.SHOWING_TEXT)
	append_text("\n[color=red]" + message + "[/color]")


func _on_response_cleared() -> void:
	print("[DialogueBox] _on_response_cleared")
	clear_dialogue()


func _on_function_call_started(_call_id: String, func_name: String) -> void:
	print("[DialogueBox] _on_function_call_started: %s" % func_name)
	_current_func_name = func_name
	_pending_func_complete = false
	if _display_state == DisplayState.EXECUTING_FUNC:
		# 连续多个函数调用，直接更新文本
		loading_label.text = _get_func_display_text(func_name)
	else:
		_set_display_state(DisplayState.EXECUTING_FUNC)
	# 启动最小显示定时器（确保用户能看到函数执行提示）
	_func_min_display_timer.wait_time = 0.8
	_func_min_display_timer.start()
	# 发送函数执行信号
	DialogueState.emit_function_executing(func_name, _call_id)


func _on_function_call_completed(_call_id: String, _name: String, _success: bool) -> void:
	print("[DialogueBox] _on_function_call_completed: %s success=%s" % [_name, _success])
	# 发送函数完成信号
	DialogueState.emit_function_completed(_name, _call_id, _success)
	if _func_min_display_timer.time_left > 0:
		# 最小显示时间未到，缓冲状态切换
		_pending_func_complete = true
	else:
		_set_display_state(DisplayState.LOADING)


func _on_func_min_display_timeout() -> void:
	if _pending_func_complete:
		_pending_func_complete = false
		_set_display_state(DisplayState.LOADING)
