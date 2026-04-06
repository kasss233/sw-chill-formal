extends Control

const SIDE_PANEL_WIDTH: float = 360.0
const TOP_BAR_HEIGHT: float = 78.0
const GRAPH_PADDING: float = 18.0

var _title_label: Label
var _add_button: Button
var _export_button: Button

var _graph_layer: Control
var _agent_hub: Control
var _side_panel: PanelContainer
var _prompt_edit: LineEdit
var _prompt_body_edit: TextEdit
var _weight_slider: HSlider
var _weight_value_label: Label
var _connected_button: CheckButton
var _delete_button: Button
var _api_output: RichTextLabel
var _json_import_edit: TextEdit
var _apply_json_button: Button

var _prompt_nodes: Array[PromptMemoryNode] = []
var _selected_node: PromptMemoryNode
var _next_prompt_id: int = 1
var _anim_time: float = 0.0
var _syncing_inspector: bool = false
## 批量导入时强制卡片为「只读布局」（正文常显）；只读场景会临时置 true。拖拽/悬停仍可用，数据改不改由 [member PromptMemoryNode.is_mutable] 决定。
var _batch_node_display_only: bool = false
## 卡片之间的展示用有向边，`from` / `to` 为 [member PromptMemoryNode.prompt_id]。仅绘制，不参与编辑。
var _inter_node_edges: Array[Dictionary] = []


func _ready() -> void:
	set_process(true)
	mouse_filter = Control.MOUSE_FILTER_PASS
	_build_ui()
	_create_demo_nodes()
	_update_inspector()
	_update_api_output()


func _process(delta: float) -> void:
	_anim_time += delta
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_layout_ui()
		_clamp_all_nodes_to_graph()
		queue_redraw()


func _draw() -> void:
	_draw_background()
	_draw_graph_network()


func _build_ui() -> void:
	# 图心、顶栏、侧栏均在 memory.tscn 中搭建，此处只做引用与信号连接。
	_graph_layer = $GraphLayer as Control
	_graph_layer.mouse_filter = Control.MOUSE_FILTER_PASS
	_agent_hub = $GraphLayer/AgentHub as Control
	if is_instance_valid(_agent_hub) and _agent_hub.get_parent() == _graph_layer:
		_graph_layer.move_child(_agent_hub, 0)

	_title_label = $TopBar/MarginContainer/HBoxContainer/MainTitleLabel
	_add_button = $TopBar/MarginContainer/HBoxContainer/AddButton
	_export_button = $TopBar/MarginContainer/HBoxContainer/ExportButton
	_side_panel = $SidePanel
	var vbox := $SidePanel/MarginContainer/VBoxContainer
	_prompt_edit = vbox.get_node("PromptEdit") as LineEdit
	_prompt_body_edit = vbox.get_node("PromptBodyEdit") as TextEdit
	_weight_slider = vbox.get_node("WeightSlider") as HSlider
	_weight_value_label = vbox.get_node("WeightValueLabel") as Label
	_connected_button = vbox.get_node("ConnectedButton") as CheckButton
	_delete_button = vbox.get_node("DeleteButton") as Button
	_api_output = vbox.get_node("ApiOutput") as RichTextLabel
	_json_import_edit = vbox.get_node("JsonImportEdit") as TextEdit
	_apply_json_button = vbox.get_node("ApplyJsonButton") as Button

	_add_button.pressed.connect(_on_add_prompt_pressed)
	_export_button.pressed.connect(_on_export_pressed)
	_delete_button.pressed.connect(_on_delete_pressed)
	_prompt_edit.text_submitted.connect(_on_prompt_text_submitted)
	_prompt_edit.text_changed.connect(_on_prompt_text_changed)
	_prompt_body_edit.text_changed.connect(_on_prompt_body_changed)
	_weight_slider.value_changed.connect(_on_weight_changed)
	_connected_button.toggled.connect(_on_connected_toggled)
	_apply_json_button.pressed.connect(_on_apply_json_pressed)

	_layout_ui()


