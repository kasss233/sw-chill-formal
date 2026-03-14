extends Control

enum DateMode {
	DAY,
	MONTH,
}

@export_group("布局参数（单位：px）")
@export_range(0.0, 200.0, 1.0, "suffix:px") var top_bar_height: float = 48.0
@export_range(0.0, 200.0, 1.0, "suffix:px") var padding_left: float = 56.0
@export_range(0.0, 200.0, 1.0, "suffix:px") var padding_right: float = 18.0
@export_range(0.0, 200.0, 1.0, "suffix:px") var padding_top: float = 16.0
@export_range(0.0, 200.0, 1.0, "suffix:px") var padding_bottom: float = 56.0

@export_group("柱体参数")
@export_range(1, 12, 1) var grid_steps: int = 4
@export_range(4.0, 200.0, 1.0, "suffix:px") var bar_max_width: float = 48.0
@export_range(0.1, 1.0, 0.01) var bar_width_ratio: float = 0.72
@export_range(2, 24, 1) var capsule_corner_detail: int = 6
@export var bar_color: Color = Color(0.12, 0.45, 0.86, 1.0)
@export var axis_color: Color = Color(0.83, 0.86, 0.9, 1.0)
@export var grid_color: Color = Color(0.85, 0.88, 0.93, 0.55)

@export_group("动画参数")
@export_range(0.05, 2.0, 0.01, "suffix:s") var bar_anim_duration: float = 0.35
@export_range(0.0, 200.0, 1.0, "suffix:px") var bar_anim_slide_distance: float = 22.0

@export_group("文本参数")
@export var chart_title: String = "数据统计"

@export var chart_data: Array[Dictionary] = [
	{"date": "2026-03-01", "value": 6.0},
	{"date": "2026-03-02", "value": 9.0},
	{"date": "2026-03-03", "value": 4.0},
	{"date": "2026-03-04", "value": 11.0},
	{"date": "2026-03-05", "value": 8.0},
	{"date": "2026-03-06", "value": 12.0},
	{"date": "2026-03-07", "value": 5.0},
	{"date": "2026-03-18", "value": 10.0},
	{"date": "2026-04-01", "value": 7.0},
	{"date": "2026-04-02", "value": 13.0},
	{"date": "2026-04-10", "value": 6.0},
	{"date": "2026-05-01", "value": 15.0},
]

var _date_mode: DateMode = DateMode.DAY
# 相对“系统当前周”的偏移，0=当前周，-1=上一周，+1=下一周
var _week_offset: int = 0
var _source_data: Array[Dictionary] = []
var _bars: Array[Dictionary] = []
var _display_values: Array[float] = []
var _anim_from_values: Array[float] = []
var _anim_to_values: Array[float] = []
var _anim_t: float = 1.0
var _animating: bool = false
var _pending_transition_direction: int = 0
var _current_transition_direction: int = 0
var _is_first_build: bool = true
var _anim_tween: Tween
@onready var _mode_selector: MaterialDropdown = $ChartBackgroundPanel/TopBarContainer/LeftControls/ModeSelector
@onready var _prev_week_button: MaterialButton = $ChartBackgroundPanel/TopBarContainer/LeftControls/PrevWeekButton
@onready var _next_week_button: MaterialButton = $ChartBackgroundPanel/TopBarContainer/LeftControls/NextWeekButton
@onready var _chart_title_label: Label = $ChartBackgroundPanel/TopBarContainer/ChartTitleLabel
@onready var _total_value_label: Label = $ChartBackgroundPanel/TopBarContainer/StatsPanel/StatsContainer/TotalValueLabel
@onready var _average_value_label: Label = $ChartBackgroundPanel/TopBarContainer/StatsPanel/StatsContainer/AverageValueLabel


func _ready() -> void:
	_source_data = chart_data.duplicate(true)
	_update_chart_title_display()
	_setup_top_controls()
	_rebuild_bars()
	resized.connect(_on_resized)


# ===== API 函数：供外部模块调用 =====
# 设置完整数据集（元素格式：{"date": "YYYY-MM-DD", "value": 数值}）
func set_chart_data(data: Array[Dictionary]) -> void:
	_source_data = data.duplicate(true)
	_pending_transition_direction = 0
	_rebuild_bars()


