extends Control

const PROMPT_NODE_SCENE: PackedScene = preload("res://scenes/test/memory/prompt_memory_node.tscn")


const SIDE_PANEL_WIDTH: float = 360.0
const TOP_BAR_HEIGHT: float = 78.0
const GRAPH_PADDING: float = 18.0

var _title_label: Label
var _add_button: Button
var _export_button: Button

var _side_panel: PanelContainer
var _prompt_edit: LineEdit
var _weight_slider: HSlider
var _weight_value_label: Label
var _connected_button: CheckButton
var _delete_button: Button
var _api_output: RichTextLabel

var _prompt_nodes: Array[PromptMemoryNode] = []
var _selected_node: PromptMemoryNode
var _next_prompt_id: int = 1
var _anim_time: float = 0.0


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
	var top_bar := PanelContainer.new()
	top_bar.name = "TopBar"
	add_child(top_bar)

	var top_style := StyleBoxFlat.new()
	top_style.bg_color = Color("0f1726")
	top_style.corner_radius_bottom_left = 20
	top_style.corner_radius_bottom_right = 20
	top_style.border_width_bottom = 1
	top_style.border_color = Color("2c364d")
	top_bar.add_theme_stylebox_override("panel", top_style)

	var top_margin := MarginContainer.new()
	top_margin.add_theme_constant_override("margin_left", 20)
	top_margin.add_theme_constant_override("margin_right", 20)
	top_margin.add_theme_constant_override("margin_top", 16)
	top_margin.add_theme_constant_override("margin_bottom", 12)
	top_bar.add_child(top_margin)

	var top_row := HBoxContainer.new()
	top_row.alignment = BoxContainer.ALIGNMENT_CENTER
	top_row.add_theme_constant_override("separation", 12)
	top_margin.add_child(top_row)

	_title_label = Label.new()
	_title_label.text = "Agent 短期记忆图"
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title_label.add_theme_font_size_override("font_size", 24)
	_title_label.add_theme_color_override("font_color", Color("dce8ff"))
	top_row.add_child(_title_label)

	_add_button = _create_action_button("+ 添加提示词")
	_add_button.pressed.connect(_on_add_prompt_pressed)
	top_row.add_child(_add_button)

	_export_button = _create_action_button("导出 API")
	_export_button.pressed.connect(_on_export_pressed)
	top_row.add_child(_export_button)

	_side_panel = PanelContainer.new()
	_side_panel.name = "SidePanel"
	add_child(_side_panel)

	var side_style := StyleBoxFlat.new()
	side_style.bg_color = Color("111a2c")
	side_style.corner_radius_top_left = 20
	side_style.border_width_left = 1
	side_style.border_color = Color("2d3750")
	_side_panel.add_theme_stylebox_override("panel", side_style)

	var side_margin := MarginContainer.new()
	side_margin.add_theme_constant_override("margin_left", 16)
	side_margin.add_theme_constant_override("margin_right", 16)
	side_margin.add_theme_constant_override("margin_top", 18)
	side_margin.add_theme_constant_override("margin_bottom", 18)
	_side_panel.add_child(side_margin)

	var side_layout := VBoxContainer.new()
	side_layout.add_theme_constant_override("separation", 12)
	side_margin.add_child(side_layout)

	var panel_title := Label.new()
	panel_title.text = "提示词控制台"
	panel_title.add_theme_font_size_override("font_size", 20)
	panel_title.add_theme_color_override("font_color", Color("cfe0ff"))
	side_layout.add_child(panel_title)

	_prompt_edit = LineEdit.new()
	_prompt_edit.placeholder_text = "提示词文本"
	_prompt_edit.text_submitted.connect(_on_prompt_text_submitted)
	_prompt_edit.text_changed.connect(_on_prompt_text_changed)
	side_layout.add_child(_prompt_edit)

	var weight_title := Label.new()
	weight_title.text = "权重 (0 ~ 1)"
	side_layout.add_child(weight_title)

	_weight_slider = HSlider.new()
	_weight_slider.min_value = 0.0
	_weight_slider.max_value = 1.0
	_weight_slider.step = 0.01
	_weight_slider.value_changed.connect(_on_weight_changed)
	side_layout.add_child(_weight_slider)

	_weight_value_label = Label.new()
	_weight_value_label.text = "0.50"
	side_layout.add_child(_weight_value_label)

	_connected_button = CheckButton.new()
	_connected_button.text = "连接到 Agent（勾选才生效）"
	_connected_button.toggled.connect(_on_connected_toggled)
	side_layout.add_child(_connected_button)

	_delete_button = _create_action_button("删除当前提示词")
	_delete_button.pressed.connect(_on_delete_pressed)
	side_layout.add_child(_delete_button)

	var sep := HSeparator.new()
	side_layout.add_child(sep)

	var api_title := Label.new()
	api_title.text = "API 输出（仅连接节点）"
	api_title.add_theme_color_override("font_color", Color("9ac4ff"))
	side_layout.add_child(api_title)

	_api_output = RichTextLabel.new()
	_api_output.fit_content = false
	_api_output.scroll_following = true
	_api_output.bbcode_enabled = false
	_api_output.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_api_output.custom_minimum_size = Vector2(0, 260)
	side_layout.add_child(_api_output)

	_layout_ui()


