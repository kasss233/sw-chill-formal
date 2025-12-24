extends Button

# DatePicker 组件 - 点击弹出日历选择器

# 信号
signal date_selected(year: int, month: int, day: int)

# 当前选中的日期
var current_date: Dictionary = {}  # {year: int, month: int, day: int}

# 日历实例
var calendar_popup: Control = null
var calendar_instance = null

func _ready():
	# 初始化按钮文本
	if current_date.is_empty():
		var today = Time.get_date_dict_from_system()
		current_date = {
			"year": today.year,
			"month": today.month,
			"day": today.day
		}
	
	_update_button_text()
	
	# 连接按钮点击事件
	pressed.connect(_on_button_pressed)

func _update_button_text():
	"""更新按钮显示的日期文本"""
	if current_date.has("year"):
		text = "%d年%d月%d日" % [current_date["year"], current_date["month"], current_date["day"]]
	else:
		text = "选择日期"

func _on_button_pressed():
	"""按钮被点击，弹出日历"""
	if calendar_popup == null:
		_create_calendar_popup()
	
	if calendar_popup.visible:
		_hide_calendar()
	else:
		_show_calendar()

func _create_calendar_popup():
	"""创建日历弹出窗口"""
	# 创建弹出容器
	calendar_popup = Control.new()
	calendar_popup.set_anchors_preset(Control.PRESET_FULL_RECT)
	calendar_popup.mouse_filter = Control.MOUSE_FILTER_STOP
	calendar_popup.visible = false
	calendar_popup.z_index = 100  # 确保在最上层
	
	# 创建半透明背景（点击关闭）
	var overlay = ColorRect.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0, 0, 0, 0.3)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.gui_input.connect(_on_overlay_input)
	calendar_popup.add_child(overlay)
	
	# 获取按钮的全局位置和大小
	var button_global_pos = global_position
	var button_size = size
	
	# 实例化日历
	var calendar_scene = preload("res://scenes/main/ui/components/calendar/calendar.tscn")
	calendar_instance = calendar_scene.instantiate()
	
	# 设置日历位置（在按钮下方）
	calendar_instance.position = Vector2(
		button_global_pos.x,
		button_global_pos.y + button_size.y + 5
	)
	
	# 确保日历不会超出屏幕边界
	var viewport_size = get_viewport().size
	var calendar_size = Vector2(360, 424)  # 日历的大小
	
	# 调整 X 位置
	if calendar_instance.position.x + calendar_size.x > viewport_size.x:
		calendar_instance.position.x = viewport_size.x - calendar_size.x - 10
	if calendar_instance.position.x < 10:
		calendar_instance.position.x = 10
	
	# 调整 Y 位置
	if calendar_instance.position.y + calendar_size.y > viewport_size.y:
		calendar_instance.position.y = button_global_pos.y - calendar_size.y - 5
	
	calendar_popup.add_child(calendar_instance)
	
	# 添加到场景树先
	get_tree().root.add_child(calendar_popup)
	
	# 等待一帧确保节点树完全构建
	await get_tree().process_frame
	
	# 设置日历的初始日期
	if current_date.has("year"):
		calendar_instance.set_date(current_date["year"], current_date["month"], current_date["day"])
	
	# 显示日历的确认/取消按钮
	calendar_instance.show_action_buttons(true)
	
	# 连接日历信号
	calendar_instance.date_selected.connect(_on_calendar_date_selected)
	calendar_instance.cancelled.connect(_on_calendar_cancelled)

func _show_calendar():
	"""显示日历"""
	if calendar_popup:
		calendar_popup.visible = true

func _hide_calendar():
	"""隐藏日历"""
	if calendar_popup:
		calendar_popup.visible = false

func _on_overlay_input(event: InputEvent):
	"""点击背景遮罩关闭日历"""
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_hide_calendar()

func _on_calendar_date_selected(year: int, month: int, day: int):
	"""日历日期被选中（确认按钮被点击）"""
	current_date = {
		"year": year,
		"month": month,
		"day": day
	}
	_update_button_text()
	_hide_calendar()
	
	# 发送信号给父组件
	date_selected.emit(year, month, day)

func _on_calendar_cancelled():
	"""取消选择（取消按钮被点击）"""
	_hide_calendar()

func get_selected_date() -> Dictionary:
	"""获取当前选中的日期"""
	return current_date

func set_date(year: int, month: int, day: int):
	"""设置日期"""
	current_date = {
		"year": year,
		"month": month,
		"day": day
	}
	_update_button_text()
	
	# 如果日历已创建，同步更新
	if calendar_instance and is_instance_valid(calendar_instance):
		calendar_instance.set_date(year, month, day)

func _exit_tree():
	"""清理弹出窗口"""
	if calendar_popup and is_instance_valid(calendar_popup):
		calendar_popup.queue_free()
