extends PanelContainer
class_name PromptMemoryNode

signal selected(node: PromptMemoryNode)
signal moved(node: PromptMemoryNode)
signal connect_toggled(node: PromptMemoryNode)
signal content_changed(node: PromptMemoryNode)
signal delete_requested(node: PromptMemoryNode)

## 是否允许用户通过控制台等途径修改内容、权重、连接与删除（展示用记忆可关）。
@export var is_mutable: bool = true

@export_group("演出")
## 已点亮：边缘 RGB 流光（与 FrostedPanel / aiglow 同源逻辑）；未点亮：关闭流光。运行时请优先用 [method set_lit] 以控制是否播放过渡。
@export var is_lit: bool = false

var prompt_id: int = -1
## 卡片顶部标题（短句，用于列表识别）。
var prompt_title: String = ""
## 状态行下方的正文，注入 Agent 时的主要描述内容。
var prompt_body: String = ""
var weight: float = 0.5
var connected: bool = false

var _body_expanded: bool = false

var _title_label: Label
var _state_label: Label
var _body_label: Label
var _body_toggle_row: HBoxContainer
var _body_toggle_button: Button
var _title_edit: LineEdit
var _body_edit: TextEdit
var _delete_inline_button: Button
var _dragging: bool = false
var _drag_offset: Vector2 = Vector2.ZERO
var _hover_tween: Tween
var _editing_title: bool = false
var _editing_body: bool = false

@onready var _title_label_node: Label = $Center/Margin/Layout/TitleLabel
@onready var _state_label_node: Label = $Center/Margin/Layout/StateLabel
@onready var _body_toggle_row_node: HBoxContainer = $Center/Margin/Layout/BodyToggleRow
@onready var _body_toggle_button_node: Button = $Center/Margin/Layout/BodyToggleRow/BodyToggleButton
@onready var _body_label_node: Label = $Center/Margin/Layout/BodyLabel
@onready var _title_edit_node: LineEdit = $Center/Margin/Layout/TitleEdit
@onready var _body_edit_node: TextEdit = $Center/Margin/Layout/BodyEdit
@onready var _delete_inline_button_node: Button = $Center/Margin/Layout/DeleteInlineButton
@onready var _glow_overlay: ColorRect = $GlowOverlay

