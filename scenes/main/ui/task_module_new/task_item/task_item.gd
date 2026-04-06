@tool
extends InnerPanel

# --- 信号（传 ID 代替 self）---
signal completed_changed(task_id: int, completed: bool)
signal content_changed(task_id: int, new_content: String)
signal delete_requested(task_id: int)
signal due_time_changed(task_id: int, timestamp: int)
signal edit_requested(id)
signal drag_started(item: InnerPanel)
signal drag_ended(item: InnerPanel)
signal task_overdue(item: InnerPanel)  # 纯 UI 视觉信号

@onready var complete_check_box: CheckBox = $MarginContainer/VBoxContainer/HBoxContainer/CompleteCheckBox
@onready var due_time_label: Label = $MarginContainer/VBoxContainer/HBoxContainer/VBoxContainer/DueTimeLabel
@onready var line_edit: LineEdit = $MarginContainer/VBoxContainer/HBoxContainer/VBoxContainer/LineEdit
@onready var h_box_container_2: HBoxContainer = $MarginContainer/VBoxContainer/HBoxContainer2
@onready var close_button: Button = $MarginContainer/VBoxContainer/HBoxContainer2/CloseButton
@onready var time_set_button: Button = $MarginContainer/VBoxContainer/HBoxContainer2/TimeSetButton

@onready var long_press_timer: Timer = $LongPressTimer

var is_pressing: bool = false
var is_dragging: bool = false
var is_editing: bool = false
var _is_updating_display: bool = false

var task_data: TaskData

func _ready() -> void:
	super._ready()  # 调用父类 InnerPanel 的 _ready()，确保 shader 初始化

	# 初始状态设置
	mouse_filter = Control.MOUSE_FILTER_PASS

	# 初始化关闭编辑模式
	_disable_edit_mode()

	# 阻止 CheckBox 的点击事件传递到父容器
	if complete_check_box:
		complete_check_box.mouse_filter = Control.MOUSE_FILTER_STOP

	# 连接关闭按钮信号
	if close_button:
		close_button.pressed.connect(_on_close_button_pressed)

	# 连接时间设置按钮信号
	if time_set_button:
		time_set_button.pressed.connect(_on_time_set_button_pressed)

	# 连接长按定时器信号
	if long_press_timer:
		long_press_timer.timeout.connect(_on_long_press_timer_timeout)

## 设置任务数据（只读取数据设置 UI，不修改数据）
func set_task(data: TaskData):
	self.task_data = data

	if not is_instance_valid(task_data):
		push_error("["+self.name+"]"+"Invaild Data")
		visible = false
		return

	visible = true

	line_edit.text = task_data.title
	complete_check_box.button_pressed = task_data.is_completed
	line_edit.is_completed = task_data.is_completed

	# 已完成任务不显示截止时间
	if task_data.is_completed:
		due_time_label.visible = false
	elif task_data.due_timestamp == 0:
		due_time_label.visible = false
	else:
		due_time_label.text = task_data.get_formatted_due_time()
		due_time_label.visible = true
		_check_and_update_overdue_status()

## 外部调用更新显示（TaskState 数据变化时）
func update_display(task: TaskData) -> void:
	self.task_data = task

	if not is_instance_valid(task_data):
		return

	_is_updating_display = true
	# 如果 LineEdit 正在被用户编辑（有焦点），跳过文本更新以避免光标重置
	if not line_edit.has_focus():
		line_edit.text = task_data.title
	complete_check_box.button_pressed = task_data.is_completed
	line_edit.is_completed = task_data.is_completed
	_is_updating_display = false

	if task_data.is_completed:
		due_time_label.visible = false
		if is_editing:
			_disable_edit_mode()
	elif task_data.due_timestamp == 0:
		due_time_label.visible = false
	else:
		due_time_label.text = task_data.get_formatted_due_time()
		due_time_label.visible = true
		_check_and_update_overdue_status()

## 返回当前绑定的 task_id
func get_task_id() -> int:
	if task_data:
		return task_data.id
	return -1

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			# 鼠标按下
			is_pressing = true
			is_dragging = false
			# 启动长按定时器
			if long_press_timer:
				long_press_timer.start()

		else:
			# 鼠标松开
			# 停止长按定时器
			if long_press_timer:
				long_press_timer.stop()

			if is_pressing and not is_dragging:
				# 单击事件逻辑：已完成任务不允许编辑
				if not task_data.is_completed:
					if is_editing:
						_disable_edit_mode() # 如果正在编辑，再次点击背景则退出
					else:
						_enable_edit_mode() # 如果没在编辑，点击则进入

			# 重置状态
			if is_dragging and not task_data.is_completed:
				drag_ended.emit(self)

			is_pressing = false
			is_dragging = false


