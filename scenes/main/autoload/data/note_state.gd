extends Node

## 笔记数据管理单例（Data Autoload）
## 唯一数据源，负责所有笔记的 CRUD、分类管理、搜索和持久化
## 每次数据修改后自动保存到 user://note_data.json

# --- 信号 ---
signal note_added(note: NoteData)
signal note_removed(note_id: int)
signal note_updated(note: NoteData)
signal data_loaded
signal category_added(category: String)
signal category_removed(category: String)
signal agent_note_created(note: NoteData)
signal agent_content_written(note_id: int, content: String)
signal agent_open_note_requested(note_id: int)
signal agent_close_note_requested

# --- 内部状态 ---
var _notes: Array[NoteData] = []
var _categories: Array[String] = []
var _next_id: int = 1
var _id_index: Dictionary = {}          # {int id → NoteData}
var _server_id_index: Dictionary = {}   # {int server_id → NoteData}

const SAVE_PATH = "user://note_data.json"
const PROTECTED_CATEGORIES: Array[String] = ["反思总结"]
const SAVE_DEBOUNCE_SEC := 0.5
var _save_timer: SceneTreeTimer


func _ready() -> void:
	load_data()
	_ensure_protected_categories()
	print("[NoteState] Initialized as autoload singleton")


# ======================== 查询 API ========================

## 获取所有笔记（副本）
func get_all_notes() -> Array[NoteData]:
	return _notes.duplicate()

## 按 id 查找笔记
func get_note_by_id(id: int) -> NoteData:
	return _id_index.get(id, null)

## 获取指定分类的笔记
func get_notes_by_category(category: String) -> Array[NoteData]:
	var result: Array[NoteData] = []
	for note in _notes:
		if category in note.categories:
			result.append(note)
	return result

## 获取笔记总数
func get_note_count() -> int:
	return _notes.size()

## 获取所有分类
func get_categories() -> Array[String]:
	return _categories.duplicate()

## 搜索笔记（标题和内容模糊匹配）
func search_notes(query: String) -> Array[NoteData]:
	if query.strip_edges() == "":
		return _notes.duplicate()
	var q = query.to_lower()
	var result: Array[NoteData] = []
	for note in _notes:
		if note.title.to_lower().find(q) >= 0 or note.content.to_lower().find(q) >= 0:
			result.append(note)
	return result


# ======================== 修改 API ========================

## 添加笔记（新笔记插入到列表最前面）
func add_note(title: String = "", content: String = "", category: String = "") -> NoteData:
	var cats: Array[String] = []
	if category != "":
		cats.append(category)
	var note = NoteData.new(_next_id, title, content, cats)
	_next_id += 1
	_notes.insert(0, note)
	_index_add(note)
	_queue_save()
	note_added.emit(note)
	print("[NoteState] Added note(id: %d)" % note.id)
	return note

## 删除笔记
func remove_note(id: int) -> bool:
	for i in range(_notes.size()):
		if _notes[i].id == id:
			_index_remove(_notes[i])
			_notes.remove_at(i)
			_queue_save()
			note_removed.emit(id)
			print("[NoteState] Removed note(id: %d)" % id)
			return true
	print("[NoteState] Note with id %d not found" % id)
	return false

## 更新笔记标题
func update_note_title(id: int, title: String) -> bool:
	var note = get_note_by_id(id)
	if note == null:
		return false
	note.title = title
	note.updated_at = int(Time.get_unix_time_from_system())
	_queue_save()
	note_updated.emit(note)
	return true

## 更新笔记内容
func update_note_content(id: int, content: String) -> bool:
	var note = get_note_by_id(id)
	if note == null:
		return false
	note.content = content
	note.updated_at = int(Time.get_unix_time_from_system())
	_queue_save()
	note_updated.emit(note)
	return true

## 同时更新标题和内容
func update_note(id: int, title: String, content: String) -> bool:
	var note = get_note_by_id(id)
	if note == null:
		return false
	note.title = title
	note.content = content
	note.updated_at = int(Time.get_unix_time_from_system())
	_queue_save()
	note_updated.emit(note)
	return true

## 切换笔记分类（已有则移除，没有则添加）
func toggle_note_category(id: int, category: String) -> bool:
	var note = get_note_by_id(id)
	if note == null:
		return false
	var idx = note.categories.find(category)
	if idx >= 0:
		note.categories.remove_at(idx)
	else:
		note.categories.append(category)
	note.updated_at = int(Time.get_unix_time_from_system())
	_queue_save()
	note_updated.emit(note)
	return true

## 设置笔记分类（替换所有分类，兼容旧调用）
func set_note_category(id: int, category: String) -> bool:
	var note = get_note_by_id(id)
	if note == null:
		return false
	note.categories.clear()
	if category != "":
		note.categories.append(category)
	note.updated_at = int(Time.get_unix_time_from_system())
	_queue_save()
	note_updated.emit(note)
	return true


