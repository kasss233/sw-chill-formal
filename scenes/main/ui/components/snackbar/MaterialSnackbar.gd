@tool
class_name MaterialSnackbar
extends Control

## Material Design 风格消息提示条
## 从底部弹出显示消息，支持操作按钮和自动消失

## 操作按钮点击信号
signal action_pressed
## 消息关闭信号
signal dismissed

## 消息位置常量
const POS_BOTTOM_CENTER: int = 0   ## 底部居中
const POS_TOP_CENTER: int = 1      ## 顶部居中
const POS_CENTER: int = 2          ## 屏幕中央
const POS_TOP_LEFT: int = 3        ## 左上角
const POS_TOP_RIGHT: int = 4       ## 右上角
const POS_BOTTOM_LEFT: int = 5     ## 左下角
const POS_BOTTOM_RIGHT: int = 6    ## 右下角

## 消息类型常量
const TYPE_DEFAULT: int = 0   ## 默认（无图标）
const TYPE_INFO: int = 1      ## 信息
const TYPE_SUCCESS: int = 2   ## 成功
const TYPE_WARNING: int = 3   ## 警告
const TYPE_ERROR: int = 4     ## 错误

## 消息类型配置（背景色、图标色、图标字符）
const TYPE_CONFIG: Dictionary = {
	TYPE_DEFAULT: {
		"bg_color": Color(0.2, 0.2, 0.2, 0.95),
		"icon_color": Color.WHITE,
		"icon": ""
	},
	TYPE_INFO: {
		"bg_color": Color(0.15, 0.35, 0.55, 0.95),
		"icon_color": Color(0.4, 0.7, 1.0),
		"icon": "ℹ"
	},
	TYPE_SUCCESS: {
		"bg_color": Color(0.15, 0.4, 0.25, 0.95),
		"icon_color": Color(0.4, 0.9, 0.5),
		"icon": "✓"
	},
	TYPE_WARNING: {
		"bg_color": Color(0.45, 0.35, 0.15, 0.95),
		"icon_color": Color(1.0, 0.8, 0.3),
		"icon": "⚠"
	},
	TYPE_ERROR: {
		"bg_color": Color(0.45, 0.15, 0.15, 0.95),
		"icon_color": Color(1.0, 0.4, 0.4),
		"icon": "✕"
	}
}

## 消息内容
@export var message: String = "":
	set(v):
		message = v
		if _message_label:
			_message_label.text = message

## 操作按钮文字（为空则不显示按钮）
@export var action_text: String = "":
	set(v):
		action_text = v
		_update_action_button()

## 显示位置
@export_enum("Bottom Center", "Top Center", "Center", "Top Left", "Top Right", "Bottom Left", "Bottom Right") var display_position: int = POS_BOTTOM_CENTER

## 自动消失时长（秒），0表示不自动消失
@export_range(0, 10, 0.5) var duration: float = 3.0

## 背景颜色
@export var background_color: Color = Color(0.2, 0.2, 0.2, 0.95):
	set(v):
		background_color = v
		_update_style()

## 文字颜色
@export var text_color: Color = Color.WHITE:
	set(v):
		text_color = v
		_update_style()

## 操作按钮颜色
@export var action_color: Color = Color(0.35, 0.65, 0.95):
	set(v):
		action_color = v
		_update_style()

## 圆角半径
@export_range(0, 24, 2) var corner_radius: int = 8:
	set(v):
		corner_radius = v
		_update_style()

## 边距
@export_range(8, 64, 4) var edge_margin: int = 24:
	set(v):
		edge_margin = v

## 水平边距
@export_range(8, 64, 4) var horizontal_margin: int = 16:
	set(v):
		horizontal_margin = v

## 图标大小
@export_range(16, 32, 2) var icon_size: int = 20:
	set(v):
		icon_size = v
		_update_icon()

# 内部节点
var _background: Panel
var _hbox: HBoxContainer
var _icon_label: Label
var _message_label: Label
var _action_button: Button
var _timer: Timer
var _tween: Tween