# 开启编辑模式
func _enable_edit_mode() -> void:
	is_editing = true
	h_box_container_2.visible = true

	# 启用 LineEdit 鼠标交互，允许选中文字
	line_edit.mouse_filter = Control.MOUSE_FILTER_STOP

# 关闭编辑模式
func _disable_edit_mode() -> void:
	is_editing = false
	h_box_container_2.visible = false

	# 禁用 LineEdit 鼠标交互，让点击事件能穿透到 PanelContainer (背景)
	line_edit.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# 清除焦点（如果在输入状态下）
	if line_edit.has_focus():
		line_edit.release_focus()

func _on_close_button_pressed() -> void:
	# 按钮点击事件处理
	_disable_edit_mode()

func _on_edit_button_pressed() -> void:
	edit_requested.emit(task_data.id)

func _on_long_press_timer_timeout() -> void:
	if is_pressing:
		is_dragging = true
		drag_started.emit(self)

func _on_line_edit_text_changed(new_text: String) -> void:
	print("[%s]Task title change to \"%s\"" %[self.name,new_text])
	# 不直接修改 task_data，发射信号让外部处理
	content_changed.emit(task_data.id, new_text)


func _on_line_edit_editing_toggled(toggled_on: bool) -> void:
	var new_text = line_edit.text
	if new_text == task_data.title:
		return
	print("[%s]Task title change to \"%s\"" %[self.name,new_text])
	content_changed.emit(task_data.id, new_text)

func _on_del_button_pressed() -> void:
	delete_requested.emit(task_data.id)

func _on_complete_check_box_toggled(toggled_on: bool) -> void:
	# 防止 update_display 设置 button_pressed 触发的信号回路
	if _is_updating_display:
		return
	# 不直接修改 task_data，发射信号让外部处理
	line_edit.is_completed = toggled_on

	if toggled_on:
		due_time_label.visible = false
		# 退出编辑模式
		if is_editing:
			_disable_edit_mode()

	# 发射带 ID 的完成状态变化信号
	completed_changed.emit(task_data.id, toggled_on)

## 处理时间设置按钮点击
func _on_time_set_button_pressed() -> void:
	_show_datetime_picker()

