@tool
class_name MaterialSwitch
extends CheckBox

## Material Design 风格开关 (Switch)
## 简化版，单一尺寸，带加速度动画和背景渐变

## 开启状态颜色（主题色）
@export var active_color: Color = Color(0.35, 0.65, 0.95, 0.8):
	set(value):
		active_color = value
		_update_all()

## 关闭状态颜色（轨道颜色）
@export var inactive_color: Color = Color(0.5, 0.5, 0.5, 0.6):
	set(value):
		inactive_color = value
		_update_all()

## 滑块颜色
@export var thumb_color: Color = Color.WHITE:
	set(value):
		thumb_color = value
		_update_all()

## 文字标签（显示在开关右侧）
@export var label_text: String = "":
	set(value):
		label_text = value
		_update_all()

## 图标与文字间距
@export_range(0, 32, 1) var label_gap: int = 12:
	set(value):
		label_gap = value
		_update_all()

## 是否显示图标（开启状态）
@export var show_icon: bool = true:
	set(value):
		show_icon = value
		_update_thumb_icon()

## 开启状态图标
@export var active_icon: Texture2D = null:
	set(value):
		active_icon = value
		_update_thumb_icon()

# 内部节点
var _track: Panel
var _thumb: Panel
var _thumb_icon: TextureRect
var _label: Label
var _animation_tween: Tween

var _updating: bool = false

# 固定尺寸配置
const TRACK_WIDTH: int = 48
const TRACK_HEIGHT: int = 26
const THUMB_SIZE: int = 20

func _ready() -> void:
	_setup_switch()
	_update_all()

	# 连接信号
	if not toggled.is_connected(_on_toggled):
		toggled.connect(_on_toggled)

func _setup_switch() -> void:
	# 设置基础属性
	clip_contents = false
	focus_mode = Control.FOCUS_NONE  # 禁用焦点，避免显示白色边框
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	# 隐藏默认的 CheckBox 图标
	var empty_texture = ImageTexture.new()
	add_theme_icon_override("checked", empty_texture)
	add_theme_icon_override("unchecked", empty_texture)
	add_theme_constant_override("h_separation", 0)
	add_theme_constant_override("icon_max_width", 0)

	# 禁用所有状态的样式（避免白色边框）
	var empty_style = StyleBoxEmpty.new()
	add_theme_stylebox_override("normal", empty_style)
	add_theme_stylebox_override("hover", empty_style)
	add_theme_stylebox_override("pressed", empty_style)
	add_theme_stylebox_override("focus", empty_style)
	add_theme_stylebox_override("disabled", empty_style)

	# 创建轨道（使用 Panel 以支持 StyleBox）
	if not _track:
		_track = Panel.new()
		_track.name = "Track"
		_track.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_track)

	# 创建滑块
	if not _thumb:
		_thumb = Panel.new()
		_thumb.name = "Thumb"
		_thumb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_thumb.z_index = 1
		add_child(_thumb)

	# 创建滑块图标
	if not _thumb_icon:
		_thumb_icon = TextureRect.new()
		_thumb_icon.name = "ThumbIcon"
		_thumb_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_thumb_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_thumb_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_thumb_icon.z_index = 2
		_thumb.add_child(_thumb_icon)

	# 创建标签
	if not _label:
		_label = Label.new()
		_label.name = "SwitchLabel"
		_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		add_child(_label)

func _update_all() -> void:
	if not is_inside_tree():
		return

	_update_layout()
	_update_track_style()
	_update_thumb_style()
	_update_thumb_icon()
	_update_label()

func _update_layout() -> void:
	if not is_inside_tree() or _updating:
		return

	_updating = true

	# 设置整体尺寸
	var has_label = label_text != ""

	if has_label:
		custom_minimum_size = Vector2(TRACK_WIDTH + label_gap + 80, TRACK_HEIGHT)
	else:
		custom_minimum_size = Vector2(TRACK_WIDTH, TRACK_HEIGHT)

	size = custom_minimum_size

	# 设置轨道位置和尺寸（居中）
	if _track:
		_track.position = Vector2(0, (size.y - TRACK_HEIGHT) / 2.0)
		_track.size = Vector2(TRACK_WIDTH, TRACK_HEIGHT)

	# 设置滑块位置和尺寸（居中，比轨道小）
	if _thumb:
		var thumb_x = 3.0 if not button_pressed else (TRACK_WIDTH - THUMB_SIZE - 3.0)
		var thumb_y = (size.y - THUMB_SIZE) / 2.0
		_thumb.position = Vector2(thumb_x, thumb_y)
		_thumb.size = Vector2(THUMB_SIZE, THUMB_SIZE)

	# 设置标签
	if _label:
		_label.text = label_text
		_label.position = Vector2(TRACK_WIDTH + label_gap, 0)
		_label.size = Vector2(size.x - TRACK_WIDTH - label_gap, size.y)
		_label.visible = has_label

	_updating = false

