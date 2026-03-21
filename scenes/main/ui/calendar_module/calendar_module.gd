extends MarginContainer

## 日历模块，负责今日 / 节奏 / 回顾 / 习惯四个视图之间的上下文联动

@onready var _tab_bar: MaterialSegmentedButton = $FrostedPanel/MarginContainer/VBoxContainer/TabBar
@onready var _today_dashboard: Node = %TodayDashboard
@onready var _week_view: Node = %WeekScheduleView
@onready var _review_panel: Node = %ReviewPanel
@onready var _habit_panel: Node = %HabitLibraryPanel

var _views: Array = []
var _selected_date_key: String = ""


func _ready() -> void:
	_selected_date_key = DateUtil.get_today_key()
	_views = [_today_dashboard, _week_view, _review_panel, _habit_panel]

	_tab_bar.segment_selected.connect(_on_tab_changed)
	_today_dashboard.date_context_changed.connect(_on_date_context_changed)
	_today_dashboard.jump_to_rhythm_requested.connect(_on_jump_to_rhythm)
	_today_dashboard.jump_to_review_requested.connect(_on_jump_to_review)
	_today_dashboard.ai_help_requested.connect(_on_ai_help_requested)

	_week_view.ai_schedule_requested.connect(_on_ai_schedule_requested)
	_review_panel.date_context_changed.connect(_on_date_context_changed)
	_review_panel.generate_reflection_requested.connect(_on_generate_reflection)

	_sync_views()
	_on_tab_changed(0, "今日")


func _on_tab_changed(index: int, _text: String) -> void:
	for view in _views:
		view.visible = false
	if index < _views.size():
		_views[index].visible = true
	_sync_views()


func _on_date_context_changed(date_key: String) -> void:
	_selected_date_key = date_key
	_sync_views()


func _on_jump_to_rhythm(week_key: String) -> void:
	_tab_bar.set_selected_no_signal(1)
	_on_tab_changed(1, "节奏")
	_week_view.show_for_week(week_key, _selected_date_key)


func _on_jump_to_review(period_type: String, _period_key: String) -> void:
	_tab_bar.set_selected_no_signal(2)
	_on_tab_changed(2, "回顾")
	_review_panel.set_selected_date_key(_selected_date_key)
	_review_panel.set_period_type(period_type)


func _on_ai_help_requested(date_key: String) -> void:
	if ChatState:
		ChatState.agent_set_input_text("请根据我 %s 的安排，给我一个轻量、鼓励式的今日建议，告诉我先做什么更容易开始。" % date_key)


func _on_ai_schedule_requested(week_key: String, style: String) -> void:
	HabitState.agent_generate_week_schedule(week_key, style)


func _on_generate_reflection(period_type: String, period_key: String) -> void:
	HabitState.agent_generate_period_reflection(period_type, period_key)


func _sync_views() -> void:
	_today_dashboard.set_selected_date_key(_selected_date_key)
	_week_view.set_selected_date_key(_selected_date_key)
	_review_panel.set_selected_date_key(_selected_date_key)
