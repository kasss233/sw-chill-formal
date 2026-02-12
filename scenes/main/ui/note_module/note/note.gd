class_name Note
extends Control
@onready var text_edit: TextEdit =$FrostedPanel/MarginContainer/VBoxContainer/TextEdit
@onready var material_menu: MaterialMenu = $MaterialMenu

signal note_closed
func _ready() -> void:
	# 确保父节点 Note 大小正确，以便 NoteModule 居中计算
	size = $FrostedPanel.size

	# 设置缩放中心为中心点
	pivot_offset = size / 2.0

	# 初始隐藏，防止位置设置前的闪烁
	modulate.a = 0.0
	visible = false

	# 等待一帧，确保 NoteModule 已设置其 global_position（居中）
	await get_tree().process_frame

	visible = true
	var target_pos_y = position.y
	# 从下方较远距离滑入
	position.y += 300

	# 入场动画：透明度增加、向上滑入
	var tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 1.0, 0.5)
	tween.tween_property(self, "position:y", target_pos_y, 0.5)



func close() -> void:
	note_closed.emit()

	# 停止打字动画
	if _typing_tween:
		_typing_tween.kill()

	# 禁用交互，防止动画过程中继续操作
	set_process_input(false)
	holding = false

	# 出场动画：大幅度向下滑动，同时消失
	var tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "modulate:a", 0.0, 0.4)
	# 向下滑动更长距离 (500px) 营造"掉落/滑出"感
	tween.tween_property(self, "position:y", position.y + 500, 0.4)

	tween.chain().finished.connect(queue_free)


## ---拖拽相关---
var holding = false
var drag_offset = Vector2.ZERO
func _on_move_button_button_up() -> void:
	holding = false


func _on_move_button_button_down() -> void:
	holding = true
	drag_offset = get_global_mouse_position() - global_position


func _input(event: InputEvent) -> void:
	if holding and event is InputEventMouseMotion:
		global_position = get_global_mouse_position() - drag_offset


## ---api---
var _typing_tween: Tween
func set_text(text: String) -> void:
	if not is_node_ready():
		await ready

	if _typing_tween:
		_typing_tween.kill()

	_typing_tween = create_tween()
	text_edit.text = ""

	# 设置打字速度，例如每秒20个字符
	var duration = text.length() / 20.0
	if duration < 0.1: duration = 0.1

	_typing_tween.tween_method(
		func(length: int):
			text_edit.text = text.left(length)
			text_edit.set_caret_line(text_edit.get_line_count()),
		0,
		text.length(),
		duration
	)


func _on_menu_button_menu_item_pressed(index: int, _item: MaterialMenuItem) -> void:
	if index == 0:
		_import_to_notebook()
	elif index == 1:
		close()


func _import_to_notebook() -> void:
	var content = text_edit.text.strip_edges()
	if content == "":
		print("[Note] 便签内容为空，无法导入")
		return
	# 标题取第一行非空行，否则"便签"
	var title = "便签"
	for line in content.split("\n"):
		var trimmed = line.strip_edges()
		if trimmed != "":
			title = trimmed
			if title.length() > 50:
				title = title.substr(0, 50) + "..."
			break
	NoteState.add_note(title, content)
	print("[Note] 已导入便签到笔记本: %s" % title)
	close()
