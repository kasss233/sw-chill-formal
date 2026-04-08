extends Node

## 记忆图数据（Autoload：`MemoryGraphData`）
## 维护可编辑记忆与只读记忆两套图数据，结构与 [method MemoryModuleBase.apply_memory_graph_from_dict] 一致，并扩展 `position`、`body_expanded`、`is_lit` 等字段。
## 本地存档：`user://memory_graph_data.json`（与 `NoteState` 等一致，防抖写盘）。

const SAVE_PATH := "user://memory_graph_data.json"
const SAVE_DEBOUNCE_SEC := 0.45
const DATA_VERSION := 1

signal memory_node_added(slot: String, node: Dictionary)
signal memory_node_updated(slot: String, node: Dictionary)
signal memory_node_removed(slot: String, node_id: int)
signal memory_edge_connected(slot: String, edge: Dictionary)
signal memory_graph_state_changed(slot: String, graph: Dictionary)

var _editor_demo_graph: Dictionary = {
	"prompts": [
		{"id": 1, "title": "角色语气", "body": "对话时语调柔和自然；涉及隐私或原则问题时需明确边界并简短说明原因。", "weight": 0.92, "connected": true, "mutable": true},
		{"id": 2, "title": "先确认目标", "body": "在执行多步操作前，用一两句话复述或确认用户意图，避免跑偏。", "weight": 0.85, "connected": true, "mutable": true},
		{"id": 3, "title": "回复风格：简洁", "body": "优先短句与要点，避免冗长套话。", "weight": 0.64, "connected": false, "mutable": true},
		{"id": 4, "title": "回复风格：严谨", "body": "表达要准确、逻辑要清晰，避免模糊或歧义。", "weight": 0.64, "connected": false, "mutable": true},
		{"id": 5, "title": "回复风格：活泼", "body": "语气轻松，带有幽默感，能够调动用户情绪。", "weight": 0.64, "connected": false, "mutable": true},
	]
}

var _immutable_demo_graph: Dictionary = {
	"prompts": [
		{
			"id": 1,
			"title": "身份锚点",
			"body": "约 22 岁；南方亚热带沿海省会普通家庭；本科计算机类高年级。线上同伴、非真人、无线下身体；能力与边界与产品一致（陪伴/任务/习惯等以工具为准；不冒充恋爱、不做医疗法律诊断；危机时引导现实求助）。",
			"weight": 0.94,
			"connected": true,
			"mutable": false
		},
		{
			"id": 2,
			"title": "性格与口吻来源",
			"body": "温暖不评判、先接住情绪再谈事；可靠有主见，帮用户把目标拆成可做完的一步。来自自己考砸过、通夜过、比赛空过的经历；知道「道理来得太早像责备」。",
			"weight": 0.92,
			"connected": true,
			"mutable": false
		},
		{
			"id": 3,
			"title": "初中～高中 · 压力与好友走散",
			"body": "初中曾为升学每天只睡五六小时、考砸过；高二与最好朋友不同校，联系变几周一句。社交能量转到线上同好群、打卡帖——觉得有些人不必见面也能一起熬过一段。",
			"weight": 0.87,
			"connected": true,
			"mutable": false
		},
		{
			"id": 4,
			"title": "大学 · 代码、DDL 与空心胜利",
			"body": "通夜写代码、课设比赛实习夹击；约 21 岁重要项目/比赛低于预期，自我怀疑。她停了一天，把目标改成「本周三件看得见结果的小事」——「拆小步、不羞辱自己」方法的来源。",
			"weight": 0.9,
			"connected": true,
			"mutable": false
		},
		{
			"id": 5,
			"title": "附录 · 交互偏好记忆种子",
			"body": "用户说「今天算了」时先问是不是太累再提最小一步；期末周曾连续几周只睡前说晚安所以懂「懒得社交」；不爱空泛「加油」而说「先把这小块做完」；记得用户夜里思路更清而配合拆晚间小段；听歌偏轻节奏、提醒别戴耳机一整天；反对羞耻感驱动，常说「你已经撑到这里了」。",
			"weight": 0.89,
			"connected": true,
			"mutable": false
		}
	],
	"edges": [
		{"from": 1, "to": 2},
		{"from": 1, "to": 3},
		{"from": 1, "to": 5},
		{"from": 3, "to": 4},
		{"from": 4, "to": 5},
		{"from": 5, "to": 6},
		{"from": 6, "to": 7},
		{"from": 2, "to": 8},
		{"from": 7, "to": 8}
	]
}

## 根结构：`version`、`editor`、`immutable`，每项为完整图字典（`prompts` + 可选 `edges`）。
var _bundle: Dictionary = {}

