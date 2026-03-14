extends VBoxContainer

## 统计面板 - 显示习惯完成率、热力图和专注统计

signal generate_reflection_requested(week_key: String)

var _current_week_key: String = ""

@onready var _week_label: Label = $NavBar/WeekLabel
@onready var _overall_progress: MaterialProgressIndicator = $OverallPanel/OverallVBox/OverallProgress
@onready var _overall_rate_label: Label = $OverallPanel/OverallVBox/OverallRateLabel
@onready var _habits_container: VBoxContainer = $HabitsScroll/HabitsContainer
@onready var _heatmap_container: HBoxContainer = $HeatmapPanel/HeatmapVBox/HeatmapContainer
@onready var _reflection_label: Label = $ReflectionPanel/ReflectionVBox/ReflectionLabel
@onready var _generate_btn: MaterialButton = $ReflectionPanel/ReflectionVBox/GenerateBtn
@onready var _prev_btn: MaterialButton = $NavBar/PrevWeekBtn
@onready var _next_btn: MaterialButton = $NavBar/NextWeekBtn

# 专注统计节点
@onready var _focus_nav_bar: HBoxContainer = $FocusStatsPanel/FocusVBox/FocusNavBar
@onready var _focus_prev_btn: MaterialButton = $FocusStatsPanel/FocusVBox/FocusNavBar/FocusPrevBtn
@onready var _focus_next_btn: MaterialButton = $FocusStatsPanel/FocusVBox/FocusNavBar/FocusNextBtn
@onready var _focus_date_label: Label = $FocusStatsPanel/FocusVBox/FocusNavBar/FocusDateLabel
@onready var _focus_view_mode: MaterialSegmentedButton = $FocusStatsPanel/FocusVBox/FocusViewMode
@onready var _today_title: Label = $FocusStatsPanel/FocusVBox/FocusCardsRow/TodayCard/TodayVBox/TodayTitle
@onready var _today_value: Label = $FocusStatsPanel/FocusVBox/FocusCardsRow/TodayCard/TodayVBox/TodayValue
@onready var _period_title: Label = $FocusStatsPanel/FocusVBox/FocusCardsRow/PeriodCard/PeriodVBox/PeriodTitle
@onready var _period_value: Label = $FocusStatsPanel/FocusVBox/FocusCardsRow/PeriodCard/PeriodVBox/PeriodValue
@onready var _focus_chart: Control = $FocusStatsPanel/FocusVBox/FocusChart

# 专注统计状态：0=周, 1=月, 2=年
var _focus_view: int = 0
var _focus_offset: int = 0


func _ready() -> void:
	_prev_btn.pressed.connect(_on_prev_week)
	_next_btn.pressed.connect(_on_next_week)
	_generate_btn.set_filled_style(Color(0.35, 0.65, 0.95))
	_generate_btn.pressed.connect(func(): generate_reflection_requested.emit(_current_week_key))

	_current_week_key = HabitState.get_current_week_key()
	_refresh_stats()

	HabitState.execution_updated.connect(func(_r): _refresh_stats())
	HabitState.schedule_updated.connect(func(_wk): _refresh_stats())
	HabitState.data_loaded.connect(_refresh_stats)

	_init_focus_panel()


func show_for_week(week_key: String) -> void:
	_current_week_key = week_key
	_refresh_stats()


func _refresh_stats() -> void:
	_update_week_label()
	var stats = HabitState.get_week_stats(_current_week_key)

	# 整体完成率
	var rate = stats.get("completion_rate", 0.0)
	_overall_rate_label.text = "本周完成率: %d%%" % int(rate * 100)
	_overall_progress.set_progress_value(rate)

	# 热力图
	_refresh_heatmap()

	# 各习惯统计
	_refresh_habit_stats()

	# 反思内容
	_refresh_reflection()


