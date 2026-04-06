extends VBoxContainer

## 个人中心 - "统计" Tab
## 整合专注统计、习惯完成率、热力图、洞察、反思总结

# 周期切换
@onready var _period_switch: MaterialSegmentedButton = $PeriodSwitch
@onready var _nav_bar: HBoxContainer = $NavBar
@onready var _nav_prev_btn: MaterialButton = $NavBar/NavPrevBtn
@onready var _nav_title_label: Label = $NavBar/NavTitleLabel
@onready var _nav_next_btn: MaterialButton = $NavBar/NavNextBtn

# 概览卡片
@onready var _focus_total_value: Label = $OverviewGrid/FocusTotalCard/FocusTotalVBox/FocusTotalValueLabel
@onready var _task_done_value: Label = $OverviewGrid/TaskDoneCard/TaskDoneVBox/TaskDoneValueLabel
@onready var _habit_rate_value: Label = $OverviewGrid/HabitRateCard/HabitRateVBox/HabitRateValueLabel
@onready var _daily_avg_value: Label = $OverviewGrid/DailyAvgCard/DailyAvgVBox/DailyAvgValueLabel

# 柱状图
@onready var _focus_chart: Control = $ChartPanel/ChartVBox/FocusChart

# 专注时间线
@onready var _timeline_panel: InnerPanel = $TimelinePanel
@onready var _timeline_container: VBoxContainer = $TimelinePanel/TimelineVBox/TimelineContainer

# 热力图
@onready var _heatmap_container: GridContainer = $HeatmapPanel/HeatmapVBox/HeatmapContainer

# 洞察 + 反思
@onready var _insight_container: VBoxContainer = $InsightPanel/InsightVBox/InsightContainer
@onready var _reflection_label: Label = $ReflectionPanel/ReflectionVBox/ReflectionLabel
@onready var _generate_btn: MaterialButton = $ReflectionPanel/ReflectionVBox/ReflectionTop/GenerateBtn

# 状态
var _focus_view: int = 0  # 0=周, 1=月, 2=年
var _focus_offset: int = 0
var _selected_date_key: String = ""


func _ready() -> void:
	_selected_date_key = DateUtil.get_today_key()
	_generate_btn.set_filled_style(Color(0.35, 0.65, 0.95))
	_connect_signals()
	_refresh()


# ======================== 信号连接 ========================

func _connect_signals() -> void:
	_period_switch.segment_selected.connect(_on_period_changed)
	_nav_prev_btn.pressed.connect(_on_nav_prev)
	_nav_next_btn.pressed.connect(_on_nav_next)
	_generate_btn.pressed.connect(_on_generate_reflection)

	HabitState.execution_updated.connect(func(_record): _refresh())
	HabitState.schedule_updated.connect(func(_week_key): _refresh())
	HabitState.habit_updated.connect(func(_habit): _refresh())
	HabitState.data_loaded.connect(_refresh)

	if StatsState:
		StatsState.record_added.connect(func(_record): _refresh())
		StatsState.record_removed.connect(func(_id): _refresh())
		StatsState.data_loaded.connect(_refresh)

	if NoteState:
		NoteState.note_added.connect(func(_note): _refresh())
		NoteState.note_updated.connect(func(_note): _refresh())

	TaskState.task_state_changed.connect(func(_t): _refresh_overview_cards())
	TaskState.data_loaded.connect(_refresh_overview_cards)


# ======================== 周期切换 ========================

func _on_period_changed(index: int, _text: String) -> void:
	_focus_view = index
	_focus_offset = 0
	_update_nav_visibility()
	_refresh()


func _on_nav_prev() -> void:
	_focus_offset -= 1
	_refresh()


func _on_nav_next() -> void:
	_focus_offset += 1
	_refresh()


func _update_nav_visibility() -> void:
	_nav_bar.visible = _focus_view != 0
	_timeline_panel.visible = _focus_view == 0