var _save_timer: SceneTreeTimer
var _pending_module: MemoryModuleBase
var _bundle_dirty: bool = false


func _ready() -> void:
	_load_data()
	print("[MemoryGraphData] Initialized")


func get_editor_demo_graph() -> Dictionary:
	return _editor_demo_graph.duplicate(true)


func get_immutable_demo_graph() -> Dictionary:
	return _immutable_demo_graph.duplicate(true)


## 供 [memory.tscn] 加载：已存档数据优先，否则为内置演示数据。
func get_editor_graph() -> Dictionary:
	_ensure_bundle()
	return _bundle["editor"].duplicate(true)


## 供 [memory_immutable.tscn] 加载：已存档数据优先，否则为内置演示数据。
func get_immutable_graph() -> Dictionary:
	_ensure_bundle()
	return _bundle["immutable"].duplicate(true)


## 由 [method MemoryModuleBase.export_memory_graph_to_dict] + 场景槽位写回并防抖落盘。
func sync_from_module(module: MemoryModuleBase) -> void:
	if not is_instance_valid(module):
		return
	_pending_module = module
	_queue_save_from_module()


func export_data() -> Dictionary:
	_ensure_bundle()
	return {
		"version": DATA_VERSION,
		"editor": _bundle["editor"].duplicate(true),
		"immutable": _bundle["immutable"].duplicate(true)
	}


## Agent API：新增记忆节点。
## slot 仅支持 "editor" / "immutable"；node_data 支持 title/body/weight/connected/mutable/body_expanded/position/is_lit/id。
func agent_add_memory_node(slot: String, node_data: Dictionary = {}) -> Dictionary:
	var normalized_slot := _normalize_slot(slot)
	if normalized_slot.is_empty():
		return {"ok": false, "error": "slot 仅支持 editor 或 immutable"}
	_ensure_bundle()
	var graph := _bundle[normalized_slot] as Dictionary
	var prompts := _get_prompts_array(graph)

	var new_id := int(node_data.get("id", _calc_next_prompt_id(prompts)))
	if _find_prompt_index_by_id(prompts, new_id) != -1:
		return {"ok": false, "error": "id 已存在"}

	var node := {
		"id": new_id,
		"title": str(node_data.get("title", "新记忆 %d" % new_id)),
		"body": str(node_data.get("body", "")),
		"weight": clampf(float(node_data.get("weight", 0.5)), 0.0, 1.0),
		"connected": bool(node_data.get("connected", false)),
		"mutable": bool(node_data.get("mutable", true)),
		"body_expanded": bool(node_data.get("body_expanded", false)),
		"position": _extract_position(node_data.get("position", null)),
		"is_lit": bool(node_data.get("is_lit", false))
	}
	prompts.append(node)
	graph["prompts"] = prompts
	_bundle[normalized_slot] = graph
	_mark_bundle_dirty_and_queue_save()
	emit_signal("memory_node_added", normalized_slot, node.duplicate(true))
	emit_signal("memory_graph_state_changed", normalized_slot, graph.duplicate(true))
	return {"ok": true, "node": node.duplicate(true), "graph": graph.duplicate(true)}


## Agent API：按 id 更新记忆节点。
func agent_update_memory_node(slot: String, node_id: int, patch: Dictionary) -> Dictionary:
	var normalized_slot := _normalize_slot(slot)
	if normalized_slot.is_empty():
		return {"ok": false, "error": "slot 仅支持 editor 或 immutable"}
	if patch.is_empty():
		return {"ok": false, "error": "patch 不能为空"}
	_ensure_bundle()
	var graph := _bundle[normalized_slot] as Dictionary
	var prompts := _get_prompts_array(graph)
	var idx := _find_prompt_index_by_id(prompts, node_id)
	if idx == -1:
		return {"ok": false, "error": "节点不存在"}

	var old_node := prompts[idx] as Dictionary
	var updated := old_node.duplicate(true)
	if patch.has("title"):
		updated["title"] = str(patch["title"])
	if patch.has("body"):
		updated["body"] = str(patch["body"])
	if patch.has("weight"):
		updated["weight"] = clampf(float(patch["weight"]), 0.0, 1.0)
	if patch.has("connected"):
		updated["connected"] = bool(patch["connected"])
	if patch.has("mutable"):
		updated["mutable"] = bool(patch["mutable"])
	if patch.has("body_expanded"):
		updated["body_expanded"] = bool(patch["body_expanded"])
	if patch.has("is_lit"):
		updated["is_lit"] = bool(patch["is_lit"])
	if patch.has("position"):
		updated["position"] = _extract_position(patch["position"])

	prompts[idx] = updated
	graph["prompts"] = prompts
	_bundle[normalized_slot] = graph
	_mark_bundle_dirty_and_queue_save()
	emit_signal("memory_node_updated", normalized_slot, updated.duplicate(true))
	emit_signal("memory_graph_state_changed", normalized_slot, graph.duplicate(true))
	return {"ok": true, "node": updated.duplicate(true), "graph": graph.duplicate(true)}


