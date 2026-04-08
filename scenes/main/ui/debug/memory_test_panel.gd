extends Control

@onready var info_label: RichTextLabel = $MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/InfoLabel
@onready var slot_input: LineEdit = $MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/InputSection/SlotInput
@onready var node_id_input: LineEdit = $MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/InputSection/NodeIdInput
@onready var title_input: LineEdit = $MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/InputSection/TitleInput
@onready var body_input: LineEdit = $MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/InputSection/BodyInput
@onready var weight_input: LineEdit = $MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/InputSection/WeightInput
@onready var from_id_input: LineEdit = $MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/InputSection/FromIdInput
@onready var to_id_input: LineEdit = $MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/InputSection/ToIdInput

@onready var show_module_btn: Button = $MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/ModuleSection/ShowModuleBtn
@onready var hide_module_btn: Button = $MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/ModuleSection/HideModuleBtn

@onready var add_node_btn: Button = $MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/AgentSection/AddNodeBtn
@onready var update_node_btn: Button = $MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/AgentSection/UpdateNodeBtn
@onready var remove_node_btn: Button = $MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/AgentSection/RemoveNodeBtn
@onready var connect_nodes_btn: Button = $MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/AgentSection/ConnectNodesBtn
@onready var toggle_connected_btn: Button = $MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/AgentSection/ToggleConnectedBtn
@onready var get_graph_btn: Button = $MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/AgentSection/GetGraphBtn


func _ready() -> void:
	show_module_btn.pressed.connect(_on_show_module_pressed)
	hide_module_btn.pressed.connect(_on_hide_module_pressed)
	add_node_btn.pressed.connect(_on_add_node_pressed)
	update_node_btn.pressed.connect(_on_update_node_pressed)
	remove_node_btn.pressed.connect(_on_remove_node_pressed)
	connect_nodes_btn.pressed.connect(_on_connect_nodes_pressed)
	toggle_connected_btn.pressed.connect(_on_toggle_connected_pressed)
	get_graph_btn.pressed.connect(_on_get_graph_pressed)

	MemoryState.memory_node_added.connect(_on_state_node_added)
	MemoryState.memory_node_updated.connect(_on_state_node_updated)
	MemoryState.memory_node_removed.connect(_on_state_node_removed)
	MemoryState.memory_edge_connected.connect(_on_state_edge_connected)
	MemoryState.memory_graph_state_changed.connect(_on_state_graph_changed)

	_log_info("Memory 调试面板已就绪")
	_log_info("默认 slot=editor，可改为 immutable")


func _on_show_module_pressed() -> void:
	LayerManager.agent_show_module("memory")
	_log_success("已请求显示 memory 模块")


func _on_hide_module_pressed() -> void:
	LayerManager.agent_hide_module("memory")
	_log_success("已请求隐藏 memory 模块")


func _on_add_node_pressed() -> void:
	var slot := _read_slot()
	var title := title_input.text.strip_edges()
	if title.is_empty():
		title = "测试记忆_%d" % Time.get_ticks_msec()
	var body := body_input.text.strip_edges()
	var payload := {
		"title": title,
		"body": body,
		"weight": _read_weight(),
		"connected": false,
		"mutable": true
	}
	var r: Dictionary = MemoryState.agent_add_memory_node(slot, payload)
	if bool(r.get("ok", false)):
		var node: Dictionary = r.get("node", {})
		node_id_input.text = str(int(node.get("id", 0)))
		_log_success("添加节点成功: id=%d slot=%s" % [int(node.get("id", -1)), slot])
		_log_data(JSON.stringify(node))
	else:
		_log_error("添加节点失败: %s" % str(r.get("error", "unknown")))


func _on_update_node_pressed() -> void:
	var slot := _read_slot()
	var node_id := _read_node_id()
	if node_id <= 0:
		_log_error("请输入有效 Node ID")
		return
	var patch := {
		"title": title_input.text.strip_edges(),
		"body": body_input.text.strip_edges(),
		"weight": _read_weight()
	}
	var r: Dictionary = MemoryState.agent_update_memory_node(slot, node_id, patch)
	if bool(r.get("ok", false)):
		_log_success("更新节点成功: id=%d slot=%s" % [node_id, slot])
		_log_data(JSON.stringify(r.get("node", {})))
	else:
		_log_error("更新节点失败: %s" % str(r.get("error", "unknown")))


