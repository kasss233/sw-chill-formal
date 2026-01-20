@tool
class_name MaterialSlider
extends Control

## Material Design 风格滑动条
## 用于音量控制、播放进度等场景
## 支持横向和竖向两种方向

## 方向常量
const HORIZONTAL: int = 0  ## 横向
const VERTICAL: int = 1    ## 竖向

## 值改变信号
signal value_changed(value: float)

## 滑动条方向
@export_enum("Horizontal", "Vertical") var orientation: int = HORIZONTAL:
	set(v):
		orientation = v
		_update_all()

## 当前值
@export var value: float = 0.0:
	set(v):
		var old_value = value
		value = _clamp_value(v)
		if old_value != value:
			_update_layout()
			value_changed.emit(value)

## 最小值
@export var min_value: float = 0.0:
	set(v):
		min_value = v
		_update_layout()

## 最大值
@export var max_value: float = 100.0:
	set(v):
		max_value = v
		_update_layout()

## 步进值
@export var step: float = 1.0

## 轨道厚度（高度/宽度取决于方向）
@export_range(16, 64, 2) var track_thickness: int = 32:
	set(v):
		track_thickness = v
		_update_all()

## 激活轨道颜色
@export var active_color: Color = Color(0.35, 0.65, 0.95):
	set(v):
		active_color = v
		_update_track_fill_style()

## 未激活轨道颜色
@export var inactive_color: Color = Color(0.85, 0.85, 0.85):
	set(v):
		inactive_color = v
		_update_track_bg_style()

## 滑块颜色
@export var thumb_color: Color = Color.WHITE:
	set(v):
		thumb_color = v
		_update_thumb_style()

# 内部节点
var _track_bg: Panel        # 轨道背景（整个胶囊形状）
var _track_fill: Panel      # 轨道填充（激活部分）
var _thumb: Panel           # 滑块

# 交互状态
var _is_dragging: bool = false
var _thumb_tween: Tween

# 尺寸配置
const THUMB_MARGIN: int = 4       # 滑块与轨道边缘的间距
const THUMB_PRESSED_SCALE: float = 1.1

func _ready() -> void:
	_setup_slider()
	_update_all()

func _setup_slider() -> void:
	# 设置基础属性
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	# 创建轨道背景（整个胶囊形状）
	if not _track_bg:
		_track_bg = Panel.new()
		_track_bg.name = "TrackBackground"
		_track_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_track_bg)

	# 创建轨道填充（激活部分，也是胶囊形状）
	if not _track_fill:
		_track_fill = Panel.new()
		_track_fill.name = "TrackFill"
		_track_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_track_fill)

	# 创建滑块（圆形，嵌入在轨道内）
	if not _thumb:
		_thumb = Panel.new()
		_thumb.name = "Thumb"
		_thumb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_thumb.z_index = 1
		add_child(_thumb)

func _update_all() -> void:
	if not is_inside_tree():
		return

	_update_minimum_size()
	_update_track_bg_style()
	_update_track_fill_style()
	_update_thumb_style()
	_update_layout()

func _update_minimum_size() -> void:
	if orientation == HORIZONTAL:
		custom_minimum_size = Vector2(100, track_thickness)
	else:
		custom_minimum_size = Vector2(track_thickness, 100)

func _get_thumb_size() -> int:
	# 滑块直径 = 轨道厚度 - 2 * 边距
	return track_thickness - THUMB_MARGIN * 2

func _get_corner_radius() -> int:
	# 圆角半径 = 轨道厚度的一半（形成胶囊形状）
	return track_thickness / 2

func _update_track_bg_style() -> void:
	if not _track_bg or not is_inside_tree():
		return

	var radius = _get_corner_radius()
	var style = StyleBoxFlat.new()
	style.bg_color = inactive_color
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius

	_track_bg.add_theme_stylebox_override("panel", style)

func _update_track_fill_style() -> void:
	if not _track_fill or not is_inside_tree():
		return

	var radius = _get_corner_radius()
	var style = StyleBoxFlat.new()
	style.bg_color = active_color
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius

	_track_fill.add_theme_stylebox_override("panel", style)

func _update_thumb_style() -> void:
	if not _thumb or not is_inside_tree():
		return

	var thumb_size = _get_thumb_size()
	var radius = thumb_size / 2.0
	var style = StyleBoxFlat.new()
	style.bg_color = thumb_color
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius

	# 添加轻微阴影
	style.shadow_color = Color(0, 0, 0, 0.15)
	style.shadow_size = 2
	style.shadow_offset = Vector2(0, 1)

	_thumb.add_theme_stylebox_override("panel", style)

func _update_layout() -> void:
	if not is_inside_tree():
		return

	var ratio = _get_value_ratio()
	var thumb_size = _get_thumb_size()

	if orientation == HORIZONTAL:
		_update_layout_horizontal(ratio, thumb_size)
	else:
		_update_layout_vertical(ratio, thumb_size)