# ======================== Agent API ========================

## Agent: 创建笔记（触发 UI 打开页面 + 打字动画）
func agent_create_note(title: String, content: String, category: String = "") -> NoteData:
	var note = add_note(title, content, category)
	agent_note_created.emit(note)
	return note


## Agent: 写入笔记内容（触发 UI 打字动画）
## 直接修改数据，只发 agent_content_written 信号（不发 note_updated，避免双信号冲突）
func agent_write_content(note_id: int, content: String) -> bool:
	var note = get_note_by_id(note_id)
	if note == null:
		return false
	note.content = content
	note.updated_at = int(Time.get_unix_time_from_system())
	_queue_save()
	agent_content_written.emit(note_id, content)
	return true


## Agent: 打开笔记页（仅打开，不写入内容）
func agent_open_note(note_id: int) -> bool:
	var note = get_note_by_id(note_id)
	if note == null:
		return false
	agent_open_note_requested.emit(note_id)
	return true


## Agent: 关闭当前笔记页（返回列表视图）
func agent_close_note() -> void:
	agent_close_note_requested.emit()


# ======================== 分类管理 ========================

## 添加分类
func add_category(cat_name: String) -> bool:
	if cat_name.strip_edges() == "":
		return false
	if cat_name in _categories:
		return false
	_categories.append(cat_name)
	_queue_save()
	category_added.emit(cat_name)
	print("[NoteState] Added category: %s" % cat_name)
	return true

## 删除分类（同时从笔记的分类列表中移除该分类）
func remove_category(cat_name: String) -> bool:
	if cat_name in PROTECTED_CATEGORIES:
		push_warning("[NoteState] Cannot remove protected category: %s" % cat_name)
		return false
	var idx = _categories.find(cat_name)
	if idx < 0:
		return false
	_categories.remove_at(idx)
	# 从所有笔记的分类列表中移除该分类
	for note in _notes:
		var cat_idx = note.categories.find(cat_name)
		if cat_idx >= 0:
			note.categories.remove_at(cat_idx)
			note.updated_at = int(Time.get_unix_time_from_system())
	_queue_save()
	category_removed.emit(cat_name)
	print("[NoteState] Removed category: %s" % cat_name)
	return true

## 检查分类是否存在
func has_category(cat_name: String) -> bool:
	return cat_name in _categories


# ======================== 持久化 ========================

func _queue_save() -> void:
	if _save_timer and _save_timer.time_left > 0.0:
		return
	_save_timer = get_tree().create_timer(SAVE_DEBOUNCE_SEC)
	_save_timer.timeout.connect(_save_data, CONNECT_ONE_SHOT)

func _save_data() -> void:
	var data = {
		"version": 1,
		"next_id": _next_id,
		"categories": [],
		"notes": []
	}
	for cat in _categories:
		data["categories"].append(cat)
	for note in _notes:
		data["notes"].append(note.to_dict())

	var json_string = JSON.stringify(data, "\t")
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(json_string)
		file.close()
	else:
		push_error("[NoteState] Failed to save data to %s" % SAVE_PATH)


func load_data() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		print("[NoteState] No save file found, starting fresh")
		data_loaded.emit()
		return

	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		push_error("[NoteState] Failed to open save file")
		data_loaded.emit()
		return

	var json_string = file.get_as_text()
	file.close()

	var json = JSON.new()
	var error = json.parse(json_string)
	if error != OK:
		push_error("[NoteState] Failed to parse save file: %s" % json.get_error_message())
		data_loaded.emit()
		return

	var data = json.get_data()
	if not data is Dictionary:
		push_error("[NoteState] Invalid save data format")
		data_loaded.emit()
		return

	_next_id = data.get("next_id", 1)
	_notes.clear()
	_categories.clear()

	var categories_array = data.get("categories", [])
	for cat in categories_array:
		_categories.append(cat)

	var notes_array = data.get("notes", [])
	for note_dict in notes_array:
		var note = NoteData.from_dict(note_dict)
		_notes.append(note)

	print("[NoteState] Loaded %d notes, %d categories" % [_notes.size(), _categories.size()])
	_rebuild_index()
	data_loaded.emit()


## 导出数据（用于云同步）
func export_data() -> Dictionary:
	var data = {
		"version": 1,
		"next_id": _next_id,
		"categories": _categories.duplicate(),
		"notes": []
	}
	for note in _notes:
		data["notes"].append(note.to_dict())
	return data


## 导入数据（用于云同步）
func import_data(data: Dictionary) -> void:
	if not data.has("notes"):
		push_error("[NoteState] Invalid import data")
		return

	_next_id = data.get("next_id", 1)
	_notes.clear()
	_categories.clear()

	var categories_array = data.get("categories", [])
	for cat in categories_array:
		_categories.append(cat)

	var notes_array = data.get("notes", [])
	for note_dict in notes_array:
		var note = NoteData.from_dict(note_dict)
		_notes.append(note)

	_save_data()
	print("[NoteState] Imported %d notes" % _notes.size())
	_rebuild_index()
	data_loaded.emit()

