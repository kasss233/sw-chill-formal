@tool
class_name MaterialSegmentedButton
extends Control

## Material Design 风格分段选择器 (Segmented Button)
## 胶囊形状容器，选中项有蓝色背景高亮

## 选中状态改变信号
signal segment_selected(index: int, text: String)

## 编辑器配置的选项
@export var editor_segments: Array[String] = []:
	set(value):
		editor_segments = value
		if Engine.is_editor_hint() and is_inside_tree():
			_rebuild_from_editor_segments()

## 选中索引
@export var selected_index: int = -1:
	set(value):
		if value < -1 or value >= _segments.size():
			return
		selected_index = value
		_update_selection()

## 背景颜色（容器）
@export var background_color: Color = Color("26262632"):
	set(value):
		background_color = value
		_update_style()

## 选中项背景颜色
@export var selected_color: Color = Color("ffffff"):
	set(value):
		selected_color = value
		_update_selection()

## 未选中文字颜色
@export var unselected_color: Color = Color(0.7, 0.7, 0.7, 1):
	set(value):
		unselected_color = value
		_update_segment_colors()

## 选中文字颜色
@export var selected_text_color: Color = Color.BLACK:
	set(value):
		selected_text_color = value
		_update_segment_colors()

## 胶囊圆角半径
@export_range(4, 32, 1) var corner_radius: int = 20:
	set(value):
		corner_radius = value
		_update_style()

## 按钮高度
@export_range(28, 64, 1) var button_height: int = 36:
	set(value):
		button_height = value
		_update_style()

## 按钮最小宽度
@export_range(60, 200, 5) var min_button_width: int = 80:
	set(value):
		min_button_width = value
		_update_style()

## 按钮间距（0表示紧凑）
@export_range(0, 8, 1) var button_gap: int = 0:
	set(value):
		button_gap = value
		_update_style()

## 是否启用滑块动画
@export var enable_slide_animation: bool = true

## 动画时长
@export_range(0.1, 0.5, 0.05) var animation_duration: float = 0.25

# 内部节点
var _background_panel: Panel
var _selection_indicator: Panel
var _segments_container: HBoxContainer
var _segments: Array[Button] = []
var _slide_tween: Tween
var _is_in_update_selection: bool = false

func _ready() -> void:
	_setup_component()
	_ensure_nodes_in_tree()
	_update_style()

	# 处理暂存的选项（在不在树中时调用的 add_segment）
	if has_meta("_pending_segments"):
		var pending = get_meta("_pending_segments")
		_segments.clear()  # 清除占位符
		for text in pending:
			_add_segment_immediate(text)
		remove_meta("_pending_segments")

	# 从编辑器配置创建选项
	if editor_segments.size() > 0:
		_rebuild_from_editor_segments()

	# 更新布局和选中状态
	_update_layout()
	_update_selection()

func _ensure_nodes_in_tree() -> void:
	# 确保已创建的节点都被添加到树中
	if _background_panel and _background_panel.get_parent() == null:
		add_child(_background_panel)
	if _segments_container and _segments_container.get_parent() == null:
		add_child(_segments_container)
	if _selection_indicator and _background_panel and _selection_indicator.get_parent() == null:
		_background_panel.add_child(_selection_indicator)

func _add_segment_immediate(text: String) -> void:
	# 内部方法：假设已经在场景树中
	if not _segments_container:
		return

	var button = Button.new()
	button.name = "Segment_%d" % _segments.size()
	button.text = text
	button.mouse_filter = Control.MOUSE_FILTER_STOP

	_update_segment_style(button)
	button.custom_minimum_size.x = min_button_width
	button.custom_minimum_size.y = button_height

	var index = _segments.size()
	button.pressed.connect(_on_segment_pressed.bind(index))

	_segments_container.add_child(button)
	_segments.append(button)

	if _segments.size() == 1 and selected_index < 0:
		selected_index = 0

func _setup_component() -> void:
	# 防止重复初始化
	if _background_panel and _segments_container and _selection_indicator:
		return

	mouse_filter = Control.MOUSE_FILTER_PASS

	# 创建背景面板（作为底层，覆盖整个组件）
	if not _background_panel:
		_background_panel = Panel.new()
		_background_panel.name = "BackgroundPanel"
		_background_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_background_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
		_background_panel.offset_left = 0
		_background_panel.offset_top = 0
		_background_panel.offset_right = 0
		_background_panel.offset_bottom = 0
		if is_inside_tree():
			add_child(_background_panel)

	# 创建按钮容器（居中放置在背景之上）
	if not _segments_container:
		_segments_container = HBoxContainer.new()
		_segments_container.name = "SegmentsContainer"
		_segments_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_segments_container.set_anchors_preset(Control.PRESET_FULL_RECT)
		_segments_container.add_theme_constant_override("separation", button_gap)
		if is_inside_tree():
			add_child(_segments_container)

	# 创建选中指示器（在背景面板上）
	if not _selection_indicator and _background_panel:
		_selection_indicator = Panel.new()
		_selection_indicator.name = "SelectionIndicator"
		_selection_indicator.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_selection_indicator.set_anchors_preset(Control.PRESET_TOP_LEFT)
		_background_panel.add_child(_selection_indicator)