func _layout_ui() -> void:
	var viewport_size := size
	if _graph_layer:
		_graph_layer.position = Vector2.ZERO
		_graph_layer.size = viewport_size
	var top_bar := get_node_or_null("TopBar") as Control
	if top_bar:
		top_bar.position = Vector2.ZERO
		top_bar.size = Vector2(viewport_size.x, TOP_BAR_HEIGHT)

	if _side_panel:
		_side_panel.position = Vector2(viewport_size.x - SIDE_PANEL_WIDTH, TOP_BAR_HEIGHT)
		_side_panel.size = Vector2(SIDE_PANEL_WIDTH, viewport_size.y - TOP_BAR_HEIGHT)

	_layout_agent_hub()


func _layout_agent_hub() -> void:
	if not is_instance_valid(_agent_hub):
		return
	var gr := _get_graph_rect()
	var hub_size: Vector2 = _agent_hub.size
	if hub_size.x < 1.0 or hub_size.y < 1.0:
		hub_size = _agent_hub.custom_minimum_size
		_agent_hub.size = hub_size
	_agent_hub.position = gr.position + gr.size * 0.5 - hub_size * 0.5


func _create_demo_nodes() -> void:
	var r := apply_memory_graph_from_dict(_demo_memory_export_dict())
	if not r.get("ok", false):
		push_warning("[Memory] 演示数据加载失败：%s" % str(r.get("error", "")))
		return
	_apply_random_lit_demo_effects()


func _demo_memory_export_dict() -> Dictionary:
	return {
		"prompts": [
			{"id": 1, "title": "角色语气", "body": "对话时语调柔和自然；涉及隐私或原则问题时需明确边界并简短说明原因。", "weight": 0.92, "connected": true, "mutable": true},
			{"id": 2, "title": "先确认目标", "body": "在执行多步操作前，用一两句话复述或确认用户意图，避免跑偏。", "weight": 0.85, "connected": true, "mutable": true},
			{"id": 3, "title": "回复风格：简洁", "body": "优先短句与要点，避免冗长套话。", "weight": 0.64, "connected": false, "mutable": true},
			{"id": 4, "title": "架构：数据经 State", "body": "所有数据变更必须通过对应 XxxState 单例 API；UI 只响应信号刷新，禁止直接改数据字段。", "weight": 0.70, "connected": true, "mutable": true},
			{"id": 5, "title": "【系统】只读展示", "body": "此条由系统注入，仅展示；用户不可在侧栏修改或删除。", "weight": 0.55, "connected": true, "mutable": false},
			{"id": 6, "title": "【演出】流光 · 常亮", "body": "进入场景时即点亮，与未发光卡片对照。", "weight": 0.78, "connected": true, "mutable": true},
			{"id": 7, "title": "【演出】流光 · 渐亮", "body": "约 0.85s 后淡入点亮，演示 set_lit(true) 过渡。", "weight": 0.72, "connected": true, "mutable": true},
			{"id": 8, "title": "【演出】未点亮", "body": "默认不发光；可在侧栏选中后自行用代码 set_lit(true) 试验。", "weight": 0.66, "connected": false, "mutable": true}
		]
	}


## 演示用：在已成功导入的卡片中随机抽 2～4 张做流光（立即点亮或短时延迟点亮），其余保持未点亮。
func _apply_random_lit_demo_effects() -> void:
	if _prompt_nodes.is_empty():
		return
	var pool: Array = _prompt_nodes.duplicate()
	pool.shuffle()
	var lo := mini(2, pool.size())
	var hi := mini(4, pool.size())
	var k := randi_range(lo, hi)
	for i in k:
		var node: PromptMemoryNode = pool[i]
		if randf() < 0.55:
			node.set_lit(true, false)
		else:
			node.is_lit = false
			var delay := randf_range(0.45, 1.15)
			get_tree().create_timer(delay).timeout.connect(
				func () -> void:
					if is_instance_valid(node):
						node.set_lit(true, true)
			)


