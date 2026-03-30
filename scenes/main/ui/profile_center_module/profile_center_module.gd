extends MarginContainer

## 个人中心模块，管理"我的" / "统计" / "习惯"三个 Tab 视图

@onready var _tab_bar: MaterialSegmentedButton = $FrostedPanel/MarginContainer/VBoxContainer/TabBar
@onready var _profile_view: Node = %ProfileView
@onready var _stats_view: Node = %StatsView
@onready var _habit_panel: Node = %HabitLibraryPanel
@onready var _habit_schedule_panel: Node = %HabitSchedulePanel

var _views: Array = []


func _ready() -> void:
	_views = [_profile_view, _stats_view, _habit_panel]
	_views = [_profile_view, _stats_view, _habit_panel, _habit_schedule_panel]
	_tab_bar.segment_selected.connect(_on_tab_changed)
	_on_tab_changed(0, "我的")


func _on_tab_changed(index: int, _text: String) -> void:
	for view in _views:
		view.visible = false
	if index < _views.size():
		_views[index].visible = true
