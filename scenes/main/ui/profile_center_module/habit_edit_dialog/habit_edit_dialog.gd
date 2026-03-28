extends MaterialDialog

## 习惯编辑对话框 - 新建/编辑习惯

signal habit_confirmed(data: Dictionary)

# 编辑模式相关
var _editing_habit_id: int = -1  # -1 表示新建

# UI 元素
@onready var _name_field: MaterialTextField = $FormContent/NameField
@onready var _duration_label: Label = $FormContent/DurationBox/DurationLabel
@onready var _duration_slider: MaterialSlider = $FormContent/DurationBox/DurationSlider
@onready var _period_seg: MaterialSegmentedButton = $FormContent/PeriodBox/PeriodSeg
@onready var _frequency_seg: MaterialSegmentedButton = $FormContent/FreqBox/FreqSeg

var _color_buttons: Array[MaterialButton] = []
var _selected_color: String = "#4CAF50"

const PRESET_COLORS: Array[String] = [
	"#4CAF50", "#2196F3", "#FF9800", "#E91E63",
	"#9C27B0", "#00BCD4", "#FF5722", "#607D8B"
]


func _ready() -> void:
	super._ready()
	dialog_title = "新建习惯"
	dialog_size = MaterialDialog.DialogSize.MEDIUM

	# 收集颜色按钮并连接信号
	var color_row = $FormContent/ColorBox/ColorRow
	for i in range(color_row.get_child_count()):
		var btn = color_row.get_child(i) as MaterialButton
		btn.pressed.connect(_on_color_selected.bind(i))
		_color_buttons.append(btn)

	# 连接滑块信号
	_duration_slider.value_changed.connect(_on_duration_changed)

	# 将 FormContent 移入对话框内容区
	set_custom_content($FormContent)
	_add_dialog_buttons()
	visible = false


func _add_dialog_buttons() -> void:
	clear_buttons()
	add_button("取消").pressed.connect(func(): hide_dialog())
	var confirm_btn = add_button("确定")
	confirm_btn.set_filled_style(Color(0.35, 0.65, 0.95))
	confirm_btn.pressed.connect(_on_confirm)


func show_create() -> void:
	_editing_habit_id = -1
	dialog_title = "新建习惯"
	_name_field.set_text("")
	_duration_slider.set_value_no_signal(30)
	_duration_label.text = "预估时长: 30 分钟"
	_period_seg.set_selected_no_signal(0)
	_frequency_seg.set_selected_no_signal(0)
	_selected_color = PRESET_COLORS[0]
	_update_color_highlight()
	show_dialog()


func show_edit(habit: HabitData) -> void:
	_editing_habit_id = habit.id
	dialog_title = "编辑习惯"
	_name_field.set_text(habit.name)
	_duration_slider.set_value_no_signal(habit.estimated_minutes)
	_duration_label.text = "预估时长: %d 分钟" % habit.estimated_minutes
	_period_seg.set_selected_no_signal(habit.preferred_period)
	_frequency_seg.set_selected_no_signal(habit.frequency)
	_selected_color = habit.color
	_update_color_highlight()
	show_dialog()


func _on_duration_changed(val: float) -> void:
	_duration_label.text = "预估时长: %d 分钟" % int(val)


func _on_color_selected(index: int) -> void:
	_selected_color = PRESET_COLORS[index]
	_update_color_highlight()


func _update_color_highlight() -> void:
	for i in range(_color_buttons.size()):
		if PRESET_COLORS[i] == _selected_color:
			_color_buttons[i].modulate = Color(1, 1, 1, 1)
		else:
			_color_buttons[i].modulate = Color(1, 1, 1, 0.4)


func _on_confirm() -> void:
	var habit_name = _name_field.get_text().strip_edges()
	if habit_name.is_empty():
		return

	var data = {
		"id": _editing_habit_id,
		"name": habit_name,
		"estimated_minutes": int(_duration_slider.value),
		"preferred_period": _period_seg.get_selected_index(),
		"frequency": _frequency_seg.get_selected_index(),
		"color": _selected_color,
	}
	habit_confirmed.emit(data)
	hide_dialog()