func _update_nav_label() -> void:
	match _focus_view:
		1:
			var ref := DateUtil.get_month_for_offset(_focus_offset)
			_nav_title_label.text = "%d年%d月" % [ref["year"], ref["month"]]
		2:
			var now := Time.get_datetime_dict_from_system()
			var year: int = int(now["year"]) + _focus_offset
			_nav_title_label.text = "%d年" % year


# ======================== 数据刷新 ========================

func _refresh() -> void:
	_update_nav_visibility()
	_update_nav_label()
	_refresh_overview_cards()
	_refresh_focus_chart()
	_refresh_timeline()
	_refresh_review_data()


func _refresh_overview_cards() -> void:
	if not StatsState:
		_focus_total_value.text = "0 分钟"
		_daily_avg_value.text = "0 分钟"
		_task_done_value.text = "0"
		_habit_rate_value.text = "0%"
		return

	var period_seconds: int = 0
	var period_days: int = 7

	match _focus_view:
		0:  # 周
			var week_key := DateUtil.offset_week(DateUtil.date_to_week_key(_selected_date_key), _focus_offset)
			var monday := DateUtil.get_monday_for_week(week_key)
			var totals := StatsState.get_week_daily_totals("focus", monday, "duration_seconds")
			for item in totals:
				period_seconds += int(item["value"])
			period_days = 7
		1:  # 月
			var ref := DateUtil.get_month_for_offset(_focus_offset)
			var totals := StatsState.get_month_daily_totals("focus", ref["year"], ref["month"], "duration_seconds")
			for item in totals:
				period_seconds += int(item["value"])
			period_days = totals.size()
		2:  # 年
			var now := Time.get_datetime_dict_from_system()
			var year: int = int(now["year"]) + _focus_offset
			var totals := StatsState.get_year_monthly_totals("focus", year, "duration_seconds")
			for item in totals:
				period_seconds += int(item["value"])
			period_days = 365

	_focus_total_value.text = DateUtil.format_duration(period_seconds)

	var avg_seconds: int = period_seconds / period_days if period_days > 0 else 0
	_daily_avg_value.text = DateUtil.format_duration(avg_seconds)

	# 任务完成数（周期内）
	var task_totals := StatsState.get_task_completion_totals(_get_stats_period(), _get_stats_reference())
	var task_total := 0
	for item in task_totals:
		task_total += int(item.get("value", 0))
	_task_done_value.text = str(task_total)

	# 习惯完成率
	var period_type := _get_review_period_type()
	var period_key := _get_review_period_key()
	var summary := HabitState.get_review_summary(period_type, period_key)
	var overview: Dictionary = summary.get("overview", {})
	_habit_rate_value.text = "%d%%" % int(round(float(overview.get("completion_rate", 0.0)) * 100.0))


func _refresh_focus_chart() -> void:
	if not StatsState:
		return

	var chart_data: Array[Dictionary] = []
	var day_labels = ["一", "二", "三", "四", "五", "六", "日"]

	match _focus_view:
		0:  # 周
			var week_key := DateUtil.offset_week(DateUtil.date_to_week_key(_selected_date_key), _focus_offset)
			var monday := DateUtil.get_monday_for_week(week_key)
			var totals := StatsState.get_week_focus_totals(monday)
			for i in range(totals.size()):
				var label = day_labels[i] if i < day_labels.size() else str(i)
				chart_data.append({"label": label, "value": totals[i]["value"]})

			var total_hours: float = 0.0
			for item in chart_data:
				total_hours += float(item["value"])
			_focus_chart.set_average_line(total_hours / 7.0)

		1:  # 月
			var ref := DateUtil.get_month_for_offset(_focus_offset)
			var totals := StatsState.get_month_daily_totals("focus", ref["year"], ref["month"], "duration_seconds")
			for i in range(totals.size()):
				var hours = float(totals[i]["value"]) / 3600.0
				chart_data.append({"label": str(i + 1), "value": hours})

			var total_hours: float = 0.0
			for item in chart_data:
				total_hours += float(item["value"])
			var avg = total_hours / float(chart_data.size()) if not chart_data.is_empty() else 0.0
			_focus_chart.set_average_line(avg)

		2:  # 年
			var now := Time.get_datetime_dict_from_system()
			var year: int = int(now["year"]) + _focus_offset
			var totals := StatsState.get_year_monthly_totals("focus", year, "duration_seconds")
			var month_labels = ["1月","2月","3月","4月","5月","6月","7月","8月","9月","10月","11月","12月"]
			for i in range(totals.size()):
				var hours = float(totals[i]["value"]) / 3600.0
				chart_data.append({"label": month_labels[i], "value": hours})

			var total_hours: float = 0.0
			for item in chart_data:
				total_hours += float(item["value"])
			_focus_chart.set_average_line(total_hours / 12.0)

	_focus_chart.set_chart_data(chart_data)