# 追加单条数据点
func add_data_point(date_text: String, value: float) -> void:
	_source_data.append({"date": date_text, "value": value})
	_pending_transition_direction = 0
	_rebuild_bars()


# 清空所有数据
func clear_chart_data() -> void:
	_source_data.clear()
	_pending_transition_direction = 0
	_rebuild_bars()


# 设置图表标题
func set_chart_title(title: String) -> void:
	chart_title = title
	_update_chart_title_display()


# 获取图表标题
func get_chart_title() -> String:
	return chart_title


# 切换显示模式（DAY/MONTH）
func set_display_mode(mode: DateMode) -> void:
	_date_mode = mode
	if _mode_selector != null:
		_mode_selector.set_selected_by_value(_mode_to_value(mode))
	_pending_transition_direction = 0
	_update_week_navigation_state()
	_rebuild_bars()


# 重置为系统日期所在周
func reset_to_current_week() -> void:
	_pending_transition_direction = - signi(_week_offset)
	_week_offset = 0
	_rebuild_bars()


func _setup_top_controls() -> void:
	# 控件由场景树预置，这里只做初始化与信号绑定。
	_mode_selector.clear_options()
	_mode_selector.placeholder = "选择模式"
	_mode_selector.add_option("按日", _mode_to_value(DateMode.DAY))
	_mode_selector.add_option("按月", _mode_to_value(DateMode.MONTH))
	_mode_selector.set_selected_by_value(_mode_to_value(DateMode.DAY))
	_mode_selector.selection_changed.connect(_on_mode_selected)

	_prev_week_button.background_color = Color(1, 1, 1, 0.08)
	_prev_week_button.corner_radius = 8
	_next_week_button.background_color = Color(1, 1, 1, 0.08)
	_next_week_button.corner_radius = 8
	_prev_week_button.pressed.connect(_on_prev_week_pressed)
	_next_week_button.pressed.connect(_on_next_week_pressed)

	_update_week_navigation_state()


func _update_chart_title_display() -> void:
	if _chart_title_label == null:
		return
	_chart_title_label.text = chart_title


func _on_mode_selected(_index: int, value: Variant) -> void:
	_date_mode = _value_to_mode(str(value))
	_pending_transition_direction = 0
	_update_week_navigation_state()
	_rebuild_bars()


func _mode_to_value(mode: DateMode) -> String:
	if mode == DateMode.MONTH:
		return "MONTH"
	return "DAY"


func _value_to_mode(value: String) -> DateMode:
	if value == "MONTH":
		return DateMode.MONTH
	return DateMode.DAY


func _on_prev_week_pressed() -> void:
	_pending_transition_direction = -1
	_week_offset -= 1
	_rebuild_bars()


func _on_next_week_pressed() -> void:
	_pending_transition_direction = 1
	_week_offset += 1
	_rebuild_bars()


func _update_week_navigation_state() -> void:
	if _prev_week_button == null or _next_week_button == null:
		return
	var enabled := _date_mode == DateMode.DAY
	_prev_week_button.disabled = not enabled
	_next_week_button.disabled = not enabled


func _on_resized() -> void:
	queue_redraw()


func _rebuild_bars() -> void:
	var old_display_values := _display_values.duplicate()
	_bars = _aggregate_by_mode(_source_data, _date_mode)
	_start_bar_animation(old_display_values)
	_update_summary_stats()
	queue_redraw()


func _start_bar_animation(old_display_values: Array[float]) -> void:
	var count := _bars.size()
	_anim_to_values.clear()
	for point in _bars:
		_anim_to_values.append(float(point.get("value", 0.0)))

	_anim_from_values.resize(count)
	for i: int in range(count):
		if _is_first_build:
			_anim_from_values[i] = 0.0
		elif i < old_display_values.size():
			_anim_from_values[i] = float(old_display_values[i])
		else:
			_anim_from_values[i] = 0.0

	_current_transition_direction = _pending_transition_direction
	_pending_transition_direction = 0

	if _anim_tween and _anim_tween.is_valid():
		_anim_tween.kill()

	_anim_t = 0.0
	_animating = true
	_set_anim_t(0.0)
	_anim_tween = create_tween()
	_anim_tween.set_trans(Tween.TRANS_CUBIC)
	_anim_tween.set_ease(Tween.EASE_OUT)
	_anim_tween.tween_method(_set_anim_t, 0.0, 1.0, bar_anim_duration)
	_anim_tween.finished.connect(_on_bar_anim_finished)