# ======================== 同步辅助 API ========================

## 按 server_id 查找笔记
func get_note_by_server_id(sid: int) -> NoteData:
	return _server_id_index.get(sid, null)

## 从远程数据创建笔记（同步用）
func sync_create_note(note: NoteData) -> void:
	if note.id >= _next_id:
		_next_id = note.id + 1
	_notes.insert(0, note)
	_index_add(note)
	_save_data()
	note_added.emit(note)
	print("[NoteState] Sync created note(id: %d, server_id: %d)" % [note.id, note.server_id])

## 按字段精确更新（同步用）
func sync_update_note(local_id: int, fields: Dictionary) -> bool:
	var note = get_note_by_id(local_id)
	if note == null:
		return false
	var old_server_id = note.server_id
	if fields.has("title"):
		note.title = fields["title"]
	if fields.has("content"):
		note.content = fields["content"]
	if fields.has("categories"):
		note.categories = []
		for c in fields["categories"]:
			note.categories.append(str(c))
	if fields.has("updated_at"):
		note.updated_at = fields["updated_at"]
	if fields.has("server_id"):
		note.server_id = fields["server_id"]
	# 更新 server_id 索引
	if note.server_id != old_server_id:
		if old_server_id > 0:
			_server_id_index.erase(old_server_id)
		if note.server_id > 0:
			_server_id_index[note.server_id] = note
	_save_data()
	note_updated.emit(note)
	print("[NoteState] Sync updated note(id: %d)" % local_id)
	return true

## 删除笔记（同步用）
func sync_remove_note(local_id: int) -> bool:
	for i in range(_notes.size()):
		if _notes[i].id == local_id:
			_index_remove(_notes[i])
			_notes.remove_at(i)
			_save_data()
			note_removed.emit(local_id)
			print("[NoteState] Sync removed note(id: %d)" % local_id)
			return true
	return false

## 全量替换（full sync 用）
func sync_replace_all(notes: Array[NoteData], categories: Array[String]) -> void:
	_notes.clear()
	_categories.clear()
	for cat in categories:
		_categories.append(cat)
	for note in notes:
		_notes.append(note)
		if note.id >= _next_id:
			_next_id = note.id + 1
	_save_data()
	_rebuild_index()
	print("[NoteState] Sync replaced all: %d notes, %d categories" % [_notes.size(), _categories.size()])
	data_loaded.emit()

## 获取分类的位置索引
func get_category_position(cat_name: String) -> int:
	return _categories.find(cat_name)

## 在指定位置插入分类（同步用）
func sync_insert_category_at(cat_name: String, position: int) -> void:
	if cat_name in _categories:
		return
	position = clamp(position, 0, _categories.size())
	_categories.insert(position, cat_name)
	_save_data()
	category_added.emit(cat_name)
	print("[NoteState] Sync inserted category '%s' at position %d" % [cat_name, position])

## 删除分类（同步用，同时从笔记中移除，保持数据一致）
func sync_remove_category(cat_name: String) -> void:
	if cat_name in PROTECTED_CATEGORIES:
		push_warning("[NoteState] Sync remove ignored for protected category: %s" % cat_name)
		return
	var idx = _categories.find(cat_name)
	if idx < 0:
		return
	_categories.remove_at(idx)
	for note in _notes:
		var cat_idx = note.categories.find(cat_name)
		if cat_idx >= 0:
			note.categories.remove_at(cat_idx)
	_save_data()
	category_removed.emit(cat_name)
	print("[NoteState] Sync removed category '%s'" % cat_name)

## 分配新的本地 ID
func allocate_id() -> int:
	var id = _next_id
	_next_id += 1
	return id


## 重建索引（load/import/sync_replace_all 后调用）
func _rebuild_index() -> void:
	_id_index.clear()
	_server_id_index.clear()
	for note in _notes:
		_id_index[note.id] = note
		if note.server_id > 0:
			_server_id_index[note.server_id] = note


## 索引维护：添加
func _index_add(note: NoteData) -> void:
	_id_index[note.id] = note
	if note.server_id > 0:
		_server_id_index[note.server_id] = note


## 索引维护：移除
func _index_remove(note: NoteData) -> void:
	_id_index.erase(note.id)
	if note.server_id > 0:
		_server_id_index.erase(note.server_id)


## 确保受保护分类存在
func _ensure_protected_categories() -> void:
	var changed = false
	for cat in PROTECTED_CATEGORIES:
		if cat not in _categories:
			_categories.append(cat)
			changed = true
			print("[NoteState] Created protected category: %s" % cat)
	if changed:
		_save_data()
