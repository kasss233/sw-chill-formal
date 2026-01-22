@tool
extends Control
class_name InputBox
## 仿 ChatGPT 官网的 AI 对话输入框
## 一开始使用 LineEdit 输入，当文本超出边界时自动切换到 TextEdit 多行输入

# 信号
signal text_submitted(text: String)  # 用户提交文本时发出
signal text_changed(text: String)    # 文本变化时发出

# 配置
@export var max_text_edit_height: float = 200.0  # TextEdit 最大高度
@export var min_text_edit_height: float = 36.0   # TextEdit 最小高度
@export var transition_duration: float = 0.15    # 切换动画时长
@export var singleline_threshold_ratio: float = 0.8  # 切换回单行模式的阈值比例（相对于可用宽度）

# 节点引用
@onready var frosted_panel: PanelContainer = $FrostedPanel
@onready var line_edit: LineEdit = $FrostedPanel/MarginContainer/VBoxContainer/ButtonHBoxContainer/LineEdit
@onready var text_edit_container: MarginContainer = $FrostedPanel/MarginContainer/VBoxContainer/MarginContainer
@onready var text_edit: TextEdit = $FrostedPanel/MarginContainer/VBoxContainer/MarginContainer/TextEdit
@onready var submit_button = $FrostedPanel/MarginContainer/VBoxContainer/ButtonHBoxContainer/SubmitToggleButton

# 状态
var _is_multiline_mode: bool = false  # 是否处于多行模式
var _is_transitioning: bool = false   # 是否正在切换动画中
var _current_tween: Tween = null      # 当前动画 Tween
var _height_tween: Tween = null       # 高度调整动画 Tween

# LineEdit 的原始最小宽度，用于保持布局稳定
var _line_edit_min_width: float = 0.0
# LineEdit 原始的鼠标过滤模式
var _line_edit_original_mouse_filter: Control.MouseFilter = Control.MOUSE_FILTER_STOP


func _ready() -> void:
	if Engine.is_editor_hint():
		return

	# 保存 LineEdit 的原始属性
	_line_edit_min_width = line_edit.custom_minimum_size.x
	_line_edit_original_mouse_filter = line_edit.mouse_filter

	# 连接信号
	line_edit.text_changed.connect(_on_line_edit_text_changed)
	line_edit.text_submitted.connect(_on_line_edit_submitted)
	line_edit.gui_input.connect(_on_line_edit_gui_input)

	text_edit.text_changed.connect(_on_text_edit_text_changed)
	text_edit.gui_input.connect(_on_text_edit_gui_input)

	# 初始化状态：隐藏 TextEdit 容器（使用 visible = false 因为它在独立的位置）
	text_edit_container.visible = false
	text_edit_container.modulate.a = 0.0
	text_edit.custom_minimum_size.y = min_text_edit_height


func _on_line_edit_text_changed(new_text: String) -> void:
	text_changed.emit(new_text)

	if _is_transitioning:
		return

	# 检查文本是否超出 LineEdit 可见区域
	if _should_switch_to_multiline():
		_switch_to_multiline_mode()


func _on_line_edit_submitted(new_text: String) -> void:
	if new_text.strip_edges().is_empty():
		return
	text_submitted.emit(new_text)
	clear_text()


func _on_line_edit_gui_input(event: InputEvent) -> void:
	# 处理 LineEdit 中的回车键（Shift+Enter 切换到多行）
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ENTER and event.shift_pressed:
			# Shift+Enter 强制切换到多行模式
			_switch_to_multiline_mode()
			get_viewport().set_input_as_handled()


func _on_text_edit_text_changed() -> void:
	var current_text := text_edit.text
	text_changed.emit(current_text)

	if _is_transitioning:
		return

	# 动态调整 TextEdit 高度
	_update_text_edit_height()

	# 检查是否应该切换回单行模式
	if _should_switch_to_singleline():
		_switch_to_singleline_mode()


