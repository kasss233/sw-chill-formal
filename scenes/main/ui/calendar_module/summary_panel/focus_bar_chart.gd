extends Control

## 专注统计柱状图组件
## 胶囊柱体 + 日均虚线 + Tween 动画，暗色主题

var _chart_data: Array[Dictionary] = []  # [{"label": "一", "value": 2.5}, ...]
var _average_value: float = 0.0
var _show_average: bool = false

# 绘制参数
var _padding_left: float = 40.0
var _padding_right: float = 12.0
var _padding_top: float = 20.0
var _padding_bottom: float = 28.0
var _bar_max_width: float = 36.0
var _bar_width_ratio: float = 0.65

# 动画
var _display_values: Array[float] = []
var _anim_to_values: Array[float] = []
var _anim_from_values: Array[float] = []
var _anim_tween: Tween
var _is_first_build: bool = true

# 颜色
var _bar_color: Color = Color(0.35, 0.65, 0.95, 0.85)
var _grid_color: Color = Color(1, 1, 1, 0.08)
var _text_color: Color = Color(0.7, 0.7, 0.7, 1)
var _value_text_color: Color = Color(0.85, 0.85, 0.85, 1)
var _average_line_color: Color = Color(1, 0.85, 0.3, 0.6)


func _ready() -> void:
	custom_minimum_size = Vector2(0, 180)
	resized.connect(func(): queue_redraw())


func set_chart_data(data: Array[Dictionary]) -> void:
	_chart_data = data.duplicate(true)
	_start_animation()


func set_average_line(value: float) -> void:
	_average_value = value
	_show_average = value > 0.0
	queue_redraw()


func clear_data() -> void:
	_chart_data.clear()
	_display_values.clear()
	_anim_to_values.clear()
	_show_average = false
	_average_value = 0.0
	_is_first_build = true
	queue_redraw()


func _start_animation() -> void:
	var old_values = _display_values.duplicate()
	var count = _chart_data.size()

	_anim_to_values.clear()
	for item in _chart_data:
		_anim_to_values.append(float(item.get("value", 0.0)))

	_anim_from_values.resize(count)
	for i in range(count):
		if _is_first_build:
			_anim_from_values[i] = 0.0
		elif i < old_values.size():
			_anim_from_values[i] = float(old_values[i])
		else:
			_anim_from_values[i] = 0.0

	if _anim_tween and _anim_tween.is_valid():
		_anim_tween.kill()

	_set_anim_t(0.0)
	_anim_tween = create_tween()
	_anim_tween.set_trans(Tween.TRANS_CUBIC)
	_anim_tween.set_ease(Tween.EASE_OUT)
	_anim_tween.tween_method(_set_anim_t, 0.0, 1.0, 0.35)
	_anim_tween.finished.connect(func():
		_is_first_build = false
		_display_values = _anim_to_values.duplicate()
		queue_redraw()
	)


func _set_anim_t(t: float) -> void:
	_display_values.resize(_anim_to_values.size())
	for i in range(_anim_to_values.size()):
		_display_values[i] = lerpf(float(_anim_from_values[i]), float(_anim_to_values[i]), t)
	queue_redraw()


