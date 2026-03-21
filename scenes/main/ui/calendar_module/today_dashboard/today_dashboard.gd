extends VBoxContainer

signal date_context_changed(date_key: String)
signal jump_to_rhythm_requested(week_key: String)
signal jump_to_review_requested(period_type: String, period_key: String)
signal ai_help_requested(date_key: String)

const CalendarScene = preload("res://scenes/main/ui/components/calendar/calendar.tscn")

var _selected_date_key: String = ""

var _headline_label: Label
var _date_label: Label
var _status_label: Label
var _progress_label: Label
var _focus_label: Label
var _progress_bar: MaterialProgressIndicator
var _cards_container: VBoxContainer
var _timeline_container: VBoxContainer
var _calendar: Node
var _host_scroll: ScrollContainer
var _host_uses_smooth_scroll: bool = false
var _touch_tracking: bool = false
var _touch_dragging: bool = false
var _touch_id: int = -1
var _touch_drag_delta: Vector2 = Vector2.ZERO
var _mouse_tracking: bool = false
var _mouse_dragging: bool = false
var _mouse_drag_delta: Vector2 = Vector2.ZERO

const TOUCH_SCROLL_THRESHOLD: float = 10.0


func _ready() -> void:
	add_theme_constant_override("separation", 6)
	mouse_filter = Control.MOUSE_FILTER_PASS
	_build_ui()
	_selected_date_key = DateUtil.get_today_key()
	_host_scroll = _find_host_scroll_container()
	_host_uses_smooth_scroll = _detect_smooth_scroll_host()
	_connect_signals()
	_refresh()


func set_selected_date_key(date_key: String) -> void:
	if date_key.is_empty():
		return
	_selected_date_key = date_key
	_refresh()


func get_selected_date_key() -> String:
	return _selected_date_key


