extends MarginContainer

## 日历模块 - 管理月历、课表、习惯库和统计的 Tab 切换

@onready var _tab_bar: MaterialSegmentedButton = $FrostedPanel/MarginContainer/VBoxContainer/TabBar
@onready var _calendar: Node = $FrostedPanel/MarginContainer/VBoxContainer/Calendar
@onready var _week_view: Node = $FrostedPanel/MarginContainer/VBoxContainer/WeekScheduleView
@onready var _habit_panel: Node = $FrostedPanel/MarginContainer/VBoxContainer/HabitLibraryPanel
@onready var _summary_panel: Node = $FrostedPanel/MarginContainer/VBoxContainer/SummaryPanel

var _views: Array = []


func _ready() -> void:
	_views = [_calendar, _week_view, _habit_panel, _summary_panel]

	_tab_bar.segment_selected.connect(_on_tab_changed)
	_calendar.show_action_buttons(false)
	_calendar.date_selected.connect(_on_date_selected)

	_week_view.ai_schedule_requested.connect(_on_ai_schedule_requested)
	_summary_panel.generate_reflection_requested.connect(_on_generate_reflection)


func _on_tab_changed(index: int, _text: String) -> void:
	for v in _views:
		v.visible = false
	if index < _views.size():
		_views[index].visible = true


func _on_date_selected(year: int, month: int, day: int) -> void:
	print("[CalendarModule] Date selected: %d-%02d-%02d" % [year, month, day])


func _on_ai_schedule_requested(week_key: String) -> void:
	if ChatState:
		ChatState.agent_set_input_text("请帮我安排 %s 的习惯课表" % week_key)
	print("[CalendarModule] AI schedule requested for: %s" % week_key)


func _on_generate_reflection(week_key: String) -> void:
	if ChatState:
		ChatState.agent_set_input_text("请根据我 %s 的习惯执行情况，生成一份反思总结" % week_key)
	print("[CalendarModule] Reflection requested for: %s" % week_key)
