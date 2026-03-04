extends Control

@onready var info_label: RichTextLabel = $MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/InfoLabel
@onready var name_input: LineEdit = $MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/InputSection/NameInput
@onready var category_input: LineEdit = $MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/InputSection/CategoryInput
@onready var required_level_input: LineEdit = $MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/InputSection/RequiredLevelInput
@onready var icon_path_input: LineEdit = $MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/InputSection/IconPathInput
@onready var item_id_input: LineEdit = $MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/InputSection/ItemIdInput

@onready var add_item_btn: Button = $MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/ButtonSection/AddItemBtn
@onready var select_item_btn: Button = $MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/ButtonSection/SelectItemBtn
@onready var remove_item_btn: Button = $MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/ButtonSection/RemoveItemBtn
@onready var clear_all_btn: Button = $MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/ButtonSection/ClearAllBtn
@onready var clear_all_categories_btn: Button = $MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/ButtonSection/ClearAllCategoriesBtn
@onready var get_all_btn: Button = $MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/ButtonSection/GetAllBtn
@onready var get_selected_btn: Button = $MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/ButtonSection/GetSelectedBtn
@onready var add_sample_set_btn: Button = $MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/ButtonSection/AddSampleSetBtn


func _ready() -> void:
	add_item_btn.pressed.connect(_on_add_item_pressed)
	select_item_btn.pressed.connect(_on_select_item_pressed)
	remove_item_btn.pressed.connect(_on_remove_item_pressed)
	clear_all_btn.pressed.connect(_on_clear_all_pressed)
	clear_all_categories_btn.pressed.connect(_on_clear_all_categories_pressed)
	get_all_btn.pressed.connect(_on_get_all_pressed)
	get_selected_btn.pressed.connect(_on_get_selected_pressed)
	add_sample_set_btn.pressed.connect(_on_add_sample_set_pressed)

	RoomDecorState.room_decor_added.connect(_on_state_item_added)
	RoomDecorState.room_decor_removed.connect(_on_state_item_removed)
	RoomDecorState.room_decor_updated.connect(_on_state_item_updated)
	RoomDecorState.room_decor_state_changed.connect(_on_state_changed)
	RoomDecorState.agent_room_decor_added.connect(_on_agent_item_added)
	RoomDecorState.agent_room_decor_selected.connect(_on_agent_item_selected)

	_log_info("RoomDecor 调试面板已就绪")
	_on_get_selected_pressed()


func _on_add_item_pressed() -> void:
	var name := _read_name()
	var category := _read_category()
	var required_level := _read_required_level()
	var icon_path := icon_path_input.text.strip_edges()
	var item := RoomDecorState.add_item(name, category, required_level, icon_path)
	if item == null:
		_log_error("添加失败，名称不能为空")
		return
	item_id_input.text = str(item.id)
	_log_success("添加成功: id=%d, category=%s, level=%d" % [item.id, category, required_level])


func _on_select_item_pressed() -> void:
	var item_id := item_id_input.text.to_int()
	if item_id <= 0:
		_log_error("请选择有效 item_id")
		return
	var ok := RoomDecorState.select_item(item_id)
	if ok:
		_log_success("选择成功: id=%d" % item_id)
		_on_get_selected_pressed()
	else:
		_log_error("选择失败（可能ID不存在或未解锁）")


func _on_remove_item_pressed() -> void:
	var item_id := item_id_input.text.to_int()
	if item_id <= 0:
		_log_error("请选择有效 item_id")
		return
	var ok := RoomDecorState.remove_item(item_id)
	if ok:
		_log_success("删除成功: id=%d" % item_id)
	else:
		_log_error("删除失败（ID不存在）")


func _on_clear_all_pressed() -> void:
	var removed_count := RoomDecorState.clear_all_items()
	_log_success("删除全部装饰完成，移除 %d 条" % removed_count)


func _on_clear_all_categories_pressed() -> void:
	var result := RoomDecorState.clear_all_categories()
	var removed_categories := int(result.get("removed_category_count", 0))
	var removed_items := int(result.get("removed_item_count", 0))
	_log_success("删除全部分类完成，移除分类 %d 个，物品 %d 条" % [removed_categories, removed_items])


func _on_get_all_pressed() -> void:
	var items := RoomDecorState.get_all_items()
	_log_success("全部物品(%d)" % items.size())
	_log_data(JSON.stringify(items))


func _on_get_selected_pressed() -> void:
	var selected_map := RoomDecorState.get_selected_item_ids_by_category()
	_log_info("分类选中映射: %s" % JSON.stringify(selected_map))


func _on_add_sample_set_pressed() -> void:
	var created: Array[int] = []
	var item1 := RoomDecorState.add_item("木地板", "地面", 1, "")
	if item1:
		created.append(item1.id)
	var item2 := RoomDecorState.add_item("地毯", "地面", 2, "")
	if item2:
		created.append(item2.id)
	var item3 := RoomDecorState.add_item("书桌", "桌面", 1, "")
	if item3:
		created.append(item3.id)
	var item4 := RoomDecorState.add_item("夜灯", "灯具", 3, "")
	if item4:
		created.append(item4.id)
	_log_success("已添加示例数据: %s" % str(created))
	_on_get_selected_pressed()


func _on_state_item_added(data: Dictionary) -> void:
	_log_info("[signal] room_decor_added -> id=%d category=%s" % [int(data.get("id", -1)), str(data.get("category", ""))])


func _on_state_item_removed(item_id: int) -> void:
	_log_info("[signal] room_decor_removed -> id=%d" % item_id)


func _on_state_item_updated(data: Dictionary) -> void:
	_log_info("[signal] room_decor_updated -> id=%d selected=%s" % [int(data.get("id", -1)), str(data.get("selected", false))])


func _on_state_changed(data: Dictionary) -> void:
	_log_info("[signal] room_decor_state_changed -> selected=%s" % JSON.stringify(data.get("selected_item_ids_by_category", {})))


func _on_agent_item_added(data: Dictionary) -> void:
	_log_info("[signal] agent_room_decor_added -> id=%d" % int(data.get("id", -1)))


func _on_agent_item_selected(item_id: int) -> void:
	_log_info("[signal] agent_room_decor_selected -> id=%d" % item_id)


func _read_name() -> String:
	var value := name_input.text.strip_edges()
	if value.is_empty():
		value = "装饰_%d" % Time.get_ticks_msec()
	return value


func _read_category() -> String:
	var value := category_input.text.strip_edges()
	if value.is_empty():
		value = "default"
	return value


func _read_required_level() -> int:
	return max(1, required_level_input.text.to_int())


func _log_info(message: String) -> void:
	info_label.append_text("[color=white]%s[/color]\n" % message)
	print("[RoomDecorTest] %s" % message)


func _log_success(message: String) -> void:
	info_label.append_text("[color=green]%s[/color]\n" % message)
	print("[RoomDecorTest] %s" % message)


func _log_error(message: String) -> void:
	info_label.append_text("[color=red]%s[/color]\n" % message)
	print("[RoomDecorTest] ERROR: %s" % message)


func _log_data(message: String) -> void:
	info_label.append_text("[color=cyan]%s[/color]\n" % message)
	print("[RoomDecorTest] %s" % message)
