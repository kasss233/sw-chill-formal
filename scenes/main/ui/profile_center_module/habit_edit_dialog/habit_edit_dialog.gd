extends MaterialDialog

## 习惯编辑对话框 - 新建/编辑习惯

signal habit_confirmed(data: Dictionary)

# 编辑模式相关
var _editing_habit_id: int = -1 # -1 表示新建

# UI 元素
@onready var _name_field: MaterialTextField = $FormContent/NameField
@onready var _duration_box: VBoxContainer = $FormContent/DurationBox
@onready var _period_box: VBoxContainer = $FormContent/PeriodBox
@onready var _legacy_freq_box: VBoxContainer = $FormContent/FreqBox

var _color_buttons: Array[MaterialButton] = []
var _weekday_checks: Array[CheckBox] = []
var _selected_color: String = "#4CAF50"
var _start_hour_spin: SpinBox
var _start_minute_selector: MaterialDropdown
var _end_time_selector: MaterialDropdown

const MAX_HABIT_DURATION_MINUTES := 120

const WEEKDAY_LABELS := ["周一", "周二", "周三", "周四", "周五", "周六", "周日"]

const PRESET_COLORS: Array[String] = [
	"#4CAF50", "#2196F3", "#FF9800", "#E91E63",
	"#9C27B0", "#00BCD4", "#FF5722", "#607D8B"
]


func _ready() -> void:
	super._ready()
	dialog_title = "新建习惯"
	dialog_size = MaterialDialog.DialogSize.MEDIUM

	# 收集颜色按钮并连接信号
	var color_row = $FormContent/ColorBox/ColorRow
	for i in range(color_row.get_child_count()):
		var btn = color_row.get_child(i) as MaterialButton
		btn.pressed.connect(_on_color_selected.bind(i))
		_color_buttons.append(btn)

	_duration_box.visible = false
	_period_box.visible = false
	_legacy_freq_box.visible = false
	_setup_time_range_selector()
	_setup_weekday_checks()

	# 将 FormContent 移入对话框内容区
	set_custom_content($FormContent)
	_add_dialog_buttons()
	visible = false


func _add_dialog_buttons() -> void:
	clear_buttons()
	add_button("取消").pressed.connect(func(): hide_dialog())
	var confirm_btn = add_button("确定")
	confirm_btn.set_filled_style(Color(0.35, 0.65, 0.95))
	confirm_btn.pressed.connect(_on_confirm)


func show_create() -> void:
	_editing_habit_id = -1
	dialog_title = "新建习惯"
	_name_field.set_text("")
	_set_time_selection("08:00", "09:00")
	_set_selected_week_days([0, 1, 2, 3, 4, 5, 6])
	_selected_color = PRESET_COLORS[0]
	_update_color_highlight()
	show_dialog()


func show_edit(habit: HabitData) -> void:
	_editing_habit_id = habit.id
	dialog_title = "编辑习惯"
	_name_field.set_text(habit.name)
	_set_time_selection(habit.preferred_start_time, habit.preferred_end_time)
	_set_selected_week_days(habit.get_selected_week_days())
	_selected_color = habit.color
	_update_color_highlight()
	show_dialog()


func _setup_weekday_checks() -> void:
	var form := $FormContent as VBoxContainer
	var box := VBoxContainer.new()
	box.name = "WeekdayBox"
	box.add_theme_constant_override("separation", 8)

	var label := Label.new()
	label.text = "执行日期"
	label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8, 1.0))
	label.add_theme_font_size_override("font_size", 13)
	box.add_child(label)

	var row := HBoxContainer.new()
	row.name = "WeekdayRow"
	row.add_theme_constant_override("separation", 8)
	box.add_child(row)

	for i in range(WEEKDAY_LABELS.size()):
		var cb := CheckBox.new()
		cb.text = WEEKDAY_LABELS[i]
		cb.custom_minimum_size = Vector2(64, 28)
		row.add_child(cb)
		_weekday_checks.append(cb)

	form.add_child(box)
	form.move_child(box, 4)