func _refresh_heatmap() -> void:
	for child in _heatmap_container.get_children():
		child.queue_free()

	var day_names = ["一", "二", "三", "四", "五", "六", "日"]
	for day in range(7):
		var day_entries = HabitState.get_day_schedule(_current_week_key, day)
		var date_key = _get_date_key_for_day(day)
		var records = HabitState.get_records_by_date(date_key)

		var total = day_entries.size()
		var completed: int = 0
		for r in records:
			if r.status == HabitData.ExecutionRecord.Status.COMPLETED:
				completed += 1

		var day_vbox = VBoxContainer.new()
		day_vbox.alignment = BoxContainer.ALIGNMENT_CENTER

		# 圆形色块
		var circle = Panel.new()
		circle.custom_minimum_size = Vector2(28, 28)
		var style = StyleBoxFlat.new()
		style.corner_radius_top_left = 14
		style.corner_radius_top_right = 14
		style.corner_radius_bottom_left = 14
		style.corner_radius_bottom_right = 14

		if total > 0:
			var intensity = float(completed) / float(total)
			style.bg_color = Color(0.35, 0.65, 0.95, 0.2 + intensity * 0.7)
		else:
			style.bg_color = Color(0.2, 0.2, 0.2, 0.5)

		circle.add_theme_stylebox_override("panel", style)
		day_vbox.add_child(circle)

		var day_label = Label.new()
		day_label.text = day_names[day]
		day_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		day_label.add_theme_font_size_override("font_size", 10)
		day_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		day_vbox.add_child(day_label)

		_heatmap_container.add_child(day_vbox)


func _refresh_habit_stats() -> void:
	for child in _habits_container.get_children():
		child.queue_free()

	var habits = HabitState.get_all_habits()
	var entries = HabitState.get_week_schedule(_current_week_key)

	for habit in habits:
		# 该习惯在本周的排期数
		var habit_entries: Array = []
		for e in entries:
			if e.habit_id == habit.id:
				habit_entries.append(e)
		if habit_entries.is_empty():
			continue

		# 统计完成数
		var total = habit_entries.size()
		var completed: int = 0
		var records = HabitState.get_records_by_week(_current_week_key)
		for r in records:
			if r.habit_id == habit.id and r.status == HabitData.ExecutionRecord.Status.COMPLETED:
				completed += 1

		var rate = float(completed) / float(total) if total > 0 else 0.0

		# 创建卡片
		var card = InnerPanel.new()
		card.content_padding = 10.0
		card.background_color = Color(1, 1, 1, 0.05)

		var hbox = HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 8)

		# 颜色标记
		var color_rect = ColorRect.new()
		color_rect.custom_minimum_size = Vector2(4, 0)
		color_rect.size_flags_vertical = Control.SIZE_EXPAND_FILL
		color_rect.color = Color.from_string(habit.color, Color(0.3, 0.7, 0.3))
		hbox.add_child(color_rect)

		# 名称
		var name_label = Label.new()
		name_label.text = habit.name
		name_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
		name_label.add_theme_font_size_override("font_size", 13)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hbox.add_child(name_label)

		# 进度条
		var progress = MaterialProgressIndicator.new()
		progress.indicator_type = MaterialProgressIndicator.IndicatorType.LINEAR
		progress.linear_width = 80
		progress.track_thickness = 4
		progress.progress_color = Color.from_string(habit.color, Color(0.35, 0.65, 0.95))
		progress.set_progress_immediate(rate)
		hbox.add_child(progress)

		# 完成数
		var count_label = Label.new()
		count_label.text = "%d/%d" % [completed, total]
		count_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		count_label.add_theme_font_size_override("font_size", 12)
		hbox.add_child(count_label)

		card.add_child(hbox)
		_habits_container.add_child(card)


func _refresh_reflection() -> void:
	# 查找最新的反思笔记
	if not NoteState:
		return
	var reflection_notes = NoteState.get_notes_by_category("反思总结")
	if reflection_notes.is_empty():
		_reflection_label.text = "暂无反思总结"
		return

	# 显示最新的
	var latest = reflection_notes[0]
	_reflection_label.text = latest.content.left(200)
	if latest.content.length() > 200:
		_reflection_label.text += "..."


func _on_prev_week() -> void:
	_current_week_key = _offset_week(_current_week_key, -1)
	_refresh_stats()
	if _focus_view == 0:
		_refresh_focus_stats()


func _on_next_week() -> void:
	_current_week_key = _offset_week(_current_week_key, 1)
	_refresh_stats()
	if _focus_view == 0:
		_refresh_focus_stats()


func _update_week_label() -> void:
	var parts = _current_week_key.split("-W")
	if parts.size() == 2:
		_week_label.text = "%s年 第%s周 统计" % [parts[0], parts[1]]
	else:
		_week_label.text = _current_week_key


