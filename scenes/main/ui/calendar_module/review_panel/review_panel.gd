extends VBoxContainer

signal date_context_changed(date_key: String)
signal generate_reflection_requested(period_type: String, period_key: String)

const CalendarScene = preload("res://scenes/main/ui/components/calendar/calendar.tscn")
const FocusBarChartScript = preload("res://scenes/main/ui/calendar_module/summary_panel/focus_bar_chart.gd")

var _selected_date_key: String = ""
var _period_type: String = "week"

var _title_label: Label
var _completion_value: Label
var _focus_value: Label
var _habit_value: Label
var _period_value: Label
var _heatmap_container: GridContainer
var _habit_chart: Control
var _focus_chart: Control
var _trend_chart: Control
var _insight_container: VBoxContainer
var _reflection_label: Label
var _calendar: Node
var _period_switch: MaterialSegmentedButton


func _ready() -> void:
	add_theme_constant_override("separation", 6)
	mouse_filter = Control.MOUSE_FILTER_PASS
	_selected_date_key = DateUtil.get_today_key()
	_build_ui()
	_connect_signals()
	_refresh()


func set_selected_date_key(date_key: String) -> void:
	if date_key.is_empty():
		return
	_selected_date_key = date_key
	_refresh()


func set_period_type(period_type: String) -> void:
	_period_type = period_type
	match period_type:
		"month":
			_period_switch.set_selected_no_signal(1)
		"recent30":
			_period_switch.set_selected_no_signal(2)
		_:
			_period_switch.set_selected_no_signal(0)
	_refresh()


func get_selected_date_key() -> String:
	return _selected_date_key


func _build_ui() -> void:
	var header := _create_panel()
	add_child(header)

	var header_box := VBoxContainer.new()
	header_box.add_theme_constant_override("separation", 6)
	header.add_child(header_box)

	_title_label = Label.new()
	_title_label.add_theme_color_override("font_color", Color(1, 1, 1))
	_title_label.add_theme_font_size_override("font_size", 18)
	header_box.add_child(_title_label)

	_period_switch = MaterialSegmentedButton.new()
	_period_switch.mouse_filter = Control.MOUSE_FILTER_PASS
	_period_switch.add_segment("本周")
	_period_switch.add_segment("本月")
	_period_switch.add_segment("最近30天")
	_period_switch.set_selected_no_signal(0)
	header_box.add_child(_period_switch)

	var overview_row := GridContainer.new()
	overview_row.columns = 2
	overview_row.add_theme_constant_override("h_separation", 8)
	overview_row.add_theme_constant_override("v_separation", 6)
	add_child(overview_row)

	var card_a := _create_metric_card("完成率")
	_completion_value = card_a["value"]
	overview_row.add_child(card_a["panel"])

	var card_b := _create_metric_card("专注时长")
	_focus_value = card_b["value"]
	overview_row.add_child(card_b["panel"])

	var card_c := _create_metric_card("最稳定习惯")
	_habit_value = card_c["value"]
	overview_row.add_child(card_c["panel"])

	var card_d := _create_metric_card("更顺手时段")
	_period_value = card_d["value"]
	overview_row.add_child(card_d["panel"])

	var heatmap_panel := _create_panel()
	add_child(heatmap_panel)

	var heatmap_box := VBoxContainer.new()
	heatmap_box.add_theme_constant_override("separation", 6)
	heatmap_panel.add_child(heatmap_box)

	var heat_title := Label.new()
	heat_title.text = "完成热力"
	heat_title.add_theme_color_override("font_color", Color(1, 1, 1))
	heat_title.add_theme_font_size_override("font_size", 15)
	heatmap_box.add_child(heat_title)

	_heatmap_container = GridContainer.new()
	_heatmap_container.columns = 7
	_heatmap_container.add_theme_constant_override("h_separation", 6)
	_heatmap_container.add_theme_constant_override("v_separation", 6)
	heatmap_box.add_child(_heatmap_container)

	var chart_panel := _create_panel()
	add_child(chart_panel)

	var chart_box := VBoxContainer.new()
	chart_box.add_theme_constant_override("separation", 8)
	chart_panel.add_child(chart_box)

	chart_box.add_child(_create_chart_title("习惯完成排行"))
	_habit_chart = _create_chart()
	chart_box.add_child(_habit_chart)

	chart_box.add_child(_create_chart_title("专注时长"))
	_focus_chart = _create_chart()
	chart_box.add_child(_focus_chart)

	chart_box.add_child(_create_chart_title("节奏趋势"))
	_trend_chart = _create_chart()
	chart_box.add_child(_trend_chart)

	var insight_panel := _create_panel()
	add_child(insight_panel)

	var insight_box := VBoxContainer.new()
	insight_box.add_theme_constant_override("separation", 6)
	insight_panel.add_child(insight_box)

	var insight_title := Label.new()
	insight_title.text = "这段时间的反馈"
	insight_title.add_theme_color_override("font_color", Color(1, 1, 1))
	insight_title.add_theme_font_size_override("font_size", 15)
	insight_box.add_child(insight_title)

	_insight_container = VBoxContainer.new()
	_insight_container.add_theme_constant_override("separation", 6)
	insight_box.add_child(_insight_container)

	var reflection_panel := _create_panel()
	add_child(reflection_panel)

	var reflection_box := VBoxContainer.new()
	reflection_box.add_theme_constant_override("separation", 6)
	reflection_panel.add_child(reflection_box)

	var reflection_top := HBoxContainer.new()
	reflection_top.add_theme_constant_override("separation", 6)
	reflection_box.add_child(reflection_top)

	var reflection_title := Label.new()
	reflection_title.text = "回顾摘要"
	reflection_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	reflection_title.add_theme_color_override("font_color", Color(1, 1, 1))
	reflection_title.add_theme_font_size_override("font_size", 15)
	reflection_top.add_child(reflection_title)

	var generate_btn := MaterialButton.new()
	generate_btn.text = "生成本段回顾"
	generate_btn.mouse_filter = Control.MOUSE_FILTER_PASS
	generate_btn.set_filled_style(Color(0.35, 0.65, 0.95))
	generate_btn.pressed.connect(func():
		generate_reflection_requested.emit(_period_type, _get_period_key())
	)
	reflection_top.add_child(generate_btn)

	_reflection_label = Label.new()
	_reflection_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_reflection_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	_reflection_label.add_theme_font_size_override("font_size", 12)
	reflection_box.add_child(_reflection_label)

	var calendar_panel := _create_panel()
	add_child(calendar_panel)

	var calendar_box := VBoxContainer.new()
	calendar_box.add_theme_constant_override("separation", 6)
	calendar_panel.add_child(calendar_box)

	var calendar_title := Label.new()
	calendar_title.text = "月度轨迹"
	calendar_title.add_theme_color_override("font_color", Color(1, 1, 1))
	calendar_title.add_theme_font_size_override("font_size", 15)
	calendar_box.add_child(calendar_title)

	_calendar = CalendarScene.instantiate()
	_calendar.mouse_filter = Control.MOUSE_FILTER_PASS
	_calendar.set_swipe_navigation_enabled(false)
	_calendar.show_action_buttons(false)
	calendar_box.add_child(_calendar)