func _update_style() -> void:
	if not is_inside_tree():
		return

	# 更新按钮容器间距
	if _segments_container:
		_segments_container.add_theme_constant_override("separation", button_gap)

	# 更新背景样式
	if _background_panel:
		var bg_style = StyleBoxFlat.new()
		bg_style.bg_color = background_color
		bg_style.corner_radius_top_left = corner_radius
		bg_style.corner_radius_top_right = corner_radius
		bg_style.corner_radius_bottom_left = corner_radius
		bg_style.corner_radius_bottom_right = corner_radius
		_background_panel.add_theme_stylebox_override("panel", bg_style)

	# 更新选中指示器样式
	if _selection_indicator:
		var indicator_style = StyleBoxFlat.new()
		indicator_style.bg_color = selected_color
		indicator_style.corner_radius_top_left = corner_radius - 2
		indicator_style.corner_radius_top_right = corner_radius - 2
		indicator_style.corner_radius_bottom_left = corner_radius - 2
		indicator_style.corner_radius_bottom_right = corner_radius - 2
		_selection_indicator.add_theme_stylebox_override("panel", indicator_style)

	# 更新所有按钮样式
	for segment in _segments:
		if segment:
			_update_segment_style(segment)

	# 更新按钮尺寸
	_update_button_sizes()

	# 更新布局
	_update_layout()

func _update_layout() -> void:
	if not is_inside_tree():
		return

	# 等待一帧确保尺寸已更新
	call_deferred("_deferred_update_layout")

func _deferred_update_layout() -> void:
	if not is_inside_tree():
		return

	# 计算所有按钮的总宽度
	var total_width = 0
	for segment in _segments:
		if not segment:
			continue
		total_width += segment.size.x
		if _segments_container:
			total_width += _segments_container.get_theme_constant("separation")

	# 设置组件尺寸（确保背景面板有足够尺寸）
	if _segments.size() > 0:
		custom_minimum_size = Vector2(total_width, button_height)
	else:
		custom_minimum_size = Vector2(min_button_width, button_height)

	# 更新选中指示器位置和尺寸
	_update_selection()

func _update_button_sizes() -> void:
	for segment in _segments:
		if not segment:
			continue
		segment.custom_minimum_size.x = min_button_width
		segment.custom_minimum_size.y = button_height

func _update_segment_style(segment: Button) -> void:
	if not segment:
		return

	# 清除所有样式覆盖
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var empty_style = StyleBoxEmpty.new()
		segment.add_theme_stylebox_override(state, empty_style)

	# 设置字体颜色
	segment.add_theme_color_override("font_color", unselected_color)
	segment.add_theme_color_override("font_hover_color", unselected_color)

	# 设置焦点模式
	segment.focus_mode = Control.FOCUS_NONE
	segment.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

func _update_segment_colors() -> void:
	for i in range(_segments.size()):
		var segment = _segments[i]
		if not segment:
			continue

		if i == selected_index:
			segment.add_theme_color_override("font_color", selected_text_color)
		else:
			segment.add_theme_color_override("font_color", unselected_color)

func _update_selection() -> void:
	if not is_inside_tree() or not _selection_indicator:
		return

	# 更新文字颜色
	_update_segment_colors()

	# 如果没有选中项，隐藏指示器
	if selected_index < 0 or selected_index >= _segments.size():
		_selection_indicator.visible = false
		return

	_selection_indicator.visible = true
	var target_segment = _segments[selected_index]

	if not target_segment:
		return

	# 等待一帧确保按钮尺寸已更新
	if not _is_in_update_selection:
		_is_in_update_selection = true
		await get_tree().process_frame
		_is_in_update_selection = false
		if not is_inside_tree():
			return

	# 计算目标位置和尺寸
	var target_pos = target_segment.position
	var target_size = target_segment.size

	# 指示器应该与按钮位置和尺寸一致（考虑内边距）
	var indicator_offset = 2
	var indicator_y = indicator_offset + (button_height - target_size.y) / 2.0

	# 如果启用动画，使用滑动效果
	if enable_slide_animation and is_inside_tree():
		if _slide_tween and _slide_tween.is_valid():
			_slide_tween.kill()

		_slide_tween = create_tween()
		_slide_tween.set_ease(Tween.EASE_OUT)
		_slide_tween.set_trans(Tween.TRANS_CUBIC)
		_slide_tween.set_parallel(true)
		_slide_tween.tween_property(_selection_indicator, "position:x", target_pos.x + indicator_offset, animation_duration)
		_slide_tween.tween_property(_selection_indicator, "position:y", indicator_y, animation_duration)
		_slide_tween.tween_property(_selection_indicator, "size:x", target_size.x - indicator_offset * 2, animation_duration)
		_slide_tween.tween_property(_selection_indicator, "size:y", target_size.y - indicator_offset * 2, animation_duration)
	else:
		_selection_indicator.position = Vector2(target_pos.x + indicator_offset, indicator_y)
		_selection_indicator.size = target_size - Vector2(indicator_offset * 2, indicator_offset * 2)

# ============ 公共 API ============

