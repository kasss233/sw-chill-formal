@tool
extends Control

## 饼图组件
## 数据格式: Array[Dictionary] 每项 {"label": str, "value": float}，value 可为绝对值（自动按比例）或 0~1 比例
## 可通过 chart_style 配置样式；编辑器下修改属性会实时重绘

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
var _data: Array[Dictionary] = []  # [{"label": "A", "value": 30}, ...]
var _display_t: float = 1.0  # 动画 0~1
var _segment_reveal_t: Array[float] = []  # 每扇区当前展示比例 0~1，用于转出动画
var _anim_tween: Tween
var _is_first_build: bool = true
var _totals: Array[float] = []  # 每项占比 0~1
var _start_angles: Array[float] = []  # 每项起始弧度


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
	var sum := 0.0
	for item in data:
		if item is Dictionary:
			var v := float(item.get("value", 0.0))
			sum += v
			_data.append({"label": str(item.get("label", "")), "value": v})
		else:
			sum += float(item)
			_data.append({"label": "", "value": float(item)})

	_totals.clear()
	_start_angles.clear()
	_segment_reveal_t.clear()
	if sum > 0.0:
		var acc := 0.0
		for item in _data:
			var r := float(item.get("value", 0.0)) / sum
			_totals.append(r)
			_start_angles.append(acc)
			acc += r
			_segment_reveal_t.append(1.0)
	else:
		for item in _data:
			_totals.append(0.0)
			_start_angles.append(0.0)
			_segment_reveal_t.append(1.0)

	if animate:
		_start_animation()
	else:
		_display_t = 1.0
		_is_first_build = false
		queue_redraw()


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


func clear_data() -> void:
	_data.clear()
	_totals.clear()
	_start_angles.clear()
	_segment_reveal_t.clear()
	_display_t = 0.0
	_is_first_build = true
	queue_redraw()


func _get_style() -> ChartStyle:
	return _chart_style if _chart_style else null


func _get_animation_duration() -> float:
	var s := _get_style()
	if s and s.pie_animation_duration > 0.0:
		return s.pie_animation_duration
	return 1.2


## 百分比标签沿射线向外延伸的距离系数（相对半径），>1 表示在圆外
func _get_pie_label_distance_ratio() -> float:
	return 1.12


func _start_animation() -> void:
	if _anim_tween and _anim_tween.is_valid():
		_anim_tween.kill()
	var from_t := 0.0 if _is_first_build else 1.0
	_display_t = from_t
	_update_segment_reveal_from_t(from_t)
	_anim_tween = create_tween()
	_anim_tween.set_trans(Tween.TRANS_CUBIC)
	_anim_tween.set_ease(Tween.EASE_OUT)
	var dur := _get_animation_duration()
	_anim_tween.tween_method(_set_display_t, from_t, 1.0, dur)
	_anim_tween.finished.connect(func():
		_is_first_build = false
		_update_segment_reveal_from_t(1.0)
		queue_redraw()
	)


## 播放“扇区转出”的展示动画（需先 set_chart_data(data, false) 设好数据，再调用）。duration <= 0 时使用 ChartStyle 中的 pie_animation_duration
func play_show_animation(duration: float = -1.0) -> void:
	if _data.is_empty():
		queue_redraw()
		return
	var dur := duration if duration > 0.0 else _get_animation_duration()
	_segment_reveal_t.resize(_data.size())
	for i in range(_data.size()):
		_segment_reveal_t[i] = 0.0
	_display_t = 0.0
	if _anim_tween and _anim_tween.is_valid():
		_anim_tween.kill()
	_anim_tween = create_tween()
	_anim_tween.set_trans(Tween.TRANS_CUBIC)
	_anim_tween.set_ease(Tween.EASE_OUT)
	_anim_tween.tween_method(_set_display_t, 0.0, 1.0, dur)
	_anim_tween.finished.connect(func():
		_update_segment_reveal_from_t(1.0)
		_display_t = 1.0
		queue_redraw()
	)


func _set_display_t(t: float) -> void:
	_display_t = t
	_update_segment_reveal_from_t(t)
	queue_redraw()


