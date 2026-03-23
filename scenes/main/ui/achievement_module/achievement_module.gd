extends Control

signal tab_changed(tab_name: String)

@export var item_scene: PackedScene

@onready var module_title_label: Label = %ModuleTitleLabel
@onready var tab_segmented_button: MaterialSegmentedButton = %TabSegmentedButton
@onready var daily_task_list: VBoxContainer = %DailyTaskList
@onready var achievement_list: VBoxContainer = %AchievementList
@onready var empty_label: Label = %EmptyLabel
@onready var canvas_layer: CanvasLayer = %CanvasLayer
@onready var panel: PanelContainer = %PanelContainer
@onready var button: Button = %Button
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
	AchievementState.daily_task_state_updated.connect(_on_state_daily_task_state_updated)
	AchievementState.daily_task_completed.connect(_on_state_daily_task_completed)
	AchievementState.daily_task_reward_claimed.connect(_on_state_daily_task_reward_claimed)
	AchievementState.achievement_added.connect(_on_state_achievement_added)
	AchievementState.achievement_removed.connect(_on_state_achievement_removed)
	AchievementState.achievement_state_updated.connect(_on_state_achievement_state_updated)
	AchievementState.achievement_completed.connect(_on_state_achievement_completed)
	AchievementState.achievement_reward_claimed.connect(_on_state_achievement_reward_claimed)
	AchievementState.data_loaded.connect(_on_state_data_loaded)
	tab_segmented_button.segment_selected.connect(_on_tab_segment_selected)
	panel.visible = false
	_render_all()
	_switch_tab(Tab.DAILY_TASK)
	_refresh_module_title()
	_refresh_empty_state()


func _exit_tree() -> void:
	if AchievementState.daily_task_added.is_connected(_on_state_daily_task_added):
		AchievementState.daily_task_added.disconnect(_on_state_daily_task_added)
	if AchievementState.daily_task_removed.is_connected(_on_state_daily_task_removed):
		AchievementState.daily_task_removed.disconnect(_on_state_daily_task_removed)
	if AchievementState.daily_task_state_updated.is_connected(_on_state_daily_task_state_updated):
		AchievementState.daily_task_state_updated.disconnect(_on_state_daily_task_state_updated)
	if AchievementState.daily_task_completed.is_connected(_on_state_daily_task_completed):
		AchievementState.daily_task_completed.disconnect(_on_state_daily_task_completed)
	if AchievementState.daily_task_reward_claimed.is_connected(_on_state_daily_task_reward_claimed):
		AchievementState.daily_task_reward_claimed.disconnect(_on_state_daily_task_reward_claimed)
	if AchievementState.achievement_added.is_connected(_on_state_achievement_added):
		AchievementState.achievement_added.disconnect(_on_state_achievement_added)
	if AchievementState.achievement_removed.is_connected(_on_state_achievement_removed):
		AchievementState.achievement_removed.disconnect(_on_state_achievement_removed)
	if AchievementState.achievement_state_updated.is_connected(_on_state_achievement_state_updated):
		AchievementState.achievement_state_updated.disconnect(_on_state_achievement_state_updated)
	if AchievementState.achievement_completed.is_connected(_on_state_achievement_completed):
		AchievementState.achievement_completed.disconnect(_on_state_achievement_completed)
	if AchievementState.achievement_reward_claimed.is_connected(_on_state_achievement_reward_claimed):
		AchievementState.achievement_reward_claimed.disconnect(_on_state_achievement_reward_claimed)
	if AchievementState.data_loaded.is_connected(_on_state_data_loaded):
		AchievementState.data_loaded.disconnect(_on_state_data_loaded)


func show_daily_task_tab() -> void:
	_switch_tab(Tab.DAILY_TASK)

func show_achievement_tab() -> void:
	_switch_tab(Tab.ACHIEVEMENT)

func _on_tab_segment_selected(index: int, _text: String) -> void:
	_switch_tab(index)


func _on_item_completed_changed(item_id: int, completed: bool, category: String) -> void:
	if category != "daily_task":
		return
	AchievementState.set_daily_task_completed(item_id, completed)

func _on_item_delete_requested(item_id: int, category: String) -> void:
	if category == "achievement":
		AchievementState.remove_achievement(item_id)
	else:
		AchievementState.remove_daily_task(item_id)

func _on_item_claim_requested(item_id: int, category: String) -> void:
	if category == "daily_task":
		AchievementState.claim_daily_task(item_id)
	else:
		AchievementState.claim_achievement(item_id)

func _switch_tab(tab: int) -> void:
	_current_tab = tab
	daily_task_list.visible = tab == Tab.DAILY_TASK
	achievement_list.visible = tab == Tab.ACHIEVEMENT
	tab_segmented_button.set_selected_no_signal(tab)
	_refresh_empty_state()
	tab_changed.emit("daily_task" if tab == Tab.DAILY_TASK else "achievement")

func _refresh_module_title() -> void:
	module_title_label.text = "每日任务(%d)  成就(%d)" % [AchievementState.get_daily_task_count(), AchievementState.get_achievement_count()]

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

func _on_state_daily_task_state_updated(data: Dictionary) -> void:
	_update_item("daily_task", data)

func _on_state_daily_task_completed(data: Dictionary) -> void:
	_update_item("daily_task", data)

func _on_state_daily_task_reward_claimed(data: Dictionary) -> void:
	_update_item("daily_task", data)

func _on_state_achievement_added(data: Dictionary) -> void:
	_create_item_node(data)
	_refresh_module_title()
	_refresh_empty_state()

func _on_state_achievement_removed(item_id: int) -> void:
	_remove_item_node("achievement", item_id)

func _on_state_achievement_state_updated(data: Dictionary) -> void:
	_update_item("achievement", data)

func _on_state_achievement_completed(data: Dictionary) -> void:
	_update_item("achievement", data)

func _on_state_achievement_reward_claimed(data: Dictionary) -> void:
	_update_item("achievement", data)

func _on_state_data_loaded() -> void:
	_render_all()

func show_module() -> void:
	if button.current_state == 0:
		LayerManager.bring_to_front(canvas_layer)
		GuiTransitions.show("achievement")
		button.set_state_no_signal(1)

func hide_module() -> void:
	if button.current_state == 1:
		GuiTransitions.hide("achievement")
		button.set_state_no_signal(0)

func _on_button_state_changed(old_state: int, new_state: int) -> void:
	if new_state == 0:
		GuiTransitions.hide("achievement")
	else:
		LayerManager.bring_to_front(canvas_layer)
		GuiTransitions.show("achievement")
