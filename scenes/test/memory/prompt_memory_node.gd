extends PanelContainer
class_name PromptMemoryNode

signal selected(node: PromptMemoryNode)
signal moved(node: PromptMemoryNode)
signal connect_toggled(node: PromptMemoryNode)

var prompt_id: int = -1
var prompt_text: String = ""
var weight: float = 0.5
var connected: bool = false

var _title_label: Label
var _state_label: Label
var _dragging: bool = false
var _drag_offset: Vector2 = Vector2.ZERO
var _hover_tween: Tween

@onready var _margin: MarginContainer = $Margin
@onready var _layout: VBoxContainer = $Margin/Layout
@onready var _title_label_node: Label = $Margin/Layout/TitleLabel
@onready var _state_label_node: Label = $Margin/Layout/StateLabel


func _ready() -> void:
	custom_minimum_size = Vector2(200, 86)
	mouse_filter = Control.MOUSE_FILTER_STOP
	pivot_offset = custom_minimum_size * 0.5
	_title_label = _title_label_node
	_state_label = _state_label_node

	_refresh_visuals()
	scale = Vector2(0.88, 0.88)
	modulate.a = 0.0
	var intro := create_tween().set_parallel(true)
	intro.tween_property(self , "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	intro.tween_property(self , "modulate:a", 1.0, 0.22).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_dragging = true
				_drag_offset = event.position
				emit_signal("selected", self )
			else:
				_dragging = false
				emit_signal("moved", self )
				accept_event()
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			toggle_connected()
			accept_event()
	elif event is InputEventMouseMotion and _dragging:
		position += event.position - _drag_offset
		emit_signal("moved", self )
		accept_event()


func _on_mouse_entered() -> void:
	if _hover_tween:
		_hover_tween.kill()
	_hover_tween = create_tween()
	_hover_tween.tween_property(self , "scale", Vector2(1.03, 1.03), 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _on_mouse_exited() -> void:
	if _hover_tween:
		_hover_tween.kill()
	_hover_tween = create_tween()
	_hover_tween.tween_property(self , "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _enter_tree() -> void:
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)


func set_prompt_text(value: String) -> void:
	prompt_text = value.strip_edges()
	if prompt_text.is_empty():
		prompt_text = "未命名提示词"
	_refresh_visuals()


func set_weight(value: float) -> void:
	weight = clampf(value, 0.0, 1.0)
	_refresh_visuals()


func set_connected(value: bool) -> void:
	connected = value
	_refresh_visuals()


func toggle_connected() -> void:
	connected = not connected
	_refresh_visuals()
	emit_signal("connect_toggled", self )


func _refresh_visuals() -> void:
	if not is_inside_tree():
		return

	_title_label.text = prompt_text
	if connected:
		_state_label.text = "已连接  |  权重 %.2f" % weight
		_state_label.modulate = Color("8dd9ff")
	else:
		_state_label.text = "未连接（不生效）  |  权重 %.2f" % weight
		_state_label.modulate = Color("8e97aa")