func _draw() -> void:
	var plot_rect = Rect2(
		_padding_left,
		_padding_top,
		size.x - _padding_left - _padding_right,
		size.y - _padding_top - _padding_bottom,
	)

	if plot_rect.size.x <= 0.0 or plot_rect.size.y <= 0.0:
		return

	# 网格线
	_draw_grid(plot_rect)

	if _chart_data.is_empty():
		_draw_centered_text("暂无专注数据", plot_rect)
		return

	var max_value = _find_max_display_value()
	if is_zero_approx(max_value):
		max_value = 1.0

	var count = _chart_data.size()
	var slot_width = plot_rect.size.x / float(count)
	var bar_width = minf(_bar_max_width, slot_width * _bar_width_ratio)

	# 是否间隔显示 X 轴标签（柱数 > 14）
	var label_interval = 1
	if count > 14:
		label_interval = ceili(float(count) / 14.0)

	# 绘制柱体
	for i in range(count):
		var value: float = 0.0
		if i < _display_values.size():
			value = _display_values[i]

		var ratio = clampf(value / max_value, 0.0, 1.0)
		var bar_height = ratio * plot_rect.size.y
		var x = plot_rect.position.x + float(i) * slot_width + (slot_width - bar_width) * 0.5
		var y = plot_rect.end.y - bar_height

		if bar_height > 1.0:
			_draw_capsule_bar(Rect2(x, y, bar_width, bar_height), _bar_color)

		# 柱顶数值
		if value > 0.0:
			var val_text = _format_value(value)
			_draw_text_at(val_text, Vector2(x + bar_width * 0.5, y - 4.0), _value_text_color, 10, HORIZONTAL_ALIGNMENT_CENTER)

		# X 轴标签
		if i % label_interval == 0:
			var label_text = str(_chart_data[i].get("label", ""))
			_draw_text_at(label_text, Vector2(x + bar_width * 0.5, plot_rect.end.y + 16.0), _text_color, 10, HORIZONTAL_ALIGNMENT_CENTER)

	# 日均虚线
	if _show_average and _average_value > 0.0:
		var avg_ratio = clampf(_average_value / max_value, 0.0, 1.0)
		var avg_y = plot_rect.end.y - avg_ratio * plot_rect.size.y
		_draw_dashed_line(
			Vector2(plot_rect.position.x, avg_y),
			Vector2(plot_rect.end.x, avg_y),
			_average_line_color, 1.0, 6.0, 4.0
		)
		_draw_text_at(_format_value(_average_value) + "h", Vector2(plot_rect.end.x + 2.0, avg_y + 4.0), _average_line_color, 9, HORIZONTAL_ALIGNMENT_LEFT)


func _draw_grid(plot_rect: Rect2) -> void:
	var steps = 4
	for i in range(steps + 1):
		var t = float(i) / float(steps)
		var y = lerpf(plot_rect.end.y, plot_rect.position.y, t)
		draw_line(Vector2(plot_rect.position.x, y), Vector2(plot_rect.end.x, y), _grid_color, 1.0)


func _draw_capsule_bar(rect: Rect2, color: Color) -> void:
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return
	var radius = int(floor(minf(rect.size.x, rect.size.y) * 0.5))
	var style = StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	style.set_corner_detail(6)
	draw_style_box(style, rect)


func _draw_dashed_line(from: Vector2, to: Vector2, color: Color, width: float, dash: float, gap: float) -> void:
	var total_length = from.distance_to(to)
	if total_length <= 0.0:
		return
	var dir = (to - from).normalized()
	var pos: float = 0.0
	while pos < total_length:
		var dash_end = minf(pos + dash, total_length)
		draw_line(from + dir * pos, from + dir * dash_end, color, width)
		pos = dash_end + gap


func _draw_text_at(text: String, pos: Vector2, color: Color, font_size: int, alignment: HorizontalAlignment) -> void:
	var font = ThemeDB.fallback_font
	if font == null:
		return
	draw_string(font, pos, text, alignment, -1.0, font_size, color)


func _draw_centered_text(text: String, rect: Rect2) -> void:
	_draw_text_at(text, Vector2(rect.position.x + rect.size.x * 0.5, rect.position.y + rect.size.y * 0.5), _text_color, 13, HORIZONTAL_ALIGNMENT_CENTER)


func _find_max_display_value() -> float:
	var max_val: float = 0.0
	for v in _anim_to_values:
		if v > max_val:
			max_val = v
	for v in _anim_from_values:
		if v > max_val:
			max_val = v
	return max_val


func _format_value(value: float) -> String:
	if absf(value - roundf(value)) < 0.01:
		return str(int(round(value)))
	return "%0.1f" % value
