@tool
extends InnerPanel

signal state_changed(item: InnerPanel)
signal edit_requested(id)
signal delete_requested(item: InnerPanel)
signal content_changed(item: InnerPanel)
signal drag_started(item: InnerPanel)
signal drag_ended(item: InnerPanel)
signal task_overdue(item: InnerPanel)  # 任务过期信号
signal task_completed(item: InnerPanel)  # 任务完成信号
signal task_deadline_reached(item: InnerPanel)  # 截止时间到信号
signal task_deadline_warning(item: InnerPanel)  # 截止时间剩余15分钟警告信号

@onready var complete_check_box: CheckBox = $MarginContainer/VBoxContainer/HBoxContainer/CompleteCheckBox
@onready var due_time_label: Label = $MarginContainer/VBoxContainer/HBoxContainer/VBoxContainer/DueTimeLabel
@onready var line_edit: LineEdit = $MarginContainer/VBoxContainer/HBoxContainer/VBoxContainer/LineEdit
@onready var h_box_container_2: HBoxContainer = $MarginContainer/VBoxContainer/HBoxContainer2
@onready var close_button: Button = $MarginContainer/VBoxContainer/HBoxContainer2/CloseButton
@onready var time_set_button: Button = $MarginContainer/VBoxContainer/HBoxContainer2/TimeSetButton

@onready var long_press_timer: Timer = $LongPressTimer

var is_pressing: bool = false
var is_dragging: bool = false
var is_editing: bool = false # 新增：用于判断当前状态

var task_data: TaskData

# 截止时间检查相关
var deadline_check_timer: Timer = null
var has_warned_15min: bool = false  # 是否已发出15分钟警告
var has_warned_deadline: bool = false  # 是否已发出截止时间到警告
var should_warn_15min: bool = false  # 是否应该发出15分钟警告（总时间>30分钟时为true）

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

	# 创建并配置截止时间检查定时器
	deadline_check_timer = Timer.new()
	deadline_check_timer.wait_time = 60.0  # 每60秒检查一次
	deadline_check_timer.autostart = false
	deadline_check_timer.timeout.connect(_on_deadline_check_timer_timeout)
	add_child(deadline_check_timer)

func set_task(data: TaskData):
	self.task_data = data

	if not is_instance_valid(task_data):
		push_error("["+self.name+"]"+"Invaild Data")
		visible = false
		return

	visible = true

	line_edit.text = task_data.title
	complete_check_box.button_pressed = task_data.is_completed

	# 重置警告标志
	has_warned_15min = false
	has_warned_deadline = false
	should_warn_15min = false

	# 已完成任务不显示截止时间
	if task_data.is_completed:
		due_time_label.visible = false
		# 停止定时器
		if deadline_check_timer:
			deadline_check_timer.stop()
	# 没有设置截止时间时也不显示
	elif task_data.due_timestamp == 0:
		due_time_label.visible = false
		# 停止定时器
		if deadline_check_timer:
			deadline_check_timer.stop()
	else:
		# 有截止时间且未完成，显示并检查过期状态
		due_time_label.text = task_data.get_formatted_due_time()
		due_time_label.visible = true
		_check_and_update_overdue_status()

		# 判断是否应该发出15分钟警告（检查当前剩余时间是否大于30分钟）
		var now = Time.get_unix_time_from_system()
		var time_remaining = task_data.due_timestamp - now
		should_warn_15min = (time_remaining > 1800)

		# 启动定时器
		if deadline_check_timer:
			deadline_check_timer.start()

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
	# 可选：如果你想点开就自动聚焦输入框
	# line_edit.grab_focus() 

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
	task_data.title = new_text
	content_changed.emit(self)


func _on_line_edit_editing_toggled(toggled_on: bool) -> void:
	var new_text = line_edit.text
	if new_text == task_data.title:
		return
	print("[%s]Task title change to \"%s\"" %[self.name,new_text])
	task_data.title = new_text
	content_changed.emit(self)

func _on_del_button_pressed() -> void:
	delete_requested.emit(self)