func _layout_ui() -> void:
	var viewport_size := size
	var top_bar := get_node_or_null("TopBar") as Control
	if top_bar:
		top_bar.position = Vector2.ZERO
		top_bar.size = Vector2(viewport_size.x, TOP_BAR_HEIGHT)

	if _side_panel:
		_side_panel.position = Vector2(viewport_size.x - SIDE_PANEL_WIDTH, TOP_BAR_HEIGHT)
		_side_panel.size = Vector2(SIDE_PANEL_WIDTH, viewport_size.y - TOP_BAR_HEIGHT)


func _create_action_button(text_value: String) -> Button:
	var button := Button.new()
	button.text = text_value
	button.custom_minimum_size = Vector2(120, 40)

	var style := StyleBoxFlat.new()
	style.bg_color = Color("1f3559")
	style.corner_radius_top_left = 14
	style.corner_radius_top_right = 14
	style.corner_radius_bottom_right = 14
	style.corner_radius_bottom_left = 14
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = Color("4f8cff")

	var hover_style := style.duplicate()
	hover_style.bg_color = Color("2a4b79")

	button.add_theme_stylebox_override("normal", style)
	button.add_theme_stylebox_override("hover", hover_style)
	button.add_theme_stylebox_override("pressed", hover_style)
	button.add_theme_color_override("font_color", Color("e8f2ff"))

	return button


func _create_demo_nodes() -> void:
	_create_prompt_node("角色语气：温柔且有边界感", 0.92, true)
	_create_prompt_node("先确认用户目标再行动", 0.85, true)
	_create_prompt_node("回复风格：简洁优先", 0.64, false)
	_create_prompt_node("避免在UI层直接改数据", 0.70, true)


func _create_prompt_node(prompt: String, weight: float, connected: bool) -> void:
	var node := PROMPT_NODE_SCENE.instantiate() as PromptMemoryNode
	node.prompt_id = _next_prompt_id
	_next_prompt_id += 1
	node.set_prompt_text(prompt)
	node.set_weight(weight)
	node.set_connected(connected)
	node.selected.connect(_on_prompt_selected)
	node.moved.connect(_on_prompt_moved)
	node.connect_toggled.connect(_on_prompt_connect_toggled)
	add_child(node)

	var graph_rect := _get_graph_rect()
	var center := graph_rect.position + graph_rect.size * 0.5
	var angle := randf() * TAU
	var radius := minf(graph_rect.size.x, graph_rect.size.y) * 0.32 + randf() * 40.0
	var pos := center + Vector2(cos(angle), sin(angle)) * radius - node.custom_minimum_size * 0.5
	node.position = pos
	_clamp_node_to_graph(node)

	_prompt_nodes.append(node)
	_select_node(node)


func _select_node(node: PromptMemoryNode) -> void:
	_selected_node = node
	_update_inspector()
	queue_redraw()


func _update_inspector() -> void:
	var has_selection := _selected_node != null
	_prompt_edit.editable = has_selection
	_weight_slider.editable = has_selection
	_connected_button.disabled = not has_selection
	_delete_button.disabled = not has_selection

	if not has_selection:
		_prompt_edit.text = ""
		_weight_slider.value = 0.0
		_weight_value_label.text = "-"
		_connected_button.button_pressed = false
		return

	_prompt_edit.text = _selected_node.prompt_text
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

	var pulse := 0.5 + 0.5 * sin(_anim_time * 2.2)
	draw_circle(center, 72.0 + pulse * 6.0, Color(0.30, 0.60, 1.0, 0.12))
	draw_circle(center, 58.0, Color("214372"))
	draw_circle(center, 54.0, Color("2c5e9f"))
	draw_circle(center, 36.0, Color("8cd0ff"))

	var font := ThemeDB.fallback_font
	var font_size := 20
	var text := "AGENT"
	var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	draw_string(font, center - Vector2(text_size.x * 0.5, -7), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color("0b1e38"))


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
	_create_prompt_node("新提示词 %d" % _next_prompt_id, 0.50, false)
	_update_api_output()


func _on_export_pressed() -> void:
	_update_api_output(true)


func _on_delete_pressed() -> void:
	if _selected_node == null:
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
	if _selected_node == null:
		return
	_selected_node.set_prompt_text(new_text)
	_update_api_output()


func _on_prompt_text_submitted(new_text: String) -> void:
	_on_prompt_text_changed(new_text)


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
			"prompt": node.prompt_text,
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
