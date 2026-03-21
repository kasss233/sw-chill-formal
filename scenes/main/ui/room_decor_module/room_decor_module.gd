extends Control

signal item_selected(item_id: int, item_data: Dictionary)

@export var item_scene: PackedScene

@onready var module_title_label: Label = $CanvasLayer/FrostedPanel/BoxContainer/VBoxContainer/Header/ModuleTitleLabel
@onready var item_count_label: Label = $CanvasLayer/FrostedPanel/BoxContainer/VBoxContainer/Header/ItemCountLabel
@onready var empty_label: Label = $CanvasLayer/FrostedPanel/BoxContainer/VBoxContainer/Content/EmptyLabel
@onready var category_list: VBoxContainer = $CanvasLayer/FrostedPanel/BoxContainer/VBoxContainer/Content/ScrollContainer/CategoryList
@onready var panel = $CanvasLayer/FrostedPanel
@onready var button = $Button
@onready var canvas_layer = $CanvasLayer
var _item_nodes: Dictionary = {}
var _item_categories: Dictionary = {}
var _category_sections: Dictionary = {}


func _ready() -> void:
	if item_scene == null:
		item_scene = preload("res://scenes/main/ui/room_decor_module/room_decor_item/room_decor_item.tscn")

	if RoomDecorState.has_signal("room_decor_added"):
		RoomDecorState.room_decor_added.connect(_on_state_item_added)
	if RoomDecorState.has_signal("room_decor_removed"):
		RoomDecorState.room_decor_removed.connect(_on_state_item_removed)
	if RoomDecorState.has_signal("room_decor_updated"):
		RoomDecorState.room_decor_updated.connect(_on_state_item_updated)
	if RoomDecorState.has_signal("room_decor_state_changed"):
		RoomDecorState.room_decor_state_changed.connect(_on_state_changed)
	if RoomDecorState.has_signal("data_loaded"):
		RoomDecorState.data_loaded.connect(_on_state_data_loaded)
	panel.visible = false
	_render_all()


func add_decor_item(item_name: String, category: String, required_level: int = 1, icon_path: String = "") -> Dictionary:
	var item := RoomDecorState.add_item(item_name, category, required_level, icon_path)
	if item == null:
		return {}
	for data in RoomDecorState.get_all_items():
		if int(data.get("id", -1)) == item.id:
			return data
	return {}


func select_decor_item(item_id: int) -> bool:
	return RoomDecorState.select_item(item_id)


func _render_all() -> void:
	for section in _category_sections.values():
		if section and is_instance_valid(section):
			section.queue_free()
	_category_sections.clear()

	for node in _item_nodes.values():
		if node and is_instance_valid(node):
			node.queue_free()
	_item_nodes.clear()
	_item_categories.clear()

	var items := RoomDecorState.get_all_items()
	for data in items:
		_create_item_node(data)
	_refresh_header()
	_refresh_empty_state()


func _create_item_node(data: Dictionary) -> void:
	if item_scene == null:
		return

	var category := _normalize_category(str(data.get("category", "default")))
	var section_grid := _get_or_create_category_grid(category)
	if section_grid == null:
		return

	var item = item_scene.instantiate()
	if item == null:
		return

	section_grid.add_child(item)
	if item.has_method("set_data"):
		item.set_data(data)
	if item.has_signal("select_requested"):
		item.select_requested.connect(_on_item_select_requested)
	if item.has_signal("deselect_requested"):
		item.deselect_requested.connect(_on_item_deselect_requested)
	var item_id := int(data.get("id", -1))
	_item_nodes[item_id] = item
	_item_categories[item_id] = category
	_refresh_category_count(category)


func _on_item_select_requested(item_id: int) -> void:
	if not RoomDecorState.select_item(item_id):
		return
	for data in RoomDecorState.get_all_items():
		if int(data.get("id", -1)) == item_id:
			item_selected.emit(item_id, data)
			break


func _on_item_deselect_requested(item_id: int) -> void:
	RoomDecorState.deselect_item(item_id)


func _on_state_item_added(data: Dictionary) -> void:
	_create_item_node(data)
	_refresh_header()
	_refresh_empty_state()


func _on_state_item_removed(item_id: int) -> void:
	var category := _normalize_category(str(_item_categories.get(item_id, "default")))
	var node = _item_nodes.get(item_id)
	if node and is_instance_valid(node):
		if node.get_parent():
			node.get_parent().remove_child(node)
		node.queue_free()
	_item_nodes.erase(item_id)
	_item_categories.erase(item_id)
	_refresh_category_count(category)
	_try_remove_empty_category_section(category)
	_refresh_header()
	_refresh_empty_state()


