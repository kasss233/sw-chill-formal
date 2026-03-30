extends HBoxContainer

## 习惯条目组件 - 显示单个习惯的信息

signal edit_requested(habit_id: int)
signal active_toggled(habit_id: int, active: bool)
signal delete_requested(habit_id: int)

var _habit_id: int = 0

@onready var _color_rect: ColorRect = $ColorMark
@onready var _name_label: Label = $InfoBox/NameLabel
@onready var _chips_container: HBoxContainer = $InfoBox/ChipsContainer
@onready var _switch: MaterialSwitch = $ActiveSwitch
@onready var _edit_button: MaterialButton = $EditButton
@onready var _context_menu: MaterialContextMenu = $ContextMenu


func _ready() -> void:
	_switch.toggled.connect(_on_switch_toggled)
	_edit_button.pressed.connect(_on_edit_pressed)

	_context_menu.add_item("编辑", preload("res://assets/ui/icons/edit_24dp.svg"))
	_context_menu.add_item("删除", preload("res://assets/ui/icons/delete_forever_24dp_FFFFFF_FILL0_wght400_GRAD0_opsz24.svg"))
	_context_menu.item_pressed.connect(_on_context_item)
	_context_menu.attach_to(self )


func update_display(habit: HabitData) -> void:
	_habit_id = habit.id
	_name_label.text = habit.name
	_color_rect.color = Color.from_string(habit.color, Color(0.3, 0.7, 0.3))
	_switch.set_checked_no_signal(habit.is_active)

	# 清空并重建 chips
	for child in _chips_container.get_children():
		child.queue_free()

	# 频率 chip
	var freq_chip = MaterialChip.new()
	freq_chip.text = habit.get_frequency_name()
	freq_chip.chip_size = MaterialChip.ChipSize.SMALL
	freq_chip.chip_style = MaterialChip.ChipStyle.OUTLINED
	_chips_container.add_child(freq_chip)

	# 时间 chip
	var time_chip = MaterialChip.new()
	time_chip.text = "%s-%s" % [habit.preferred_start_time, habit.preferred_end_time]
	time_chip.chip_size = MaterialChip.ChipSize.SMALL
	time_chip.chip_style = MaterialChip.ChipStyle.OUTLINED
	_chips_container.add_child(time_chip)


func _on_switch_toggled(pressed: bool) -> void:
	active_toggled.emit(_habit_id, pressed)


func _on_edit_pressed() -> void:
	edit_requested.emit(_habit_id)


func _on_context_item(index: int, _item: MaterialMenuItem) -> void:
	match index:
		0: edit_requested.emit(_habit_id)
		1: delete_requested.emit(_habit_id)