func _create_prompt_node(
	title: String,
	weight: float,
	connected: bool,
	mutable: bool = true,
	body: String = "",
	lit: bool = false,
	lit_delay_sec: float = -1.0,
	display_only: bool = false,
	place_index: int = -1,
	place_total: int = -1
) -> void:
	var node := PromptMemoryNode.create_from_content(title, body, weight, connected, mutable, display_only)
	if lit_delay_sec >= 0.0:
		node.is_lit = false
	else:
		node.is_lit = lit
	node.prompt_id = _next_prompt_id
	_next_prompt_id += 1
	node.selected.connect(_on_prompt_selected)
	node.moved.connect(_on_prompt_moved)
	node.connect_toggled.connect(_on_prompt_connect_toggled)
	_graph_layer.add_child(node)
	if lit_delay_sec >= 0.0:
		get_tree().create_timer(lit_delay_sec).timeout.connect(
			func () -> void:
				if is_instance_valid(node):
					node.set_lit(true)
		)

	if place_index >= 0 and place_total > 0:
		node.position = _compute_import_radial_position(place_index, place_total, node)
	else:
		var graph_rect := _get_graph_rect()
		var center := _get_agent_center()
		var angle := randf() * TAU
		var radius := minf(graph_rect.size.x, graph_rect.size.y) * 0.32 + randf() * 40.0
		var placement_half := node.get_combined_minimum_size() * 0.5
		if placement_half.x < 4.0 or placement_half.y < 4.0:
			placement_half = Vector2(48, 40)
		node.position = center + Vector2(cos(angle), sin(angle)) * radius - placement_half
	_clamp_node_to_graph(node)

	_prompt_nodes.append(node)
	_select_node(node)


func _compute_import_radial_position(index: int, total: int, node: Control) -> Vector2:
	var graph_rect := _get_graph_rect()
	var center := _get_agent_center()
	var radius := minf(graph_rect.size.x, graph_rect.size.y) * 0.34
	var angle := (float(index) / float(total)) * TAU - PI * 0.5
	var placement_half := node.get_combined_minimum_size() * 0.5
	if placement_half.x < 4.0 or placement_half.y < 4.0:
		placement_half = Vector2(48, 40)
	return center + Vector2(cos(angle), sin(angle)) * radius - placement_half


func _clear_all_prompt_nodes() -> void:
	_inter_node_edges.clear()
	for node in _prompt_nodes:
		if is_instance_valid(node):
			node.queue_free()
	_prompt_nodes.clear()
	_selected_node = null


func _parse_inter_node_edges_from_data(parsed: Variant) -> void:
	_inter_node_edges.clear()
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var d: Dictionary = parsed
	if not d.has("edges"):
		return
	var raw: Variant = d["edges"]
	if typeof(raw) != TYPE_ARRAY:
		return
	for e in raw:
		if typeof(e) == TYPE_DICTIONARY:
			_inter_node_edges.append({
				"from": int(e.get("from", -1)),
				"to": int(e.get("to", -1))
			})
		elif typeof(e) == TYPE_ARRAY:
			var arr: Array = e
			if arr.size() >= 2:
				_inter_node_edges.append({"from": int(arr[0]), "to": int(arr[1])})


func _find_node_by_prompt_id(p_id: int) -> PromptMemoryNode:
	for node in _prompt_nodes:
		if node.prompt_id == p_id:
			return node
	return null


## 与 [method _update_api_output] / [method agent_get_short_term_memory] 导出结构互逆：[br]
## 根对象可为：`prompts`（推荐，可逐项含 `connected` / `mutable`）、`connected_prompts`（默认已连接、可变）。[br]
## 根为数组时视为整表条目列表（等价于仅含 connected_prompts）。[br]
## 条目字段：`id`、`title`、`body`、`prompt`、`weight`；可选 `connected`（默认 true）、`mutable`（默认 true）、`display_only`。[br]
## 可选 `edges`：`[{"from": id, "to": id}, ...]` 或 `[[from, to], ...]`，表示记忆节点之间的展示关联（与 Agent 中心连线独立）。
func apply_memory_graph_from_export_json(json_text: String) -> Dictionary:
	var stripped := json_text.strip_edges()
	if stripped.is_empty():
		return {"ok": false, "error": "JSON 为空"}
	var parsed: Variant = JSON.parse_string(stripped)
	if parsed == null:
		return {"ok": false, "error": "JSON 解析失败"}
	return apply_memory_graph_from_parsed(parsed)


