extends Node

# RoomDecorState
# 职责：房间装饰物品数据源（增删改查、分类选中、解锁校验、持久化、资源导入）。
# 规则：UI/Agent 仅调用本 State API，不直接改写内部数据。

# ===== 信号 =====
signal room_decor_added(data: Dictionary)
signal room_decor_removed(item_id: int)
signal room_decor_updated(data: Dictionary)
signal room_decor_state_changed(data: Dictionary)
signal room_decor_selected(item_name: String, category: String)
signal room_decor_category_unselected(category: String)
signal data_loaded

# ===== 内部状态 =====
var _items: Array[RoomDecorData] = []
var _next_id: int = 1
var _selected_item_ids_by_category: Dictionary = {}

const SAVE_PATH := "user://room_decor_data.json"
const RESOURCE_PATH := "res://resource/room_decor_res/room_decor_res.tres"
const SAVE_DEBOUNCE_SEC := 0.5
var _save_timer: SceneTreeTimer


# ===== 生命周期 =====
func _ready() -> void:
	load_data()
	if _items.is_empty():
		load_from_resource()
	_connect_level_signals()
	call_deferred("_emit_startup_sync_signals")


# ===== 查询 API =====
func get_all_items() -> Array[Dictionary]:
	var list: Array[Dictionary] = []
	for item in _items:
		list.append(_to_view_data(item))
	return list


func get_selected_item_ids_by_category() -> Dictionary:
	return _selected_item_ids_by_category.duplicate()


# ===== 写入 API =====
# 添加装饰物品；若该分类尚无选中项且物品已解锁，则自动设为选中。
func add_item(item_name: String, category: String = "default", required_level: int = 1, icon_path: String = "") -> RoomDecorData:
	var final_name := item_name.strip_edges()
	if final_name.is_empty():
		return null
	var final_category := _normalize_category(category)

	var item := RoomDecorData.new(_next_id, final_name, final_category, required_level, icon_path)
	_next_id += 1
	_items.append(item)

	if _get_selected_id(final_category) <= 0 and _is_unlocked(item):
		_selected_item_ids_by_category[final_category] = item.id

	_queue_save()
	room_decor_added.emit(_to_view_data(item))
	_emit_state_changed()
	return item


func remove_item(item_id: int) -> bool:
	var prev_selected_map := _selected_item_ids_by_category.duplicate()
	for i in range(_items.size()):
		if _items[i].id != item_id:
			continue

		var removed_category := _normalize_category(_items[i].category)
		_items.remove_at(i)
		if _get_selected_id(removed_category) == item_id:
			_selected_item_ids_by_category.erase(removed_category)
			_assign_first_unlocked_for_category(removed_category)

		_queue_save()
		room_decor_removed.emit(item_id)
		_emit_unselected_categories(prev_selected_map)
		_emit_state_changed()
		return true

	return false


func clear_all_items() -> int:
	if _items.is_empty():
		return 0
	var prev_selected_map := _selected_item_ids_by_category.duplicate()

	var removed_ids: Array[int] = []
	for item in _items:
		removed_ids.append(item.id)

	_items.clear()
	_selected_item_ids_by_category.clear()
	_queue_save()

	for item_id in removed_ids:
		room_decor_removed.emit(item_id)

	_emit_unselected_categories(prev_selected_map)
	_emit_state_changed()
	return removed_ids.size()


func clear_all_categories() -> Dictionary:
	if _items.is_empty():
		return {
			"removed_category_count": 0,
			"removed_item_count": 0
		}

	var category_map: Dictionary = {}
	for item in _items:
		category_map[_normalize_category(item.category)] = true

	var removed_category_count := category_map.size()
	var removed_item_count := clear_all_items()

	return {
		"removed_category_count": removed_category_count,
		"removed_item_count": removed_item_count
	}


func select_item(item_id: int) -> bool:
	# 选中成功后统一发出 room_decor_selected(name, category) 信号。
	var item := _get_item_by_id(item_id)
	if item == null:
		return false
	if not _is_unlocked(item):
		return false

	var category := _normalize_category(item.category)
	var old_id := _get_selected_id(category)
	if old_id == item_id:
		return true

	_selected_item_ids_by_category[category] = item_id
	_queue_save()

	if old_id > 0:
		var old_item := _get_item_by_id(old_id)
		if old_item:
			room_decor_updated.emit(_to_view_data(old_item))
	room_decor_updated.emit(_to_view_data(item))
	room_decor_selected.emit(item.name, category)
	_emit_state_changed()
	return true


