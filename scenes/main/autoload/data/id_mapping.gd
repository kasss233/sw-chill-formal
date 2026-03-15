class_name IdMapping
extends RefCounted

## 本地 ↔ 服务器 ID 双向映射管理
## 维护 resource → { local_key → server_id } 的映射关系

# 正向映射: { "task": { "3": 42 }, "note": { "1": 10 }, "category": { "工作": 5 } }
var _maps: Dictionary = {}
# 反向映射: { "task": { 42: "3" }, ... }
var _reverse: Dictionary = {}

const SAVE_PATH = "user://id_mapping.json"


func _init():
	pass


## 设置映射关系
func set_mapping(resource: String, local_key: String, server_id: int) -> void:
	_ensure_resource(resource)
	# 清除旧的反向映射
	var old_server_id = _maps[resource].get(local_key, 0)
	if old_server_id > 0:
		_reverse[resource].erase(old_server_id)
	# 清除新 server_id 的旧正向映射
	var old_local_key = _reverse[resource].get(server_id, "")
	if old_local_key != "":
		_maps[resource].erase(old_local_key)
	# 建立新映射
	_maps[resource][local_key] = server_id
	_reverse[resource][server_id] = local_key


## 通过本地 key 获取 server_id（0 = 无映射）
func get_server_id(resource: String, local_key: String) -> int:
	_ensure_resource(resource)
	return _maps[resource].get(local_key, 0)


## 通过 server_id 获取本地 key（"" = 无映射）
func get_local_key(resource: String, server_id: int) -> String:
	_ensure_resource(resource)
	return _reverse[resource].get(server_id, "")


## 检查 server_id 是否已有映射
func has_server_id(resource: String, server_id: int) -> bool:
	_ensure_resource(resource)
	return _reverse[resource].has(server_id)


## 按本地 key 移除映射
func remove_by_local(resource: String, local_key: String) -> void:
	_ensure_resource(resource)
	var server_id = _maps[resource].get(local_key, 0)
	if server_id > 0:
		_reverse[resource].erase(server_id)
	_maps[resource].erase(local_key)


## 按 server_id 移除映射
func remove_by_server(resource: String, server_id: int) -> void:
	_ensure_resource(resource)
	var local_key = _reverse[resource].get(server_id, "")
	if local_key != "":
		_maps[resource].erase(local_key)
	_reverse[resource].erase(server_id)


## 获取资源的所有映射（用于 reorder 等批量操作）
func get_all_mappings(resource: String) -> Dictionary:
	_ensure_resource(resource)
	return _maps[resource].duplicate()


## 序列化为字典
func to_dict() -> Dictionary:
	var result = {}
	for resource in _maps:
		result[resource] = {}
		for local_key in _maps[resource]:
			result[resource][str(local_key)] = _maps[resource][local_key]
	return result


## 从字典反序列化
func load_from_dict(d: Dictionary) -> void:
	_maps.clear()
	_reverse.clear()
	for resource in d:
		if not _maps.has(resource):
			_maps[resource] = {}
			_reverse[resource] = {}
		var map_data = d[resource]
		if map_data is Dictionary:
			for local_key in map_data:
				var server_id = int(map_data[local_key])
				_maps[resource][str(local_key)] = server_id
				_reverse[resource][server_id] = str(local_key)


## 保存到文件
func save_to_file() -> void:
	var json_string = JSON.stringify(to_dict(), "\t")
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(json_string)
		file.close()
	else:
		push_error("[IdMapping] Failed to save to %s" % SAVE_PATH)


## 从文件加载
func load_from_file() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		return
	var json_string = file.get_as_text()
	file.close()
	var json = JSON.new()
	if json.parse(json_string) != OK:
		push_error("[IdMapping] Failed to parse %s" % SAVE_PATH)
		return
	var data = json.get_data()
	if data is Dictionary:
		load_from_dict(data)
	print("[IdMapping] Loaded mappings: %s" % str(_maps))


## 清除所有映射
func clear_all() -> void:
	for res in _maps:
		_maps[res].clear()
		_reverse[res].clear()


## 确保资源类型的 dict 存在
func _ensure_resource(resource: String) -> void:
	if not _maps.has(resource):
		_maps[resource] = {}
		_reverse[resource] = {}
