@tool
extends Control

## 折线图组件
## 单系列数据格式: Array[Dictionary] 每项 {"label": str, "value": float}
## 多系列: Array[Dictionary] 每项 {"label": str, "series": [v1, v2, ...]} 或 data 为 Array[Array] 多个系列
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
# 单系列: [{"label":"1月","value":10}, ...]
# 多系列: [{"label":"1月","values":[10,20]}, ...] 或 series_array = [[10,20,30],[5,15,25]]
var _data: Array[Dictionary] = []
var _series_count: int = 1  # 几条线
var _display_t: float = 1.0  # 动画 0~1
var _animate_reveal: bool = false  # true 时按 _display_t 逐点显示
var _anim_tween: Tween
var _is_first_build: bool = true


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


## 设置单系列数据。animate 为 false 时仅更新数据不播动画，可之后调用 play_show_animation() 再播
func set_chart_data(data: Array, animate: bool = false) -> void:
	_data.clear()
	_series_count = 1
	for item in data:
		if item is Dictionary:
			_data.append({"label": str(item.get("label", "")), "values": [float(item.get("value", 0.0))]})
		else:
			_data.append({"label": "", "values": [float(item)]})
	_animate_reveal = false
	if animate:
		_start_animation()
	else:
		_display_t = 1.0
		_is_first_build = false
		queue_redraw()


## 设置多系列数据；each_item 格式 {"label": str, "values": Array[float]} 或 "series": Array。animate 为 false 时不自动播动画
func set_multi_series_data(data: Array, series_count: int = 0, animate: bool = false) -> void:
	_data.clear()
	var count := series_count
	for item in data:
		if item is Dictionary:
			var vals: Array = item.get("values", item.get("series", []))
			var vf: Array = []
			for v in vals:
				vf.append(float(v))
			if count == 0 and vf.size() > 0:
				count = vf.size()
			_data.append({"label": str(item.get("label", "")), "values": vf})
		else:
			_data.append({"label": "", "values": []})
	if count > 0:
		_series_count = count
	else:
		_series_count = 1
	_animate_reveal = false
	if animate:
		_start_animation()
	else:
		_display_t = 1.0
		_is_first_build = false
		queue_redraw()


func update_display(data: Variant) -> void:
	if data == null:
		_data.clear()
		queue_redraw()
		return
	if data is Array:
		if data.size() > 0 and data[0] is Array:
			# 多系列 [[a,b],[c,d],...]
			var rows: Array[Dictionary] = []
			var max_cols := 0
			for row in data:
				var vf: Array = []
				for x in row:
					vf.append(float(x))
				if vf.size() > max_cols:
					max_cols = vf.size()
				rows.append({"label": "", "values": vf})
			for i in rows.size():
				while rows[i]["values"].size() < max_cols:
					rows[i]["values"].append(0.0)
			set_multi_series_data(rows, max_cols)
		else:
			set_chart_data(data)
	elif data is Dictionary and data.has("items"):
		set_chart_data(data["items"])
	else:
		set_chart_data([data])


func clear_data() -> void:
	_data.clear()
	_series_count = 1
	_display_t = 0.0
	_is_first_build = true
	queue_redraw()


func _get_style() -> ChartStyle:
	return _chart_style if _chart_style else null


func _get_animation_duration() -> float:
	var s := _get_style()
	if s and s.line_animation_duration > 0.0:
		return s.line_animation_duration
	return 1.2


func _start_animation() -> void:
	if _anim_tween and _anim_tween.is_valid():
		_anim_tween.kill()
	var from_t := 0.0 if _is_first_build else 1.0
	_display_t = from_t
	_anim_tween = create_tween()
	_anim_tween.set_trans(Tween.TRANS_CUBIC)
	_anim_tween.set_ease(Tween.EASE_OUT)
	var dur := _get_animation_duration()
	_anim_tween.tween_method(_set_display_t, from_t, 1.0, dur)
	_anim_tween.finished.connect(func():
		_is_first_build = false
		_animate_reveal = false
		queue_redraw()
	)