func deselect_item(item_id: int) -> bool:
	var item := _get_item_by_id(item_id)
	if item == null:
		return false

	var category := _normalize_category(item.category)
	if _get_selected_id(category) != item_id:
		return false

	_selected_item_ids_by_category.erase(category)
	_queue_save()
	room_decor_updated.emit(_to_view_data(item))
	room_decor_category_unselected.emit(category)
	_emit_state_changed()
	return true


# ===== Agent API（仅方法名保留 agent_ 前缀） =====
func agent_add_room_decor_item(item_name: String, category: String, required_level: int = 1, icon_path: String = "") -> Dictionary:
	var item := add_item(item_name, category, required_level, icon_path)
	if item == null:
		return {}
	return _to_view_data(item)


func agent_select_room_decor_item(item_id: int) -> bool:
	return select_item(item_id)


func agent_deselect_room_decor_item(item_id: int) -> bool:
	return deselect_item(item_id)


func agent_remove_room_decor_item(item_id: int) -> bool:
	return remove_item(item_id)


func agent_clear_all_room_decor() -> int:
	return clear_all_items()


func agent_clear_all_room_decor_categories() -> Dictionary:
	return clear_all_categories()


func agent_get_selected_room_decor() -> Dictionary:
	return get_selected_item_ids_by_category()


func agent_load_room_decor_from_resource() -> Dictionary:
	"""AI API: 从 room_decor_res 资源文件加载初始房间装饰物品"""
	var initial_count := _items.size()
	load_from_resource()
	var final_count := _items.size()
	var loaded_count := final_count - initial_count

	return {
		"success": loaded_count > 0,
		"loaded_count": loaded_count,
		"total_count": final_count
	}


func agent_get_all_room_decor() -> Array[Dictionary]:
	return get_all_items()


func agent_get_available_room_decor() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for item in _items:
		if _is_unlocked(item):
			result.append(_to_view_data(item))
	return result


# ===== 内部实现 =====
func _get_item_by_id(item_id: int) -> RoomDecorData:
	for item in _items:
		if item.id == item_id:
			return item
	return null


func _is_unlocked(item: RoomDecorData) -> bool:
	var current_level := 1
	if typeof(LevelState) != TYPE_NIL:
		current_level = int(LevelState.level)
	return current_level >= item.required_level


func _to_view_data(item: RoomDecorData) -> Dictionary:
	var unlocked := _is_unlocked(item)
	var category := _normalize_category(item.category)
	return {
		"id": item.id,
		"name": item.name,
		"category": category,
		"icon_path": item.icon_path,
		"required_level": item.required_level,
		"unlocked": unlocked,
		"selected": _get_selected_id(category) == item.id,
		"created_at": item.created_at,
		"updated_at": item.updated_at
	}


func _emit_state_changed() -> void:
	var unlocked_count := 0
	var category_count := 0
	var category_map: Dictionary = {}
	for item in _items:
		category_map[_normalize_category(item.category)] = true
		if _is_unlocked(item):
			unlocked_count += 1
	category_count = category_map.size()

	room_decor_state_changed.emit({
		"count": _items.size(),
		"category_count": category_count,
		"selected_item_ids_by_category": _selected_item_ids_by_category.duplicate(),
		"unlocked_count": unlocked_count,
		"current_level": int(LevelState.level) if typeof(LevelState) != TYPE_NIL else 1
	})


func _queue_save() -> void:
	if _save_timer and _save_timer.time_left > 0.0:
		return
	_save_timer = get_tree().create_timer(SAVE_DEBOUNCE_SEC)
	_save_timer.timeout.connect(_save_data, CONNECT_ONE_SHOT)

func _save_data() -> void:
	var data := {
		"version": 1,
		"next_id": _next_id,
		"selected_item_ids_by_category": _selected_item_ids_by_category.duplicate(),
		"items": []
	}
	for item in _items:
		data["items"].append(item.to_dict())

	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data, "\t"))
		file.close()