func _update_segment_reveal_from_t(t: float) -> void:
	var n := _segment_reveal_t.size()
	if n == 0:
		return
	for i in range(n):
		var slot_start := float(i) / float(n)
		var slot_end := float(i + 1) / float(n)
		_segment_reveal_t[i] = clampf((t - slot_start) / (slot_end - slot_start), 0.0, 1.0)


func _get_draw_size() -> Vector2:
	var sz := size
	if sz.x < 80.0 or sz.y < 80.0:
		sz = Vector2(maxf(sz.x, 320.0), maxf(sz.y, 240.0))
	return sz


func _draw() -> void:
	var s := _get_style()
	var p := Vector4(24.0, 24.0, 24.0, 24.0)
	var draw_size := _get_draw_size()
	if s:
		p = s.padding
		if s.background_color.a > 0.0:
			draw_rect(Rect2(Vector2.ZERO, draw_size), s.background_color)

	var plot_rect := Rect2(p.x, p.y, draw_size.x - p.x - p.z, draw_size.y - p.y - p.w)
	if plot_rect.size.x <= 0.0 or plot_rect.size.y <= 0.0:
		return

	var empty_color := Color(0.6, 0.6, 0.6, 1.0)
	var label_color := Color(0.85, 0.85, 0.85, 1.0)
	var label_fs := 11
	var stroke_col := Color(0.2, 0.2, 0.2, 0.5)
	var stroke_w := 1.0
	var inner_ratio := 0.0
	var show_legend := true
	var legend_spacing := 16.0
	var label_mode := 2  # 0 无 1 仅百分比 2 标签+百分比

	if s:
		empty_color = s.empty_message_color
		label_color = s.value_color
		label_fs = s.label_font_size
		stroke_col = s.pie_stroke_color
		stroke_w = s.pie_stroke_width
		inner_ratio = s.pie_inner_radius_ratio
		show_legend = s.pie_show_legend
		legend_spacing = s.pie_legend_spacing
		label_mode = s.pie_label_mode

	if _data.is_empty():
		_draw_centered_text("暂无数据", plot_rect, empty_color, s)
		return

	var total_ratio := 0.0
	for r in _totals:
		total_ratio += r
	if is_zero_approx(total_ratio):
		_draw_centered_text("无有效数据", plot_rect, empty_color, s)
		return

	# 饼图绘制区域：留出图例空间
	var chart_size := plot_rect.size
	var legend_width := 0.0
	if show_legend:
		legend_width = minf(120.0, plot_rect.size.x * 0.35)
		chart_size.x = plot_rect.size.x - legend_width - legend_spacing

	var cx := plot_rect.position.x + chart_size.x * 0.5
	var cy := plot_rect.position.y + chart_size.y * 0.5
	var radius := minf(chart_size.x, chart_size.y) * 0.5 * 0.95

	if radius <= 0.0:
		return

	var inner_r := radius * clampf(inner_ratio, 0.0, 0.99)

	# 从 -90° 开始（12 点方向为起点）
	var start_angle := -PI / 2.0

	var segment_reveal: Array[float] = _segment_reveal_t
	if segment_reveal.size() != _data.size():
		segment_reveal = []
		for _k in range(_data.size()):
			segment_reveal.append(1.0)

	for i in range(_data.size()):
		var span := _totals[i] * segment_reveal[i] * TAU
		if span <= 0.0001:
			continue

		var seg_start := start_angle + _start_angles[i] * TAU
		var seg_end := seg_start + span

		var color: Color = _default_pie_color(i)
		if s and s.pie_colors.size() > 0:
			color = s.pie_colors[i % s.pie_colors.size()]

		# 扇区不描边（不画两弧之间的连线），仅填充
		if inner_r > 0.0:
			_draw_ring_segment(cx, cy, inner_r, radius, seg_start, seg_end, color, stroke_col, 0.0)
		else:
			_draw_pie_segment(cx, cy, radius, seg_start, seg_end, color, stroke_col, 0.0)

		# 仅显示百分比：沿「圆心 → 该扇区弧线中点」的射线向外延伸一定距离放置，避免字挤在一起
		if label_mode > 0 and segment_reveal[i] >= 0.99 and _totals[i] >= 0.04:
			var mid_angle := seg_start + span * 0.5
			# 沿射线向外延伸：距离 = 半径 × (1 + 延伸比例)，例如 1.12 表示在圆外 12% 半径处
			var label_r := radius * _get_pie_label_distance_ratio()
			var lx := cx + cos(mid_angle) * label_r
			var ly := cy + sin(mid_angle) * label_r
			_draw_text_at("%.0f%%" % (_totals[i] * 100.0), Vector2(lx, ly), label_color, label_fs, HORIZONTAL_ALIGNMENT_CENTER)

	# 图例：加大行高避免重叠
	var legend_line_height := 22.0
	if show_legend and _data.size() > 0:
		var leg_x := plot_rect.position.x + chart_size.x + legend_spacing
		var leg_y := plot_rect.position.y
		for i in range(_data.size()):
			var c: Color = _default_pie_color(i)
			if s and s.pie_colors.size() > 0:
				c = s.pie_colors[i % s.pie_colors.size()]
			draw_rect(Rect2(leg_x, leg_y + i * legend_line_height, 12, 12), c)
			var lbl := str(_data[i].get("label", ""))
			if lbl.is_empty():
				lbl = "%.0f%%" % (_totals[i] * 100.0)
			else:
				lbl = lbl + " %.0f%%" % (_totals[i] * 100.0)
			_draw_text_at(lbl, Vector2(leg_x + 18, leg_y + i * legend_line_height + 10.0), label_color, label_fs, HORIZONTAL_ALIGNMENT_LEFT)