func _setup_time_range_selector() -> void:
	var row := HBoxContainer.new()
	row.name = "TimeRangeRow"
	row.add_theme_constant_override("separation", 8)

	var start_label := Label.new()
	start_label.text = "起始"
	start_label.custom_minimum_size = Vector2(40, 0)
	start_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8, 1.0))
	start_label.add_theme_font_size_override("font_size", 13)
	row.add_child(start_label)

	var start_time_row := HBoxContainer.new()
	start_time_row.add_theme_constant_override("separation", 4)
	start_time_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(start_time_row)

	_start_hour_spin = _build_time_spin(0, 23, 1)
	_start_hour_spin.custom_minimum_size = Vector2(90, 32)
	start_time_row.add_child(_start_hour_spin)

	_start_minute_selector = MaterialDropdown.new()
	_start_minute_selector.placeholder = "分钟"
	_start_minute_selector.custom_minimum_size = Vector2(90, 32)
	_start_minute_selector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	start_time_row.add_child(_start_minute_selector)

	var end_label := Label.new()
	end_label.text = "结束"
	end_label.custom_minimum_size = Vector2(40, 0)
	end_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8, 1.0))
	end_label.add_theme_font_size_override("font_size", 13)
	row.add_child(end_label)

	_end_time_selector = MaterialDropdown.new()
	_end_time_selector.placeholder = "结束时间"
	_end_time_selector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_end_time_selector.custom_minimum_size = Vector2(140, 32)
	row.add_child(_end_time_selector)

	var form := $FormContent as VBoxContainer
	form.add_child(row)
	form.move_child(row, 2)

	_ensure_dropdown_menu_ready(_start_minute_selector)
	_ensure_dropdown_menu_ready(_end_time_selector)
	_start_minute_selector.add_option("00", "00")
	_start_minute_selector.add_option("30", "30")
	_start_hour_spin.value_changed.connect(_on_start_hour_changed)
	_start_minute_selector.selection_changed.connect(_on_start_minute_changed)

	# 保持 SpinBox 原生数值编辑行为，确保上下箭头步进可用


func _build_time_spin(min_value: int, max_value: int, step_value: int) -> SpinBox:
	var spin := SpinBox.new()
	spin.min_value = float(min_value)
	spin.max_value = float(max_value)
	spin.step = float(step_value)
	spin.rounded = true
	spin.editable = true
	spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spin.custom_minimum_size = Vector2(78, 32)
	return spin


func _ensure_dropdown_menu_ready(dropdown: MaterialDropdown) -> void:
	if dropdown == null:
		return
	if dropdown.menu == null:
		dropdown.create_menu()
	if dropdown.menu and dropdown.menu.get_parent() == null:
		dropdown.add_child(dropdown.menu)
		dropdown.menu.set_as_top_level(true)


func _rebuild_end_time_options(start_minutes: int, preferred_end_minutes: int = -1) -> void:
	if _end_time_selector == null:
		return

	_end_time_selector.clear_options()
	var min_end := start_minutes + 30
	var max_end := mini(start_minutes + MAX_HABIT_DURATION_MINUTES, 23 * 60 + 30)
	for t in range(min_end, max_end + 1, 30):
		var end_text := _minutes_to_text(t)
		_end_time_selector.add_option(end_text, end_text)

	if _end_time_selector.get_option_count() == 0:
		return

	var selected_end := preferred_end_minutes
	if selected_end < min_end:
		selected_end = min_end
	if selected_end > max_end:
		selected_end = max_end
	_end_time_selector.set_selected_by_value(_minutes_to_text(selected_end))


func _get_selected_start_minutes() -> int:
	if _start_hour_spin == null or _start_minute_selector == null:
		return _time_to_minutes("08:00")
	var minute_value := str(_start_minute_selector.get_selected_value())
	var minute := 0
	if minute_value == "30":
		minute = 30
	return int(_start_hour_spin.value) * 60 + minute