func _set_anim_t(value: float) -> void:
	_anim_t = value
	_display_values.resize(_anim_to_values.size())
	for i: int in range(_anim_to_values.size()):
		_display_values[i] = lerpf(float(_anim_from_values[i]), float(_anim_to_values[i]), _anim_t)
	queue_redraw()


func _on_bar_anim_finished() -> void:
	_animating = false
	_is_first_build = false
	_display_values = _anim_to_values.duplicate()
	queue_redraw()


func _update_summary_stats() -> void:
	if _total_value_label == null or _average_value_label == null:
		return
	var total: float = 0.0
	for item in _bars:
		total += float(item.get("value", 0.0))
	var avg: float = 0.0
	if not _bars.is_empty():
		avg = total / float(_bars.size())
	_total_value_label.text = "累计值: %s" % _format_value_text(total)
	_average_value_label.text = "平均值: %s" % _format_value_text(avg)


func _draw() -> void:
	# 绘图区域需避开顶部控制栏和四周内边距。
	var plot_rect := Rect2(
		padding_left,
		top_bar_height + padding_top,
		size.x - padding_left - padding_right,
		size.y - top_bar_height - padding_top - padding_bottom
	)

	if plot_rect.size.x <= 0.0 or plot_rect.size.y <= 0.0:
		return

	_draw_y_axis(plot_rect, axis_color, grid_color)
	draw_line(plot_rect.position, Vector2(plot_rect.position.x, plot_rect.end.y), axis_color, 2.0)
	draw_line(Vector2(plot_rect.position.x, plot_rect.end.y), plot_rect.end, axis_color, 2.0)

	if _bars.is_empty():
		_draw_empty_hint(plot_rect)
		return

	var max_value := _find_max_value_from_float_array(_anim_from_values)
	max_value = maxf(max_value, _find_max_value_from_float_array(_anim_to_values))
	if is_zero_approx(max_value):
		max_value = 1.0

	var count := _bars.size()
	var slot_width := plot_rect.size.x / float(count)
	var bar_width: float = min(bar_max_width, slot_width * bar_width_ratio)

	for i: int in range(count):
		var point: Dictionary = _bars[i]
		var value: float = float(point.get("value", 0.0))
		if i < _display_values.size():
			value = _display_values[i]
		var ratio: float = clampf(value / max_value, 0.0, 1.0)
		var bar_height: float = ratio * plot_rect.size.y
		var x: float = plot_rect.position.x + float(i) * slot_width + (slot_width - bar_width) * 0.5
		var transition_offset_y := 0.0
		if _animating and _current_transition_direction != 0:
			transition_offset_y = - float(_current_transition_direction) * bar_anim_slide_distance * (1.0 - _anim_t)
		var y: float = plot_rect.end.y - bar_height + transition_offset_y
		var bar_rect := Rect2(x, y, bar_width, bar_height)
		# 柱形使用胶囊样式，保证高宽变化时圆角仍自然。
		_draw_capsule_bar(bar_rect, bar_color)
		_draw_text(_format_value_text(value), Vector2(x + bar_width * 0.5, y - 6.0), HORIZONTAL_ALIGNMENT_CENTER)

		_draw_x_label(str(point.get("label", "")), x + bar_width * 0.5, plot_rect.end.y + 20.0)


