@tool
extends Control

## 条形图组件
## 数据格式: Array[Dictionary] 每项 {"label": str, "value": float}
## 可通过 chart_style 配置样式；未设置时使用内置默认
## 编辑器下修改 chart_style 或图表 export 属性会实时重绘

# ---------- 样式接口 ----------
var _chart_style: ChartStyle
@export var chart_style: ChartStyle:
	get: return _chart_style
	set(v):
		if _chart_style != null and _chart_style.style_changed.is_connected(_on_style_changed):
			_chart_style.style_changed.disconnect(_on_style_changed)
		_chart_style = v
		if _chart_style != null:
			_chart_style.style_changed.connect(_on_style_changed)
		queue_redraw()

# ---------- 数据 ----------
var _data: Array[Dictionary] = []  # [{"label": "一", "value": 2.5}, ...]
var _display_values: Array[float] = []
var _anim_to_values: Array[float] = []
var _anim_from_values: Array[float] = []
var _anim_tween: Tween
var _is_first_build: bool = true

# 参考线（如平均值）
var _reference_value: float = 0.0
var _show_reference: bool = false


func _ready() -> void:
	custom_minimum_size = Vector2(120, 120)
	resized.connect(func(): queue_redraw())


func _exit_tree() -> void:
	if _chart_style != null and _chart_style.style_changed.is_connected(_on_style_changed):
		_chart_style.style_changed.disconnect(_on_style_changed)
	if _anim_tween and _anim_tween.is_valid():
		_anim_tween.kill()


func _on_style_changed() -> void:
	queue_redraw()


## 设置图表数据。animate 为 false 时仅更新数据不播动画，可之后调用 play_show_animation() 再播
func set_chart_data(data: Array, animate: bool = false) -> void:
	_data.clear()
	for item in data:
		if item is Dictionary:
			_data.append({"label": str(item.get("label", "")), "value": float(item.get("value", 0.0))})
		else:
			_data.append({"label": "", "value": float(item)})
	_anim_to_values.clear()
	for item in _data:
		_anim_to_values.append(float(item.get("value", 0.0)))
	if animate:
		_start_animation()
	else:
		_display_values = _anim_to_values.duplicate()
		_anim_from_values = _anim_to_values.duplicate()
		_is_first_build = false
		queue_redraw()


## 兼容三层架构：由 Module 调用，传入 data
func update_display(data: Variant) -> void:
	if data == null:
		clear_data()
		return
	if data is Array:
		set_chart_data(data)
	elif data is Dictionary and data.has("items"):
		set_chart_data(data["items"])
	else:
		set_chart_data([data])


## 设置参考线（如平均值），value <= 0 则不显示
func set_reference_line(value: float) -> void:
	_reference_value = value
	_show_reference = value > 0.0
	queue_redraw()


## 清空数据
func clear_data() -> void:
	_data.clear()
	_display_values.clear()
	_anim_to_values.clear()
	_anim_from_values.clear()
	_show_reference = false
	_reference_value = 0.0
	_is_first_build = true
	queue_redraw()


func _start_animation() -> void:
	var old_values = _display_values.duplicate()
	var count = _data.size()

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

	var dur := _get_animation_duration()
	_set_anim_t(0.0)
	_anim_tween = create_tween()
	_anim_tween.set_trans(Tween.TRANS_CUBIC)
	_anim_tween.set_ease(Tween.EASE_OUT)
	_anim_tween.tween_method(_set_anim_t, 0.0, 1.0, dur)
	_anim_tween.finished.connect(func():
		_is_first_build = false
		_display_values = _anim_to_values.duplicate()
		queue_redraw()
	)


## 播放“逐条伸出”的展示动画（需先 set_chart_data(data, false) 设好数据，再调用）。duration <= 0 时使用 ChartStyle 中的 bar_animation_duration
func play_show_animation(duration: float = -1.0) -> void:
	if _data.is_empty():
		queue_redraw()
		return
	var dur := duration if duration > 0.0 else _get_animation_duration()
	var count := _anim_to_values.size()
	_anim_from_values.resize(count)
	for i in range(count):
		_anim_from_values[i] = 0.0
	_display_values.resize(count)
	for i in range(count):
		_display_values[i] = 0.0
	if _anim_tween and _anim_tween.is_valid():
		_anim_tween.kill()
	# 全局 t 0..1，第 i 条在 t >= i/N 时开始伸长，在 t >= (i+1)/N 时到位
	_anim_tween = create_tween()
	_anim_tween.set_trans(Tween.TRANS_CUBIC)
	_anim_tween.set_ease(Tween.EASE_OUT)
	_anim_tween.tween_method(_set_anim_t_staggered, 0.0, 1.0, dur)
	_anim_tween.finished.connect(func():
		_display_values = _anim_to_values.duplicate()
		queue_redraw()
	)


