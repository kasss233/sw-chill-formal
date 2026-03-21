extends VBoxContainer

## 周节奏视图，展示一周习惯安排并支持轻量微调

signal ai_schedule_requested(week_key: String, style: String)

var _current_week_key: String = ""
var _selected_day: int = -1

@onready var _week_label: Label = $NavBar/WeekLabel
@onready var _hint_label: Label = $RhythmHintLabel
@onready var _grid_container: GridContainer = $ScrollContainer/GridContainer
@onready var _time_slot_editor = $TimeSlotEditor
@onready var _prev_btn: MaterialButton = $NavBar/PrevWeekBtn
@onready var _next_btn: MaterialButton = $NavBar/NextWeekBtn
@onready var _ai_btn: MaterialButton = $ActionRow/AIScheduleBtn
@onready var _ai_disciplined_btn: MaterialButton = $ActionRow/AIDisciplinedBtn
@onready var _copy_btn: MaterialButton = $ActionRow/CopyWeekBtn
@onready var _edit_slots_btn: MaterialButton = $ActionRow/EditSlotsBtn
@onready var _empty_hint_label: Label = $EmptyHintLabel

const DAY_SHORT = ["一", "二", "三", "四", "五", "六", "日"]


func _ready() -> void:
	_ai_btn.set_filled_style(Color(0.35, 0.65, 0.95))
	_ai_btn.pressed.connect(func(): ai_schedule_requested.emit(_current_week_key, "relaxed"))

	_ai_disciplined_btn.set_outlined_style(Color(0.6, 0.78, 1.0), 1)
	_ai_disciplined_btn.pressed.connect(func(): ai_schedule_requested.emit(_current_week_key, "disciplined"))

	_copy_btn.set_outlined_style(Color(0.5, 0.5, 0.5))
	_copy_btn.pressed.connect(_on_copy_to_next_week)

	_edit_slots_btn.set_text_style(Color(0.6, 0.6, 0.6))
	_edit_slots_btn.pressed.connect(_on_edit_slots)

	_prev_btn.pressed.connect(_on_prev_week)
	_next_btn.pressed.connect(_on_next_week)

	_current_week_key = HabitState.get_current_week_key()
	_selected_day = DateUtil.get_today_day_of_week()
	_refresh_grid()

	HabitState.schedule_entry_added.connect(func(_entry): _refresh_grid())
	HabitState.schedule_entry_removed.connect(func(_entry_id): _refresh_grid())
	HabitState.schedule_updated.connect(func(_week_key): _refresh_grid())
	HabitState.schedule_cleared.connect(func(_week_key): _refresh_grid())
	HabitState.time_slot_template_changed.connect(_refresh_grid)
	HabitState.execution_updated.connect(func(_record): _refresh_grid())
	HabitState.data_loaded.connect(_refresh_grid)


func _refresh_grid() -> void:
	_update_week_label()

	for child in _grid_container.get_children():
		child.queue_free()

	var templates = HabitState.get_time_slot_templates()
	var entries = HabitState.get_week_schedule(_current_week_key)
	var rhythm_data := HabitState.get_week_rhythm_data(_current_week_key)
	_hint_label.text = "%s  ·  %s" % [str(rhythm_data.get("theme_title", "")), str(rhythm_data.get("theme_text", ""))]
	_empty_hint_label.visible = entries.is_empty()
	_empty_hint_label.text = str(rhythm_data.get("empty_state_text", ""))

	var today_dow := DateUtil.get_today_day_of_week()

	_grid_container.add_child(_create_header_cell(""))
	for day in range(7):
		var header = _create_header_cell(DAY_SHORT[day])
		if day == _selected_day:
			header.add_theme_color_override("font_color", Color(1.0, 0.92, 0.72))
		elif day == today_dow and _is_current_week():
			header.add_theme_color_override("font_color", Color(0.35, 0.65, 0.95))
		_grid_container.add_child(header)

	for slot in templates:
		_grid_container.add_child(_create_slot_label(slot))
		for day in range(7):
			_grid_container.add_child(_create_cell(slot, day, entries))