var _glow_material: ShaderMaterial
var _glow_intensity: float = 0.0
var _glow_tween: Tween


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_init_glow_overlay()
	_title_label = _title_label_node
	_state_label = _state_label_node
	_body_label = _body_label_node
	_body_toggle_row = _body_toggle_row_node
	_body_toggle_button = _body_toggle_button_node
	_title_edit = _title_edit_node
	_body_edit = _body_edit_node
	_delete_inline_button = _delete_inline_button_node
	_body_toggle_button.pressed.connect(_on_body_toggle_pressed)
	_title_edit.text_submitted.connect(_on_title_edit_submitted)
	_title_edit.focus_exited.connect(_commit_title_edit)
	_body_edit.focus_exited.connect(_commit_body_edit)
	_delete_inline_button.pressed.connect(_on_delete_inline_pressed)
	_body_toggle_button.add_theme_color_override("font_color", Color("8eb6e8"))
	_body_toggle_button.add_theme_color_override("font_hover_color", Color("b5d4ff"))
	_body_toggle_button.add_theme_color_override("font_pressed_color", Color("6a9fd4"))
	_update_pivot()

	_refresh_visuals()
	scale = Vector2(0.88, 0.88)
	modulate.a = 0.0
	var intro := create_tween().set_parallel(true)
	intro.tween_property(self , "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	intro.tween_property(self , "modulate:a", 1.0, 0.22).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_update_pivot()
		_update_glow_size()
	elif what == NOTIFICATION_VISIBILITY_CHANGED:
		if visible:
			call_deferred("_refresh_visuals")


func _init_glow_overlay() -> void:
	if not is_instance_valid(_glow_overlay):
		return
	var base_mat := _glow_overlay.material as ShaderMaterial
	if base_mat:
		_glow_material = base_mat.duplicate() as ShaderMaterial
		_glow_overlay.material = _glow_material
	else:
		_glow_material = null
	_update_glow_size()
	_apply_lit_visual(false)


func _update_glow_size() -> void:
	if _glow_material:
		_glow_material.set_shader_parameter("size", size)


## 演出用：切换点亮状态；[param animated] 为 false 时立即到位。
func set_lit(value: bool, animated: bool = true) -> void:
	var v := value
	if is_lit == v:
		return
	is_lit = v
	_apply_lit_visual(animated)


func _apply_lit_visual(animated: bool) -> void:
	if not _glow_material:
		return
	if _glow_tween:
		_glow_tween.kill()
		_glow_tween = null
	var target := 1.0 if is_lit else 0.0
	if not animated:
		_set_glow_intensity(target)
		return
	if not is_inside_tree():
		_set_glow_intensity(target)
		return
	_glow_tween = create_tween()
	if is_lit:
		_glow_tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		_glow_tween.tween_method(_set_glow_intensity, _glow_intensity, 1.0, 0.4)
	else:
		_glow_tween.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
		_glow_tween.tween_method(_set_glow_intensity, _glow_intensity, 0.0, 0.6)


func _set_glow_intensity(v: float) -> void:
	_glow_intensity = v
	if _glow_material:
		_glow_material.set_shader_parameter("glow_intensity", v)


func _update_pivot() -> void:
	if size.x > 0.0 and size.y > 0.0:
		pivot_offset = size * 0.5


static func create_from_content(
	title: String,
	body: String = "",
	weight_value: float = 0.5,
	connected_value: bool = false,
	mutable: bool = true
) -> PromptMemoryNode:
	var packed := load("res://scenes/test/memory/prompt_memory_node.tscn") as PackedScene
	var node := packed.instantiate() as PromptMemoryNode
	node._configure_content(title.strip_edges(), body.strip_edges(), weight_value, connected_value)
	node.is_mutable = mutable
	return node


## 合并标题与正文，供提示词拼接（标题非空时顶格一行，正文另起段落）。
func get_prompt_for_injection() -> String:
	var t := prompt_title.strip_edges()
	var b := prompt_body.strip_edges()
	if t.is_empty() and b.is_empty():
		return ""
	if t.is_empty():
		return b
	if b.is_empty():
		return t
	return "%s\n%s" % [t, b]


## 导出为可嵌入提示词或存档的纯文本块（含元数据与标题/正文）。
func export_to_text() -> String:
	var lines: PackedStringArray = PackedStringArray([
		"--- PromptMemory ---",
		"id=%d" % prompt_id,
		"mutable=%s" % ("true" if is_mutable else "false"),
		"weight=%.2f" % weight,
		"connected=%s" % ("true" if connected else "false"),
		"---title---",
		prompt_title,
		"---body---",
		prompt_body
	])
	return "\n".join(lines)


func _configure_content(title: String, body: String, weight_value: float, connected_value: bool) -> void:
	var ti := title.strip_edges()
	prompt_title = ti if not ti.is_empty() else "未命名标题"
	prompt_body = body.strip_edges()
	weight = clampf(weight_value, 0.0, 1.0)
	connected = connected_value


func _on_body_toggle_pressed() -> void:
	_body_expanded = not _body_expanded
	_refresh_visuals()


func _shrink_wrap_to_content() -> void:
	## 在正文折叠后让 Panel 收回高度；Godot 的 Label 曾参与布局后易残留最小尺寸，需 reset + 清空文案配合。
	if not is_instance_valid(self ) or not is_inside_tree():
		return
	reset_size()
	_update_pivot()
	emit_signal("moved", self )


func _gui_input(event: InputEvent) -> void:
	if _editing_title or _editing_body:
		return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				if event.double_click and is_mutable:
					if _is_pointer_over_title():
						_begin_title_edit()
						accept_event()
						return
					if _is_pointer_over_body():
						_begin_body_edit()
						accept_event()
						return
				_dragging = true
				_drag_offset = event.position
				emit_signal("selected", self )
			else:
				_dragging = false
				emit_signal("moved", self )
				accept_event()
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			if is_mutable:
				toggle_connected()
			accept_event()
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			if is_mutable:
				set_weight(weight + 0.02)
				emit_signal("content_changed", self )
			accept_event()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			if is_mutable:
				set_weight(weight - 0.02)
				emit_signal("content_changed", self )
			accept_event()
	elif event is InputEventMouseMotion and _dragging:
		position += event.position - _drag_offset
		emit_signal("moved", self )
		accept_event()


func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	if not event.pressed:
		return
	if _editing_title and event.keycode == KEY_ESCAPE:
		_cancel_title_edit()
		accept_event()
		return
	if _editing_body:
		if event.keycode == KEY_ESCAPE:
			_cancel_body_edit()
			accept_event()
			return
		if event.keycode == KEY_ENTER and event.ctrl_pressed:
			_commit_body_edit()
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


func set_prompt_title(value: String) -> void:
	if not is_mutable:
		return
	var v := value.strip_edges()
	prompt_title = v if not v.is_empty() else "未命名标题"
	_refresh_visuals()
	emit_signal("content_changed", self )


func set_prompt_body(value: String) -> void:
	if not is_mutable:
		return
	prompt_body = value.strip_edges()
	if prompt_body.is_empty():
		_body_expanded = false
	_refresh_visuals()
	emit_signal("content_changed", self )


## 兼容旧调用：整段写入时视为仅更新标题（正文不变）。
func set_prompt_text(value: String) -> void:
	set_prompt_title(value)


func set_weight(value: float) -> void:
	if not is_mutable:
		return
	weight = clampf(value, 0.0, 1.0)
	_refresh_visuals()
	emit_signal("content_changed", self )


func set_connected(value: bool) -> void:
	if not is_mutable:
		return
	connected = value
	_refresh_visuals()
	emit_signal("content_changed", self )


func toggle_connected() -> void:
	if not is_mutable:
		return
	connected = not connected
	_refresh_visuals()
	emit_signal("content_changed", self )
	emit_signal("connect_toggled", self )


func _refresh_visuals() -> void:
	if not is_inside_tree():
		return
	set_lit(connected, true)

	var readonly_prefix := "" if is_mutable else "只读 · "
	_title_label.text = prompt_title
	if connected:
		_state_label.text = "%s已连接  |  权重 %.2f" % [readonly_prefix, weight]
		_state_label.modulate = Color("8dd9ff") if is_mutable else Color("a8b8cc")
	else:
		_state_label.text = "%s未连接（不生效）  |  权重 %.2f" % [readonly_prefix, weight]
		_state_label.modulate = Color("8e97aa")

	var body := prompt_body.strip_edges()
	var has_body := not body.is_empty()

	if not has_body:
		_body_expanded = false

	_body_toggle_row.visible = has_body

	var show_body := has_body and _body_expanded
	_body_label.visible = show_body
	## 收起时必须清空文本，否则 Wrapped Label 的最小高度不会收回。
	if show_body:
		_body_label.text = body
	else:
		_body_label.text = ""

	if has_body:
		_body_toggle_button.text = "收起正文 ▲" if _body_expanded else "展开正文 ▼"
		_body_label.modulate = Color(0.75, 0.82, 0.92, 1.0)

	_title_edit.visible = _editing_title
	_body_edit.visible = _editing_body
	_body_edit.custom_minimum_size = Vector2(0, 90) if _editing_body else Vector2.ZERO
	_delete_inline_button.visible = is_mutable

	call_deferred("_shrink_wrap_to_content")


func _is_pointer_over_title() -> bool:
	return Rect2(_title_label.global_position, _title_label.size).has_point(get_global_mouse_position())


func _is_pointer_over_body() -> bool:
	var mouse_pos := get_global_mouse_position()
	var in_body := Rect2(_body_label.global_position, _body_label.size).has_point(mouse_pos)
	var in_toggle := Rect2(_body_toggle_row.global_position, _body_toggle_row.size).has_point(mouse_pos)
	return in_body or in_toggle


func _begin_title_edit() -> void:
	_editing_title = true
	_title_edit.text = prompt_title
	_refresh_visuals()
	_title_edit.grab_focus()
	_title_edit.select_all()


func _begin_body_edit() -> void:
	_editing_body = true
	_body_expanded = true
	_body_edit.text = prompt_body
	_refresh_visuals()
	_body_edit.grab_focus()


func _on_title_edit_submitted(_new_text: String) -> void:
	_commit_title_edit()


func _commit_title_edit() -> void:
	if not _editing_title:
		return
	_editing_title = false
	set_prompt_title(_title_edit.text)
	_refresh_visuals()


func _cancel_title_edit() -> void:
	if not _editing_title:
		return
	_editing_title = false
	_refresh_visuals()


func _commit_body_edit() -> void:
	if not _editing_body:
		return
	_editing_body = false
	set_prompt_body(_body_edit.text)
	_refresh_visuals()


func _cancel_body_edit() -> void:
	if not _editing_body:
		return
	_editing_body = false
	_refresh_visuals()


func _on_delete_inline_pressed() -> void:
	if not is_mutable:
		return
	emit_signal("delete_requested", self )
