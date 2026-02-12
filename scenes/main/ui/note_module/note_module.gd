class_name NoteModule
extends Control

@export var note: PackedScene

@onready var canvas_layer: CanvasLayer = $CanvasLayer


func _ready() -> void:
	canvas_layer.layer = 10
	StickyNoteState.sticky_note_requested.connect(_on_sticky_note_requested)


func _on_sticky_note_requested(text: String) -> void:
	_create_note_with_text(text)


## 内部创建便签
func _create_note_internal() -> Note:
	if note == null:
		printerr("[Note Module] Error: 'note' PackedScene is not assigned!")
		return null
	LayerManager.bring_to_front(canvas_layer)
	var new_note = note.instantiate() as Note
	new_note.note_closed.connect(_on_note_closed)
	canvas_layer.add_child(new_note)
	new_note.global_position = get_viewport().get_visible_rect().size / 2 - new_note.size / 2
	StickyNoteState.notify_created()
	return new_note


## 创建带文本的便签
func _create_note_with_text(text: String) -> bool:
	var new_note = _create_note_internal()
	if new_note == null:
		return false
	new_note.set_text(text)
	return true


## 用户按钮点击
func _on_material_button_pressed() -> void:
	if not StickyNoteState.can_create():
		print("[Note Module] 便签数量已达上限")
		return
	_create_note_internal()


## 便签关闭回调
func _on_note_closed() -> void:
	StickyNoteState.notify_closed()


## Agent/外部 API
func take_note(text: String) -> bool:
	if not StickyNoteState.can_create():
		return false
	return _create_note_with_text(text)
