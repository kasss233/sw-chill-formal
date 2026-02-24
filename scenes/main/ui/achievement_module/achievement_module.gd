extends Control

signal tab_changed(tab_name: String)

@export var item_scene: PackedScene

@onready var module_title_label: Label = $CanvasLayer/PanelContainer/VBoxContainer/HeaderRow/ModuleTitleLabel
@onready var daily_task_button: Button = $CanvasLayer/PanelContainer/VBoxContainer/HeaderRow/TabButtons/DailyTaskButton
@onready var achievement_button: Button = $CanvasLayer/PanelContainer/VBoxContainer/HeaderRow/TabButtons/AchievementButton
@onready var add_button: Button = $CanvasLayer/PanelContainer/VBoxContainer/HeaderRow/AddButton
@onready var daily_task_list: VBoxContainer = $CanvasLayer/PanelContainer/VBoxContainer/ScrollContainer/ContentContainer/DailyTaskList
@onready var achievement_list: VBoxContainer = $CanvasLayer/PanelContainer/VBoxContainer/ScrollContainer/ContentContainer/AchievementList
@onready var empty_label: Label = $CanvasLayer/PanelContainer/VBoxContainer/ScrollContainer/ContentContainer/EmptyLabel
@onready var canvas_layer=$CanvasLayer
@onready var panel=$CanvasLayer/PanelContainer
enum Tab {
	DAILY_TASK,
	ACHIEVEMENT
}

var _current_tab: int = Tab.DAILY_TASK
var _item_nodes: Dictionary = {
	"daily_task": {},
	"achievement": {}
}

func _ready() -> void:
	AchievementState.daily_task_added.connect(_on_state_daily_task_added)
	AchievementState.daily_task_removed.connect(_on_state_daily_task_removed)
	AchievementState.daily_task_updated.connect(_on_state_daily_task_updated)
	AchievementState.achievement_added.connect(_on_state_achievement_added)
	AchievementState.achievement_removed.connect(_on_state_achievement_removed)
	AchievementState.achievement_updated.connect(_on_state_achievement_updated)
	AchievementState.data_loaded.connect(_on_state_data_loaded)
	panel.visible=false
	_render_all()
	_switch_tab(Tab.DAILY_TASK)
	_refresh_module_title()
	_refresh_empty_state()

func add_daily_task(title: String, description: String = "", target: int = 1, current: int = 0) -> int:
	var data := AchievementState.add_daily_task(title, description, target, current)
	return int(data.get("id", -1))

func add_achievement(title: String, description: String = "", target: int = 1, current: int = 0) -> int:
	var data := AchievementState.add_achievement(title, description, target, current)
	return int(data.get("id", -1))

func remove_daily_task(item_id: int) -> void:
	AchievementState.remove_daily_task(item_id)

func remove_achievement(item_id: int) -> void:
	AchievementState.remove_achievement(item_id)

func clear_daily_tasks() -> void:
	AchievementState.clear_daily_tasks()

func clear_achievements() -> void:
	AchievementState.clear_achievements()

func set_daily_task_progress(item_id: int, current: int, target: int = -1) -> void:
	AchievementState.set_daily_task_progress(item_id, current, target)

func set_achievement_progress(item_id: int, current: int, target: int = -1) -> void:
	AchievementState.set_achievement_progress(item_id, current, target)

func mark_daily_task_completed(item_id: int, completed: bool = true) -> void:
	AchievementState.set_daily_task_completed(item_id, completed)

func claim_achievement(item_id: int) -> bool:
	return AchievementState.claim_achievement(item_id)

func get_daily_tasks() -> Array:
	return AchievementState.get_daily_tasks()

func get_achievements() -> Array:
	return AchievementState.get_achievements()

func show_daily_task_tab() -> void:
	_switch_tab(Tab.DAILY_TASK)

func show_achievement_tab() -> void:
	_switch_tab(Tab.ACHIEVEMENT)

func _on_daily_task_button_pressed() -> void:
	_switch_tab(Tab.DAILY_TASK)

func _on_achievement_button_pressed() -> void:
	_switch_tab(Tab.ACHIEVEMENT)

func _on_add_button_pressed() -> void:
	if _current_tab == Tab.DAILY_TASK:
		AchievementState.add_daily_task("新每日任务", "", 1, 0)
	else:
		AchievementState.add_achievement("新成就", "", 1, 0)

