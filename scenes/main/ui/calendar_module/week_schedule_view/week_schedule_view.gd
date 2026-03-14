extends VBoxContainer

## 周课表视图 - 显示一周的习惯排期网格

signal ai_schedule_requested(week_key: String)

var _current_week_key: String = ""
var _cell_map: Dictionary = {}  # {"day_slot": Control}

@onready var _week_label: Label = $NavBar/WeekLabel
@onready var _grid_container: GridContainer = $ScrollContainer/GridContainer
@onready var _time_slot_editor = $TimeSlotEditor
@onready var _prev_btn: MaterialButton = $NavBar/PrevWeekBtn
@onready var _next_btn: MaterialButton = $NavBar/NextWeekBtn
@onready var _ai_btn: MaterialButton = $ActionRow/AIScheduleBtn
@onready var _copy_btn: MaterialButton = $ActionRow/CopyWeekBtn
@onready var _edit_slots_btn: MaterialButton = $ActionRow/EditSlotsBtn

const DAY_NAMES = ["周一", "周二", "周三", "周四", "周五", "周六", "周日"]
const DAY_SHORT = ["一", "二", "三", "四", "五", "六", "日"]


func _ready() -> void:
	# 设置按钮样式
	_ai_btn.set_filled_style(Color(0.35, 0.65, 0.95))
	_ai_btn.pressed.connect(func(): ai_schedule_requested.emit(_current_week_key))

	_copy_btn.set_outlined_style(Color(0.5, 0.5, 0.5))
	_copy_btn.pressed.connect(_on_copy_to_next_week)

	_edit_slots_btn.set_text_style(Color(0.6, 0.6, 0.6))
	_edit_slots_btn.pressed.connect(_on_edit_slots)

	_prev_btn.pressed.connect(_on_prev_week)
	_next_btn.pressed.connect(_on_next_week)

	_current_week_key = HabitState.get_current_week_key()
	_refresh_grid()

	# 连接信号
	HabitState.schedule_entry_added.connect(func(_e): _refresh_grid())
	HabitState.schedule_entry_removed.connect(func(_id): _refresh_grid())
	HabitState.schedule_updated.connect(func(_wk): _refresh_grid())
	HabitState.schedule_cleared.connect(func(_wk): _refresh_grid())
	HabitState.time_slot_template_changed.connect(_refresh_grid)
	HabitState.execution_updated.connect(func(_r): _refresh_grid())
	HabitState.data_loaded.connect(_refresh_grid)


func _refresh_grid() -> void:
	_update_week_label()
	_cell_map.clear()

	# 清空网格
	for child in _grid_container.get_children():
		child.queue_free()

	var templates = HabitState.get_time_slot_templates()
	var entries = HabitState.get_week_schedule(_current_week_key)

	# 获取今天是周几 (0=周一)
	var today_dow = _get_today_day_of_week()

	# 表头行：空 + 周一~周日
	var corner = _create_header_cell("")
	_grid_container.add_child(corner)
	for d in range(7):
		var header = _create_header_cell(DAY_SHORT[d])
		if d == today_dow and _is_current_week():
			header.add_theme_color_override("font_color", Color(0.35, 0.65, 0.95))
		_grid_container.add_child(header)

	# 每个时间段一行
	for slot in templates:
		# 时间段名称列
		var slot_label = _create_slot_label(slot)
		_grid_container.add_child(slot_label)

		# 7天的格子
		for day in range(7):
			var cell = _create_cell(slot, day, entries)
			_grid_container.add_child(cell)
			_cell_map["%d_%d" % [day, slot.id]] = cell


func _create_header_cell(text: String) -> Label:
	var label = Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	label.add_theme_font_size_override("font_size", 12)
	label.custom_minimum_size = Vector2(40, 28)
	return label


