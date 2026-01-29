extends MarginContainer
class_name DialogueBox
## AI 对话框组件
## 支持流式传输（逐字显示）和自动高度调整

# 信号
signal dialogue_started  # 对话开始时发出
signal dialogue_finished  # 对话完成时发出
signal dialogue_stopped  # 对话被停止时发出
signal button_pressed(button_index: int)  # 按钮被点击时发出

# 配置
@export_group("流式传输设置")
## 每个字符显示的间隔时间（秒）
@export_range(0.01, 0.5, 0.01) var char_display_interval: float = 0.05
## 是否启用流式传输（false 则直接显示全部文本）
@export var enable_streaming: bool = true

@export_group("高度设置")
## 最小高度
@export var min_height: float = 100.0
## 最大高度
@export var max_height: float = 400.0
## 高度调整动画时长
@export var height_transition_duration: float = 0.2

@export_group("按钮设置")
## 按钮文本列表（空数组则隐藏按钮区域）
@export var button_texts: Array[String] = []

# 节点引用
@onready var vbox_container: VBoxContainer = $VBoxContainer
@onready var frosted_panel: PanelContainer = $VBoxContainer/FrostedPanel
@onready var rich_text_label: RichTextLabel = $VBoxContainer/FrostedPanel/MarginContainer/RichTextLabel
@onready var button_container: MarginContainer = $VBoxContainer/MarginContainer
@onready var button_hbox: HBoxContainer = $VBoxContainer/MarginContainer/HBoxContainer
@onready var button1: Button = $VBoxContainer/MarginContainer/HBoxContainer/MaterialButton
@onready var button2: Button = $VBoxContainer/MarginContainer/HBoxContainer/MaterialButton2
@onready var button3: Button = $VBoxContainer/MarginContainer/HBoxContainer/MaterialButton3

# 内部状态
var _full_text: String = ""  # 完整文本
var _current_char_index: int = 0  # 当前显示到的字符索引
var _is_streaming: bool = false  # 是否正在流式显示
var _stream_timer: Timer = null  # 流式显示定时器
var _height_tween: Tween = null  # 高度调整动画
var _buttons: Array[Button] = []  # 按钮数组


func _ready() -> void:
	# 创建流式显示定时器
	_stream_timer = Timer.new()
	_stream_timer.one_shot = false
	_stream_timer.timeout.connect(_on_stream_timer_timeout)
	add_child(_stream_timer)

	# 收集按钮
	_buttons = [button1, button2, button3]

	# 连接按钮信号
	for i in range(_buttons.size()):
		_buttons[i].pressed.connect(_on_button_pressed.bind(i))

	# 初始化按钮显示
	_update_buttons()

	# 初始化 RichTextLabel
	rich_text_label.bbcode_enabled = true
	rich_text_label.fit_content = false  # 禁用自动适应内容，使用固定尺寸
	rich_text_label.scroll_following = true
	rich_text_label.scroll_active = true  # 启用滚动
	rich_text_label.clip_contents = true  # 裁剪超出内容

	# 设置初始高度
	rich_text_label.custom_minimum_size.y = min_height

	# 监听 RichTextLabel 的尺寸变化
	rich_text_label.resized.connect(_on_rich_text_label_resized)

##显示/隐藏
##由agent模块调用
func show_module() -> void:
	if !visible:
		GuiTransitions.show("dialogue")

func hide_module() -> void:
	if visible:
		GuiTransitions.hide("dialogue")

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

	# 发出开始信号
	dialogue_started.emit()

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
	dialogue_stopped.emit()


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

	dialogue_finished.emit()


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

	# 如果没有在流式显示，立即显示追加的文本
	if not _is_streaming:
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
	rich_text_label.text = text
	_update_height()


# 内部方法

## 流式显示定时器回调
func _on_stream_timer_timeout() -> void:
	if _current_char_index >= _full_text.length():
		# 显示完成
		_stream_timer.stop()
		_is_streaming = false
		dialogue_finished.emit()
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

	# 获取 RichTextLabel 的内容高度
	var content_height = rich_text_label.get_content_height()

	# 计算目标高度（加上 margin）
	var margin_top = 12.0
	var margin_bottom = 16.0
	var target_height = clamp(content_height + margin_top + margin_bottom, min_height, max_height)

	# 使用 Tween 平滑调整高度
	if _height_tween:
		_height_tween.kill()

	_height_tween = create_tween()
	_height_tween.set_ease(Tween.EASE_OUT)
	_height_tween.set_trans(Tween.TRANS_CUBIC)
	_height_tween.set_parallel(true)

	# 同时设置 custom_minimum_size 和 custom_maximum_size 来限制高度
	_height_tween.tween_property(
		rich_text_label,
		"custom_minimum_size:y",
		target_height,
		height_transition_duration
	)
	_height_tween.tween_property(
		rich_text_label,
		"size:y",
		target_height,
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
	button_pressed.emit(button_index)
