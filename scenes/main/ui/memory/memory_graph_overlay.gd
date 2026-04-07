extends Control

@export var memory_root_path: NodePath = ^"../../.."

var _memory_root: Node


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_memory_root = get_node_or_null(memory_root_path)
	set_process(true)


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if _memory_root == null:
		return
	if not _memory_root.has_method("get_graph_overlay_data"):
		return
	var data: Variant = _memory_root.call("get_graph_overlay_data")
	if typeof(data) != TYPE_DICTIONARY:
		return
	var d: Dictionary = data
	var center: Vector2 = d.get("center", Vector2.ZERO)
	var anim_time: float = float(d.get("anim_time", 0.0))
	var nodes: Array = d.get("nodes", [])
	var edges: Array = d.get("edges", [])

	_draw_inter_edges(edges, nodes, anim_time)
	_draw_agent_edges(center, nodes, anim_time)


func _draw_agent_edges(center: Vector2, nodes: Array, anim_time: float) -> void:
	for n in nodes:
		if typeof(n) != TYPE_DICTIONARY:
			continue
		var nd: Dictionary = n
		if not bool(nd.get("connected", false)):
			continue
		var pos: Vector2 = nd.get("position", Vector2.ZERO)
		var sz: Vector2 = nd.get("size", Vector2.ZERO)
		var target := pos + sz * 0.5
		var node_id: int = int(nd.get("id", 0))
		var weight: float = float(nd.get("weight", 0.5))
		var line_energy := 0.45 + 0.35 * sin(anim_time * 3.0 + float(node_id))
		var line_color := Color("6fd4ff").lerp(Color("96f0ff"), weight)
		line_color.a = clampf(line_energy, 0.25, 0.92)
		var width := 2.2 + weight * 3.4
		draw_line(center, target, line_color, width, true)
		var mid := center.lerp(target, 0.5 + 0.08 * sin(anim_time * 2.4 + node_id))
		draw_circle(mid, 2.2 + weight * 2.5, Color(line_color.r, line_color.g, line_color.b, 0.65))


func _draw_inter_edges(edges: Array, nodes: Array, anim_time: float) -> void:
	for edge in edges:
		if typeof(edge) != TYPE_DICTIONARY:
			continue
		var e: Dictionary = edge
		var from_id: int = int(e.get("from", -1))
		var to_id: int = int(e.get("to", -1))
		var a: Vector2 = _find_node_center(nodes, from_id)
		var b: Vector2 = _find_node_center(nodes, to_id)
		if a == Vector2.INF or b == Vector2.INF:
			continue
		var pulse := 0.35 + 0.12 * sin(anim_time * 1.7 + float(from_id) * 0.31)
		var col := Color(0.42, 0.68, 0.92, pulse)
		draw_line(a, b, col, 1.9, true)
		var mid_e: Vector2 = a.lerp(b, 0.52 + 0.06 * sin(anim_time * 2.1 + float(to_id)))
		draw_circle(mid_e, 2.0, Color(col.r, col.g, col.b, 0.55))


func _find_node_center(nodes: Array, target_id: int) -> Vector2:
	for n in nodes:
		if typeof(n) != TYPE_DICTIONARY:
			continue
		var nd: Dictionary = n
		if int(nd.get("id", -1)) != target_id:
			continue
		var pos: Vector2 = nd.get("position", Vector2.ZERO)
		var sz: Vector2 = nd.get("size", Vector2.ZERO)
		return pos + sz * 0.5
	return Vector2.INF