func _update_layout_horizontal(ratio: float, thumb_size: int) -> void:
	# 轨道背景 - 占满整个控件
	if _track_bg:
		_track_bg.position = Vector2.ZERO
		_track_bg.size = size

	# 计算滑块可移动的范围
	var track_length = size.x - thumb_size - THUMB_MARGIN * 2
	var thumb_x = THUMB_MARGIN + ratio * track_length

	# 轨道填充 - 从左边到滑块右边缘（包住滑块）
	if _track_fill:
		var fill_width = thumb_x + thumb_size + THUMB_MARGIN
		_track_fill.position = Vector2.ZERO
		_track_fill.size = Vector2(fill_width, size.y)

	# 滑块位置
	if _thumb:
		var thumb_y = THUMB_MARGIN
		_thumb.position = Vector2(thumb_x, thumb_y)
		_thumb.size = Vector2(thumb_size, thumb_size)
		_thumb.pivot_offset = Vector2(thumb_size / 2.0, thumb_size / 2.0)

func _update_layout_vertical(ratio: float, thumb_size: int) -> void:
	# 轨道背景 - 占满整个控件
	if _track_bg:
		_track_bg.position = Vector2.ZERO
		_track_bg.size = size

	# 计算滑块可移动的范围（竖向时，底部是最小值，顶部是最大值）
	var track_length = size.y - thumb_size - THUMB_MARGIN * 2
	var thumb_y = THUMB_MARGIN + (1.0 - ratio) * track_length

	# 轨道填充 - 从底部到滑块顶边缘（包住滑块）
	if _track_fill:
		var fill_y = thumb_y - THUMB_MARGIN
		var fill_height = size.y - fill_y
		_track_fill.position = Vector2(0, fill_y)
		_track_fill.size = Vector2(size.x, fill_height)

	# 滑块位置
	if _thumb:
		var thumb_x = THUMB_MARGIN
		_thumb.position = Vector2(thumb_x, thumb_y)
		_thumb.size = Vector2(thumb_size, thumb_size)
		_thumb.pivot_offset = Vector2(thumb_size / 2.0, thumb_size / 2.0)

func _get_value_ratio() -> float:
	if max_value <= min_value:
		return 0.0
	return clampf((value - min_value) / (max_value - min_value), 0.0, 1.0)

func _clamp_value(v: float) -> float:
	var clamped = clampf(v, min_value, max_value)
	if step > 0:
		clamped = round((clamped - min_value) / step) * step + min_value
		clamped = clampf(clamped, min_value, max_value)
	return clamped

func _value_from_position(pos: Vector2) -> float:
	var thumb_size = _get_thumb_size()

	if orientation == HORIZONTAL:
		var track_length = size.x - thumb_size - THUMB_MARGIN * 2
		var ratio = clampf((pos.x - THUMB_MARGIN - thumb_size / 2.0) / track_length, 0.0, 1.0)
		return min_value + ratio * (max_value - min_value)
	else:
		var track_length = size.y - thumb_size - THUMB_MARGIN * 2
		var ratio = 1.0 - clampf((pos.y - THUMB_MARGIN - thumb_size / 2.0) / track_length, 0.0, 1.0)
		return min_value + ratio * (max_value - min_value)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event = event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT:
			if mouse_event.pressed:
				# 开始拖动或点击定位
				_is_dragging = true
				_animate_thumb_press()
				var new_value = _value_from_position(mouse_event.position)
				value = new_value
			else:
				# 结束拖动
				_is_dragging = false
				_animate_thumb_release()

	elif event is InputEventMouseMotion:
		if _is_dragging:
			var motion_event = event as InputEventMouseMotion
			var new_value = _value_from_position(motion_event.position)
			value = new_value

func _animate_thumb_press() -> void:
	if not _thumb or not is_inside_tree():
		return

	if _thumb_tween and _thumb_tween.is_valid():
		_thumb_tween.kill()

	_thumb_tween = create_tween()
	_thumb_tween.set_ease(Tween.EASE_OUT)
	_thumb_tween.set_trans(Tween.TRANS_BACK)
	_thumb_tween.tween_property(_thumb, "scale", Vector2(THUMB_PRESSED_SCALE, THUMB_PRESSED_SCALE), 0.15)

func _animate_thumb_release() -> void:
	if not _thumb or not is_inside_tree():
		return

	if _thumb_tween and _thumb_tween.is_valid():
		_thumb_tween.kill()

	_thumb_tween = create_tween()
	_thumb_tween.set_ease(Tween.EASE_OUT)
	_thumb_tween.set_trans(Tween.TRANS_BACK)
	_thumb_tween.tween_property(_thumb, "scale", Vector2.ONE, 0.15)

## 设置值但不发出信号
func set_value_no_signal(v: float) -> void:
	var clamped = _clamp_value(v)
	if value != clamped:
		value = clamped
		_update_layout()

## 设置颜色
func set_colors(active: Color, inactive: Color, thumb: Color = Color.WHITE) -> void:
	active_color = active
	inactive_color = inactive
	thumb_color = thumb
	_update_all()

## 设置范围
func set_range(min_val: float, max_val: float, step_val: float = 1.0) -> void:
	min_value = min_val
	max_value = max_val
	step = step_val
	value = _clamp_value(value)
	_update_layout()

## 设置方向
func set_orientation(orient: Orientation) -> void:
	orientation = orient

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_update_layout()
