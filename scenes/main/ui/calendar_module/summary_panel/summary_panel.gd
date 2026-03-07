extends VBoxContainer

## 统计面板 - 显示习惯完成率和热力图

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


func _on_next_week() -> void:
	_current_week_key = _offset_week(_current_week_key, 1)
	_refresh_stats()


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