func _build_ui() -> void:
	var header_panel := _create_panel()
	add_child(header_panel)

	var header_box := VBoxContainer.new()
	header_box.add_theme_constant_override("separation", 3)
	header_panel.add_child(header_box)

	_headline_label = Label.new()
	_headline_label.text = "今日陪伴"
	_headline_label.add_theme_color_override("font_color", Color(1, 1, 1))
	_headline_label.add_theme_font_size_override("font_size", 18)
	header_box.add_child(_headline_label)

	_date_label = Label.new()
	_date_label.add_theme_color_override("font_color", Color(0.84, 0.84, 0.84))
	_date_label.add_theme_font_size_override("font_size", 12)
	header_box.add_child(_date_label)

	_status_label = Label.new()
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	_status_label.add_theme_font_size_override("font_size", 13)
	header_box.add_child(_status_label)

	var progress_panel := _create_panel()
	add_child(progress_panel)

	var progress_box := VBoxContainer.new()
	progress_box.add_theme_constant_override("separation", 6)
	progress_panel.add_child(progress_box)

	var progress_top := HBoxContainer.new()
	progress_top.add_theme_constant_override("separation", 6)
	progress_box.add_child(progress_top)

	_progress_label = Label.new()
	_progress_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_progress_label.add_theme_color_override("font_color", Color(1, 1, 1))
	_progress_label.add_theme_font_size_override("font_size", 13)
	progress_top.add_child(_progress_label)

	_focus_label = Label.new()
	_focus_label.add_theme_color_override("font_color", Color(0.75, 0.84, 1.0))
	_focus_label.add_theme_font_size_override("font_size", 11)
	progress_top.add_child(_focus_label)

	_progress_bar = MaterialProgressIndicator.new()
	_progress_bar.indicator_type = MaterialProgressIndicator.IndicatorType.LINEAR
	_progress_bar.linear_width = 236
	_progress_bar.track_thickness = 6
	progress_box.add_child(_progress_bar)

	var card_panel := _create_panel()
	add_child(card_panel)

	var card_box := VBoxContainer.new()
	card_box.add_theme_constant_override("separation", 6)
	card_panel.add_child(card_box)

	var card_title := Label.new()
	card_title.text = "现在开始"
	card_title.add_theme_color_override("font_color", Color(1, 1, 1))
	card_title.add_theme_font_size_override("font_size", 15)
	card_box.add_child(card_title)

	_cards_container = VBoxContainer.new()
	_cards_container.add_theme_constant_override("separation", 6)
	card_box.add_child(_cards_container)

	var timeline_panel := _create_panel()
	add_child(timeline_panel)

	var timeline_box := VBoxContainer.new()
	timeline_box.add_theme_constant_override("separation", 6)
	timeline_panel.add_child(timeline_box)

	var timeline_title_row := HBoxContainer.new()
	timeline_title_row.add_theme_constant_override("separation", 6)
	timeline_box.add_child(timeline_title_row)

	var timeline_title := Label.new()
	timeline_title.text = "今日时间线"
	timeline_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	timeline_title.add_theme_color_override("font_color", Color(1, 1, 1))
	timeline_title.add_theme_font_size_override("font_size", 15)
	timeline_title_row.add_child(timeline_title)

	var rhythm_btn := MaterialButton.new()
	rhythm_btn.text = "查看本周节奏"
	rhythm_btn.mouse_filter = Control.MOUSE_FILTER_PASS
	rhythm_btn.set_text_style(Color(0.6, 0.78, 1.0))
	rhythm_btn.pressed.connect(func():
		jump_to_rhythm_requested.emit(DateUtil.date_to_week_key(_selected_date_key))
	)
	timeline_title_row.add_child(rhythm_btn)

	_timeline_container = VBoxContainer.new()
	_timeline_container.add_theme_constant_override("separation", 5)
	timeline_box.add_child(_timeline_container)

	var calendar_panel := _create_panel()
	add_child(calendar_panel)

	var calendar_box := VBoxContainer.new()
	calendar_box.add_theme_constant_override("separation", 6)
	calendar_panel.add_child(calendar_box)

	var calendar_header := HBoxContainer.new()
	calendar_header.add_theme_constant_override("separation", 6)
	calendar_box.add_child(calendar_header)

	var calendar_title := Label.new()
	calendar_title.text = "日期导航"
	calendar_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	calendar_title.add_theme_color_override("font_color", Color(1, 1, 1))
	calendar_title.add_theme_font_size_override("font_size", 15)
	calendar_header.add_child(calendar_title)

	var review_btn := MaterialButton.new()
	review_btn.text = "查看回顾"
	review_btn.mouse_filter = Control.MOUSE_FILTER_PASS
	review_btn.set_text_style(Color(0.6, 0.78, 1.0))
	review_btn.pressed.connect(func():
		jump_to_review_requested.emit("week", DateUtil.date_to_week_key(_selected_date_key))
	)
	calendar_header.add_child(review_btn)

	_calendar = CalendarScene.instantiate()
	_calendar.mouse_filter = Control.MOUSE_FILTER_PASS
	calendar_box.add_child(_calendar)
	_calendar.show_action_buttons(false)
	_calendar.set_swipe_navigation_enabled(false)


func _input(event: InputEvent) -> void:
	if not visible or _host_scroll == null or _host_uses_smooth_scroll:
		return

	if event is InputEventScreenTouch:
		_handle_screen_touch(event as InputEventScreenTouch)
	elif event is InputEventScreenDrag:
		_handle_screen_drag(event as InputEventScreenDrag)
	elif event is InputEventMouseButton:
		_handle_mouse_button(event as InputEventMouseButton)
	elif event is InputEventMouseMotion:
		_handle_mouse_motion(event as InputEventMouseMotion)