# 当前消息类型
var _current_type: int = TYPE_DEFAULT

# 消息队列
var _message_queue: Array = []
var _is_showing: bool = false

# 动画配置
const ANIMATION_DURATION: float = 0.25

func _ready() -> void:
	_setup_snackbar()
	_update_style()

	# 初始隐藏
	visible = false
	modulate.a = 0

func _setup_snackbar() -> void:
	# 设置基础属性
	mouse_filter = Control.MOUSE_FILTER_STOP

	# 创建背景面板
	if not _background:
		_background = Panel.new()
		_background.name = "Background"
		_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_background)

	# 创建水平布局容器
	if not _hbox:
		_hbox = HBoxContainer.new()
		_hbox.name = "HBoxContainer"
		_hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_hbox.add_theme_constant_override("separation", 12)
		_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
		add_child(_hbox)

	# 创建图标标签
	if not _icon_label:
		_icon_label = Label.new()
		_icon_label.name = "IconLabel"
		_icon_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_icon_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_icon_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_icon_label.visible = false
		_hbox.add_child(_icon_label)

	# 创建消息标签
	if not _message_label:
		_message_label = Label.new()
		_message_label.name = "MessageLabel"
		_message_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_message_label.text = message
		_message_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_message_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_message_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_message_label.autowrap_mode = TextServer.AUTOWRAP_OFF
		_hbox.add_child(_message_label)

	# 创建操作按钮
	if not _action_button:
		_action_button = Button.new()
		_action_button.name = "ActionButton"
		_action_button.flat = true
		_action_button.focus_mode = Control.FOCUS_NONE
		_action_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_action_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		_action_button.pressed.connect(_on_action_pressed)
		_hbox.add_child(_action_button)

	# 创建定时器
	if not _timer:
		_timer = Timer.new()
		_timer.name = "DismissTimer"
		_timer.one_shot = true
		_timer.timeout.connect(_on_timer_timeout)
		add_child(_timer)

	_update_action_button()

func _update_style() -> void:
	if not is_inside_tree():
		return

	# 更新背景样式
	if _background:
		var style = StyleBoxFlat.new()
		style.bg_color = background_color
		style.corner_radius_top_left = corner_radius
		style.corner_radius_top_right = corner_radius
		style.corner_radius_bottom_left = corner_radius
		style.corner_radius_bottom_right = corner_radius
		style.content_margin_left = 16
		style.content_margin_right = 16
		style.content_margin_top = 14
		style.content_margin_bottom = 14
		_background.add_theme_stylebox_override("panel", style)

	# 更新消息标签样式
	if _message_label:
		_message_label.add_theme_color_override("font_color", text_color)

	# 更新操作按钮样式
	if _action_button:
		_action_button.add_theme_color_override("font_color", action_color)
		_action_button.add_theme_color_override("font_hover_color", action_color.lightened(0.2))
		_action_button.add_theme_color_override("font_pressed_color", action_color.darkened(0.1))

		# 设置透明背景
		var empty_style = StyleBoxEmpty.new()
		_action_button.add_theme_stylebox_override("normal", empty_style)
		_action_button.add_theme_stylebox_override("hover", empty_style)
		_action_button.add_theme_stylebox_override("pressed", empty_style)
		_action_button.add_theme_stylebox_override("focus", empty_style)

func _update_action_button() -> void:
	if _action_button:
		_action_button.text = action_text
		_action_button.visible = action_text != ""

func _update_icon() -> void:
	if not _icon_label or not is_inside_tree():
		return

	var config = TYPE_CONFIG.get(_current_type, TYPE_CONFIG[TYPE_DEFAULT])
	var icon_text = config["icon"]

	if icon_text == "":
		_icon_label.visible = false
	else:
		_icon_label.visible = true
		_icon_label.text = icon_text
		_icon_label.add_theme_color_override("font_color", config["icon_color"])
		_icon_label.add_theme_font_size_override("font_size", icon_size)