## 显示日期时间选择对话框
func _show_datetime_picker() -> void:
	# 获取当前时间或任务截止时间（UTC+8）
	var timezone_offset = 8 * 3600  # UTC+8
	var current_timestamp: int
	if task_data.due_timestamp > 0:
		current_timestamp = task_data.due_timestamp
	else:
		current_timestamp = Time.get_unix_time_from_system() + 3600  # +1小时
	var local_timestamp = current_timestamp + timezone_offset
	var datetime_dict = Time.get_datetime_dict_from_unix_time(local_timestamp)

	# 创建对话框
	var dialog = MaterialDialog.new()
	get_tree().root.add_child(dialog)
	dialog.dialog_title = "设置截止时间 (UTC+8)"

	# 创建自定义内容容器
	var content = VBoxContainer.new()
	content.name = "DateTimeContent"
	content.add_theme_constant_override("separation", 8)

	# 年份选择
	var year_hbox = HBoxContainer.new()
	year_hbox.add_theme_constant_override("separation", 8)
	var year_label = Label.new()
	year_label.text = "年份："
	year_label.custom_minimum_size = Vector2(60, 36)
	year_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	year_hbox.add_child(year_label)
	var year_spinbox = SpinBox.new()
	year_spinbox.min_value = 2020
	year_spinbox.max_value = 2100
	year_spinbox.value = datetime_dict.year
	year_spinbox.custom_minimum_size = Vector2(120, 36)
	year_hbox.add_child(year_spinbox)
	content.add_child(year_hbox)

	# 月份选择
	var month_hbox = HBoxContainer.new()
	month_hbox.add_theme_constant_override("separation", 8)
	var month_label = Label.new()
	month_label.text = "月份："
	month_label.custom_minimum_size = Vector2(60, 36)
	month_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	month_hbox.add_child(month_label)
	var month_spinbox = SpinBox.new()
	month_spinbox.min_value = 1
	month_spinbox.max_value = 12
	month_spinbox.value = datetime_dict.month
	month_spinbox.custom_minimum_size = Vector2(120, 36)
	month_hbox.add_child(month_spinbox)
	content.add_child(month_hbox)

	# 日期选择
	var day_hbox = HBoxContainer.new()
	day_hbox.add_theme_constant_override("separation", 8)
	var day_label = Label.new()
	day_label.text = "日期："
	day_label.custom_minimum_size = Vector2(60, 36)
	day_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	day_hbox.add_child(day_label)
	var day_spinbox = SpinBox.new()
	day_spinbox.min_value = 1
	day_spinbox.max_value = 31
	day_spinbox.value = datetime_dict.day
	day_spinbox.custom_minimum_size = Vector2(120, 36)
	day_hbox.add_child(day_spinbox)
	content.add_child(day_hbox)

	# 小时选择
	var hour_hbox = HBoxContainer.new()
	hour_hbox.add_theme_constant_override("separation", 8)
	var hour_label = Label.new()
	hour_label.text = "小时："
	hour_label.custom_minimum_size = Vector2(60, 36)
	hour_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hour_hbox.add_child(hour_label)
	var hour_spinbox = SpinBox.new()
	hour_spinbox.min_value = 0
	hour_spinbox.max_value = 23
	hour_spinbox.value = datetime_dict.hour
	hour_spinbox.custom_minimum_size = Vector2(120, 36)
	hour_hbox.add_child(hour_spinbox)
	content.add_child(hour_hbox)

	# 分钟选择
	var minute_hbox = HBoxContainer.new()
	minute_hbox.add_theme_constant_override("separation", 8)
	var minute_label = Label.new()
	minute_label.text = "分钟："
	minute_label.custom_minimum_size = Vector2(60, 36)
	minute_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	minute_hbox.add_child(minute_label)
	var minute_spinbox = SpinBox.new()
	minute_spinbox.min_value = 0
	minute_spinbox.max_value = 59
	minute_spinbox.value = datetime_dict.minute
	minute_spinbox.custom_minimum_size = Vector2(120, 36)
	minute_hbox.add_child(minute_spinbox)
	content.add_child(minute_hbox)

	# 设置自定义内容
	dialog.set_custom_content(content)

	# 添加取消按钮
	var cancel_btn = dialog.add_button("取消")
	cancel_btn.pressed.connect(func():
		dialog.hide_dialog()
	)

	# 添加确定按钮
	var confirm_btn = dialog.add_button("确定")
	confirm_btn.pressed.connect(func():
		# 获取选择的日期时间
		var selected_year = int(year_spinbox.value)
		var selected_month = int(month_spinbox.value)
		var selected_day = int(day_spinbox.value)
		var selected_hour = int(hour_spinbox.value)
		var selected_minute = int(minute_spinbox.value)

		# 转换为UTC+8本地时间的时间戳
		var new_datetime = {
			"year": selected_year,
			"month": selected_month,
			"day": selected_day,
			"hour": selected_hour,
			"minute": selected_minute,
			"second": 0
		}
		var new_local_timestamp = Time.get_unix_time_from_datetime_dict(new_datetime)
		# 转换为UTC时间戳（减去时区偏移）
		var new_timestamp = new_local_timestamp - timezone_offset

		# 不直接修改 task_data，发射信号
		due_time_changed.emit(task_data.id, new_timestamp)

		# 先更新本地显示（UI 反馈）
		due_time_label.text = task_data.get_formatted_due_time()
		due_time_label.visible = true
		_check_and_update_overdue_status()

		dialog.hide_dialog()
	)

	dialog.show_dialog()

## 检查并更新过期状态（纯视觉）
func _check_and_update_overdue_status() -> void:
	if task_data.due_timestamp == 0:
		due_time_label.add_theme_color_override("font_color", Color.WHITE)
		return

	var now = Time.get_unix_time_from_system()
	if now > task_data.due_timestamp and not task_data.is_completed:
		# 已过期且未完成
		due_time_label.add_theme_color_override("font_color", Color.RED)
		task_overdue.emit(self)
	else:
		# 未过期或已完成
		due_time_label.add_theme_color_override("font_color", Color.WHITE)