func _create_slot_label(slot: HabitData.TimeSlotTemplate) -> VBoxContainer:
	var vbox = VBoxContainer.new()
	vbox.custom_minimum_size = Vector2(55, 40)

	var name_label = Label.new()
	name_label.text = slot.name
	name_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	name_label.add_theme_font_size_override("font_size", 10)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(name_label)

	var time_label = Label.new()
	time_label.text = slot.start_time
	time_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	time_label.add_theme_font_size_override("font_size", 9)
	time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(time_label)

	return vbox


func _create_cell(slot: HabitData.TimeSlotTemplate, day: int, entries: Array) -> Control:
	# 查找该格子的排期
	var entry = null
	for e in entries:
		if e.day_of_week == day and e.time_slot_id == slot.id:
			entry = e
			break

	var cell = Panel.new()
	cell.custom_minimum_size = Vector2(40, 40)

	var style = StyleBoxFlat.new()
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4

	if entry:
		var habit = HabitState.get_habit_by_id(entry.habit_id)
		if habit:
			var color = Color.from_string(habit.color, Color(0.3, 0.5, 0.3))
			style.bg_color = Color(color.r, color.g, color.b, 0.3)
			style.border_color = Color(color.r, color.g, color.b, 0.6)
			style.border_width_bottom = 1
			style.border_width_top = 1
			style.border_width_left = 1
			style.border_width_right = 1

			# 习惯名缩写
			var label = Label.new()
			label.text = habit.name.left(2)
			label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
			label.add_theme_font_size_override("font_size", 10)
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			label.anchors_preset = Control.PRESET_FULL_RECT
			cell.add_child(label)

			# 检查执行状态
			var date_key = _get_date_key_for_day(day)
			var records = HabitState.get_records_by_date(date_key)
			for r in records:
				if r.entry_id == entry.id:
					if r.status == HabitData.ExecutionRecord.Status.COMPLETED:
						style.bg_color = Color(color.r, color.g, color.b, 0.6)
					elif r.status == HabitData.ExecutionRecord.Status.SKIPPED:
						style.bg_color = Color(0.3, 0.3, 0.3, 0.3)
					break

		# 点击已排期格子 → 弹出操作菜单
		cell.gui_input.connect(_on_cell_input.bind(entry, day))
	else:
		style.bg_color = Color(0.15, 0.15, 0.15, 0.5)
		# 点击空格子 → 选择习惯
		cell.gui_input.connect(_on_empty_cell_input.bind(slot.id, day))

	# 当日高亮
	if day == _get_today_day_of_week() and _is_current_week():
		style.border_color = Color(0.35, 0.65, 0.95, 0.5)
		style.border_width_bottom = 1
		style.border_width_top = 1
		style.border_width_left = 1
		style.border_width_right = 1

	cell.add_theme_stylebox_override("panel", style)
	return cell