## 播放“逐点连接”的展示动画（需先 set_chart_data(data, false) 设好数据，再调用）。duration <= 0 时使用 ChartStyle 中的 line_animation_duration
func play_show_animation(duration: float = -1.0) -> void:
	if _data.size() < 2:
		queue_redraw()
		return
	var dur := duration if duration > 0.0 else _get_animation_duration()
	_animate_reveal = true
	_display_t = 0.0
	if _anim_tween and _anim_tween.is_valid():
		_anim_tween.kill()
	_anim_tween = create_tween()
	_anim_tween.set_trans(Tween.TRANS_CUBIC)
	_anim_tween.set_ease(Tween.EASE_OUT)
	_anim_tween.tween_method(_set_display_t, 0.0, 1.0, dur)
	_anim_tween.finished.connect(func():
		_animate_reveal = false
		_display_t = 1.0
		queue_redraw()
	)


func _set_display_t(t: float) -> void:
	_display_t = t
	queue_redraw()


func _get_draw_size() -> Vector2:
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
	var grid_color := Color(1, 1, 1, 0.08)
	var empty_color := Color(0.6, 0.6, 0.6, 1.0)
	var label_fs := 11
	var line_w := 2.0
	var point_r := 4.0
	var line_col := Color(0.35, 0.65, 0.95, 1.0)
	var point_col := Color(0.35, 0.65, 0.95, 1.0)
	var fill_col := Color(0.35, 0.65, 0.95, 0.15)
	var smooth := false

	if s:
		label_color = s.label_color
		grid_color = s.grid_color
		empty_color = s.empty_message_color
		label_fs = s.label_font_size
		line_w = s.line_width
		point_r = s.line_point_radius
		point_col = s.line_point_color
		fill_col = s.line_fill_color
		smooth = s.line_smooth

	_draw_grid(plot_rect, grid_color)

	if _data.is_empty():
		_draw_centered_text("暂无数据", plot_rect, empty_color, s)
		return

	var max_val := 0.0
	for item in _data:
		var vals: Array = item.get("values", [])
		for v in vals:
			if float(v) > max_val:
				max_val = float(v)
	if is_zero_approx(max_val):
		max_val = 1.0

	var n := _data.size()
	if n < 2:
		_draw_centered_text("至少需要两个数据点", plot_rect, empty_color, s)
		return

	var label_interval := 1
	if n > 12:
		label_interval = ceili(float(n) / 12.0)

	# 按系列绘制（每条线）
	for series_idx in range(_series_count):
		var points: PackedVector2Array = []
		for i in range(n):
			var item: Dictionary = _data[i]
			var vals: Array = item.get("values", [])
			var v := 0.0
			if series_idx < vals.size():
				v = float(vals[series_idx])
			var ratio := clampf(v / max_val, 0.0, 1.0)
			var x := plot_rect.position.x + (float(i) / float(n - 1)) * plot_rect.size.x
			var y := plot_rect.end.y - ratio * plot_rect.size.y
			points.append(Vector2(x, y))

		var lcolor: Color = line_col
		if s:
			if series_idx < s.line_series_colors.size():
				lcolor = s.line_series_colors[series_idx]
			else:
				lcolor = s.line_color
		point_col = lcolor

		if _animate_reveal and n >= 2:
			# 沿路径延伸：按折线总长度比例 t 计算“线头”位置，线和面积随线头一起向前
			var cumulative: PackedFloat32Array = []
			cumulative.append(0.0)
			for i in range(n - 1):
				cumulative.append(cumulative[i] + points[i].distance_to(points[i + 1]))
			var total_len := cumulative[n - 1]
			if total_len <= 0.0:
				total_len = 1.0
			var travel := _display_t * total_len
			var path: PackedVector2Array = []
			var head: Vector2
			var seg_idx := 0
			if travel <= 0.0001:
				path.append(points[0])
				head = points[0]
			else:
				var local_t := 0.0
				for i in range(n - 1):
					if travel <= cumulative[i + 1]:
						seg_idx = i
						var seg_len := cumulative[i + 1] - cumulative[i]
						local_t = (travel - cumulative[i]) / seg_len if seg_len > 0.0 else 1.0
						local_t = clampf(local_t, 0.0, 1.0)
						break
					seg_idx = n - 2
					local_t = 1.0
				head = points[seg_idx].lerp(points[seg_idx + 1], local_t)
				for i in range(seg_idx + 1):
					path.append(points[i])
				path.append(head)
			if path.size() >= 2:
				if fill_col.a > 0.0:
					var fill_pts := path.duplicate()
					fill_pts.append(Vector2(head.x, plot_rect.end.y))
					fill_pts.append(Vector2(points[0].x, plot_rect.end.y))
					draw_colored_polygon(fill_pts, fill_col)
				for j in range(path.size() - 1):
					draw_line(path[j], path[j + 1], lcolor, line_w)
				for idx in range(seg_idx):
					var pt := points[idx]
					if point_r > 0.0:
						draw_circle(pt, point_r, point_col)
						draw_arc(pt, point_r, 0, TAU, 16, lcolor, 1.0)
				if point_r > 0.0:
					draw_circle(head, point_r * 0.7, point_col)
					draw_arc(head, point_r * 0.7, 0, TAU, 16, lcolor, 1.0)
		else:
			# 非动画或已播完：完整绘制
			if fill_col.a > 0.0 and points.size() >= 2:
				var fill_pts := points.duplicate()
				fill_pts.append(Vector2(points[-1].x, plot_rect.end.y))
				fill_pts.append(Vector2(points[0].x, plot_rect.end.y))
				draw_colored_polygon(fill_pts, fill_col)
			if points.size() >= 2:
				if smooth and points.size() >= 3:
					_draw_smooth_line(points, lcolor, line_w)
				else:
					for j in range(points.size() - 1):
						draw_line(points[j], points[j + 1], lcolor, line_w)
			for pt in points:
				if point_r > 0.0:
					draw_circle(pt, point_r, point_col)
					draw_arc(pt, point_r, 0, TAU, 16, lcolor, 1.0)

	# X 轴标签：只画一次，与数据点水平居中对齐
	for i in range(n):
		if i % label_interval != 0:
			continue
		var item: Dictionary = _data[i]
		var slot_center_x := plot_rect.position.x + (float(i) / float(n - 1)) * plot_rect.size.x
		var label_text := str(item.get("label", ""))
		_draw_text_at(label_text, Vector2(slot_center_x, plot_rect.end.y + 18.0), label_color, label_fs, HORIZONTAL_ALIGNMENT_CENTER)