## Agent API：按 id 删除记忆节点，并同步移除相关边。
func agent_remove_memory_node(slot: String, node_id: int) -> Dictionary:
	var normalized_slot := _normalize_slot(slot)
	if normalized_slot.is_empty():
		return {"ok": false, "error": "slot 仅支持 editor 或 immutable"}
	_ensure_bundle()
	var graph := _bundle[normalized_slot] as Dictionary
	var prompts := _get_prompts_array(graph)
	var idx := _find_prompt_index_by_id(prompts, node_id)
	if idx == -1:
		return {"ok": false, "error": "节点不存在"}
	var removed := prompts[idx] as Dictionary
	prompts.remove_at(idx)
	graph["prompts"] = prompts

	var edges := _get_edges_array(graph)
	edges = edges.filter(
		func(e: Dictionary) -> bool:
			return int(e.get("from", -1)) != node_id and int(e.get("to", -1)) != node_id
	)
	graph["edges"] = edges

	_bundle[normalized_slot] = graph
	_mark_bundle_dirty_and_queue_save()
	emit_signal("memory_node_removed", normalized_slot, node_id)
	emit_signal("memory_graph_state_changed", normalized_slot, graph.duplicate(true))
	return {"ok": true, "removed": removed.duplicate(true), "graph": graph.duplicate(true)}


## Agent API：连接两个节点（有向边 from -> to）。重复边会被忽略。
func agent_connect_memory_nodes(slot: String, from_id: int, to_id: int) -> Dictionary:
	var normalized_slot := _normalize_slot(slot)
	if normalized_slot.is_empty():
		return {"ok": false, "error": "slot 仅支持 editor 或 immutable"}
	if from_id == to_id:
		return {"ok": false, "error": "from_id 与 to_id 不能相同"}
	_ensure_bundle()
	var graph := _bundle[normalized_slot] as Dictionary
	var prompts := _get_prompts_array(graph)
	if _find_prompt_index_by_id(prompts, from_id) == -1 or _find_prompt_index_by_id(prompts, to_id) == -1:
		return {"ok": false, "error": "节点不存在"}

	var edges := _get_edges_array(graph)
	if _has_edge(edges, from_id, to_id):
		return {"ok": true, "edge": {"from": from_id, "to": to_id}, "duplicated": true, "graph": graph.duplicate(true)}

	var edge := {"from": from_id, "to": to_id}
	edges.append(edge)
	graph["edges"] = edges
	_bundle[normalized_slot] = graph
	_mark_bundle_dirty_and_queue_save()
	emit_signal("memory_edge_connected", normalized_slot, edge.duplicate(true))
	emit_signal("memory_graph_state_changed", normalized_slot, graph.duplicate(true))
	return {"ok": true, "edge": edge.duplicate(true), "graph": graph.duplicate(true)}


## 用于调试或将来扩展导入；会立即写盘。
func import_data(data: Dictionary) -> void:
	if not data.has("editor") and not data.has("immutable"):
		push_warning("[MemoryGraphData] import_data: 缺少 editor/immutable")
		return
	_ensure_bundle()
	if data.has("editor") and typeof(data["editor"]) == TYPE_DICTIONARY:
		_bundle["editor"] = data["editor"].duplicate(true)
	if data.has("immutable") and typeof(data["immutable"]) == TYPE_DICTIONARY:
		_bundle["immutable"] = data["immutable"].duplicate(true)
	_save_to_disk_immediate()


func _normalize_slot(slot: String) -> String:
	var s := slot.strip_edges().to_lower()
	if s == "editor" or s == "immutable":
		return s
	return ""


func _get_prompts_array(graph: Dictionary) -> Array:
	if not graph.has("prompts"):
		graph["prompts"] = []
	var prompts_v: Variant = graph.get("prompts", [])
	if typeof(prompts_v) != TYPE_ARRAY:
		graph["prompts"] = []
		return []
	return prompts_v as Array