func _default_pie_color(index: int) -> Color:
	var cols: Array[Color] = [
		Color(0.35, 0.65, 0.95, 0.9),
		Color(0.95, 0.55, 0.35, 0.9),
		Color(0.35, 0.85, 0.55, 0.9),
		Color(0.85, 0.55, 0.95, 0.9),
		Color(0.95, 0.85, 0.35, 0.9),
	]
	return cols[index % cols.size()]


func _draw_pie_segment(cx: float, cy: float, radius: float, start_angle: float, end_angle: float, fill_color: Color, stroke_color: Color, stroke_width: float) -> void:
	var steps := maxi(4, int((end_angle - start_angle) / 0.05))
	var points: PackedVector2Array = [Vector2(cx, cy)]
	for i in range(steps + 1):
		var t := float(i) / float(steps)
		var a := lerpf(start_angle, end_angle, t)
		points.append(Vector2(cx + cos(a) * radius, cy + sin(a) * radius))
	draw_colored_polygon(points, fill_color)
	if stroke_width > 0.0:
		for i in range(1, points.size()):
			draw_line(points[i], points[i - 1], stroke_color, stroke_width)
		draw_line(points[1], points[points.size() - 1], stroke_color, stroke_width)


func _draw_ring_segment(cx: float, cy: float, inner_r: float, outer_r: float, start_angle: float, end_angle: float, fill_color: Color, stroke_color: Color, stroke_width: float) -> void:
	var steps := maxi(4, int((end_angle - start_angle) / 0.05))
	var points: PackedVector2Array = []
	for i in range(steps + 1):
		var t := float(i) / float(steps)
		var a := lerpf(start_angle, end_angle, t)
		points.append(Vector2(cx + cos(a) * outer_r, cy + sin(a) * outer_r))
	for i in range(steps, -1, -1):
		var t := float(i) / float(steps)
		var a := lerpf(start_angle, end_angle, t)
		points.append(Vector2(cx + cos(a) * inner_r, cy + sin(a) * inner_r))
	draw_colored_polygon(points, fill_color)
	if stroke_width > 0.0:
		for i in range(points.size()):
			draw_line(points[i], points[(i + 1) % points.size()], stroke_color, stroke_width)


func _draw_text_at(text: String, pos: Vector2, color: Color, font_size: int, alignment: HorizontalAlignment) -> void:
	var font := ThemeDB.fallback_font
	if font == null or text.is_empty():
		return
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
