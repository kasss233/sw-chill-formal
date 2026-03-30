extends VBoxContainer

@onready var _title_label: Label = $Header/TitleLabel
@onready var _controls: HBoxContainer = $Controls
@onready var _empty_label: Label = $EmptyLabel
@onready var _schedule_scroll: ScrollContainer = $ScheduleScroll
@onready var _schedule_grid: GridContainer = $ScheduleScroll/ScheduleGrid

const DAY_LABELS := ["周一", "周二", "周三", "周四", "周五", "周六", "周日"]

var _display_week_key: String = ""


func _ready() -> void:
	_setup_table()
	_controls.visible = false

	HabitState.habit_added.connect(_on_habits_changed)
	HabitState.habit_updated.connect(_on_habits_changed)
	HabitState.habit_removed.connect(_on_habits_changed)
	HabitState.data_loaded.connect(_refresh_all)
	HabitState.time_slot_template_changed.connect(_refresh_all)
	HabitState.schedule_entry_added.connect(_on_schedule_entry_added)
	HabitState.schedule_entry_removed.connect(_on_schedule_entry_removed)
	HabitState.schedule_updated.connect(_on_schedule_week_changed)
	HabitState.schedule_cleared.connect(_on_schedule_week_changed)

	_refresh_all()


func _setup_table() -> void:
	_schedule_grid.columns = 8
	_schedule_grid.add_theme_constant_override("h_separation", 6)
	_schedule_grid.add_theme_constant_override("v_separation", 6)


func _refresh_all() -> void:
	_refresh_schedule_table()


func _refresh_schedule_table() -> void:
	_clear_schedule_grid()
	var week_key := _resolve_display_week_key()
	_display_week_key = week_key
	var entries := HabitState.get_week_schedule(week_key)
	_add_grid_cell("时段", true)
	for day_label in DAY_LABELS:
		_add_grid_cell(day_label, true)

	var block_map := {}
	var min_start := 24 * 60
	var max_end := 0
	for entry in entries:
		var habit: HabitData = HabitState.get_habit_by_id(entry.habit_id)
		if habit == null:
			continue
		var start_minutes := _time_to_minutes(habit.preferred_start_time)
		var end_minutes := _time_to_minutes(habit.preferred_end_time)
		if start_minutes < 0 or end_minutes <= start_minutes:
			continue
		min_start = mini(min_start, start_minutes)
		max_end = maxi(max_end, end_minutes)
		for t in range(start_minutes, end_minutes, 30):
			var key := "%d_%d" % [entry.day_of_week, t]
			if not block_map.has(key):
				block_map[key] = []
			block_map[key].append({
				"entry_id": entry.id,
				"start": start_minutes,
				"end": end_minutes,
				"name": habit.name,
				"color": habit.color,
			})

	if min_start >= max_end:
		min_start = 8 * 60
		max_end = 22 * 60

	min_start = int(floor(min_start / 30.0) * 30)
	max_end = int(ceil(max_end / 30.0) * 30)

	for t in range(min_start, max_end, 30):
		var row_has_blocks := false
		for day in range(7):
			var row_key := "%d_%d" % [day, t]
			if block_map.has(row_key):
				row_has_blocks = true
				break
		if not row_has_blocks:
			continue

		var axis_text := _minutes_to_text(t)
		_add_grid_cell(axis_text, false)
		for day in range(7):
			var key := "%d_%d" % [day, t]
			if not block_map.has(key):
				_add_grid_cell("", false)
				continue
			var blocks: Array = block_map[key]
			var lines: Array[String] = []
			for block in blocks:
				lines.append(str(block.get("name", "")))
			var content := "\n".join(lines)
			if not blocks.is_empty():
				var color_str := str(blocks[0].get("color", "#4CAF50"))
				_add_grid_cell(content, false, Color.from_string(color_str, Color(0.3, 0.7, 0.3)))
			else:
				_add_grid_cell(content, false)

	_empty_label.visible = entries.is_empty()
	_schedule_scroll.visible = not entries.is_empty()
	_title_label.text = "习惯课表（自动分配，%s）" % week_key


func _clear_schedule_grid() -> void:
	for child in _schedule_grid.get_children():
		child.queue_free()


func _add_grid_cell(text: String, is_header: bool, accent: Color = Color(0, 0, 0, 0)) -> void:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(98, 34)
	if is_header:
		panel.custom_minimum_size = Vector2(98, 38)

	var style := StyleBoxFlat.new()
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	if is_header:
		style.bg_color = Color(0.16, 0.16, 0.18, 0.85)
		style.border_color = Color(1, 1, 1, 0.12)
	else:
		if accent.a > 0.0:
			style.bg_color = Color(accent.r, accent.g, accent.b, 0.22)
			style.border_color = Color(accent.r, accent.g, accent.b, 0.65)
		else:
			style.bg_color = Color(0.12, 0.12, 0.14, 0.55)
			style.border_color = Color(1, 1, 1, 0.08)
	panel.add_theme_stylebox_override("panel", style)

	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", Color(0.92, 0.92, 0.95, 1.0))
	label.add_theme_font_size_override("font_size", 12)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_child(label)

	_schedule_grid.add_child(panel)


func _time_to_minutes(time_text: String) -> int:
	var parts := time_text.split(":")
	if parts.size() < 2:
		return -1
	return int(parts[0]) * 60 + int(parts[1])


func _minutes_to_text(minutes: int) -> String:
	var normalized := clampi(minutes, 0, 23 * 60 + 59)
	return "%02d:%02d" % [normalized / 60, normalized % 60]


func _resolve_display_week_key() -> String:
	if not _display_week_key.is_empty() and not HabitState.get_week_schedule(_display_week_key).is_empty():
		return _display_week_key

	var current_week := HabitState.get_current_week_key()
	if not HabitState.get_week_schedule(current_week).is_empty():
		return current_week

	var keys := HabitState.get_scheduled_week_keys()
	if keys.is_empty():
		return current_week

	return str(keys[keys.size() - 1])


func _on_habits_changed(_habit) -> void:
	_refresh_schedule_table()


func _on_schedule_entry_added(entry) -> void:
	if entry != null:
		_display_week_key = str(entry.week_key)
	_refresh_schedule_table()


func _on_schedule_entry_removed(_entry_id: int) -> void:
	_refresh_schedule_table()


func _on_schedule_week_changed(week_key: String) -> void:
	_display_week_key = week_key
	_refresh_schedule_table()