func _set_anim_t(t: float) -> void:
	_display_values.resize(_anim_to_values.size())
	for i in range(_anim_to_values.size()):
		_display_values[i] = lerpf(float(_anim_from_values[i]), float(_anim_to_values[i]), t)
	queue_redraw()


func _set_anim_t_staggered(t: float) -> void:
	var n := _anim_to_values.size()
	_display_values.resize(n)
	for i in range(n):
		var slot_start := float(i) / float(n)
		var slot_end := float(i + 1) / float(n)
		var local_t := clampf((t - slot_start) / (slot_end - slot_start), 0.0, 1.0)
		_display_values[i] = lerpf(0.0, float(_anim_to_values[i]), local_t)
	queue_redraw()


func _get_style() -> ChartStyle:
	return _chart_style if _chart_style else null


func _get_animation_duration() -> float:
	var s := _get_style()
	if s and s.bar_animation_duration > 0.0:
		return s.bar_animation_duration
	return 1.2


func _get_draw_size() -> Vector2:
	# 编辑器或未布局时 size 可能为 0，用最小尺寸保证能画出内容而非一片黑
	var sz := size
	if sz.x < 80.0 or sz.y < 80.0:
		sz = Vector2(maxf(sz.x, 320.0), maxf(sz.y, 200.0))
	return sz


func _draw() -> void:
	var s := _get_style()
	var p := Vector4(40.0, 24.0, 24.0, 32.0)
	var draw_size := _get_draw_size()
	if s:
		p = s.padding
		if s.background_color.a > 0.0:
			draw_rect(Rect2(Vector2.ZERO, draw_size), s.background_color)
	var plot_rect := Rect2(p.x, p.y, draw_size.x - p.x - p.z, draw_size.y - p.y - p.w)

	if plot_rect.size.x <= 0.0 or plot_rect.size.y <= 0.0:
		return

	var label_color := Color(0.7, 0.7, 0.7, 1.0)
	var value_color := Color(0.85, 0.85, 0.85, 1.0)
	var grid_color := Color(1, 1, 1, 0.08)
	var ref_color := Color(1, 0.85, 0.3, 0.6)
	var empty_color := Color(0.6, 0.6, 0.6, 1.0)
	var label_fs := 11
	var value_fs := 10
	var bar_max_w := 48.0
	var bar_ratio := 0.65
	var bar_radius := 0
	var show_value_label := true
	var ref_dashed := true
	var ref_width := 1.0

	if s:
		label_color = s.label_color
		value_color = s.value_color
		grid_color = s.grid_color
		ref_color = s.bar_reference_line_color
		empty_color = s.empty_message_color
		label_fs = s.label_font_size
		value_fs = s.value_font_size
		bar_max_w = s.bar_max_width
		bar_ratio = s.bar_width_ratio
		bar_radius = s.bar_corner_radius
		show_value_label = s.bar_show_value_label
		ref_dashed = s.bar_reference_line_dashed
		ref_width = s.bar_reference_line_width

	_draw_grid(plot_rect, grid_color)

	if _data.is_empty():
		_draw_centered_text("暂无数据", plot_rect, empty_color, s)
		return

	var max_val := _find_max_value()
	if is_zero_approx(max_val):
		max_val = 1.0

	var count := _data.size()
	var slot_width := plot_rect.size.x / float(count)
	var bar_width := minf(bar_max_w, slot_width * bar_ratio)
	# 统一以槽位中心对齐：条、柱顶数值、X 轴标签都用 slot_center_x
	var label_interval := 1
	if count > 14:
		label_interval = ceili(float(count) / 14.0)

	for i in range(count):
		var value: float = 0.0
		if i < _display_values.size():
			value = _display_values[i]

		var ratio := clampf(value / max_val, 0.0, 1.0)
		var bar_height := ratio * plot_rect.size.y
		var slot_center_x := plot_rect.position.x + (float(i) + 0.5) * slot_width
		var x := slot_center_x - bar_width * 0.5
		var y := plot_rect.end.y - bar_height

		var bar_color: Color = Color(0.35, 0.65, 0.95, 0.9)
		if s and s.bar_colors.size() > 0:
			bar_color = s.bar_colors[i % s.bar_colors.size()]

		if bar_height > 0.5:
			_draw_bar(Rect2(x, y, bar_width, bar_height), bar_color, bar_radius)

		if show_value_label and value > 0.0:
			var val_text := _format_value(value)
			_draw_text_at(val_text, Vector2(slot_center_x, y - 4.0), value_color, value_fs, HORIZONTAL_ALIGNMENT_CENTER)

		if i % label_interval == 0:
			var label_text := str(_data[i].get("label", ""))
			_draw_text_at(label_text, Vector2(slot_center_x, plot_rect.end.y + 18.0), label_color, label_fs, HORIZONTAL_ALIGNMENT_CENTER)

	if _show_reference and _reference_value > 0.0:
		var avg_ratio := clampf(_reference_value / max_val, 0.0, 1.0)
		var avg_y := plot_rect.end.y - avg_ratio * plot_rect.size.y
		if ref_dashed:
			_draw_dashed_line(Vector2(plot_rect.position.x, avg_y), Vector2(plot_rect.end.x, avg_y), ref_color, ref_width, 6.0, 4.0)
		else:
			draw_line(Vector2(plot_rect.position.x, avg_y), Vector2(plot_rect.end.x, avg_y), ref_color, ref_width)
		_draw_text_at(_format_value(_reference_value), Vector2(plot_rect.end.x + 2.0, avg_y + 4.0), ref_color, value_fs, HORIZONTAL_ALIGNMENT_LEFT)