func _draw_grid(plot_rect: Rect2, grid_color: Color) -> void:
	var steps := 4
	for i in range(steps + 1):
		var t := float(i) / float(steps)
		var y := lerpf(plot_rect.end.y, plot_rect.position.y, t)
		draw_line(Vector2(plot_rect.position.x, y), Vector2(plot_rect.end.x, y), grid_color, 1.0)


func _draw_smooth_line(points: PackedVector2Array, color: Color, width: float) -> void:
	# Catmull-Rom 样条，每段取 8 个插值点
	if points.size() < 2:
		return
	var n := points.size()
	var out: PackedVector2Array = []
	for i in range(n - 1):
		var p0: Vector2 = points[maxi(0, i - 1)]
		var p1: Vector2 = points[i]
		var p2: Vector2 = points[i + 1]
		var p3: Vector2 = points[mini(n - 1, i + 2)]
		var steps := 8
		for k in range(steps + 1):
			var t := float(k) / float(steps)
			var v := _catmull_rom(p0, p1, p2, p3, t)
			out.append(v)
	for j in range(out.size() - 1):
		draw_line(out[j], out[j + 1], color, width)


func _catmull_rom(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, t: float) -> Vector2:
	var t2 := t * t
	var t3 := t2 * t
	return 0.5 * (
		(2.0 * p1) +
		(-p0 + p2) * t +
		(2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 +
		(-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3
	)


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