func _on_text_edit_gui_input(event: InputEvent) -> void:
	# 处理 TextEdit 中的回车键提交
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ENTER and not event.shift_pressed:
			# 普通回车提交
			var current_text := text_edit.text.strip_edges()
			if not current_text.is_empty():
				text_submitted.emit(current_text)
				clear_text()
			get_viewport().set_input_as_handled()


## 检查是否应该切换到多行模式
func _should_switch_to_multiline() -> bool:
	if _is_multiline_mode:
		return false

	var font := line_edit.get_theme_font("font")
	var font_size := line_edit.get_theme_font_size("font_size")
	var text_width := font.get_string_size(line_edit.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x

	# 计算 LineEdit 的可用宽度（减去内边距）
	var available_width := line_edit.size.x - 16.0  # 大约的内边距

	return text_width > available_width


## 检查是否应该切换回单行模式
## 使用阈值比例，避免在边界处频繁切换
func _should_switch_to_singleline() -> bool:
	if not _is_multiline_mode:
		return false

	var current_text := text_edit.text

	# 如果文本为空，切换回单行
	if current_text.is_empty():
		return true

	# 检查是否有换行符（包括软换行产生的多行）
	if current_text.contains("\n"):
		return false

	# 检查 TextEdit 是否有多行（自动换行产生的）
	if text_edit.get_line_count() > 1:
		return false

	# 检查单行文本宽度是否能放入 LineEdit
	# 使用阈值比例，只有当文本宽度小于可用宽度的 threshold 时才切换
	var font := line_edit.get_theme_font("font")
	var font_size := line_edit.get_theme_font_size("font_size")
	var text_width := font.get_string_size(current_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var available_width := line_edit.size.x - 16.0  # 减去内边距

	# 使用阈值比例避免在边界处频繁切换
	return text_width <= available_width * singleline_threshold_ratio


## 切换到多行模式
func _switch_to_multiline_mode() -> void:
	if _is_multiline_mode or _is_transitioning:
		return

	_is_transitioning = true
	_is_multiline_mode = true

	# 保存当前文本和光标位置
	var current_text := line_edit.text
	var caret_column := line_edit.caret_column

	# 将文本转移到 TextEdit
	text_edit.text = current_text

	# 计算初始高度
	_update_text_edit_height()

	# 停止之前的动画
	if _current_tween and _current_tween.is_valid():
		_current_tween.kill()

	# 创建切换动画
	_current_tween = create_tween()
	_current_tween.set_ease(Tween.EASE_OUT)
	_current_tween.set_trans(Tween.TRANS_CUBIC)

	# 显示 TextEdit 容器
	text_edit_container.visible = true

	# 并行动画：LineEdit 淡出，TextEdit 淡入
	_current_tween.parallel().tween_property(line_edit, "modulate:a", 0.0, transition_duration)
	_current_tween.parallel().tween_property(text_edit_container, "modulate:a", 1.0, transition_duration)

	_current_tween.tween_callback(func():
		# 禁用 LineEdit 交互，但保持其占用空间（不使用 visible = false）
		line_edit.mouse_filter = Control.MOUSE_FILTER_IGNORE
		line_edit.focus_mode = Control.FOCUS_NONE
		# 清空 LineEdit 文本防止残留
		line_edit.text = ""

		# 设置 TextEdit 焦点和光标
		text_edit.grab_focus()
		text_edit.set_caret_column(caret_column)

		_is_transitioning = false
	)


## 切换回单行模式
func _switch_to_singleline_mode() -> void:
	if not _is_multiline_mode or _is_transitioning:
		return

	_is_transitioning = true
	_is_multiline_mode = false

	# 保存当前文本
	var current_text := text_edit.text
	var caret_column := text_edit.get_caret_column()

	# 恢复 LineEdit 交互
	line_edit.mouse_filter = _line_edit_original_mouse_filter
	line_edit.focus_mode = Control.FOCUS_ALL

	# 将文本转移到 LineEdit
	line_edit.text = current_text

	# 停止之前的动画
	if _current_tween and _current_tween.is_valid():
		_current_tween.kill()

	# 停止高度调整动画
	if _height_tween and _height_tween.is_valid():
		_height_tween.kill()

	# 创建切换动画
	_current_tween = create_tween()
	_current_tween.set_ease(Tween.EASE_OUT)
	_current_tween.set_trans(Tween.TRANS_CUBIC)

	# 并行动画：TextEdit 淡出，LineEdit 淡入
	_current_tween.parallel().tween_property(text_edit_container, "modulate:a", 0.0, transition_duration)
	_current_tween.parallel().tween_property(line_edit, "modulate:a", 1.0, transition_duration)

	# 同时将 TextEdit 高度动画回最小值
	_current_tween.parallel().tween_property(
		text_edit, "custom_minimum_size:y",
		min_text_edit_height,
		transition_duration
	)

	_current_tween.tween_callback(func():
		# 隐藏 TextEdit 容器
		text_edit_container.visible = false
		# 清空 TextEdit 文本防止残留
		text_edit.text = ""

		# 设置 LineEdit 焦点和光标
		line_edit.grab_focus()
		line_edit.caret_column = mini(caret_column, line_edit.text.length())

		_is_transitioning = false
	)


## 更新 TextEdit 高度以适应内容
func _update_text_edit_height() -> void:
	# 延迟到下一帧执行，确保布局已更新
	await get_tree().process_frame

	if not is_inside_tree() or not _is_multiline_mode:
		return

	# 获取字体信息
	var font := text_edit.get_theme_font("font")
	if not font:
		return

	var font_size := text_edit.get_theme_font_size("font_size")
	var line_height := font.get_height(font_size)

	# 计算所有行的总可见行数（包括自动换行）
	var total_visible_lines := 0
	var line_count := text_edit.get_line_count()

	for i in range(line_count):
		# 每个逻辑行至少占 1 行，加上自动换行产生的额外行
		total_visible_lines += 1 + text_edit.get_line_wrap_count(i)

	# 如果没有文本，至少显示 1 行
	if total_visible_lines == 0:
		total_visible_lines = 1

	# 计算所需高度（行高 × 行数 + 内边距）
	var content_height := total_visible_lines * line_height + 16.0

	# 限制在最小和最大高度之间
	var target_height := clampf(content_height, min_text_edit_height, max_text_edit_height)

	# 如果高度变化较大，使用动画
	var current_height := text_edit.custom_minimum_size.y
	if absf(target_height - current_height) > 2.0:
		# 停止之前的高度动画
		if _height_tween and _height_tween.is_valid():
			_height_tween.kill()

		# 创建高度调整动画
		_height_tween = create_tween()
		_height_tween.set_ease(Tween.EASE_OUT)
		_height_tween.set_trans(Tween.TRANS_CUBIC)
		_height_tween.tween_property(
			text_edit, "custom_minimum_size:y",
			target_height,
			0.1
		)
	else:
		text_edit.custom_minimum_size.y = target_height


## 获取当前输入的文本
func get_text() -> String:
	if _is_multiline_mode:
		return text_edit.text
	else:
		return line_edit.text


## 设置文本
func set_text(new_text: String) -> void:
	if _is_multiline_mode:
		text_edit.text = new_text
		_update_text_edit_height()
	else:
		line_edit.text = new_text
		# 检查是否需要切换模式
		if _should_switch_to_multiline():
			_switch_to_multiline_mode()


## 清空文本
func clear_text() -> void:
	# 停止正在进行的动画
	if _current_tween and _current_tween.is_valid():
		_current_tween.kill()
	if _height_tween and _height_tween.is_valid():
		_height_tween.kill()

	if _is_multiline_mode:
		text_edit.text = ""
		_switch_to_singleline_mode()
	else:
		line_edit.text = ""
		# 确保 LineEdit 状态正确
		line_edit.modulate.a = 1.0
		line_edit.mouse_filter = _line_edit_original_mouse_filter
		line_edit.focus_mode = Control.FOCUS_ALL


## 获取焦点
func focus() -> void:
	if _is_multiline_mode:
		text_edit.grab_focus()
	else:
		line_edit.grab_focus()