func _on_state_item_updated(data: Dictionary) -> void:
	var item_id := int(data.get("id", -1))
	var new_category := _normalize_category(str(data.get("category", "default")))
	var node = _item_nodes.get(item_id)
	if node and is_instance_valid(node) and node.has_method("update_display"):
		var old_category := _normalize_category(str(_item_categories.get(item_id, new_category)))
		if old_category != new_category:
			if node.get_parent():
				node.get_parent().remove_child(node)
			var target_grid := _get_or_create_category_grid(new_category)
			target_grid.add_child(node)
			_item_categories[item_id] = new_category
			_refresh_category_count(old_category)
			_refresh_category_count(new_category)
			_try_remove_empty_category_section(old_category)
		node.update_display(data)
	elif node == null:
		_create_item_node(data)
	_refresh_header()
	_refresh_empty_state()


func _on_state_changed(_data: Dictionary) -> void:
	_refresh_header()
	_refresh_empty_state()


func _on_state_data_loaded() -> void:
	_render_all()


func _refresh_header() -> void:
	var items := RoomDecorState.get_all_items()
	var unlocked_count := 0
	var selected_map := RoomDecorState.get_selected_item_ids_by_category()
	for data in items:
		if bool(data.get("unlocked", false)):
			unlocked_count += 1
	module_title_label.text = "房间装饰"
	item_count_label.text = "已解锁 %d / %d · 已选择 %d 类" % [unlocked_count, items.size(), selected_map.size()]


func _refresh_empty_state() -> void:
	empty_label.visible = _item_nodes.is_empty()


func _normalize_category(category: String) -> String:
	var normalized := category.strip_edges()
	if normalized.is_empty():
		return "default"
	return normalized


func _get_or_create_category_grid(category: String) -> Container:
	var normalized := _normalize_category(category)
	if _category_sections.has(normalized):
		var existing_section: VBoxContainer = _category_sections[normalized] as VBoxContainer
		if existing_section:
			var existing_title := existing_section.get_node("Header/CategoryTitle") as Label
			if existing_title:
				existing_title.text = "位置：%s" % normalized
			return existing_section.get_node("CategoryScroll/CategoryItems") as HBoxContainer

	var section := VBoxContainer.new()
	section.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	section.add_theme_constant_override("separation", 6)

	var header = HBoxContainer.new()
	header.name = "Header"

	var title = Label.new()
	title.name = "CategoryTitle"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.text = "位置：%s" % normalized
	header.add_child(title)

	var count_label = Label.new()
	count_label.name = "CountLabel"
	count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	header.add_child(count_label)

	section.add_child(header)

	var h_scroll = SmoothScrollContainer.new()
	h_scroll.name = "CategoryScroll"
	h_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	h_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	h_scroll.allow_vertical_scroll = false
	h_scroll.allow_horizontal_scroll = true
	h_scroll.handle_input = false
	h_scroll.hide_scrollbar_over_time = true
	h_scroll.scrollbar_hide_time = 0.5
	section.add_child(h_scroll)

	var hbox = HBoxContainer.new()
	hbox.name = "CategoryItems"
	hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hbox.add_theme_constant_override("separation", 8)
	h_scroll.add_child(hbox)

	section.name = "CategorySection_%s" % normalized
	category_list.add_child(section)
	_category_sections[normalized] = section
	_refresh_category_count(normalized)
	return hbox


func _refresh_category_count(category: String) -> void:
	var normalized := _normalize_category(category)
	var section = _category_sections.get(normalized)
	if section == null or not is_instance_valid(section):
		return
	var grid := section.get_node("CategoryScroll/CategoryItems") as Container
	var count_label := section.get_node("Header/CountLabel") as Label
	if grid == null or count_label == null:
		return

	var unlocked_count := 0
	var total_count := 0
	for child in grid.get_children():
		total_count += 1
		if child.has_method("is_unlocked") and child.is_unlocked():
			unlocked_count += 1
	count_label.text = "%d/%d" % [unlocked_count, total_count]


func _try_remove_empty_category_section(category: String) -> void:
	var normalized := _normalize_category(category)
	var section = _category_sections.get(normalized)
	if section == null or not is_instance_valid(section):
		return
	var grid := section.get_node("CategoryScroll/CategoryItems") as Container
	if grid and grid.get_child_count() == 0:
		section.queue_free()
		_category_sections.erase(normalized)

func show_module() -> void:
	if button.current_state == 0:
		LayerManager.bring_to_front(canvas_layer)
		GuiTransitions.show("room_decor")
		button.set_state_no_signal(1)

func hide_module() -> void:
	if button.current_state == 1:
		GuiTransitions.hide("room_decor")
		button.set_state_no_signal(0)

func _on_button_state_changed(_old_state: int, new_state: int) -> void:
	match new_state:
		0:
			GuiTransitions.hide("room_decor")
		1:
			LayerManager.bring_to_front(canvas_layer)
			GuiTransitions.show("room_decor")