func _draw_y_axis(plot_rect: Rect2, axis_color: Color, grid_color: Color) -> void:
	var max_value := _find_max_value(_bars)
	if is_zero_approx(max_value):
		max_value = 1.0
	var step_count := maxi(grid_steps, 1)

	for i: int in range(step_count + 1):
		var t := float(i) / float(step_count)
		var y := lerpf(plot_rect.end.y, plot_rect.position.y, t)
		draw_line(Vector2(plot_rect.position.x, y), Vector2(plot_rect.end.x, y), grid_color, 1.0)
		if i == 0:
			continue
		var value := max_value * t
		_draw_text(str(int(round(value))), Vector2(plot_rect.position.x - 8.0, y + 5.0), HORIZONTAL_ALIGNMENT_RIGHT)


func _draw_empty_hint(plot_rect: Rect2) -> void:
	_draw_text("暂无数据", Vector2(plot_rect.position.x + plot_rect.size.x * 0.5, plot_rect.position.y + plot_rect.size.y * 0.5), HORIZONTAL_ALIGNMENT_CENTER)


func _draw_x_label(text: String, center_x: float, baseline_y: float) -> void:
	_draw_text(text, Vector2(center_x, baseline_y), HORIZONTAL_ALIGNMENT_CENTER)


func _draw_text(text: String, pos: Vector2, alignment: HorizontalAlignment) -> void:
	var font := ThemeDB.fallback_font
	if font == null:
		return
	var font_size := ThemeDB.fallback_font_size
	var color := Color(0, 0, 0, 1)
	draw_string(font, pos, text, alignment, -1.0, font_size, color)


func _draw_capsule_bar(rect: Rect2, color: Color) -> void:
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return
	# 半径取短边一半，实现标准胶囊端点。
	var radius: int = int(floor(min(rect.size.x, rect.size.y) * 0.5))
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	style.set_corner_detail(maxi(capsule_corner_detail, 2))
	draw_style_box(style, rect)


func _aggregate_by_mode(data: Array[Dictionary], mode: DateMode) -> Array[Dictionary]:
	var grouped := {}
	# 默认以系统日期作为显示窗口基准，按日模式可被周偏移修正。
	var reference_date := _get_today_date()
	if mode == DateMode.DAY and _week_offset != 0:
		reference_date = _shift_date_by_days(reference_date, _week_offset * 7)

	for item in data:
		if not item.has("date") or not item.has("value"):
			continue
		var parsed := _parse_date(str(item["date"]))
		if parsed.is_empty():
			continue
		var key := _build_key(parsed, mode)
		var value := float(item["value"])
		# 同一天/同一月数据聚合到同一柱。
		grouped[key] = grouped.get(key, 0.0) + value

	if mode == DateMode.DAY:
		return _build_week_bars(grouped, reference_date)
	return _build_year_bars(grouped, reference_date)


func _build_week_bars(grouped: Dictionary, reference_date: Dictionary) -> Array[Dictionary]:
	# 固定输出周一到周日 7 根柱，没有数据的日期补 0。
	var start_unix: int = _week_start_unix(reference_date)
	var result: Array[Dictionary] = []
	for i: int in range(7):
		var day_unix: int = start_unix + i * 86400
		var day_dict := Time.get_datetime_dict_from_unix_time(day_unix)
		var key := _build_key(day_dict, DateMode.DAY)
		var weekday_text := _weekday_text(int(day_dict.get("weekday", 1)))
		var label := "%s %02d-%02d" % [weekday_text, int(day_dict.get("month", 1)), int(day_dict.get("day", 1))]
		result.append({
			"key": key,
			"label": label,
			"value": float(grouped.get(key, 0.0)),
		})
	return result


func _build_year_bars(grouped: Dictionary, reference_date: Dictionary) -> Array[Dictionary]:
	# 固定输出 1-12 月 12 根柱，没有数据的月份补 0。
	var target_year := int(reference_date.get("year", 1970))
	var result: Array[Dictionary] = []
	for month: int in range(1, 13):
		var key := "%04d-%02d" % [target_year, month]
		result.append({
			"key": key,
			"label": "%d月" % month,
			"value": float(grouped.get(key, 0.0)),
		})
	return result


func _format_value_text(value: float) -> String:
	if absf(value - roundf(value)) < 0.001:
		return str(int(round(value)))
	return "%0.1f" % value


