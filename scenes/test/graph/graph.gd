extends Control

@onready var graph_edit: GraphEdit = $RootVBox/GraphEdit
@onready var node_title_input: LineEdit = $RootVBox/Toolbar/NodeTitleInput
@onready var from_node_option: OptionButton = $RootVBox/ConnectionToolbar/FromNodeOption
@onready var to_node_option: OptionButton = $RootVBox/ConnectionToolbar/ToNodeOption
@onready var rename_option: OptionButton = $RootVBox/Toolbar/RenameNodeOption
@onready var delete_option: OptionButton = $RootVBox/Toolbar/DeleteNodeOption

var _node_index: int = 1


func _ready() -> void:
	graph_edit.connection_request.connect(_on_connection_request)
	graph_edit.disconnection_request.connect(_on_disconnection_request)
	graph_edit.delete_nodes_request.connect(_on_delete_nodes_request)

	_create_demo_node("节点 1", Vector2(100, 120))
	_create_demo_node("节点 2", Vector2(460, 240))
	_refresh_node_options()


func _on_add_node_button_pressed() -> void:
	var title := node_title_input.text.strip_edges()
	if title.is_empty():
		title = "节点 %d" % _node_index
	_create_demo_node(title, Vector2(120 + (_node_index % 4) * 180, 90 + (_node_index % 3) * 140))
	node_title_input.clear()
	_refresh_node_options()


func _on_rename_node_button_pressed() -> void:
	var node_name := _get_selected_node_name(rename_option)
	if node_name.is_empty():
		return
	var new_title := node_title_input.text.strip_edges()
	if new_title.is_empty():
		return
	var node := graph_edit.get_node_or_null(NodePath(node_name)) as GraphNode
	if node == null:
		return
	node.title = new_title
	node_title_input.clear()


func _on_delete_node_button_pressed() -> void:
	var node_name := _get_selected_node_name(delete_option)
	if node_name.is_empty():
		return
	var node := graph_edit.get_node_or_null(NodePath(node_name))
	if node == null:
		return
	node.queue_free()
	_refresh_node_options()


func _on_connect_button_pressed() -> void:
	var from_name := _get_selected_node_name(from_node_option)
	var to_name := _get_selected_node_name(to_node_option)
	if from_name.is_empty() or to_name.is_empty() or from_name == to_name:
		return
	if graph_edit.is_node_connected(from_name, 0, to_name, 0):
		return
	graph_edit.connect_node(from_name, 0, to_name, 0)


func _on_disconnect_button_pressed() -> void:
	var from_name := _get_selected_node_name(from_node_option)
	var to_name := _get_selected_node_name(to_node_option)
	if from_name.is_empty() or to_name.is_empty() or from_name == to_name:
		return
	if not graph_edit.is_node_connected(from_name, 0, to_name, 0):
		return
	graph_edit.disconnect_node(from_name, 0, to_name, 0)


func _on_clear_button_pressed() -> void:
	for child in graph_edit.get_children():
		if child is GraphNode:
			child.queue_free()
	_refresh_node_options()


func _on_connection_request(from_node: StringName, from_port: int, to_node: StringName, to_port: int) -> void:
	if from_node == to_node:
		return
	if graph_edit.is_node_connected(from_node, from_port, to_node, to_port):
		return
	graph_edit.connect_node(from_node, from_port, to_node, to_port)


func _on_disconnection_request(from_node: StringName, from_port: int, to_node: StringName, to_port: int) -> void:
	if not graph_edit.is_node_connected(from_node, from_port, to_node, to_port):
		return
	graph_edit.disconnect_node(from_node, from_port, to_node, to_port)


func _on_delete_nodes_request(nodes: Array[StringName]) -> void:
	for node_name in nodes:
		var node := graph_edit.get_node_or_null(NodePath(String(node_name)))
		if node != null:
			node.queue_free()
	_refresh_node_options()


func _create_demo_node(title: String, position: Vector2) -> void:
	var node := GraphNode.new()
	node.name = "GraphNode_%d" % _node_index
	node.title = title
	node.position_offset = position
	node.custom_minimum_size = Vector2(190, 110)
	node.resizable = true

	# 双向端口：左侧输入、右侧输出
	node.set("slot/0/left_enabled", true)
	node.set("slot/0/left_type", 0)
	node.set("slot/0/left_color", Color.SKY_BLUE)
	node.set("slot/0/right_enabled", true)
	node.set("slot/0/right_type", 0)
	node.set("slot/0/right_color", Color.SEA_GREEN)
	node.set("slot/0/draw_stylebox", true)

	var label := Label.new()
	label.text = "可拖拽节点，可通过端口连线"
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	node.add_child(label)

	graph_edit.add_child(node)
	_node_index += 1


func _refresh_node_options() -> void:
	var names: Array[String] = []
	for child in graph_edit.get_children():
		if child is GraphNode:
			names.append(child.name)

	names.sort()

	_fill_option(from_node_option, names)
	_fill_option(to_node_option, names)
	_fill_option(rename_option, names)
	_fill_option(delete_option, names)


func _fill_option(option_button: OptionButton, names: Array[String]) -> void:
	if option_button == null:
		return
	option_button.clear()
	for node_name in names:
		option_button.add_item(node_name)


func _get_selected_node_name(option_button: OptionButton) -> String:
	if option_button.item_count <= 0:
		return ""
	return option_button.get_item_text(option_button.selected)