func _create_header_cell(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", Color(0.93, 0.93, 0.93))
	label.add_theme_font_size_override("font_size", 13)
	label.custom_minimum_size = Vector2(40, 32)
	return label


func _create_slot_label(slot: HabitData.TimeSlotTemplate) -> VBoxContainer:
	var vbox := VBoxContainer.new()
	vbox.custom_minimum_size = Vector2(58, 48)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER

	var name_label := Label.new()
	name_label.text = slot.name
	name_label.add_theme_color_override("font_color", Color(0.93, 0.93, 0.93))
	name_label.add_theme_font_size_override("font_size", 11)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(name_label)

	var time_label := Label.new()
	time_label.text = slot.start_time
	time_label.add_theme_color_override("font_color", Color(0.78, 0.78, 0.78))
	time_label.add_theme_font_size_override("font_size", 10)
	time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(time_label)

	return vbox


func _create_cell(slot: HabitData.TimeSlotTemplate, day: int, entries: Array) -> Control:
	var entry: HabitData.ScheduleEntry = null
	for schedule_entry in entries:
		if schedule_entry.day_of_week == day and schedule_entry.time_slot_id == slot.id:
			entry = schedule_entry
			break

	var date_key := DateUtil.week_key_to_date(_current_week_key, day)
	var cell := Panel.new()
	cell.custom_minimum_size = Vector2(44, 48)

	var style := StyleBoxFlat.new()
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6

	if entry != null:
		var habit: HabitData = HabitState.get_habit_by_id(entry.habit_id)
		if habit != null:
			var color := Color.from_string(habit.color, Color(0.3, 0.5, 0.3))
			style.bg_color = Color(color.r, color.g, color.b, 0.35)
			style.border_color = Color(color.r, color.g, color.b, 0.7)
			style.border_width_bottom = 1
			style.border_width_top = 1
			style.border_width_left = 1
			style.border_width_right = 1

			var label := Label.new()
			label.text = _build_entry_short_text(habit, entry.id, date_key)
			label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
			label.add_theme_font_size_override("font_size", 12)
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			label.anchors_preset = Control.PRESET_FULL_RECT
			cell.add_child(label)

			var records = HabitState.get_records_by_date(date_key)
			for record in records:
				if record.entry_id != entry.id:
					continue
				if record.status == HabitData.ExecutionRecord.Status.COMPLETED:
					style.bg_color = Color(color.r, color.g, color.b, 0.65)
				elif record.status == HabitData.ExecutionRecord.Status.SKIPPED:
					style.bg_color = Color(0.3, 0.3, 0.3, 0.32)
				elif record.status == HabitData.ExecutionRecord.Status.DEFERRED:
					style.bg_color = Color(color.r, color.g, color.b, 0.22)
				break

		cell.gui_input.connect(_on_cell_input.bind(entry, day))
	else:
		style.bg_color = Color(0.2, 0.2, 0.2, 0.5)
		cell.gui_input.connect(_on_empty_cell_input.bind(slot.id, day))

	if day == _selected_day:
		style.border_color = Color(1.0, 0.93, 0.72, 0.78)
		style.border_width_bottom = 2
		style.border_width_top = 2
		style.border_width_left = 2
		style.border_width_right = 2
	elif day == DateUtil.get_today_day_of_week() and _is_current_week():
		style.border_color = Color(0.35, 0.65, 0.95, 0.5)
		style.border_width_bottom = 1
		style.border_width_top = 1
		style.border_width_left = 1
		style.border_width_right = 1

	cell.add_theme_stylebox_override("panel", style)
	return cell


func _on_cell_input(event: InputEvent, entry: HabitData.ScheduleEntry, day: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_selected_day = day
		_show_entry_actions(entry, day)
		_refresh_grid()


func _on_empty_cell_input(event: InputEvent, slot_id: int, day: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_selected_day = day
		_show_habit_picker(slot_id, day)
		_refresh_grid()


func _show_entry_actions(entry: HabitData.ScheduleEntry, day: int) -> void:
	var menu := MaterialContextMenu.new()
	add_child(menu)

	var date_key := DateUtil.week_key_to_date(_current_week_key, day)
	menu.add_item("完成", preload("res://assets/ui/icons/check_24dp_FFFFFF_FILL0_wght400_GRAD0_opsz24.svg"))
	menu.add_item("跳过")
	menu.add_item("稍后")
	menu.add_separator()
	menu.add_item("移除", preload("res://assets/ui/icons/delete_forever_24dp_FFFFFF_FILL0_wght400_GRAD0_opsz24.svg"))

	menu.item_pressed.connect(func(index: int, _item):
		match index:
			0:
				HabitState.set_execution_status(entry.id, date_key, HabitData.ExecutionRecord.Status.COMPLETED)
			1:
				HabitState.set_execution_status(entry.id, date_key, HabitData.ExecutionRecord.Status.SKIPPED)
			2:
				HabitState.set_execution_status(entry.id, date_key, HabitData.ExecutionRecord.Status.DEFERRED)
			3:
				HabitState.remove_schedule_entry(entry.id)
		menu.queue_free()
	)
	menu.popup_at_mouse()


func _show_habit_picker(slot_id: int, day: int) -> void:
	var habits = HabitState.get_active_habits()
	if habits.is_empty():
		return

	var menu := MaterialContextMenu.new()
	add_child(menu)
	for habit in habits:
		menu.add_item(habit.name)

	menu.item_pressed.connect(func(index: int, _item):
		if index < habits.size():
			HabitState.add_schedule_entry(habits[index].id, _current_week_key, day, slot_id)
		menu.queue_free()
	)
	menu.popup_at_mouse()


func _on_prev_week() -> void:
	_current_week_key = DateUtil.offset_week(_current_week_key, -1)
	_refresh_grid()


func _on_next_week() -> void:
	_current_week_key = DateUtil.offset_week(_current_week_key, 1)
	_refresh_grid()


func _on_copy_to_next_week() -> void:
	var next_week := DateUtil.offset_week(_current_week_key, 1)
	HabitState.copy_week_schedule(_current_week_key, next_week)


func _on_edit_slots() -> void:
	_time_slot_editor.show_editor()


func _update_week_label() -> void:
	var parts = _current_week_key.split("-W")
	if parts.size() == 2:
		_week_label.text = "%s 年第 %s 周" % [parts[0], parts[1]]
	else:
		_week_label.text = _current_week_key


func _build_entry_short_text(habit: HabitData, entry_id: int, date_key: String) -> String:
	var records = HabitState.get_records_by_date(date_key)
	for record in records:
		if record.entry_id != entry_id:
			continue
		match record.status:
			HabitData.ExecutionRecord.Status.COMPLETED:
				return "OK%s" % habit.name.left(2)
			HabitData.ExecutionRecord.Status.SKIPPED:
				return "-%s" % habit.name.left(2)
			HabitData.ExecutionRecord.Status.DEFERRED:
				return "~%s" % habit.name.left(2)
	return habit.name.left(2)


func _is_current_week() -> bool:
	return _current_week_key == HabitState.get_current_week_key()


func get_current_week_key() -> String:
	return _current_week_key


func set_selected_date_key(date_key: String) -> void:
	if date_key.is_empty():
		return
	_current_week_key = DateUtil.date_to_week_key(date_key)
	_selected_day = DateUtil.get_day_of_week(date_key)
	_refresh_grid()


func show_for_week(week_key: String, selected_date_key: String = "") -> void:
	_current_week_key = week_key
	if not selected_date_key.is_empty():
		_selected_day = DateUtil.get_day_of_week(selected_date_key)
	_refresh_grid()