func _on_cell_input(event: InputEvent, entry: HabitData.ScheduleEntry, day: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_show_entry_actions(entry, day)


func _on_empty_cell_input(event: InputEvent, slot_id: int, day: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		print("[WeekScheduleView] 空格子被点击: day=%d slot_id=%d" % [day, slot_id])
		_show_habit_picker(slot_id, day)


func _show_entry_actions(entry: HabitData.ScheduleEntry, day: int) -> void:
	var menu = MaterialContextMenu.new()
	add_child(menu)

	var date_key = _get_date_key_for_day(day)
	menu.add_item("完成", preload("res://assets/ui/icons/check_24dp_FFFFFF_FILL0_wght400_GRAD0_opsz24.svg"))
	menu.add_item("跳过")
	menu.add_item("延后")
	menu.add_separator()
	menu.add_item("移除", preload("res://assets/ui/icons/delete_forever_24dp_FFFFFF_FILL0_wght400_GRAD0_opsz24.svg"))

	menu.item_pressed.connect(func(index: int, _item):
		match index:
			0: HabitState.set_execution_status(entry.id, date_key, HabitData.ExecutionRecord.Status.COMPLETED)
			1: HabitState.set_execution_status(entry.id, date_key, HabitData.ExecutionRecord.Status.SKIPPED)
			2: HabitState.set_execution_status(entry.id, date_key, HabitData.ExecutionRecord.Status.DEFERRED)
			3: HabitState.remove_schedule_entry(entry.id)
		menu.queue_free()
	)
	menu.popup_at_mouse()


func _show_habit_picker(slot_id: int, day: int) -> void:
	var habits = HabitState.get_active_habits()
	print("[WeekScheduleView] 活跃习惯数量: %d" % habits.size())
	if habits.is_empty():
		print("[WeekScheduleView] 没有活跃习惯，请先在习惯库中添加")
		return

	var menu = MaterialContextMenu.new()
	add_child(menu)

	for h in habits:
		menu.add_item(h.name)

	menu.item_pressed.connect(func(index: int, _item):
		if index < habits.size():
			print("[WeekScheduleView] 选择习惯: %s -> day=%d slot=%d" % [habits[index].name, day, slot_id])
			HabitState.add_schedule_entry(habits[index].id, _current_week_key, day, slot_id)
		menu.queue_free()
	)
	menu.popup_at_mouse()


func _on_prev_week() -> void:
	_current_week_key = _offset_week(_current_week_key, -1)
	_refresh_grid()


func _on_next_week() -> void:
	_current_week_key = _offset_week(_current_week_key, 1)
	_refresh_grid()


func _on_copy_to_next_week() -> void:
	var next_week = _offset_week(_current_week_key, 1)
	HabitState.copy_week_schedule(_current_week_key, next_week)


func _on_edit_slots() -> void:
	_time_slot_editor.show_editor()


func _update_week_label() -> void:
	# 解析 week_key "2026-W10" 获取显示文本
	var parts = _current_week_key.split("-W")
	if parts.size() == 2:
		var year = parts[0]
		var week = parts[1]
		_week_label.text = "%s年 第%s周" % [year, week]
	else:
		_week_label.text = _current_week_key


func _is_current_week() -> bool:
	return _current_week_key == HabitState.get_current_week_key()


func _get_today_day_of_week() -> int:
	var dict = Time.get_datetime_dict_from_system()
	var weekday = dict["weekday"]  # 0=Sunday
	if weekday == 0:
		return 6
	return weekday - 1


func _get_date_key_for_day(day_of_week: int) -> String:
	# 从 week_key 计算指定 day_of_week 的日期
	var parts = _current_week_key.split("-W")
	if parts.size() != 2:
		return ""
	var year = int(parts[0])
	var week = int(parts[1])

	# 计算该年第一天是周几
	var jan1_str = "%04d-01-01T12:00:00" % year
	var jan1_unix = Time.get_unix_time_from_datetime_string(jan1_str)
	var jan1_dict = Time.get_datetime_dict_from_unix_time(jan1_unix)
	var jan1_weekday = jan1_dict["weekday"]  # 0=Sunday
	var jan1_iso = jan1_weekday if jan1_weekday != 0 else 7  # 1=Monday

	# 第1周的周一
	var week1_monday_unix: int
	if jan1_iso <= 4:
		week1_monday_unix = jan1_unix - (jan1_iso - 1) * 86400
	else:
		week1_monday_unix = jan1_unix + (8 - jan1_iso) * 86400

	# 目标日期
	var target_unix = week1_monday_unix + ((week - 1) * 7 + day_of_week) * 86400
	var target_dict = Time.get_datetime_dict_from_unix_time(target_unix)
	return "%04d-%02d-%02d" % [target_dict["year"], target_dict["month"], target_dict["day"]]


func _offset_week(week_key: String, offset: int) -> String:
	var parts = week_key.split("-W")
	if parts.size() != 2:
		return week_key
	var year = int(parts[0])
	var week = int(parts[1]) + offset

	if week < 1:
		year -= 1
		week = 52  # 简化处理
	elif week > 52:
		year += 1
		week = 1

	return "%04d-W%02d" % [year, week]


func get_current_week_key() -> String:
	return _current_week_key