func _draw_grid(plot_rect: Rect2, grid_color: Color) -> void:
	var steps := 4
	for i in range(steps + 1):
		var t := float(i) / float(steps)
		var y := lerpf(plot_rect.end.y, plot_rect.position.y, t)
		draw_line(Vector2(plot_rect.position.x, y), Vector2(plot_rect.end.x, y), grid_color, 1.0)


func _draw_bar(rect: Rect2, color: Color, corner_radius: int) -> void:
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return
	if corner_radius <= 0:
		draw_rect(rect, color)
		return
	var r := mini(int(minf(rect.size.x, rect.size.y) * 0.5), corner_radius)
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(r)
	style.set_corner_detail(6)
	draw_style_box(style, rect)


func _draw_dashed_line(from: Vector2, to: Vector2, color: Color, width: float, dash: float, gap: float) -> void:
	var total := from.distance_to(to)
	if total <= 0.0:
		return
	var dir := (to - from).normalized()
	var pos := 0.0
	while pos < total:
		var end := minf(pos + dash, total)
		draw_line(from + dir * pos, from + dir * end, color, width)
		pos = end + gap


func _draw_text_at(text: String, pos: Vector2, color: Color, font_size: int, alignment: HorizontalAlignment) -> void:
	var font := ThemeDB.fallback_font
	if font == null or text.is_empty():
		return
	# Godot 4 的 draw_string 对 CENTER/RIGHT 对齐可能无效，用手动偏移保证居中
	var draw_pos := pos
	if alignment == HORIZONTAL_ALIGNMENT_CENTER or alignment == HORIZONTAL_ALIGNMENT_RIGHT:
		var str_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size)
		if alignment == HORIZONTAL_ALIGNMENT_CENTER:
			draw_pos.x = pos.x - str_size.x * 0.5
		else:
			draw_pos.x = pos.x - str_size.x
	draw_string(font, draw_pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, color)


func _draw_centered_text(text: String, rect: Rect2, color: Color, s: ChartStyle) -> void:
	var fs := 14
	if s:
		fs = s.empty_message_font_size
	_draw_text_at(text, Vector2(rect.position.x + rect.size.x * 0.5, rect.position.y + rect.size.y * 0.5), color, fs, HORIZONTAL_ALIGNMENT_CENTER)


func _find_max_value() -> float:
	var m := 0.0
	for v in _anim_to_values:
		if v > m:
			m = v
	for v in _anim_from_values:
		if v > m:
			m = v
	if _show_reference and _reference_value > m:
		m = _reference_value
	return m


func _format_value(value: float) -> String:
	if absf(value - roundf(value)) < 0.01:
		return str(int(round(value)))
	return "%.1f" % value
