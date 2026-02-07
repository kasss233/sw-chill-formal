class_name NoteItemMobile
extends MarginContainer

## 笔记列表项组件
## 纯展示 + 交互，展示标题/内容预览/时间，点击时上报 note_id

signal note_pressed(note_id: int)

var _note_id: int = -1

@onready var _inner_panel: PanelContainer = $InnerPanel
@onready var _title_label: Label = $InnerPanel/VBoxContainer/TitleLabel
@onready var _content_label: Label = $InnerPanel/VBoxContainer/ContentLabel
@onready var _time_label: Label = $InnerPanel/VBoxContainer/TimeLabel


func _ready() -> void:
	_inner_panel.gui_input.connect(_on_gui_input)
	_inner_panel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


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
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		note_pressed.emit(_note_id)
