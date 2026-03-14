extends MaterialDialog

## 时间段模板编辑器

@onready var _slots_container: VBoxContainer = $EditorContent/ScrollContainer/SlotsContainer
@onready var _add_slot_btn: MaterialButton = $EditorContent/AddSlotBtn

var _slot_rows: Array = []  # [{name_field, start_field, end_field, slot_id}]


func _ready() -> void:
	super._ready()
	dialog_title = "编辑时间段"
	dialog_size = MaterialDialog.DialogSize.MEDIUM

	_add_slot_btn.set_text_style(Color(0.35, 0.65, 0.95))
	_add_slot_btn.pressed.connect(_on_add_slot)

	set_custom_content($EditorContent)
	_add_dialog_buttons()
	visible = false


func _add_dialog_buttons() -> void:
	clear_buttons()
	add_button("取消").pressed.connect(func(): hide_dialog())
	var save_btn = add_button("保存")
	save_btn.set_filled_style(Color(0.35, 0.65, 0.95))
	save_btn.pressed.connect(_on_save)


func show_editor() -> void:
	_load_slots()
	show_dialog()


func _load_slots() -> void:
	# 清空
	for child in _slots_container.get_children():
		child.queue_free()
	_slot_rows.clear()

	var templates = HabitState.get_time_slot_templates()
	for slot in templates:
		_add_slot_row(slot.id, slot.name, slot.start_time, slot.end_time)


func _add_slot_row(slot_id: int, slot_name: String, start: String, end: String) -> void:
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)

	var name_field = MaterialTextField.new()
	name_field.text_field_height = 36
	name_field.set_text(slot_name)
	name_field.placeholder_text = "名称"
	name_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_field.bg_color = Color(0.15, 0.15, 0.15, 1)
	name_field.text_color = Color(0.9, 0.9, 0.9)
	name_field.placeholder_color = Color(0.5, 0.5, 0.5)
	row.add_child(name_field)

	var start_field = MaterialTextField.new()
	start_field.text_field_height = 36
	start_field.set_text(start)
	start_field.placeholder_text = "HH:MM"
	start_field.custom_minimum_size.x = 60
	start_field.bg_color = Color(0.15, 0.15, 0.15, 1)
	start_field.text_color = Color(0.9, 0.9, 0.9)
	start_field.placeholder_color = Color(0.5, 0.5, 0.5)
	row.add_child(start_field)

	var end_field = MaterialTextField.new()
	end_field.text_field_height = 36
	end_field.set_text(end)
	end_field.placeholder_text = "HH:MM"
	end_field.custom_minimum_size.x = 60
	end_field.bg_color = Color(0.15, 0.15, 0.15, 1)
	end_field.text_color = Color(0.9, 0.9, 0.9)
	end_field.placeholder_color = Color(0.5, 0.5, 0.5)
	row.add_child(end_field)

	var del_btn = MaterialButton.new()
	del_btn.button_icon = preload("res://assets/ui/icons/close_24dp_FFFFFF_FILL0_wght400_GRAD0_opsz24.svg")
	del_btn.button_size = MaterialButton.ButtonSize.SMALL32
	del_btn.pressed.connect(_on_remove_row.bind(row))
	row.add_child(del_btn)

	_slots_container.add_child(row)
	_slot_rows.append({
		"row": row,
		"name_field": name_field,
		"start_field": start_field,
		"end_field": end_field,
		"slot_id": slot_id,
	})


func _on_add_slot() -> void:
	_add_slot_row(-1, "", "", "")


func _on_remove_row(row: HBoxContainer) -> void:
	for i in range(_slot_rows.size()):
		if _slot_rows[i]["row"] == row:
			_slot_rows.remove_at(i)
			break
	row.queue_free()


func _on_save() -> void:
	# 收集当前 rows 的数据
	var existing_ids: Array = []

	for row_data in _slot_rows:
		var name_text = row_data["name_field"].get_text().strip_edges()
		var start_text = row_data["start_field"].get_text().strip_edges()
		var end_text = row_data["end_field"].get_text().strip_edges()
		if name_text.is_empty() or start_text.is_empty() or end_text.is_empty():
			continue

		var slot_id = row_data["slot_id"]
		if slot_id > 0:
			# 更新现有
			HabitState.update_time_slot_template(slot_id, {
				"name": name_text,
				"start_time": start_text,
				"end_time": end_text,
			})
			existing_ids.append(slot_id)
		else:
			# 新增
			var slot = HabitState.add_time_slot_template(name_text, start_text, end_text)
			existing_ids.append(slot.id)

	# 删除不在列表中的模板
	var all_templates = HabitState.get_time_slot_templates()
	for t in all_templates:
		if t.id not in existing_ids:
			HabitState.remove_time_slot_template(t.id)

	# 重排序
	HabitState.reorder_time_slot_templates(existing_ids)
	hide_dialog()