func _connect_signals() -> void:
	_calendar.date_selected.connect(_on_calendar_date_selected)
	HabitState.execution_updated.connect(func(_record): _refresh())
	HabitState.schedule_entry_added.connect(func(_entry): _refresh())
	HabitState.schedule_entry_removed.connect(func(_entry_id): _refresh())
	HabitState.schedule_updated.connect(func(_week_key): _refresh())
	HabitState.schedule_cleared.connect(func(_week_key): _refresh())
	HabitState.habit_updated.connect(func(_habit): _refresh())
	HabitState.habit_added.connect(func(_habit): _refresh())
	HabitState.habit_removed.connect(func(_id): _refresh())
	if StatsState:
		StatsState.record_added.connect(func(_record): _refresh())
		StatsState.record_removed.connect(func(_id): _refresh())


func _refresh() -> void:
	var data := HabitState.get_day_dashboard_data(_selected_date_key)
	_date_label.text = "%s  ·  %s" % [str(data.get("date_title", "")), _weekday_text(int(data.get("day_of_week", 0)))]
	_status_label.text = str(data.get("status_text", ""))
	_progress_label.text = "今日进展 %d/%d" % [int(data.get("completed_count", 0)), int(data.get("total_count", 0))]
	_focus_label.text = "专注 %d 分钟" % int(data.get("focus_minutes", 0))
	_progress_bar.set_progress_value(float(data.get("progress", 0.0)))

	_refresh_cards(data.get("top_cards", []))
	_refresh_timeline(data.get("timeline", []))

	var dt := _date_key_to_dict(_selected_date_key)
	_calendar.set_date(int(dt.get("year", 0)), int(dt.get("month", 0)), int(dt.get("day", 0)))
	_calendar.set_date_marks(data.get("calendar_marks", {}))


func _refresh_cards(cards: Array) -> void:
	for child in _cards_container.get_children():
		child.queue_free()

	if cards.is_empty():
		var empty := _create_hint_label("今天比较轻松，可以添加一个小习惯或看看本周节奏。")
		_cards_container.add_child(empty)
		return

	for item in cards:
		_cards_container.add_child(_create_action_card(item))


func _refresh_timeline(items: Array) -> void:
	for child in _timeline_container.get_children():
		child.queue_free()

	if items.is_empty():
		_timeline_container.add_child(_create_hint_label("今天还没有明确安排，留一点空白也很好。"))
		return

	for item in items:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)

		var dot := ColorRect.new()
		dot.custom_minimum_size = Vector2(4, 22)
		dot.color = Color.from_string(str(item.get("color", "#4CAF50")), Color(0.35, 0.65, 0.95))
		row.add_child(dot)

		var text_box := VBoxContainer.new()
		text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text_box.add_theme_constant_override("separation", 2)
		row.add_child(text_box)

		var title := Label.new()
		title.text = "%s · %s" % [str(item.get("title", "")), str(item.get("time_text", ""))]
		title.add_theme_color_override("font_color", Color(0.98, 0.98, 0.98))
		title.add_theme_font_size_override("font_size", 12)
		text_box.add_child(title)

		var sub := Label.new()
		sub.text = str(item.get("status_text", ""))
		sub.add_theme_color_override("font_color", Color(0.72, 0.72, 0.72))
		sub.add_theme_font_size_override("font_size", 10)
		text_box.add_child(sub)

		if bool(item.get("can_start", false)):
			var done_btn := MaterialButton.new()
			done_btn.text = "完成"
			done_btn.mouse_filter = Control.MOUSE_FILTER_PASS
			done_btn.set_text_style(Color(0.55, 0.85, 0.62))
			done_btn.pressed.connect(func():
				_mark_entry_status(int(item.get("entry_id", -1)), HabitData.ExecutionRecord.Status.COMPLETED)
			)
			row.add_child(done_btn)

		_timeline_container.add_child(row)