func _offset_week(week_key: String, offset: int) -> String:
	var parts = week_key.split("-W")
	if parts.size() != 2:
		return week_key
	var year = int(parts[0])
	var week = int(parts[1]) + offset
	if week < 1:
		year -= 1
		week = 52
	elif week > 52:
		year += 1
		week = 1
	return "%04d-W%02d" % [year, week]


func _get_date_key_for_day(day_of_week: int) -> String:
	var parts = _current_week_key.split("-W")
	if parts.size() != 2:
		return ""
	var year = int(parts[0])
	var week = int(parts[1])
	var jan1_str = "%04d-01-01T12:00:00" % year
	var jan1_unix = Time.get_unix_time_from_datetime_string(jan1_str)
	var jan1_dict = Time.get_datetime_dict_from_unix_time(jan1_unix)
	var jan1_weekday = jan1_dict["weekday"]
	var jan1_iso = jan1_weekday if jan1_weekday != 0 else 7
	var week1_monday_unix: int
	if jan1_iso <= 4:
		week1_monday_unix = jan1_unix - (jan1_iso - 1) * 86400
	else:
		week1_monday_unix = jan1_unix + (8 - jan1_iso) * 86400
	var target_unix = week1_monday_unix + ((week - 1) * 7 + day_of_week) * 86400
	var target_dict = Time.get_datetime_dict_from_unix_time(target_unix)
	return "%04d-%02d-%02d" % [target_dict["year"], target_dict["month"], target_dict["day"]]


# ======================== 专注统计面板 ========================

func _init_focus_panel() -> void:
	_focus_prev_btn.pressed.connect(_on_focus_prev)
	_focus_next_btn.pressed.connect(_on_focus_next)
	_focus_view_mode.segment_selected.connect(_on_focus_view_changed)

	if StatsState:
		StatsState.record_added.connect(func(_r): _refresh_focus_stats())
		StatsState.record_removed.connect(func(_id): _refresh_focus_stats())
		StatsState.data_loaded.connect(_refresh_focus_stats)

	_refresh_focus_stats()
	_update_focus_nav_visibility()


func _on_focus_prev() -> void:
	_focus_offset -= 1
	_refresh_focus_stats()


func _on_focus_next() -> void:
	_focus_offset += 1
	_refresh_focus_stats()


func _on_focus_view_changed(index: int, _text: String) -> void:
	_focus_view = index
	_focus_offset = 0
	_update_focus_nav_visibility()
	_refresh_focus_stats()


func _refresh_focus_stats() -> void:
	_update_focus_nav_label()
	_update_focus_cards()
	_update_focus_chart()


func _update_focus_nav_visibility() -> void:
	_focus_nav_bar.visible = _focus_view != 0  # 周视图隐藏，月/年视图显示


func _update_focus_nav_label() -> void:
	match _focus_view:
		0:  # 周 - FocusNavBar 已隐藏，仅更新周期标题
			_period_title.text = "本周合计"
		1:  # 月
			var ref = _get_month_year_for_offset(_focus_offset)
			_focus_date_label.text = "%d年%d月" % [ref["year"], ref["month"]]
			_period_title.text = "本月合计"
		2:  # 年
			var now = Time.get_datetime_dict_from_system()
			var year = int(now["year"]) + _focus_offset
			_focus_date_label.text = "%d年" % year
			_period_title.text = "全年合计"


func _update_focus_cards() -> void:
	if not StatsState:
		return

	# 今日卡片
	var today_seconds = StatsState.get_today_focus_seconds()
	_today_value.text = _format_duration(today_seconds)

	# 周期卡片
	var period_seconds: int = 0
	match _focus_view:
		0:  # 周 - 复用顶部 NavBar 的周
			var monday = _get_date_key_for_day(0)
			var totals = StatsState.get_week_daily_totals("focus", monday, "duration_seconds")
			for item in totals:
				period_seconds += int(item["value"])
		1:  # 月
			var ref = _get_month_year_for_offset(_focus_offset)
			var totals = StatsState.get_month_daily_totals("focus", ref["year"], ref["month"], "duration_seconds")
			for item in totals:
				period_seconds += int(item["value"])
		2:  # 年
			var now = Time.get_datetime_dict_from_system()
			var year = int(now["year"]) + _focus_offset
			var totals = StatsState.get_year_monthly_totals("focus", year, "duration_seconds")
			for item in totals:
				period_seconds += int(item["value"])

	_period_value.text = _format_duration(period_seconds)