func _on_complete_check_box_toggled(toggled_on: bool) -> void:
	task_data.is_completed = toggled_on
	line_edit.is_completed = toggled_on

	if toggled_on:
		# 标记为完成
		task_data.finish_timestamp = Time.get_unix_time_from_system()
		due_time_label.visible = false
		# 退出编辑模式
		if is_editing:
			_disable_edit_mode()
		# 发出任务完成信号
		task_completed.emit(self)
	else:
		# 取消完成
		task_data.finish_timestamp = 0

		# 检查截止时间是否已过期
		if task_data.due_timestamp > 0:
			var now = Time.get_unix_time_from_system()
			if now > task_data.due_timestamp:
				# 已过期，重置截止时间
				task_data.due_timestamp = 0
				# 没有截止时间就不显示
				due_time_label.visible = false
			else:
				# 未过期，恢复显示截止时间
				due_time_label.text = task_data.get_formatted_due_time()
				due_time_label.visible = true
				_check_and_update_overdue_status()
		else:
			# 没有截止时间，不显示
			due_time_label.visible = false

	state_changed.emit(self)

## 处理时间设置按钮点击
func _on_time_set_button_pressed() -> void:
	_show_datetime_picker()

## 显示日期时间选择对话框
func _show_datetime_picker() -> void:
	# 获取当前时间或任务截止时间（UTC+8）
	var timezone_offset = 8 * 3600  # UTC+8
	var current_timestamp: int
	if task_data.due_timestamp > 0:
		# 如果已有截止时间，使用已有的
		current_timestamp = task_data.due_timestamp
	else:
		# 如果没有截止时间，默认设置当前时刻+1h
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

		# 更新任务数据
		task_data.due_timestamp = new_timestamp
		due_time_label.text = task_data.get_formatted_due_time()
		due_time_label.visible = true

		# 检查是否过期
		_check_and_update_overdue_status()

		# 重置警告标志（因为设置了新的截止时间）
		has_warned_15min = false
		has_warned_deadline = false

		# 判断总时间是否大于30分钟（1800秒）
		var now = Time.get_unix_time_from_system()
		var total_time = new_timestamp - now
		should_warn_15min = (total_time > 1800)

		# 启动定时器
		if deadline_check_timer and not task_data.is_completed:
			deadline_check_timer.start()

		# 触发内容变化信号
		content_changed.emit(self)

		dialog.hide_dialog()
	)

	dialog.show_dialog()

## 截止时间检查定时器超时处理
func _on_deadline_check_timer_timeout() -> void:
	# 如果任务已完成或没有截止时间，停止定时器
	if task_data.is_completed or task_data.due_timestamp == 0:
		deadline_check_timer.stop()
		return

	var now = Time.get_unix_time_from_system()
	var time_remaining = task_data.due_timestamp - now

	# 检查是否到达截止时间
	if time_remaining <= 0 and not has_warned_deadline:
		has_warned_deadline = true
		task_deadline_reached.emit(self)
		print("[%s]Task(id: %s) deadline reached!" % [self.name, task_data.id])
		# 更新过期状态显示
		_check_and_update_overdue_status()
		return

	# 检查是否剩余15分钟（900秒）
	# 只有当总时间大于30分钟时才发出15分钟警告
	if not has_warned_15min and should_warn_15min:
		if time_remaining <= 900 and time_remaining > 0:
			has_warned_15min = true
			task_deadline_warning.emit(self)
			print("[%s]Task(id: %s) has 15 minutes remaining!" % [self.name, task_data.id])

## 检查并更新过期状态
func _check_and_update_overdue_status() -> void:
	if task_data.due_timestamp == 0:
		# 没有设置截止时间
		due_time_label.add_theme_color_override("font_color", Color.WHITE)
		return

	var now = Time.get_unix_time_from_system()
	if now > task_data.due_timestamp and not task_data.is_completed:
		# 已过期且未完成
		due_time_label.add_theme_color_override("font_color", Color.RED)
		# 发出过期信号
		task_overdue.emit(self)
	else:
		# 未过期或已完成
		due_time_label.add_theme_color_override("font_color", Color.WHITE)