func _on_remove_node_pressed() -> void:
	var slot := _read_slot()
	var node_id := _read_node_id()
	if node_id <= 0:
		_log_error("请输入有效 Node ID")
		return
	var r: Dictionary = MemoryState.agent_remove_memory_node(slot, node_id)
	if bool(r.get("ok", false)):
		_log_success("删除节点成功: id=%d slot=%s" % [node_id, slot])
	else:
		_log_error("删除节点失败: %s" % str(r.get("error", "unknown")))


func _on_connect_nodes_pressed() -> void:
	var slot := _read_slot()
	var from_id := from_id_input.text.to_int()
	var to_id := to_id_input.text.to_int()
	if from_id <= 0 or to_id <= 0:
		_log_error("请输入有效 from/to ID")
		return
	var r: Dictionary = MemoryState.agent_connect_memory_nodes(slot, from_id, to_id)
	if bool(r.get("ok", false)):
		var duplicated := bool(r.get("duplicated", false))
		if duplicated:
			_log_info("连接已存在: %d -> %d" % [from_id, to_id])
		else:
			_log_success("连接成功: %d -> %d" % [from_id, to_id])
	else:
		_log_error("连接失败: %s" % str(r.get("error", "unknown")))


func _on_toggle_connected_pressed() -> void:
	var slot := _read_slot()
	var node_id := _read_node_id()
	if node_id <= 0:
		_log_error("请输入有效 Node ID")
		return
	var graph := _get_graph_by_slot(slot)
	var prompts: Array = graph.get("prompts", [])
	var current_connected := false
	for item in prompts:
		if typeof(item) == TYPE_DICTIONARY and int(item.get("id", -1)) == node_id:
			current_connected = bool(item.get("connected", false))
			break
	var r: Dictionary = MemoryState.agent_update_memory_node(slot, node_id, {"connected": not current_connected})
	if bool(r.get("ok", false)):
		_log_success("切换 connected 成功: id=%d -> %s" % [node_id, str(not current_connected)])
	else:
		_log_error("切换 connected 失败: %s" % str(r.get("error", "unknown")))


func _on_get_graph_pressed() -> void:
	var slot := _read_slot()
	var graph := _get_graph_by_slot(slot)
	var prompts: Array = graph.get("prompts", [])
	var edges: Array = graph.get("edges", [])
	_log_success("当前图: slot=%s, nodes=%d, edges=%d" % [slot, prompts.size(), edges.size()])
	_log_data(JSON.stringify(graph, "  "))


func _get_graph_by_slot(slot: String) -> Dictionary:
	if slot == "immutable":
		return MemoryState.get_immutable_graph()
	return MemoryState.get_editor_graph()


func _read_slot() -> String:
	var slot := slot_input.text.strip_edges().to_lower()
	if slot != "editor" and slot != "immutable":
		slot = "editor"
		slot_input.text = slot
	return slot


func _read_node_id() -> int:
	return node_id_input.text.to_int()


func _read_weight() -> float:
	return clampf(weight_input.text.to_float(), 0.0, 1.0)


func _on_state_node_added(slot: String, node: Dictionary) -> void:
	_log_info("[signal] node_added slot=%s id=%d" % [slot, int(node.get("id", -1))])


func _on_state_node_updated(slot: String, node: Dictionary) -> void:
	_log_info("[signal] node_updated slot=%s id=%d" % [slot, int(node.get("id", -1))])


func _on_state_node_removed(slot: String, node_id: int) -> void:
	_log_info("[signal] node_removed slot=%s id=%d" % [slot, node_id])


func _on_state_edge_connected(slot: String, edge: Dictionary) -> void:
	_log_info("[signal] edge_connected slot=%s %d->%d" % [slot, int(edge.get("from", -1)), int(edge.get("to", -1))])


func _on_state_graph_changed(slot: String, graph: Dictionary) -> void:
	var prompts: Array = graph.get("prompts", [])
	var edges: Array = graph.get("edges", [])
	_log_info("[signal] graph_changed slot=%s nodes=%d edges=%d" % [slot, prompts.size(), edges.size()])


func _log_info(message: String) -> void:
	info_label.append_text("[color=white]%s[/color]\n" % message)
	print("[MemoryTest] %s" % message)


func _log_success(message: String) -> void:
	info_label.append_text("[color=green]%s[/color]\n" % message)
	print("[MemoryTest] %s" % message)


func _log_error(message: String) -> void:
	info_label.append_text("[color=red]%s[/color]\n" % message)
	print("[MemoryTest] ERROR: %s" % message)


func _log_data(message: String) -> void:
	info_label.append_text("[color=cyan]%s[/color]\n" % message)
	print("[MemoryTest] %s" % message)