func _create_action_card(item: Dictionary) -> Control:
	var panel := _create_panel()
	panel.background_color = Color(1, 1, 1, 0.06)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	panel.add_child(box)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 6)
	box.add_child(top)

	var title_box := VBoxContainer.new()
	title_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_box.add_theme_constant_override("separation", 2)
	top.add_child(title_box)

	var title := Label.new()
	title.text = str(item.get("title", ""))
	title.add_theme_color_override("font_color", Color(1, 1, 1))
	title.add_theme_font_size_override("font_size", 13)
	title_box.add_child(title)

	var meta := Label.new()
	meta.text = "%s · %d 分钟" % [str(item.get("time_text", "")), int(item.get("minutes", 0))]
	meta.add_theme_color_override("font_color", Color(0.72, 0.72, 0.72))
	meta.add_theme_font_size_override("font_size", 10)
	title_box.add_child(meta)

	var tag := Label.new()
	tag.text = str(item.get("status_text", ""))
	tag.add_theme_color_override("font_color", Color(0.65, 0.82, 1.0))
	tag.add_theme_font_size_override("font_size", 10)
	top.add_child(tag)

	var actions := VBoxContainer.new()
	actions.add_theme_constant_override("separation", 4)
	box.add_child(actions)

	var primary_row := HBoxContainer.new()
	primary_row.add_theme_constant_override("separation", 6)
	actions.add_child(primary_row)

	var start_btn := MaterialButton.new()
	start_btn.text = "开始专注"
	start_btn.mouse_filter = Control.MOUSE_FILTER_PASS
	start_btn.set_filled_style(Color(0.35, 0.65, 0.95))
	start_btn.pressed.connect(func(): _start_focus(item))
	primary_row.add_child(start_btn)

	var music_btn := MaterialButton.new()
	music_btn.text = "播放音乐"
	music_btn.mouse_filter = Control.MOUSE_FILTER_PASS
	music_btn.set_outlined_style(Color(0.55, 0.72, 1.0), 1)
	music_btn.pressed.connect(_ensure_music_playing)
	primary_row.add_child(music_btn)

	if int(item.get("entry_id", -1)) != -1:
		var secondary_row := HBoxContainer.new()
		secondary_row.add_theme_constant_override("separation", 6)
		actions.add_child(secondary_row)

		var done_btn := MaterialButton.new()
		done_btn.text = "标记完成"
		done_btn.mouse_filter = Control.MOUSE_FILTER_PASS
		done_btn.set_text_style(Color(0.55, 0.85, 0.62))
		done_btn.pressed.connect(func():
			_mark_entry_status(int(item.get("entry_id", -1)), HabitData.ExecutionRecord.Status.COMPLETED)
		)
		secondary_row.add_child(done_btn)

		var defer_btn := MaterialButton.new()
		defer_btn.text = "稍后"
		defer_btn.mouse_filter = Control.MOUSE_FILTER_PASS
		defer_btn.set_text_style(Color(1.0, 0.78, 0.48))
		defer_btn.pressed.connect(func():
			_mark_entry_status(int(item.get("entry_id", -1)), HabitData.ExecutionRecord.Status.DEFERRED)
		)
		secondary_row.add_child(defer_btn)
	else:
		var ask_btn := MaterialButton.new()
		ask_btn.text = "AI 帮我安排"
		ask_btn.mouse_filter = Control.MOUSE_FILTER_PASS
		ask_btn.set_text_style(Color(0.84, 0.76, 1.0))
		ask_btn.pressed.connect(func():
			ai_help_requested.emit(_selected_date_key)
		)
		actions.add_child(ask_btn)

	return panel


func _create_panel() -> InnerPanel:
	var panel := InnerPanel.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.content_padding = 10.0
	panel.background_color = Color(1, 1, 1, 0.08)
	panel.border_color = Color(1, 1, 1, 0.12)
	return panel


func _create_hint_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_color_override("font_color", Color(0.74, 0.74, 0.74))
	label.add_theme_font_size_override("font_size", 12)
	return label


func _on_calendar_date_selected(year: int, month: int, day: int) -> void:
	var date_key := "%04d-%02d-%02d" % [year, month, day]
	_selected_date_key = date_key
	_refresh()
	date_context_changed.emit(date_key)