func load_data() -> void:
	var prev_selected_map := _selected_item_ids_by_category.duplicate()
	if not FileAccess.file_exists(SAVE_PATH):
		data_loaded.emit()
		_emit_unselected_categories(prev_selected_map)
		_emit_state_changed()
		return

	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		data_loaded.emit()
		_emit_unselected_categories(prev_selected_map)
		_emit_state_changed()
		return

	var text := file.get_as_text()
	file.close()

	var json := JSON.new()
	if json.parse(text) != OK or typeof(json.data) != TYPE_DICTIONARY:
		data_loaded.emit()
		_emit_unselected_categories(prev_selected_map)
		_emit_state_changed()
		return

	var data: Dictionary = json.data
	_next_id = int(data.get("next_id", 1))
	var has_selected_map := data.has("selected_item_ids_by_category")
	_selected_item_ids_by_category.clear()
	var saved_selected: Dictionary = data.get("selected_item_ids_by_category", {})
	for category in saved_selected.keys():
		var normalized := _normalize_category(str(category))
		_selected_item_ids_by_category[normalized] = int(saved_selected.get(category, 0))

	var old_selected_id := int(data.get("selected_item_id", 0))
	_items.clear()

	var items: Array = data.get("items", [])
	for d in items:
		if d is Dictionary:
			_items.append(RoomDecorData.from_dict(d))

	if old_selected_id > 0:
		var old_selected_item := _get_item_by_id(old_selected_id)
		if old_selected_item:
			var old_category := _normalize_category(old_selected_item.category)
			if _get_selected_id(old_category) <= 0:
				_selected_item_ids_by_category[old_category] = old_selected_id

	for category in _selected_item_ids_by_category.keys():
		var selected_id := int(_selected_item_ids_by_category[category])
		var selected_item := _get_item_by_id(selected_id)
		if selected_item == null:
			_selected_item_ids_by_category.erase(category)
			continue
		if _normalize_category(selected_item.category) != _normalize_category(str(category)):
			_selected_item_ids_by_category.erase(category)
			continue
		if not _is_unlocked(selected_item):
			_selected_item_ids_by_category.erase(category)

	if not has_selected_map:
		for item in _items:
			_assign_first_unlocked_for_category(_normalize_category(item.category))

	data_loaded.emit()
	_emit_unselected_categories(prev_selected_map)
	_emit_state_changed()


func _emit_startup_sync_signals() -> void:
	data_loaded.emit()
	for item in _items:
		room_decor_updated.emit(_to_view_data(item))

	var category_map: Dictionary = {}
	for item in _items:
		var category := _normalize_category(item.category)
		category_map[category] = true

	for category in category_map.keys():
		var normalized := _normalize_category(str(category))
		var selected_id := _get_selected_id(normalized)
		if selected_id > 0:
			var selected_item := _get_item_by_id(selected_id)
			if selected_item:
				room_decor_selected.emit(selected_item.name, normalized)
			else:
				room_decor_category_unselected.emit(normalized)
		else:
			room_decor_category_unselected.emit(normalized)

	_emit_state_changed()


func load_from_resource() -> void:
	"""从 room_decor_res 资源加载初始物品数据"""
	if not ResourceLoader.exists(RESOURCE_PATH):
		push_warning("RoomDecorState: 资源文件不存在: ", RESOURCE_PATH)
		return
	
	var res = ResourceLoader.load(RESOURCE_PATH)
	if res == null:
		push_error("RoomDecorState: 无法加载资源: ", RESOURCE_PATH)
		return
	
	# 获取 decor_items 数组
	var decor_items: Array = []
	if "decor_items" in res:
		var items_attr = res.get_meta("decor_items") if res.has_meta("decor_items") else res.decor_items
		if items_attr is Array:
			decor_items = items_attr
	
	if decor_items.is_empty():
		return
	
	# 遍历物品并添加
	for room_decor_item in decor_items:
		if not room_decor_item is RoomDecorItem:
			continue
		
		# 提取 Texture2D 的资源路径
		var icon_path := ""
		if room_decor_item.icon is Texture2D:
			icon_path = room_decor_item.icon.resource_path
		
		# 使用 add_item 添加（自动处理选中状态和持久化）
		add_item(
			room_decor_item.name,
			room_decor_item.category,
			room_decor_item.required_level,
			icon_path
		)


func _assign_first_unlocked_for_category(category: String) -> void:
	var normalized := _normalize_category(category)
	if _get_selected_id(normalized) > 0:
		return
	for item in _items:
		if _normalize_category(item.category) != normalized:
			continue
		if _is_unlocked(item):
			_selected_item_ids_by_category[normalized] = item.id
			return