## 添加选项
func add_segment(text: String) -> int:
	# 确保组件已初始化
	if not _segments_container:
		_setup_component()

	# 如果不在场景树中，延迟到进入场景树后再添加
	if not is_inside_tree():
		# 暂存要添加的文本，等进入场景树后再处理
		if not has_meta("_pending_segments"):
			set_meta("_pending_segments", [])
		var pending = get_meta("_pending_segments")
		pending.append(text)
		_segments.append(null)  # 占位符
		return _segments.size() - 1

	var button = Button.new()
	button.name = "Segment_%d" % _segments.size()
	button.text = text
	button.mouse_filter = Control.MOUSE_FILTER_STOP

	# 应用样式
	_update_segment_style(button)
	button.custom_minimum_size.x = min_button_width
	button.custom_minimum_size.y = button_height

	# 连接信号
	var index = _segments.size()
	button.pressed.connect(_on_segment_pressed.bind(index))

	_segments_container.add_child(button)
	_segments.append(button)

	# 如果是第一个选项且没有选中项，自动选中
	if _segments.size() == 1 and selected_index < 0:
		selected_index = 0

	# 更新布局
	_update_layout()

	return index

## 移除选项
func remove_segment(index: int) -> void:
	if index < 0 or index >= _segments.size():
		return

	var segment = _segments[index]
	if is_instance_valid(segment):
		segment.queue_free()

	_segments.remove_at(index)

	# 更新选中索引
	if selected_index >= _segments.size():
		selected_index = _segments.size() - 1
	elif selected_index == index:
		selected_index = -1

	# 重新连接所有按钮信号
	_reconnect_signals()

	_update_layout()

## 清空所有选项
func clear_segments() -> void:
	for segment in _segments:
		if is_instance_valid(segment):
			segment.queue_free()
	_segments.clear()
	selected_index = -1
	_update_layout()

## 获取选项数量
func get_segment_count() -> int:
	return _segments.size()

## 获取选项文本
func get_segment_text(index: int) -> String:
	if index >= 0 and index < _segments.size():
		var segment = _segments[index]
		if segment:
			return segment.text
	return ""

## 设置选项文本
func set_segment_text(index: int, text: String) -> void:
	if index >= 0 and index < _segments.size():
		var segment = _segments[index]
		if segment:
			segment.text = text

## 获取当前选中的索引
func get_selected_index() -> int:
	return selected_index

## 获取当前选中的文本
func get_selected_text() -> String:
	if selected_index >= 0 and selected_index < _segments.size():
		var segment = _segments[selected_index]
		if segment:
			return segment.text
	return ""

## 设置选中项（不发送信号）
func set_selected_no_signal(index: int) -> void:
	if index >= -1 and index < _segments.size():
		selected_index = index
		_update_selection()

func _on_segment_pressed(index: int) -> void:
	if index == selected_index:
		return  # 已经是选中状态

	selected_index = index
	var segment = _segments[index]
	if segment:
		segment_selected.emit(index, segment.text)

func _reconnect_signals() -> void:
	for i in range(_segments.size()):
		var segment = _segments[i]
		if not segment:
			continue
		if segment.pressed.is_connected(_on_segment_pressed):
			segment.pressed.disconnect(_on_segment_pressed)
		segment.pressed.connect(_on_segment_pressed.bind(i))

func _rebuild_from_editor_segments() -> void:
	if not is_inside_tree() or not _segments_container:
		return

	# 清除现有的编辑器生成的按钮
	for segment in _segments:
		if is_instance_valid(segment) and segment.has_meta("from_editor"):
			segment.queue_free()
	_segments.clear()

	# 从配置数组创建选项
	for segment_text in editor_segments:
		if segment_text.is_empty():
			continue

		var button = Button.new()
		button.name = "Segment_%d" % _segments.size()
		button.text = segment_text
		button.mouse_filter = Control.MOUSE_FILTER_STOP
		button.set_meta("from_editor", true)

		# 应用样式
		_update_segment_style(button)
		button.custom_minimum_size.x = min_button_width
		button.custom_minimum_size.y = button_height

		# 连接信号
		var index = _segments.size()
		button.pressed.connect(_on_segment_pressed.bind(index))

		_segments_container.add_child(button)
		_segments.append(button)

	# 如果有选项且没有选中项，默认选中第一个
	if _segments.size() > 0 and selected_index < 0:
		selected_index = 0

	_update_layout()
	_update_selection()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_update_layout()
	elif what == NOTIFICATION_CHILD_ORDER_CHANGED:
		if Engine.is_editor_hint() and is_inside_tree():
			_collect_existing_segments()

## 收集编辑器中手动添加的子节点
func _collect_existing_segments() -> void:
	if not _segments_container:
		return

	for child in _segments_container.get_children():
		if child is Button and child not in _segments:
			var index = _segments.size()
			_update_segment_style(child)
			child.custom_minimum_size.x = min_button_width
			child.custom_minimum_size.y = button_height

			if not child.pressed.is_connected(_on_segment_pressed):
				child.pressed.connect(_on_segment_pressed.bind(index))

			_segments.append(child)

	_update_layout()