func _update_focus_chart() -> void:
	if not StatsState:
		return

	var chart_data: Array[Dictionary] = []
	var day_labels = ["一", "二", "三", "四", "五", "六", "日"]

	match _focus_view:
		0:  # 周 - 复用顶部 NavBar 的周
			var monday = _get_date_key_for_day(0)
			var totals = StatsState.get_week_focus_totals(monday)
			for i in range(totals.size()):
				var label = day_labels[i] if i < day_labels.size() else str(i)
				chart_data.append({"label": label, "value": totals[i]["value"]})

			# 计算日均
			var total_hours: float = 0.0
			var active_days: int = 0
			for item in chart_data:
				if float(item["value"]) > 0.0:
					total_hours += float(item["value"])
					active_days += 1
			var avg = total_hours / 7.0
			_focus_chart.set_average_line(avg)

		1:  # 月
			var ref = _get_month_year_for_offset(_focus_offset)
			var totals = StatsState.get_month_daily_totals("focus", ref["year"], ref["month"], "duration_seconds")
			for i in range(totals.size()):
				var hours = float(totals[i]["value"]) / 3600.0
				chart_data.append({"label": str(i + 1), "value": hours})

			var total_hours: float = 0.0
			for item in chart_data:
				total_hours += float(item["value"])
			var avg = total_hours / float(chart_data.size()) if not chart_data.is_empty() else 0.0
			_focus_chart.set_average_line(avg)

		2:  # 年
			var now = Time.get_datetime_dict_from_system()
			var year = int(now["year"]) + _focus_offset
			var totals = StatsState.get_year_monthly_totals("focus", year, "duration_seconds")
			var month_labels = ["1月","2月","3月","4月","5月","6月","7月","8月","9月","10月","11月","12月"]
			for i in range(totals.size()):
				var hours = float(totals[i]["value"]) / 3600.0
				chart_data.append({"label": month_labels[i], "value": hours})

			var total_hours: float = 0.0
			for item in chart_data:
				total_hours += float(item["value"])
			var avg = total_hours / 12.0
			_focus_chart.set_average_line(avg)

	_focus_chart.set_chart_data(chart_data)


# ======================== 专注统计日期工具 ========================

func _get_monday_for_offset(offset: int) -> String:
	var now = Time.get_datetime_dict_from_system()
	var dt = {
		"year": int(now["year"]),
		"month": int(now["month"]),
		"day": int(now["day"]),
		"hour": 12,
		"minute": 0,
		"second": 0,
	}
	var unix = int(Time.get_unix_time_from_datetime_dict(dt))
	var weekday = int(Time.get_datetime_dict_from_unix_time(unix)["weekday"])
	# weekday: 0=Sunday, 1=Monday...6=Saturday
	var days_since_monday = (weekday + 6) % 7
	var monday_unix = unix - days_since_monday * 86400 + offset * 7 * 86400
	var monday_dict = Time.get_datetime_dict_from_unix_time(monday_unix)
	return "%04d-%02d-%02d" % [monday_dict["year"], monday_dict["month"], monday_dict["day"]]


func _offset_date_str(date_str: String, days: int) -> String:
	var parts = date_str.split("-")
	if parts.size() < 3:
		return date_str
	var dt = {
		"year": int(parts[0]),
		"month": int(parts[1]),
		"day": int(parts[2]),
		"hour": 12,
		"minute": 0,
		"second": 0,
	}
	var unix = int(Time.get_unix_time_from_datetime_dict(dt)) + days * 86400
	var result = Time.get_datetime_dict_from_unix_time(unix)
	return "%04d-%02d-%02d" % [result["year"], result["month"], result["day"]]


func _get_month_year_for_offset(offset: int) -> Dictionary:
	var now = Time.get_datetime_dict_from_system()
	var year = int(now["year"])
	var month = int(now["month"]) + offset
	while month < 1:
		year -= 1
		month += 12
	while month > 12:
		year += 1
		month -= 12
	return {"year": year, "month": month}


func _format_duration(seconds: int) -> String:
	var hours = seconds / 3600
	var minutes = (seconds % 3600) / 60
	if hours > 0:
		return "%dh %dm" % [hours, minutes]
	return "%dm" % minutes