func _get_selected_id(category: String) -> int:
	var normalized := _normalize_category(category)
	return int(_selected_item_ids_by_category.get(normalized, 0))


func _normalize_category(category: String) -> String:
	var normalized := category.strip_edges()
	if normalized.is_empty():
		return "default"
	return normalized


func _connect_level_signals() -> void:
	if typeof(LevelState) == TYPE_NIL:
		return
	if LevelState.has_signal("level_state_changed") and not LevelState.level_state_changed.is_connected(_on_level_state_changed):
		LevelState.level_state_changed.connect(_on_level_state_changed)


func _on_level_state_changed(_data: Dictionary) -> void:
	var prev_selected_map := _selected_item_ids_by_category.duplicate()
	var categories_need_reassign: Dictionary = {}
	for category in _selected_item_ids_by_category.keys():
		var normalized_category := _normalize_category(str(category))
		var selected_id := int(_selected_item_ids_by_category[category])
		var selected := _get_item_by_id(selected_id)
		if selected and not _is_unlocked(selected):
			_selected_item_ids_by_category.erase(category)
			categories_need_reassign[normalized_category] = true

	for category in categories_need_reassign.keys():
		_assign_first_unlocked_for_category(str(category))

	for item in _items:
		room_decor_updated.emit(_to_view_data(item))
	_queue_save()
	_emit_unselected_categories(prev_selected_map)
	_emit_state_changed()


func _emit_unselected_categories(prev_selected_map: Dictionary) -> void:
	for category in prev_selected_map.keys():
		var normalized := _normalize_category(str(category))
		var prev_selected_id := int(prev_selected_map.get(category, 0))
		if prev_selected_id <= 0:
			continue
		if _get_selected_id(normalized) > 0:
			continue
		room_decor_category_unselected.emit(normalized)


# ===== 同步 API =====
func export_data() -> Dictionary:
	var items_data: Array = []
	for item in _items:
		items_data.append(item.to_dict())
	return {
		"version": 1,
		"next_id": _next_id,
		"selected_item_ids_by_category": _selected_item_ids_by_category.duplicate(),
		"items": items_data
	}


func import_sync_data(data: Dictionary) -> void:
	if not data.has("items") and not data.has("selected_item_ids_by_category") and not data.has("selected_item_id"):
		return

	# 全量导入：房间装饰按 bundle 做 full_replace，同步时以服务端快照为准。
	var incoming_items: Array[RoomDecorData] = []
	for raw in data.get("items", []):
		if raw is Dictionary:
			incoming_items.append(RoomDecorData.from_dict(raw))

	_items = incoming_items

	var remote_next_id := int(data.get("next_id", 1))
	var max_id := 0
	for item in _items:
		max_id = max(max_id, item.id)
	_next_id = max(remote_next_id, max_id + 1)

	_selected_item_ids_by_category.clear()
	var has_selection_payload := false
	if data.has("selected_item_ids_by_category"):
		has_selection_payload = true
		var remote_selected: Dictionary = data.get("selected_item_ids_by_category", {})
		for category in remote_selected.keys():
			var normalized := _normalize_category(str(category))
			_selected_item_ids_by_category[normalized] = int(remote_selected.get(category, 0))
	elif data.has("selected_item_id"):
		has_selection_payload = true
		# 兼容旧版单选字段
		var legacy_selected_id := int(data.get("selected_item_id", 0))
		if legacy_selected_id > 0:
			var legacy_item := _get_item_by_id(legacy_selected_id)
			if legacy_item:
				_selected_item_ids_by_category[_normalize_category(legacy_item.category)] = legacy_selected_id

	for category in _selected_item_ids_by_category.keys():
		var selected_id := int(_selected_item_ids_by_category[category])
		var selected_item := _get_item_by_id(selected_id)
		if selected_item == null:
			_selected_item_ids_by_category.erase(category)
			continue
		if _normalize_category(selected_item.category) != _normalize_category(str(category)):
			_selected_item_ids_by_category.erase(category)
			continue
		if not _is_unlocked(selected_item):
			_selected_item_ids_by_category.erase(category)

	# 仅在旧版数据缺少任何选中字段时，才进行兜底自动选中。
	if not has_selection_payload:
		for item in _items:
			_assign_first_unlocked_for_category(_normalize_category(item.category))

	_save_data()
	_emit_startup_sync_signals()