func _week_start_unix(date_dict: Dictionary) -> int:
	# 先归零到当天 00:00，再回退到周一。
	var datetime := {
		"year": int(date_dict.get("year", 1970)),
		"month": int(date_dict.get("month", 1)),
		"day": int(date_dict.get("day", 1)),
		"hour": 0,
		"minute": 0,
		"second": 0,
	}
	var unix_today: int = int(Time.get_unix_time_from_datetime_dict(datetime))
	var weekday: int = int(Time.get_datetime_dict_from_unix_time(unix_today).get("weekday", 1))
	# Godot weekday 常见取值为 0-6（0=周日），这里统一换算成“距周一的偏移”。
	var offset: int = (weekday + 6) % 7
	return unix_today - offset * 86400


func _shift_date_by_days(date_dict: Dictionary, day_offset: int) -> Dictionary:
	# 使用 Unix 时间做偏移，避免跨月/跨年手动进位问题。
	var datetime := {
		"year": int(date_dict.get("year", 1970)),
		"month": int(date_dict.get("month", 1)),
		"day": int(date_dict.get("day", 1)),
		"hour": 0,
		"minute": 0,
		"second": 0,
	}
	var base_unix: int = int(Time.get_unix_time_from_datetime_dict(datetime))
	var target_unix: int = base_unix + day_offset * 86400
	var target := Time.get_datetime_dict_from_unix_time(target_unix)
	return {
		"year": int(target.get("year", 1970)),
		"month": int(target.get("month", 1)),
		"day": int(target.get("day", 1)),
	}


func _weekday_text(weekday: int) -> String:
	match weekday:
		0:
			return "周日"
		1:
			return "周一"
		2:
			return "周二"
		3:
			return "周三"
		4:
			return "周四"
		5:
			return "周五"
		6:
			return "周六"
		7:
			return "周日"
		_:
			return "周?"


func _get_today_date() -> Dictionary:
	var now := Time.get_datetime_dict_from_system()
	return {
		"year": int(now.get("year", 1970)),
		"month": int(now.get("month", 1)),
		"day": int(now.get("day", 1)),
	}


func _sort_date_key(a: String, b: String) -> bool:
	return _key_to_sort_number(a) < _key_to_sort_number(b)


func _key_to_sort_number(key: String) -> int:
	var parts := key.split("-")
	if parts.size() < 2:
		return 0
	var year := int(parts[0])
	var month := int(parts[1])
	var day := 1
	if parts.size() >= 3:
		day = int(parts[2])
	return year * 10000 + month * 100 + day


func _format_label(key: String, mode: DateMode) -> String:
	var parts := key.split("-")
	if mode == DateMode.MONTH:
		if parts.size() >= 2:
			return "%s-%s" % [parts[0], parts[1]]
		return key
	if parts.size() >= 3:
		return "%s-%s" % [parts[1], parts[2]]
	return key


func _build_key(parsed: Dictionary, mode: DateMode) -> String:
	var year := int(parsed.get("year", 0))
	var month := int(parsed.get("month", 1))
	var day := int(parsed.get("day", 1))
	if mode == DateMode.MONTH:
		return "%04d-%02d" % [year, month]
	return "%04d-%02d-%02d" % [year, month, day]


func _parse_date(date_text: String) -> Dictionary:
	var cleaned := date_text.strip_edges().replace("/", "-")
	var parts := cleaned.split("-")
	if parts.size() < 2:
		return {}

	var year := int(parts[0])
	var month := int(parts[1])
	var day := 1
	if parts.size() >= 3:
		day = int(parts[2])

	if year <= 0 or month <= 0 or month > 12 or day <= 0 or day > 31:
		return {}

	return {
		"year": year,
		"month": month,
		"day": day,
	}


func _find_max_value(data: Array[Dictionary]) -> float:
	var max_value := 0.0
	for item in data:
		var value := float(item.get("value", 0.0))
		if value > max_value:
			max_value = value
	return max_value


func _find_max_value_from_float_array(values: Array[float]) -> float:
	var max_value := 0.0
	for value in values:
		if value > max_value:
			max_value = value
	return max_value
