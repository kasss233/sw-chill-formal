extends MarginContainer

## 个人中心模块，管理"我的" / "统计" / "习惯"三个 Tab 视图

@onready var _tab_bar: MaterialSegmentedButton = $FrostedPanel/MarginContainer/VBoxContainer/TabBar
@onready var _scroll_container: ScrollContainer = $FrostedPanel/MarginContainer/VBoxContainer/SmoothScrollContainer
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
	# 重置滚动位置到顶部，避免切换 Tab 时出现空白区域
	_scroll_container.scroll_vertical = 0


## Agent API：选择指定 tab
func agent_select_tab(tab_index: int) -> bool:
	if tab_index >= 0 and tab_index < _views.size():
		_tab_bar.selected_index = tab_index
		_on_tab_changed(tab_index, "") # 手动触发视图切换
		return true
	return false