func _update_track_style() -> void:
	if not _track or not is_inside_tree():
		return

	var radius = TRACK_HEIGHT / 2.0

	var style = StyleBoxFlat.new()
	# 背景半透明
	var current_color = inactive_color if not button_pressed else active_color
	style.bg_color = current_color
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	style.content_margin_left = 0
	style.content_margin_right = 0
	style.content_margin_top = 0
	style.content_margin_bottom = 0

	_track.add_theme_stylebox_override("panel", style)

func _update_thumb_style() -> void:
	if not _thumb or not is_inside_tree():
		return

	var radius = THUMB_SIZE / 2.0

	var style = StyleBoxFlat.new()
	style.bg_color = thumb_color
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	style.content_margin_left = 0
	style.content_margin_right = 0
	style.content_margin_top = 0
	style.content_margin_bottom = 0

	# 添加阴影
	style.shadow_color = Color(0, 0, 0, 0.3)
	style.shadow_size = 3
	style.shadow_offset = Vector2(0, 1)

	_thumb.add_theme_stylebox_override("panel", style)

func _update_thumb_icon() -> void:
	if not _thumb_icon or not is_inside_tree():
		return

	if show_icon and active_icon != null:
		_thumb_icon.texture = active_icon
		_thumb_icon.visible = button_pressed
		_thumb_icon.modulate = active_color

		if _thumb_icon.visible:
			var icon_size = THUMB_SIZE * 0.5
			_thumb_icon.position = Vector2(
				(THUMB_SIZE - icon_size) / 2,
				(THUMB_SIZE - icon_size) / 2
			)
			_thumb_icon.size = Vector2(icon_size, icon_size)
	else:
		_thumb_icon.visible = false

func _update_label() -> void:
	if not _label:
		return

	_label.text = label_text
	_label.visible = label_text != ""

func _on_toggled(_pressed: bool) -> void:
	if not is_inside_tree():
		return

	_animate_toggle()

## 切换开关动画 - 带加速度效果
func _animate_toggle() -> void:
	if not is_inside_tree():
		return

	if _animation_tween and _animation_tween.is_valid():
		_animation_tween.kill()

	_animation_tween = create_tween()
	_animation_tween.set_parallel(false)

	var to_x = TRACK_WIDTH - THUMB_SIZE - 3.0 if button_pressed else 3.0

	# 颜色渐变
	var to_color = active_color if button_pressed else inactive_color
	var from_color = _get_current_track_color()

	# 背景颜色渐变动画（先快速，后慢速）
	_animation_tween.tween_method(_set_track_color, from_color, to_color, 0.3)
	_animation_tween.set_ease(Tween.EASE_OUT)
	_animation_tween.set_trans(Tween.TRANS_QUART)

	# 滑块移动动画 - 带加速度（ease out 效果）
	_animation_tween.parallel()
	_animation_tween.tween_property(_thumb, "position:x", to_x, 0.3)
	_animation_tween.set_ease(Tween.EASE_OUT)
	_animation_tween.set_trans(Tween.TRANS_BACK)

	# 图标淡入淡出
	if _thumb_icon and show_icon and active_icon != null:
		if button_pressed:
			# 开启：图标淡入
			_thumb_icon.modulate.a = 0
			_thumb_icon.visible = true
			_animation_tween.tween_property(_thumb_icon, "modulate:a", 1.0, 0.15)
		else:
			# 关闭：图标淡出
			_animation_tween.tween_property(_thumb_icon, "modulate:a", 0.0, 0.15)
			_animation_tween.tween_callback(func(): _thumb_icon.visible = false)

func _get_current_track_color() -> Color:
	if _track:
		var style = _track.get_theme_stylebox("panel")
		if style is StyleBoxFlat:
			return style.bg_color
	return inactive_color

func _set_track_color(color: Color) -> void:
	if _track:
		var style = _track.get_theme_stylebox("panel")
		if style is StyleBoxFlat:
			style.bg_color = color

## 设置状态但不发送信号
func set_checked_no_signal(pressed: bool) -> void:
	set_pressed_no_signal(pressed)
	_update_all()

## 切换开关
func toggle_switch() -> void:
	button_pressed = not button_pressed

## 设置开关颜色
func set_colors(on: Color, off: Color, thumb: Color = Color.WHITE) -> void:
	active_color = on
	inactive_color = off
	thumb_color = thumb
	_update_all()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_update_layout()