func _refresh_timeline() -> void:
	for child in _timeline_container.get_children():
		child.queue_free()

	if _focus_view != 0:
		return

	if not StatsState:
		_add_timeline_empty()
		return

	var target_date_key := _selected_date_key
	if _focus_offset != 0:
		target_date_key = DateUtil.offset_date(_selected_date_key, _focus_offset * 7)

	var records := StatsState.get_records("focus", target_date_key)
	if records.is_empty():
		_add_timeline_empty()
		return

	records.sort_custom(func(a, b) -> bool:
		return int(a.data.get("start_timestamp", 0)) < int(b.data.get("start_timestamp", 0))
	)

	for record in records:
		var data: Dictionary = record.data if record != null else {}
		var completed: bool = data.get("completed", false)
		var duration_seconds: int = int(data.get("duration_seconds", 0))
		var start_time := _resolve_record_start_time(data)

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)

		# 竖色条
		var bar := ColorRect.new()
		bar.custom_minimum_size = Vector2(4, 28)
		bar.color = Color(0.35, 0.65, 0.95) if completed else Color(0.5, 0.5, 0.5)
		row.add_child(bar)

		# 信息
		var info_box := VBoxContainer.new()
		info_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info_box.add_theme_constant_override("separation", 2)
		row.add_child(info_box)

		var time_label := Label.new()
		var time_text := start_time.left(5) if start_time.length() >= 5 else start_time
		if time_text.is_empty():
			time_text = "--:--"
		var duration_min := duration_seconds / 60
		time_label.text = "%s  ·  %d 分钟" % [time_text, duration_min]
		time_label.add_theme_color_override("font_color", Color(1, 1, 1))
		time_label.add_theme_font_size_override("font_size", 13)
		info_box.add_child(time_label)

		var status_label := Label.new()
		status_label.text = "已完成" if completed else "已中断"
		status_label.add_theme_color_override("font_color", Color(0.35, 0.65, 0.95) if completed else Color(0.6, 0.6, 0.6))
		status_label.add_theme_font_size_override("font_size", 11)
		info_box.add_child(status_label)

		_timeline_container.add_child(row)


func _refresh_review_data() -> void:
	var period_type := _get_review_period_type()
	var period_key := _get_review_period_key()
	var summary := HabitState.get_review_summary(period_type, period_key)

	_refresh_heatmap(summary.get("heatmap_days", []))
	_refresh_insights(summary.get("insights", []))

	var reflection: Dictionary = summary.get("reflection", {})
	_reflection_label.text = str(reflection.get("content", ""))


