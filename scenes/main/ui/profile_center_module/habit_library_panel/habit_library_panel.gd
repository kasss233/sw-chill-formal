extends VBoxContainer

## 习惯库面板 - 管理所有习惯

const HabitItemScene = preload("res://scenes/main/ui/profile_center_module/habit_library_panel/habit_item.tscn")

@onready var _list_container: VBoxContainer = $ScrollContainer/ListContainer
@onready var _edit_dialog = $HabitEditDialog
@onready var _empty_label: Label = $EmptyLabel
@onready var _add_btn: MaterialButton = $Header/AddBtn


func _ready() -> void:
	_add_btn.pressed.connect(_on_add_pressed)
	_edit_dialog.habit_confirmed.connect(_on_habit_confirmed)

	# 连接 HabitState 信号
	HabitState.habit_added.connect(_on_habit_added)
	HabitState.habit_removed.connect(_on_habit_removed)
	HabitState.habit_updated.connect(_on_habit_updated)
	HabitState.data_loaded.connect(_refresh_list)
	# 初始加载
	_refresh_list()


func _refresh_list() -> void:
	# 清空列表
	for child in _list_container.get_children():
		child.queue_free()

	var habits = HabitState.get_all_habits()
	_empty_label.visible = habits.is_empty()

	for habit in habits:
		_add_habit_item(habit)


func _add_habit_item(habit: HabitData) -> void:
	var item = HabitItemScene.instantiate()
	_list_container.add_child(item)
	item.update_display(habit)
	item.edit_requested.connect(_on_edit_requested)
	item.active_toggled.connect(_on_active_toggled)
	item.delete_requested.connect(_on_delete_requested)


func _on_habit_added(habit: HabitData) -> void:
	_empty_label.visible = false
	_add_habit_item(habit)


func _on_habit_removed(habit_id: int) -> void:
	for child in _list_container.get_children():
		if child._habit_id == habit_id:
			child.queue_free()
			break
	_empty_label.visible = _list_container.get_child_count() <= 1  # 一个正在 queue_free


func _on_habit_updated(habit: HabitData) -> void:
	for child in _list_container.get_children():
		if child._habit_id == habit.id:
			child.update_display(habit)
			break


func _on_add_pressed() -> void:
	_edit_dialog.show_create()


func _on_edit_requested(habit_id: int) -> void:
	var habit = HabitState.get_habit_by_id(habit_id)
	if habit:
		_edit_dialog.show_edit(habit)


func _on_active_toggled(habit_id: int, active: bool) -> void:
	HabitState.set_habit_active(habit_id, active)


func _on_delete_requested(habit_id: int) -> void:
	HabitState.remove_habit(habit_id)


func _on_habit_confirmed(data: Dictionary) -> void:
	if data["id"] == -1:
		# 新建
		HabitState.add_habit(
			data["name"],
			data["estimated_minutes"],
			data["preferred_period"],
			data["frequency"],
			data["color"],
		)
	else:
		# 编辑
		HabitState.update_habit(data["id"], {
			"name": data["name"],
			"estimated_minutes": data["estimated_minutes"],
			"preferred_period": data["preferred_period"],
			"frequency": data["frequency"],
			"color": data["color"],
		})