func _start_focus(item: Dictionary) -> void:
	var minutes: int = max(10, int(item.get("minutes", 25)))
	if PomodoroState:
		PomodoroState.agent_start_pomodoro(minutes, 5, 1)


func _ensure_music_playing() -> void:
	if not MusicState:
		return
	if not MusicState.current_track.is_empty():
		MusicState.set_playing(true)
		return
	if not MusicState.current_playlist.is_empty() and MusicState.play_next():
		MusicState.set_playing(true)
		return
	if ChatState:
		ChatState.agent_set_input_text("帮我播放一点适合现在状态的音乐")


func _mark_entry_status(entry_id: int, status: int) -> void:
	if entry_id == -1:
		return
	HabitState.set_execution_status(entry_id, _selected_date_key, status)


func _weekday_text(day: int) -> String:
	var names = ["周一", "周二", "周三", "周四", "周五", "周六", "周日"]
	if day < 0 or day >= names.size():
		return ""
	return names[day]


func _date_key_to_dict(date_key: String) -> Dictionary:
	var parts := date_key.split("-")
	if parts.size() != 3:
		return {"year": 0, "month": 0, "day": 0}
	return {
		"year": int(parts[0]),
		"month": int(parts[1]),
		"day": int(parts[2]),
	}


func _find_host_scroll_container() -> ScrollContainer:
	var node: Node = get_parent()
	while node != null:
		if node is ScrollContainer:
			return node as ScrollContainer
		node = node.get_parent()
	return null


func _detect_smooth_scroll_host() -> bool:
	if _host_scroll == null:
		return false

	var host_script: Script = _host_scroll.get_script()
	if host_script == null:
		return false
	return str(host_script.resource_path).ends_with("smooth_scroll_container.gd")


func _handle_screen_touch(event: InputEventScreenTouch) -> void:
	if event.pressed:
		if not get_global_rect().has_point(event.position):
			return
		_touch_tracking = true
		_touch_dragging = false
		_touch_id = event.index
		_touch_drag_delta = Vector2.ZERO
		return

	if _touch_tracking and event.index == _touch_id:
		_touch_tracking = false
		_touch_dragging = false
		_touch_id = -1


func _handle_screen_drag(event: InputEventScreenDrag) -> void:
	if not _touch_tracking or event.index != _touch_id:
		return

	_touch_drag_delta += event.relative
	if not _touch_dragging and abs(_touch_drag_delta.y) >= TOUCH_SCROLL_THRESHOLD:
		_touch_dragging = true

	if _touch_dragging:
		_scroll_host_by(-event.relative.y)
		get_viewport().set_input_as_handled()


func _handle_mouse_button(event: InputEventMouseButton) -> void:
	if event.button_index != MOUSE_BUTTON_LEFT:
		return

	if event.pressed:
		if not get_global_rect().has_point(event.position):
			return
		_mouse_tracking = true
		_mouse_dragging = false
		_mouse_drag_delta = Vector2.ZERO
		return

	_mouse_tracking = false
	_mouse_dragging = false


func _handle_mouse_motion(event: InputEventMouseMotion) -> void:
	if not _mouse_tracking:
		return

	_mouse_drag_delta += event.relative
	if not _mouse_dragging and abs(_mouse_drag_delta.y) >= TOUCH_SCROLL_THRESHOLD:
		_mouse_dragging = true

	if _mouse_dragging:
		_scroll_host_by(-event.relative.y)
		get_viewport().set_input_as_handled()


func _scroll_host_by(delta_y: float) -> void:
	if _host_scroll == null:
		return

	var scrollbar: VScrollBar = _host_scroll.get_v_scroll_bar()
	var max_scroll: float = max(0.0, scrollbar.max_value)
	var next_value: float = clamp(float(_host_scroll.scroll_vertical) + delta_y, 0.0, max_scroll)
	_host_scroll.scroll_vertical = int(round(next_value))