func _connect_signals() -> void:
	_period_switch.segment_selected.connect(_on_period_switched)
	_calendar.date_selected.connect(_on_calendar_date_selected)
	HabitState.execution_updated.connect(func(_record): _refresh())
	HabitState.schedule_updated.connect(func(_week_key): _refresh())
	HabitState.schedule_entry_added.connect(func(_entry): _refresh())
	HabitState.schedule_entry_removed.connect(func(_entry_id): _refresh())
	HabitState.habit_updated.connect(func(_habit): _refresh())
	HabitState.data_loaded.connect(_refresh)
	if StatsState:
		StatsState.record_added.connect(func(_record): _refresh())
		StatsState.record_removed.connect(func(_id): _refresh())
	if NoteState:
		NoteState.note_added.connect(func(_note): _refresh())
		NoteState.note_updated.connect(func(_note): _refresh())


func _refresh() -> void:
	var summary := HabitState.get_review_summary(_period_type, _get_period_key())
	_title_label.text = str(summary.get("title", "回顾"))

	var overview: Dictionary = summary.get("overview", {})
	_completion_value.text = "%d%%" % int(round(float(overview.get("completion_rate", 0.0)) * 100.0))
	_focus_value.text = "%d 分钟" % int(overview.get("focus_minutes", 0))
	_habit_value.text = str(overview.get("best_habit_name", "暂无"))
	_period_value.text = str(overview.get("best_period_text", "暂无"))

	_refresh_heatmap(summary.get("heatmap_days", []))
	_update_chart(_habit_chart, summary.get("habit_chart", []), 0.0)
	_update_chart(_focus_chart, summary.get("focus_chart", []), _average_of(summary.get("focus_chart", [])))
	_update_chart(_trend_chart, summary.get("trend_chart", []), _average_of(summary.get("trend_chart", [])))
	_refresh_insights(summary.get("insights", []))

	var reflection: Dictionary = summary.get("reflection", {})
	_reflection_label.text = str(reflection.get("content", ""))

	var dt := _date_key_to_dict(_selected_date_key)
	_calendar.set_date(int(dt.get("year", 0)), int(dt.get("month", 0)), int(dt.get("day", 0)))
	_calendar.set_date_marks(summary.get("calendar_marks", {}))