func apply_memory_graph_from_dict(data: Dictionary) -> Dictionary:
	return apply_memory_graph_from_parsed(data)


func apply_memory_graph_from_parsed(parsed: Variant) -> Dictionary:
	var items_res := _extract_prompt_items_array(parsed)
	if items_res.has("error"):
		return {"ok": false, "error": items_res["error"]}
	var items: Array = items_res["items"]
	for entry in items:
		if typeof(entry) != TYPE_DICTIONARY:
			return {"ok": false, "error": "每条目须为对象"}
	var n: int = items.size()
	_clear_all_prompt_nodes()
	if n == 0:
		_inter_node_edges.clear()
		_next_prompt_id = 1
		_update_inspector()
		_update_api_output()
		queue_redraw()
		return {"ok": true, "imported": 0}
	for i in n:
		var item: Dictionary = items[i]
		var title := str(item.get("title", "")).strip_edges()
		var body := str(item.get("body", "")).strip_edges()
		if title.is_empty() and body.is_empty():
			var split := _split_prompt_for_import(str(item.get("prompt", "")))
			title = split.title
			body = split.body
		var weight := float(item.get("weight", 0.5))
		var connected := true
		if item.has("connected"):
			connected = bool(item["connected"])
		var mutable := true
		if item.has("mutable"):
			mutable = bool(item["mutable"])
		var display_only_item := _batch_node_display_only
		if item.has("display_only"):
			display_only_item = bool(item["display_only"])
		_create_prompt_node(title, weight, connected, mutable, body, false, -1.0, display_only_item, i, n)
	for i in n:
		var item: Dictionary = items[i]
		if item.has("id"):
			_prompt_nodes[i].prompt_id = int(item["id"])
	_next_prompt_id = 1
	for node in _prompt_nodes:
		_next_prompt_id = maxi(_next_prompt_id, node.prompt_id + 1)
	_parse_inter_node_edges_from_data(parsed)
	_update_inspector()
	_update_api_output()
	queue_redraw()
	return {"ok": true, "imported": n}


func _extract_prompt_items_array(parsed: Variant) -> Dictionary:
	if typeof(parsed) == TYPE_ARRAY:
		return {"items": parsed}
	if typeof(parsed) != TYPE_DICTIONARY:
		return {"error": "根节点须为对象或数组"}
	var d: Dictionary = parsed
	if d.has("prompts"):
		var p: Variant = d["prompts"]
		if typeof(p) != TYPE_ARRAY:
			return {"error": "prompts 须为数组"}
		return {"items": p}
	if d.has("connected_prompts"):
		var c: Variant = d["connected_prompts"]
		if typeof(c) != TYPE_ARRAY:
			return {"error": "connected_prompts 须为数组"}
		return {"items": c}
	return {"error": "缺少 prompts 或 connected_prompts 数组"}


func _split_prompt_for_import(combined: String) -> Dictionary:
	var s := combined.strip_edges()
	if s.is_empty():
		return {"title": "未命名标题", "body": ""}
	var nl := s.find("\n")
	if nl == -1:
		return {"title": s, "body": ""}
	var t := s.substr(0, nl).strip_edges()
	var b := s.substr(nl + 1).strip_edges()
	if t.is_empty():
		t = "未命名标题"
	return {"title": t, "body": b}


func _on_apply_json_pressed() -> void:
	var result := apply_memory_graph_from_export_json(_json_import_edit.text)
	if not result.get("ok", false):
		push_warning("[Memory] JSON 导入失败：%s" % str(result.get("error", "未知错误")))
		print("[Memory] JSON 导入失败：", result.get("error", ""))
	else:
		print("[Memory] JSON 导入成功，卡片数：", result.get("imported", 0))


func _select_node(node: PromptMemoryNode) -> void:
	_selected_node = node
	if is_instance_valid(node) and node.get_parent() != null:
		node.move_to_front()
	_update_inspector()
	queue_redraw()


