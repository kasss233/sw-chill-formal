class_name NoteItemMobile
extends MarginContainer

## 笔记列表项组件
## 纯展示 + 交互，展示标题/内容预览/时间，点击时上报 note_id

signal note_pressed(note_id: int)

var _note_id: int = -1
var _pressing: bool = false
var _drag_distance: float = 0.0

const TAP_DRAG_THRESHOLD := 12.0

@onready var _inner_panel: PanelContainer = $InnerPanel
@onready var _title_label: Label = $InnerPanel/VBoxContainer/TitleLabel
@onready var _content_label: Label = $InnerPanel/VBoxContainer/ContentLabel
@onready var _time_label: Label = $InnerPanel/VBoxContainer/TimeLabel


func _ready() -> void:
	_enable_scroll_passthrough(self)
	_inner_panel.gui_input.connect(_on_gui_input)
	_inner_panel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


static func _enable_scroll_passthrough(node: Node) -> void:
	if node is Control:
		(node as Control).mouse_filter = Control.MOUSE_FILTER_PASS
	for child in node.get_children():
		_enable_scroll_passthrough(child)


## 更新展示数据
func update_display(data: NoteData) -> void:
	_note_id = data.id
	_title_label.text = data.get_display_title()
	_content_label.text = data.get_content_preview()
	_time_label.text = data.get_formatted_time()


## 获取当前笔记 id
func get_note_id() -> int:
	return _note_id


## 入场动画
func play_entry_animation(delay: float = 0.0) -> void:
	modulate.a = 0
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_BACK)
	tween.tween_property(self, "modulate:a", 1.0, 0.4).set_delay(delay)


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_pressing = true
			_drag_distance = 0.0
		elif _pressing:
			_pressing = false
			if _drag_distance <= TAP_DRAG_THRESHOLD:
				note_pressed.emit(_note_id)
	elif event is InputEventMouseMotion and _pressing:
		_drag_distance += event.relative.length()
	elif event is InputEventScreenTouch:
		if event.pressed:
			_pressing = true
			_drag_distance = 0.0
		elif _pressing:
			_pressing = false
			if _drag_distance <= TAP_DRAG_THRESHOLD:
				note_pressed.emit(_note_id)
	elif event is InputEventScreenDrag and _pressing:
		_drag_distance += event.relative.length()
