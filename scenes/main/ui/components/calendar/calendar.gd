extends Control

# 日历控件 - 使用 calendar_library 插件

# 信号
signal date_selected(year: int, month: int, day: int)
signal cancelled

# 节点引用

@onready var prev_month_button: MaterialButton = $VBoxContainer/HBoxContainer/PrevMonthButton
@onready var next_month_button: MaterialButton = $VBoxContainer/HBoxContainer/NextMonthButton
@onready var prev_year_button: MaterialButton = $VBoxContainer/HBoxContainer/PrevYearButton
@onready var next_year_button: MaterialButton = $VBoxContainer/HBoxContainer/NextYearButton
@onready var month_label: Label = $VBoxContainer/HBoxContainer/MonthLabel
@onready var year_label: Label = $VBoxContainer/HBoxContainer/YearLabel
@onready var grid_container: GridContainer = $VBoxContainer/GridContainer
@onready var action_container: HBoxContainer = $VBoxContainer/ActionContainer
@onready var cancel_button: MaterialButton = $VBoxContainer/HBoxContainer3/CancelButton
@onready var confirm_button: MaterialButton = $VBoxContainer/HBoxContainer3/ConfirmButton

# 日历库实例
var calendar: Calendar
# 当前显示的年月
var current_year: int
var current_month: int
# 选中的日期
var selected_date: Dictionary = {}  # {year: int, month: int, day: int}
# 日期按钮数组
var day_buttons: Array[MaterialButton] = []

# 中文月份映射
const CHINESE_MONTHS = {
	1: "一月", 2: "二月", 3: "三月", 4: "四月",
	5: "五月", 6: "六月", 7: "七月", 8: "八月",
	9: "九月", 10: "十月", 11: "十一月", 12: "十二月"
}

func _ready():
	# 初始化日历库
	calendar = Calendar.new()
	calendar.set_first_weekday(Time.WEEKDAY_MONDAY)  # 从周一开始
	
	# 获取当前日期
	var today = calendar.get_today()
	current_year = today.year
	current_month = today.month
	selected_date = {
		"year": today.year,
		"month": today.month,
		"day": today.day
	}
	
	# 收集所有日期按钮
	_collect_day_buttons()
	
	# 连接按钮信号
	prev_month_button.pressed.connect(_on_prev_month_pressed)
	next_month_button.pressed.connect(_on_next_month_pressed)
	prev_year_button.pressed.connect(_on_prev_year_pressed)
	next_year_button.pressed.connect(_on_next_year_pressed)
	
	# 连接所有日期按钮
	for i in range(day_buttons.size()):
		day_buttons[i].pressed.connect(_on_day_button_pressed.bind(i))
	
	# 连接确认和取消按钮
	if cancel_button:
		cancel_button.pressed.connect(_on_cancel_pressed)
	if confirm_button:
		confirm_button.pressed.connect(_on_confirm_pressed)
	
	# 刷新显示
	_update_calendar()

func _collect_day_buttons():
	"""收集 GridContainer 中的所有按钮"""
	day_buttons.clear()
	for child in grid_container.get_children():
		if child is MaterialButton:
			day_buttons.append(child)

func _update_calendar():
	"""更新日历显示"""
	# 更新月份和年份标签
	month_label.text = CHINESE_MONTHS.get(current_month, str(current_month) + "月")
	year_label.text = str(current_year)
	
	# 获取当前月份的日历数据（强制6周显示）
	var month_data = calendar.get_calendar_month(current_year, current_month, true, true)
	
	# 更新日期按钮
	var button_index = 0
	for week in month_data:
		for day_data in week:
			if button_index >= day_buttons.size():
				break
				
			var button = day_buttons[button_index]
			
			if not day_data or not is_instance_of(day_data, Calendar.Date):
				# 没有日期数据
				button.text = ""
				button.disabled = true
				button.modulate = Color(1, 1, 1, 0.3)
			else:
				# 是一个日期对象
				button.text = str(day_data.day)
				button.disabled = false
				
				# 判断是否是当前月份
				if day_data.month == current_month:
					button.modulate = Color(1, 1, 1, 1)
				else:
					# 相邻月份的日期，半透明显示
					button.modulate = Color(1, 1, 1, 0.5)
				
				# 高亮选中的日期
				if (selected_date.has("year") and 
					selected_date["year"] == day_data.year and
					selected_date["month"] == day_data.month and
					selected_date["day"] == day_data.day):
					button.modulate = Color(0.3, 0.7, 1.0, 1)  # 蓝色高亮
					button.background_color = Color("ffffff00")
					button.set_pressed_no_signal(true)
			
			button_index += 1

func _on_prev_month_pressed():
	"""上一个月"""
	current_month -= 1
	if current_month < 1:
		current_month = 12
		current_year -= 1
	_update_calendar()

func _on_next_month_pressed():
	"""下一个月"""
	current_month += 1
	if current_month > 12:
		current_month = 1
		current_year += 1
	_update_calendar()

func _on_prev_year_pressed():
	"""上一年"""
	current_year -= 1
	_update_calendar()

func _on_next_year_pressed():
	"""下一年"""
	current_year += 1
	_update_calendar()

func _on_day_button_pressed(button_index: int):
	"""点击日期按钮"""
	# 获取当前月份的日历数据
	var month_data = calendar.get_calendar_month(current_year, current_month, true, true)
	
	# 计算按钮对应的日期
	var week_index = button_index / 7
	var day_index = button_index % 7
	
	if week_index < month_data.size():
		var week = month_data[week_index]
		if day_index < week.size():
			var day_data = week[day_index]
			if day_data and is_instance_of(day_data, Calendar.Date):
				# 更新选中日期
				selected_date = {
					"year": day_data.year,
					"month": day_data.month,
					"day": day_data.day
				}
				
				# 如果点击的是相邻月份的日期，切换到那个月
				if day_data.month != current_month:
					current_year = day_data.year
					current_month = day_data.month
				
				_update_calendar()


func get_selected_date() -> Dictionary:
	"""获取当前选中的日期"""
	return selected_date

func set_date(year: int, month: int, day: int):
	"""设置显示的日期"""
	current_year = year
	current_month = month
	selected_date = {
		"year": year,
		"month": month,
		"day": day
	}
	_update_calendar()

func show_action_buttons(show: bool):
	"""显示或隐藏确认/取消按钮"""
	if action_container:
		action_container.visible = show

func _on_confirm_pressed():
	"""确认按钮被点击"""
	if selected_date.has("year"):
		date_selected.emit(selected_date["year"], selected_date["month"], selected_date["day"])

func _on_cancel_pressed():
	"""取消按钮被点击"""
	cancelled.emit()