func _update_inspector() -> void:
	var has_selection := _selected_node != null
	var can_edit := has_selection and _selected_node.is_mutable
	_prompt_edit.editable = can_edit
	_prompt_body_edit.editable = can_edit
	_weight_slider.editable = can_edit
	_connected_button.disabled = not has_selection or not _selected_node.is_mutable
	_delete_button.disabled = not has_selection or not _selected_node.is_mutable

	if not has_selection:
		_syncing_inspector = true
		_prompt_edit.text = ""
		_prompt_body_edit.text = ""
		_syncing_inspector = false
		_weight_slider.value = 0.0
		_weight_value_label.text = "-"
		_connected_button.button_pressed = false
		return

	_syncing_inspector = true
	_prompt_edit.text = _selected_node.prompt_title
	_prompt_body_edit.text = _selected_node.prompt_body
	_syncing_inspector = false
	_weight_slider.value = _selected_node.weight
	_weight_value_label.text = "%.2f" % _selected_node.weight
	_connected_button.button_pressed = _selected_node.connected


func _get_graph_rect() -> Rect2:
	var width := size.x - SIDE_PANEL_WIDTH - GRAPH_PADDING * 2.0
	var height := size.y - TOP_BAR_HEIGHT - GRAPH_PADDING * 2.0
	return Rect2(
		Vector2(GRAPH_PADDING, TOP_BAR_HEIGHT + GRAPH_PADDING),
		Vector2(maxf(220.0, width), maxf(220.0, height))
	)


func _get_agent_center() -> Vector2:
	if is_instance_valid(_agent_hub):
		return _agent_hub.position + _agent_hub.size * 0.5
	var graph_rect := _get_graph_rect()
	return graph_rect.position + graph_rect.size * 0.5


func _draw_background() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("0b1220"), true)

	var graph_rect := _get_graph_rect()
	var graph_bg := Color("121e33")
	draw_rect(graph_rect, graph_bg, true)

	for x in range(int(graph_rect.position.x), int(graph_rect.end.x), 36):
		for y in range(int(graph_rect.position.y), int(graph_rect.end.y), 36):
			var p := Vector2(x, y)
			var dist := p.distance_to(_get_agent_center())
			var alpha := clampf(0.16 - dist / 2200.0, 0.03, 0.16)
			draw_circle(p, 1.2, Color(0.55, 0.67, 0.86, alpha))


func _draw_graph_network() -> void:
	_draw_inter_node_edges()
	var center := _get_agent_center()
	for node in _prompt_nodes:
		if not node.connected:
			continue

		var target := node.position + node.size * 0.5
		var line_energy := 0.45 + 0.35 * sin(_anim_time * 3.0 + float(node.prompt_id))
		var line_color := Color("6fd4ff").lerp(Color("96f0ff"), node.weight)
		line_color.a = clampf(line_energy, 0.25, 0.92)
		var width := 2.2 + node.weight * 3.4
		draw_line(center, target, line_color, width, true)

		var mid := center.lerp(target, 0.5 + 0.08 * sin(_anim_time * 2.4 + node.prompt_id))
		draw_circle(mid, 2.2 + node.weight * 2.5, Color(line_color.r, line_color.g, line_color.b, 0.65))


func _draw_inter_node_edges() -> void:
	for edge in _inter_node_edges:
		var from_id: int = int(edge.get("from", -1))
		var to_id: int = int(edge.get("to", -1))
		var a := _find_node_by_prompt_id(from_id)
		var b := _find_node_by_prompt_id(to_id)
		if a == null or b == null:
			continue
		var pa := a.position + a.size * 0.5
		var pb := b.position + b.size * 0.5
		var pulse := 0.35 + 0.12 * sin(_anim_time * 1.7 + float(from_id) * 0.31)
		var col := Color(0.42, 0.68, 0.92, pulse)
		draw_line(pa, pb, col, 1.9, true)
		var mid_e := pa.lerp(pb, 0.52 + 0.06 * sin(_anim_time * 2.1 + float(to_id)))
		draw_circle(mid_e, 2.0, Color(col.r, col.g, col.b, 0.55))