func _on_item_completed_changed(item_id: int, completed: bool, category: String) -> void:
	if category != "daily_task":
		return
	mark_daily_task_completed(item_id, completed)

func _on_item_delete_requested(item_id: int, category: String) -> void:
	if category == "achievement":
		AchievementState.remove_achievement(item_id)
	else:
		AchievementState.remove_daily_task(item_id)

func _on_item_claim_requested(item_id: int) -> void:
	claim_achievement(item_id)

func _switch_tab(tab: int) -> void:
	_current_tab = tab
	daily_task_list.visible = tab == Tab.DAILY_TASK
	achievement_list.visible = tab == Tab.ACHIEVEMENT
	daily_task_button.disabled = tab == Tab.DAILY_TASK
	achievement_button.disabled = tab == Tab.ACHIEVEMENT
	_refresh_empty_state()
	tab_changed.emit("daily_task" if tab == Tab.DAILY_TASK else "achievement")

func _refresh_module_title() -> void:
	module_title_label.text = "成就模块  每日任务(%d)  成就(%d)" % [AchievementState.get_daily_task_count(), AchievementState.get_achievement_count()]

func _refresh_empty_state() -> void:
	if _current_tab == Tab.DAILY_TASK:
		empty_label.visible = AchievementState.get_daily_task_count() == 0
		empty_label.text = "暂无每日任务"
	else:
		empty_label.visible = AchievementState.get_achievement_count() == 0
		empty_label.text = "暂无成就"

func _create_item_node(data: Dictionary) -> void:
	if item_scene == null:
		return
	var item = item_scene.instantiate()
	if item == null:
		return
	var category := str(data.get("category", "daily_task"))
	if category == "achievement":
		achievement_list.add_child(item)
	else:
		daily_task_list.add_child(item)
	if item.has_method("set_data"):
		item.set_data(data)
	if item.has_signal("completed_changed"):
		item.completed_changed.connect(_on_item_completed_changed)
	if item.has_signal("delete_requested"):
		item.delete_requested.connect(_on_item_delete_requested)
	if item.has_signal("claim_requested"):
		item.claim_requested.connect(_on_item_claim_requested)
	_item_nodes[category][int(data.get("id", -1))] = item

func _remove_item_node(category: String, item_id: int) -> void:
	var node = _item_nodes.get(category, {}).get(item_id)
	if node and is_instance_valid(node):
		node.queue_free()
	_item_nodes[category].erase(item_id)
	_refresh_module_title()
	_refresh_empty_state()

func _update_item(category: String, item_data: Dictionary) -> void:
	var item_id: int = int(item_data.get("id", -1))
	var node = _item_nodes.get(category, {}).get(item_id)
	if node and is_instance_valid(node) and node.has_method("update_display"):
		node.update_display(item_data)
	elif node == null:
		_create_item_node(item_data)
	_refresh_module_title()
	_refresh_empty_state()

func _render_all() -> void:
	for category in ["daily_task", "achievement"]:
		for node in _item_nodes[category].values():
			if node and is_instance_valid(node):
				node.queue_free()
		_item_nodes[category].clear()

	for data in AchievementState.get_daily_tasks():
		_create_item_node(data)
	for data in AchievementState.get_achievements():
		_create_item_node(data)

	_refresh_module_title()
	_refresh_empty_state()

func _on_state_daily_task_added(data: Dictionary) -> void:
	_create_item_node(data)
	_refresh_module_title()
	_refresh_empty_state()

func _on_state_daily_task_removed(item_id: int) -> void:
	_remove_item_node("daily_task", item_id)

func _on_state_daily_task_updated(data: Dictionary) -> void:
	_update_item("daily_task", data)

func _on_state_achievement_added(data: Dictionary) -> void:
	_create_item_node(data)
	_refresh_module_title()
	_refresh_empty_state()

func _on_state_achievement_removed(item_id: int) -> void:
	_remove_item_node("achievement", item_id)

func _on_state_achievement_updated(data: Dictionary) -> void:
	_update_item("achievement", data)

func _on_state_data_loaded() -> void:
	_render_all()




func _on_button_state_changed(old_state: int, new_state: int) -> void:
	if new_state==0:
		GuiTransitions.hide("achievement")
	else:
		LayerManager.bring_to_front(canvas_layer)
		GuiTransitions.show("achievement")