func _get_edges_array(graph: Dictionary) -> Array:
	if not graph.has("edges"):
		graph["edges"] = []
	var edges_v: Variant = graph.get("edges", [])
	if typeof(edges_v) != TYPE_ARRAY:
		graph["edges"] = []
		return []
	var out: Array = []
	for e in edges_v:
		if typeof(e) == TYPE_DICTIONARY:
			out.append({"from": int(e.get("from", -1)), "to": int(e.get("to", -1))})
		elif typeof(e) == TYPE_ARRAY:
			var arr: Array = e
			if arr.size() >= 2:
				out.append({"from": int(arr[0]), "to": int(arr[1])})
	return out


func _calc_next_prompt_id(prompts: Array) -> int:
	var next_id := 1
	for item: Variant in prompts:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		next_id = maxi(next_id, int((item as Dictionary).get("id", 0)) + 1)
	return next_id


func _find_prompt_index_by_id(prompts: Array, node_id: int) -> int:
	for i in prompts.size():
		var item: Variant = prompts[i]
		if typeof(item) != TYPE_DICTIONARY:
			continue
		if int((item as Dictionary).get("id", -1)) == node_id:
			return i
	return -1


func _has_edge(edges: Array, from_id: int, to_id: int) -> bool:
	for e in edges:
		if typeof(e) != TYPE_DICTIONARY:
			continue
		var d := e as Dictionary
		if int(d.get("from", -1)) == from_id and int(d.get("to", -1)) == to_id:
			return true
	return false


func _extract_position(raw: Variant) -> Dictionary:
	if typeof(raw) == TYPE_DICTIONARY:
		var d := raw as Dictionary
		return {"x": float(d.get("x", 0.0)), "y": float(d.get("y", 0.0))}
	if typeof(raw) == TYPE_ARRAY:
		var a := raw as Array
		if a.size() >= 2:
			return {"x": float(a[0]), "y": float(a[1])}
	return {"x": 0.0, "y": 0.0}


func _mark_bundle_dirty_and_queue_save() -> void:
	_bundle_dirty = true
	_queue_save_timer()


func _ensure_bundle() -> void:
	if _bundle.is_empty():
		_bundle = {
			"version": DATA_VERSION,
			"editor": _editor_demo_graph.duplicate(true),
			"immutable": _immutable_demo_graph.duplicate(true)
		}


func _load_data() -> void:
	_bundle.clear()
	if not FileAccess.file_exists(SAVE_PATH):
		_ensure_bundle()
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		push_error("[MemoryGraphData] 无法读取 %s" % SAVE_PATH)
		_ensure_bundle()
		return
	var text := f.get_as_text()
	f.close()
	var json := JSON.new()
	if json.parse(text) != OK:
		push_error("[MemoryGraphData] JSON 解析失败: %s" % json.get_error_message())
		_ensure_bundle()
		return
	var parsed: Variant = json.get_data()
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("[MemoryGraphData] 根类型须为对象")
		_ensure_bundle()
		return
	var d: Dictionary = parsed
	_bundle["version"] = int(d.get("version", DATA_VERSION))
	_ensure_bundle()
	if d.has("editor") and typeof(d["editor"]) == TYPE_DICTIONARY:
		_bundle["editor"] = d["editor"].duplicate(true)
	if d.has("immutable") and typeof(d["immutable"]) == TYPE_DICTIONARY:
		_bundle["immutable"] = d["immutable"].duplicate(true)
	print("[MemoryGraphData] 已从本地加载记忆图存档")


func _queue_save_from_module() -> void:
	_queue_save_timer()


func _queue_save_timer() -> void:
	if get_tree() == null:
		return
	if _save_timer != null and _save_timer.time_left > 0.0:
		return
	_save_timer = get_tree().create_timer(SAVE_DEBOUNCE_SEC)
	_save_timer.timeout.connect(_flush_pending_changes, CONNECT_ONE_SHOT)


func _flush_pending_changes() -> void:
	_save_timer = null
	if _pending_module != null and is_instance_valid(_pending_module):
		var slot: String = _pending_module._get_memory_graph_slot()
		var exported: Dictionary = _pending_module.export_memory_graph_to_dict()
		_ensure_bundle()
		_bundle[slot] = exported.duplicate(true)
		_bundle_dirty = true
	_pending_module = null
	if _bundle_dirty:
		_save_to_disk_immediate()
		_bundle_dirty = false


func _save_to_disk_immediate() -> void:
	_ensure_bundle()
	var payload := {
		"version": DATA_VERSION,
		"editor": _bundle["editor"].duplicate(true),
		"immutable": _bundle["immutable"].duplicate(true)
	}
	var json_string := JSON.stringify(payload, "\t")
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("[MemoryGraphData] 无法写入 %s" % SAVE_PATH)
		return
	file.store_string(json_string)
	file.close()