func _clamp_all_nodes_to_graph() -> void:
	for node in _prompt_nodes:
		_clamp_node_to_graph(node)


func _clamp_node_to_graph(node: PromptMemoryNode) -> void:
	var graph_rect := _get_graph_rect()
	var max_x := graph_rect.end.x - node.size.x
	var max_y := graph_rect.end.y - node.size.y
	node.position.x = clampf(node.position.x, graph_rect.position.x, max_x)
	node.position.y = clampf(node.position.y, graph_rect.position.y, max_y)


func _remove_prompt_node(node: PromptMemoryNode) -> void:
	_prompt_nodes.erase(node)
	node.queue_free()
	if _selected_node == node:
		_selected_node = null
	_update_inspector()
	_update_api_output()
	queue_redraw()


func _on_add_prompt_pressed() -> void:
	_create_prompt_node("新记忆 %d" % _next_prompt_id, 0.50, false, true, "")
	_update_api_output()


func _on_export_pressed() -> void:
	_update_api_output(true)


func _on_delete_pressed() -> void:
	if _selected_node == null:
		return
	if not _selected_node.is_mutable:
		return
	_remove_prompt_node(_selected_node)


func _on_prompt_selected(node: PromptMemoryNode) -> void:
	_select_node(node)


func _on_prompt_moved(node: PromptMemoryNode) -> void:
	_clamp_node_to_graph(node)
	queue_redraw()


func _on_prompt_connect_toggled(node: PromptMemoryNode) -> void:
	if _selected_node == node:
		_connected_button.button_pressed = node.connected
	_update_api_output()
	queue_redraw()


func _on_prompt_text_changed(new_text: String) -> void:
	if _syncing_inspector or _selected_node == null:
		return
	_selected_node.set_prompt_title(new_text)
	_update_api_output()


func _on_prompt_text_submitted(new_text: String) -> void:
	_on_prompt_text_changed(new_text)


func _on_prompt_body_changed() -> void:
	if _syncing_inspector or _selected_node == null:
		return
	_selected_node.set_prompt_body(_prompt_body_edit.text)
	_update_api_output()


func _on_weight_changed(new_value: float) -> void:
	_weight_value_label.text = "%.2f" % new_value
	if _selected_node == null:
		return
	_selected_node.set_weight(new_value)
	_update_api_output()
	queue_redraw()


func _on_connected_toggled(pressed: bool) -> void:
	if _selected_node == null:
		return
	_selected_node.set_connected(pressed)
	_update_api_output()
	queue_redraw()


func _update_api_output(log_to_console: bool = false) -> void:
	var data := {
		"connected_prompts": api_get_connected_prompt_weights(),
		"total_nodes": _prompt_nodes.size(),
		"active_nodes": api_get_connected_prompt_weights().size()
	}
	var json := JSON.stringify(data, "\t")
	_api_output.text = json
	if log_to_console:
		print("[Memory API] ", json)


# API：仅返回已连接（生效）的提示词与权重
func api_get_connected_prompt_weights() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for node in _prompt_nodes:
		if not node.connected:
			continue
		result.append({
			"id": node.prompt_id,
			"title": node.prompt_title,
			"body": node.prompt_body,
			"prompt": node.get_prompt_for_injection(),
			"weight": snappedf(node.weight, 0.01)
		})
	return result


# API：Agent 场景可直接调用，获取短期记忆上下文
func agent_get_short_term_memory() -> Dictionary:
	return {
		"connected_prompts": api_get_connected_prompt_weights(),
		"memory_strength": _calc_memory_strength()
	}


func api_get_connected_prompt_weights_json() -> String:
	return JSON.stringify(api_get_connected_prompt_weights(), "\t")


func _calc_memory_strength() -> float:
	var active := api_get_connected_prompt_weights()
	if active.is_empty():
		return 0.0
	var total := 0.0
	for item in active:
		total += item.get("weight", 0.0)
	return snappedf(total / active.size(), 0.01)