func _refresh_heatmap(items: Array) -> void:
	for child in _heatmap_container.get_children():
		child.queue_free()

	if items.is_empty():
		var empty := Label.new()
		empty.text = "还没有足够的数据形成热力图。"
		empty.add_theme_color_override("font_color", Color(0.72, 0.72, 0.72))
		_heatmap_container.add_child(empty)
		return

	var total_items := items.size()
	for i in range(total_items):
		var item: Dictionary = items[i]
		var completed := int(item.get("completed", 0))
		var total := int(item.get("total", 0))
		var ratio := 0.0 if total == 0 else float(completed) / float(total)
		var date_key := str(item.get("date_key", ""))

		var day_btn := MaterialButton.new()
		day_btn.text = _heatmap_label_for_index(i, date_key, total_items)
		day_btn.mouse_filter = Control.MOUSE_FILTER_PASS
		day_btn.button_size = MaterialButton.ButtonSize.SMALL32
		day_btn.background_color = Color(0.35, 0.65, 0.95, 0.1 + ratio * 0.55)
		day_btn.pressed.connect(func():
			if not date_key.is_empty():
				_selected_date_key = date_key
				date_context_changed.emit(date_key)
				_refresh()
		)
		_heatmap_container.add_child(day_btn)


func _refresh_insights(insights: Array) -> void:
	for child in _insight_container.get_children():
		child.queue_free()

	for text in insights:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)

		var dot := ColorRect.new()
		dot.custom_minimum_size = Vector2(6, 6)
		dot.color = Color(0.35, 0.65, 0.95)
		row.add_child(dot)

		var label := Label.new()
		label.text = str(text)
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.add_theme_color_override("font_color", Color(0.88, 0.88, 0.88))
		label.add_theme_font_size_override("font_size", 12)
		row.add_child(label)
		_insight_container.add_child(row)


func _update_chart(chart: Control, data: Array, average: float) -> void:
	var typed_data: Array[Dictionary] = []
	for item in data:
		if item is Dictionary:
			typed_data.append(item)
	chart.set_chart_data(typed_data)
	chart.set_average_line(average)


func _create_chart() -> Control:
	var chart := Control.new()
	chart.set_script(FocusBarChartScript)
	return chart


func _create_metric_card(title: String) -> Dictionary:
	var panel := _create_panel()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	panel.add_child(box)

	var title_label := Label.new()
	title_label.text = title
	title_label.add_theme_color_override("font_color", Color(0.76, 0.76, 0.76))
	title_label.add_theme_font_size_override("font_size", 11)
	box.add_child(title_label)

	var value_label := Label.new()
	value_label.add_theme_color_override("font_color", Color(1, 1, 1))
	value_label.add_theme_font_size_override("font_size", 16)
	box.add_child(value_label)

	return {"panel": panel, "value": value_label}


func _create_panel() -> InnerPanel:
	var panel := InnerPanel.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.content_padding = 10.0
	panel.background_color = Color(1, 1, 1, 0.08)
	panel.border_color = Color(1, 1, 1, 0.12)
	return panel


func _create_chart_title(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", Color(1, 1, 1))
	label.add_theme_font_size_override("font_size", 14)
	return label


func _on_period_switched(index: int, _text: String) -> void:
	match index:
		1:
			_period_type = "month"
		2:
			_period_type = "recent30"
		_:
			_period_type = "week"
	_refresh()


func _get_period_key() -> String:
	match _period_type:
		"month":
			var dt := _date_key_to_dict(_selected_date_key)
			return "%04d-%02d" % [int(dt.get("year", 0)), int(dt.get("month", 0))]
		"recent30":
			return _selected_date_key
		_:
			return DateUtil.date_to_week_key(_selected_date_key)


func _on_calendar_date_selected(year: int, month: int, day: int) -> void:
	var date_key := "%04d-%02d-%02d" % [year, month, day]
	_selected_date_key = date_key
	date_context_changed.emit(date_key)
	_refresh()


func _date_key_to_dict(date_key: String) -> Dictionary:
	var parts := date_key.split("-")
	if parts.size() != 3:
		return {"year": 0, "month": 0, "day": 0}
	return {
		"year": int(parts[0]),
		"month": int(parts[1]),
		"day": int(parts[2]),
	}


func _average_of(data: Array) -> float:
	if data.is_empty():
		return 0.0
	var total := 0.0
	for item in data:
		total += float(item.get("value", 0.0))
	return total / float(data.size())


func _heatmap_label_for_index(index: int, date_key: String, total_items: int) -> String:
	if _period_type == "week":
		var names = ["一", "二", "三", "四", "五", "六", "日"]
		return names[index] if index < names.size() else str(index + 1)
	if _period_type == "month" and not date_key.is_empty():
		return str(int(date_key.get_slice("-", 2)))
	if _period_type == "recent30":
		if total_items > 10 and index % 3 != 0:
			return "·"
		return date_key.right(2)
	return str(index + 1)