func _get_selected_end_minutes() -> int:
	if _end_time_selector == null:
		return _time_to_minutes("09:00")
	return _time_to_minutes(str(_end_time_selector.get_selected_value()))


func _set_time_selection(start_time: String, end_time: String) -> void:
	if _start_hour_spin == null or _start_minute_selector == null or _end_time_selector == null:
		return
	var start_minutes := _time_to_minutes(start_time)
	var end_minutes := _time_to_minutes(end_time)
	if start_minutes < 0:
		start_minutes = _time_to_minutes("08:00")
	if start_minutes > 23 * 60:
		start_minutes = 23 * 60
	if end_minutes <= start_minutes:
		end_minutes = start_minutes + 30
	if end_minutes - start_minutes > MAX_HABIT_DURATION_MINUTES:
		end_minutes = start_minutes + MAX_HABIT_DURATION_MINUTES

	start_minutes = int(round(start_minutes / 30.0) * 30)
	_start_hour_spin.value = float(int(start_minutes / 60))
	var minute_text := "30" if int(start_minutes % 60) >= 30 else "00"
	_start_minute_selector.set_selected_by_value(minute_text)
	_rebuild_end_time_options(start_minutes, end_minutes)


func _on_start_hour_changed(_value: float) -> void:
	var start_minutes := _get_selected_start_minutes()
	var current_end := _get_selected_end_minutes()
	_rebuild_end_time_options(start_minutes, current_end)


func _on_start_minute_changed(_index: int, _value: Variant) -> void:
	var start_minutes := _get_selected_start_minutes()
	var current_end := _get_selected_end_minutes()
	_rebuild_end_time_options(start_minutes, current_end)


func _time_to_minutes(time_text: String) -> int:
	var parts := time_text.split(":")
	if parts.size() < 2:
		return -1
	return int(parts[0]) * 60 + int(parts[1])


func _minutes_to_text(minutes: int) -> String:
	var normalized := clampi(minutes, 0, 23 * 60 + 30)
	return "%02d:%02d" % [normalized / 60, normalized % 60]


func _on_color_selected(index: int) -> void:
	_selected_color = PRESET_COLORS[index]
	_update_color_highlight()


func _update_color_highlight() -> void:
	for i in range(_color_buttons.size()):
		if PRESET_COLORS[i] == _selected_color:
			_color_buttons[i].modulate = Color(1, 1, 1, 1)
		else:
			_color_buttons[i].modulate = Color(1, 1, 1, 0.4)


func _set_selected_week_days(days: Array) -> void:
	var day_map := {}
	for d in days:
		day_map[int(d)] = true
	for i in range(_weekday_checks.size()):
		_weekday_checks[i].button_pressed = day_map.has(i)


func _collect_selected_week_days() -> Array[int]:
	var result: Array[int] = []
	for i in range(_weekday_checks.size()):
		if _weekday_checks[i].button_pressed:
			result.append(i)
	if result.is_empty():
		result.append(0)
	return result


func _on_confirm() -> void:
	var habit_name = _name_field.get_text().strip_edges()
	if habit_name.is_empty():
		return
	var start_minutes := _get_selected_start_minutes()
	var end_minutes := _get_selected_end_minutes()
	if end_minutes <= start_minutes:
		end_minutes = mini(start_minutes + 30, 23 * 60 + 30)
	if end_minutes - start_minutes > MAX_HABIT_DURATION_MINUTES:
		end_minutes = mini(start_minutes + MAX_HABIT_DURATION_MINUTES, 23 * 60 + 30)
	var duration := maxi(end_minutes - start_minutes, 30)

	var data = {
		"id": _editing_habit_id,
		"name": habit_name,
		"estimated_minutes": duration,
		"preferred_start_time": _minutes_to_text(start_minutes),
		"preferred_end_time": _minutes_to_text(end_minutes),
		"selected_week_days": _collect_selected_week_days(),
		"color": _selected_color,
	}
	habit_confirmed.emit(data)
	hide_dialog()
