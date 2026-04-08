extends MemoryModuleBase

func _get_memory_graph_slot() -> String:
	return "immutable"


func _ready() -> void:
	set_process(true)
	mouse_filter = Control.MOUSE_FILTER_PASS
	_build_ui()
	_bind_memory_state_signal()
	_create_demo_nodes()


func _build_ui() -> void:
	_graph_layer = get_node_or_null(graph_layer_path) as Control
	if _graph_layer == null:
		push_error("[MemoryImmutable] 未绑定 GraphLayer 节点")
		return
	_graph_layer.mouse_filter = Control.MOUSE_FILTER_PASS
	_move_bounds = get_node_or_null(move_bounds_path) as Control
	_graph_overlay = _graph_layer.get_node_or_null("GraphOverlay") as Control
	_agent_hub = get_node_or_null(agent_hub_path) as Control
	# 连线在最底层，AgentHub（圆环）叠在其上；记忆卡片由 add_child 追加在后，保证可点选。
	if is_instance_valid(_graph_overlay) and _graph_overlay.get_parent() == _graph_layer:
		_graph_layer.move_child(_graph_overlay, 0)
	if is_instance_valid(_agent_hub) and _agent_hub.get_parent() == _graph_layer:
		_graph_layer.move_child(_agent_hub, 1)
	_layout_ui()


func _layout_ui() -> void:
	if _graph_layer:
		_graph_layer.position = Vector2.ZERO
	_layout_agent_hub()


func _layout_agent_hub() -> void:
	# 只读场景中 AgentHub 位置以 tscn 手工布局为准，不做运行时自动居中。
	pass


func _get_graph_rect() -> Rect2:
	if is_instance_valid(_move_bounds):
		return Rect2(_move_bounds.position, _move_bounds.size)
	var width := size.x - GRAPH_PADDING * 2.0
	var height := size.y - GRAPH_PADDING * 2.0
	return Rect2(
		Vector2(GRAPH_PADDING, GRAPH_PADDING),
		Vector2(maxf(220.0, width), maxf(220.0, height))
	)


func _update_inspector() -> void:
	pass


func _update_api_output(_log_to_console: bool = false) -> void:
	pass


func _select_node(node: PromptMemoryNode) -> void:
	_selected_node = node
	if is_instance_valid(node) and node.get_parent() != null:
		node.move_to_front()
	queue_redraw()


func _create_demo_nodes() -> void:
	var r := apply_memory_graph_from_dict(MemoryState.get_immutable_graph())
	if not r.get("ok", false):
		push_warning("[MemoryImmutable] 演示数据加载失败：%s" % str(r.get("error", "")))
		return