func _refresh_heatmap(items: Array) -> void:
	for child in _heatmap_container.get_children():
		child.queue_free()

	if items.is_empty():
		var empty := Label.new()
		empty.text = "还没有足够的数据形成热力图。"
		empty.add_theme_color_override("font_color", Color(0.72, 0.72, 0.72))
		_heatmap_container.add_child(empty)
		return

	for i in range(items.size()):
		var item: Dictionary = items[i]
		var completed := int(item.get("completed", 0))
		var total := int(item.get("total", 0))
		var ratio := 0.0 if total == 0 else float(completed) / float(total)
		var date_key := str(item.get("date_key", ""))

		var day_btn := MaterialButton.new()
		day_btn.text = _heatmap_label_for_index(i, date_key, items.size())
		day_btn.mouse_filter = Control.MOUSE_FILTER_PASS
		day_btn.button_size = MaterialButton.ButtonSize.SMALL32
		day_btn.background_color = Color(0.35, 0.65, 0.95, 0.1 + ratio * 0.55)
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


# ======================== 操作回调 ========================

func _on_generate_reflection() -> void:
	var period_type := _get_review_period_type()
	var period_key := _get_review_period_key()
	# 通过 AI 的 generate_reflection 函数调用生成反思
	var prompt := "请为我的%s生成一段温和、鼓励式的回顾总结。包含亮点、节奏观察和下一步建议。" % _period_title_for_display(period_type, period_key)
	ChatState.agent_set_input_text(prompt)


func _period_title_for_display(period_type: String, period_key: String) -> String:
	match period_type:
		"month":
			return "%s 月度回顾" % period_key
		"recent30":
			return "最近30天回顾"
		_:
			return "周回顾"


# ======================== 工具方法 ========================

func _get_stats_period() -> String:
	match _focus_view:
		1: return "month"
		2: return "year"
		_: return "week"


func _get_stats_reference() -> Dictionary:
	match _focus_view:
		1:
			return DateUtil.get_month_for_offset(_focus_offset)
		2:
			var now := Time.get_datetime_dict_from_system()
			return {"year": int(now["year"]) + _focus_offset}
		_:
			var week_key := DateUtil.offset_week(DateUtil.date_to_week_key(_selected_date_key), _focus_offset)
			return {"monday_date": DateUtil.get_monday_for_week(week_key)}


func _get_review_period_type() -> String:
	match _focus_view:
		1: return "month"
		2: return "recent30"
		_: return "week"


func _get_review_period_key() -> String:
	match _focus_view:
		1:
			var ref := DateUtil.get_month_for_offset(_focus_offset)
			return "%04d-%02d" % [int(ref.get("year", 0)), int(ref.get("month", 0))]
		2:
			return _selected_date_key
		_:
			return DateUtil.offset_week(DateUtil.date_to_week_key(_selected_date_key), _focus_offset)


func _add_timeline_empty() -> void:
	var empty := Label.new()
	empty.text = "今天还没有专注记录"
	empty.add_theme_color_override("font_color", Color(0.72, 0.72, 0.72))
	empty.add_theme_font_size_override("font_size", 13)
	_timeline_container.add_child(empty)


func _heatmap_label_for_index(index: int, date_key: String, total_items: int) -> String:
	var period_type := _get_review_period_type()
	if period_type == "week":
		var names = ["一", "二", "三", "四", "五", "六", "日"]
		return names[index] if index < names.size() else str(index + 1)
	if period_type == "month" and not date_key.is_empty():
		return str(int(date_key.get_slice("-", 2)))
	if period_type == "recent30":
		if total_items > 10 and index % 3 != 0:
			return "·"
		return date_key.right(2)
	return str(index + 1)


func _resolve_record_start_time(data: Dictionary) -> String:
	var start_time := str(data.get("start_time", ""))
	if not start_time.is_empty():
		return start_time

	var start_timestamp := int(data.get("start_timestamp", 0))
	if start_timestamp <= 0:
		return ""

	var dt := DateUtil.utc_unix_to_datetime_dict_cn(start_timestamp)
	return "%02d:%02d" % [int(dt.get("hour", 0)), int(dt.get("minute", 0))]