func _apply_type_style(msg_type: int) -> void:
	_current_type = msg_type
	var config = TYPE_CONFIG.get(msg_type, TYPE_CONFIG[TYPE_DEFAULT])

	# 更新背景颜色
	if _background:
		var style = StyleBoxFlat.new()
		style.bg_color = config["bg_color"]
		style.corner_radius_top_left = corner_radius
		style.corner_radius_top_right = corner_radius
		style.corner_radius_bottom_left = corner_radius
		style.corner_radius_bottom_right = corner_radius
		style.content_margin_left = 16
		style.content_margin_right = 16
		style.content_margin_top = 14
		style.content_margin_bottom = 14
		_background.add_theme_stylebox_override("panel", style)

	# 更新图标
	_update_icon()

func _update_layout() -> void:
	if not is_inside_tree() or not get_parent():
		return

	var parent_size = get_parent_area_size()

	# 计算 snackbar 尺寸
	var max_width = parent_size.x - horizontal_margin * 2
	var min_width = min(300, max_width)

	# 计算内容需要的宽度
	var icon_width = 0
	if _icon_label and _icon_label.visible:
		icon_width = icon_size + 8  # 图标宽度 + 间距

	var action_width = 0
	if _action_button and _action_button.visible:
		action_width = _action_button.get_combined_minimum_size().x + 16

	var message_width = 0
	if _message_label:
		var font = _message_label.get_theme_font("font")
		var font_size = _message_label.get_theme_font_size("font_size")
		if font:
			message_width = font.get_string_size(message, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x

	var content_width = icon_width + message_width + action_width + 32
	var snackbar_width = clamp(content_width, min_width, max_width)
	var snackbar_height = 48

	size = Vector2(snackbar_width, snackbar_height)

	# 根据 display_position 计算位置
	var pos = _calculate_position(parent_size, snackbar_width, snackbar_height)
	set_position(pos)

	# 更新内部布局
	if _background:
		_background.position = Vector2.ZERO
		_background.size = size

	if _hbox:
		_hbox.position = Vector2(16, 0)
		_hbox.size = Vector2(size.x - 32, size.y)

## 根据显示位置计算坐标
func _calculate_position(parent_size: Vector2, w: float, h: float) -> Vector2:
	var pos_x: float
	var pos_y: float

	match display_position:
		POS_BOTTOM_CENTER:
			pos_x = (parent_size.x - w) / 2.0
			pos_y = parent_size.y - h - edge_margin
		POS_TOP_CENTER:
			pos_x = (parent_size.x - w) / 2.0
			pos_y = edge_margin
		POS_CENTER:
			pos_x = (parent_size.x - w) / 2.0
			pos_y = (parent_size.y - h) / 2.0
		POS_TOP_LEFT:
			pos_x = horizontal_margin
			pos_y = edge_margin
		POS_TOP_RIGHT:
			pos_x = parent_size.x - w - horizontal_margin
			pos_y = edge_margin
		POS_BOTTOM_LEFT:
			pos_x = horizontal_margin
			pos_y = parent_size.y - h - edge_margin
		POS_BOTTOM_RIGHT:
			pos_x = parent_size.x - w - horizontal_margin
			pos_y = parent_size.y - h - edge_margin
		_:
			pos_x = (parent_size.x - w) / 2.0
			pos_y = parent_size.y - h - edge_margin

	return Vector2(pos_x, pos_y)

## 获取动画起始位置（从屏幕外滑入）
func _get_animation_start_pos(target_pos: Vector2, parent_size: Vector2) -> Vector2:
	match display_position:
		POS_BOTTOM_CENTER, POS_BOTTOM_LEFT, POS_BOTTOM_RIGHT:
			return Vector2(target_pos.x, parent_size.y)
		POS_TOP_CENTER, POS_TOP_LEFT, POS_TOP_RIGHT:
			return Vector2(target_pos.x, -size.y)
		POS_CENTER:
			return Vector2(target_pos.x, parent_size.y)
		_:
			return Vector2(target_pos.x, parent_size.y)

## 获取动画结束位置（滑出屏幕）
func _get_animation_end_pos(current_pos: Vector2, parent_size: Vector2) -> Vector2:
	match display_position:
		POS_BOTTOM_CENTER, POS_BOTTOM_LEFT, POS_BOTTOM_RIGHT:
			return Vector2(current_pos.x, parent_size.y)
		POS_TOP_CENTER, POS_TOP_LEFT, POS_TOP_RIGHT:
			return Vector2(current_pos.x, -size.y)
		POS_CENTER:
			return Vector2(current_pos.x, parent_size.y)
		_:
			return Vector2(current_pos.x, parent_size.y)

## 显示消息（带类型）
func show_message(msg: String, action: String = "", dur: float = -1, msg_type: int = TYPE_DEFAULT) -> void:
	# 添加到队列
	_message_queue.append({
		"message": msg,
		"action": action,
		"duration": dur if dur >= 0 else duration,
		"type": msg_type
	})

	# 如果当前没有显示消息，开始显示
	if not _is_showing:
		_show_next_message()

## 显示信息消息
func show_info(msg: String, action: String = "", dur: float = -1) -> void:
	show_message(msg, action, dur, TYPE_INFO)

## 显示成功消息
func show_success(msg: String, action: String = "", dur: float = -1) -> void:
	show_message(msg, action, dur, TYPE_SUCCESS)

## 显示警告消息
func show_warning(msg: String, action: String = "", dur: float = -1) -> void:
	show_message(msg, action, dur, TYPE_WARNING)

## 显示错误消息
func show_error(msg: String, action: String = "", dur: float = -1) -> void:
	show_message(msg, action, dur, TYPE_ERROR)

## 立即关闭当前消息
func dismiss() -> void:
	if _is_showing:
		_hide_snackbar()

func _show_next_message() -> void:
	if _message_queue.is_empty():
		_is_showing = false
		return

	_is_showing = true
	var msg_data = _message_queue.pop_front()

	# 设置内容
	message = msg_data["message"]
	action_text = msg_data["action"]
	var dur = msg_data["duration"]
	var msg_type = msg_data.get("type", TYPE_DEFAULT)

	# 应用消息类型样式
	_apply_type_style(msg_type)

	_update_layout()
	_animate_show()

	# 设置自动消失定时器
	if dur > 0:
		_timer.start(dur)

func _animate_show() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()

	visible = true

	# 计算起始位置
	var parent_size = get_parent_area_size()
	var target_pos = position
	var start_pos = _get_animation_start_pos(target_pos, parent_size)

	set_position(start_pos)
	modulate.a = 0

	_tween = create_tween()
	_tween.set_ease(Tween.EASE_OUT)
	_tween.set_trans(Tween.TRANS_BACK)
	_tween.set_parallel(true)
	_tween.tween_property(self, "position", target_pos, ANIMATION_DURATION)
	_tween.tween_property(self, "modulate:a", 1.0, ANIMATION_DURATION * 0.6)

func _hide_snackbar() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()

	_timer.stop()

	var parent_size = get_parent_area_size()
	var end_pos = _get_animation_end_pos(position, parent_size)

	_tween = create_tween()
	_tween.set_ease(Tween.EASE_IN)
	_tween.set_trans(Tween.TRANS_QUAD)
	_tween.set_parallel(true)
	_tween.tween_property(self, "position", end_pos, ANIMATION_DURATION * 0.8)
	_tween.tween_property(self, "modulate:a", 0.0, ANIMATION_DURATION * 0.6)
	_tween.chain().tween_callback(_on_hide_complete)

func _on_hide_complete() -> void:
	visible = false
	dismissed.emit()

	# 显示队列中的下一条消息
	_show_next_message()

func _on_action_pressed() -> void:
	action_pressed.emit()
	dismiss()

func _on_timer_timeout() -> void:
	dismiss()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED or what == NOTIFICATION_PARENTED:
		if _is_showing:
			_update_layout()
