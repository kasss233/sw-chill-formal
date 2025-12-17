class_name TaskData
extends RefCounted

var id: int = 0
var title: String = "新任务"
var due_timestamp: int  = 0 # 使用 Unix 时间戳 
var finish_timestamp: int = 0 #真实完成时间
var is_completed: bool = false


func _init(p_id: int, p_title: String, p_timestamp: int, p_completed: bool = false):
	self.id = p_id
	self.title = p_title
	self.due_timestamp = p_timestamp
	self.is_completed = p_completed

static func create_example():
	return TaskData.new(114154,"新任务",Time.get_unix_time_from_system(),false)

func get_formatted_due_time() -> String:
	if due_timestamp == 0:
		return "No due date"
	
	# +8 时区偏移量（秒）：8 小时 = 8 * 3600 = 28800 秒
	var timezone_offset = 8 * 3600
	
	# 获取当前本地时间戳和截止本地时间戳
	var now_local_timestamp = Time.get_unix_time_from_system() + timezone_offset
	var due_local_timestamp = due_timestamp + timezone_offset
	
	# 计算天数索引（从 1970-01-01 开始的天数）
	var today_day_index = int(now_local_timestamp / 86400)
	var due_day_index = int(due_local_timestamp / 86400)
	
	# 判断日期
	var date_string: String
	if today_day_index == due_day_index:
		date_string = "今天"
	elif due_day_index - today_day_index == 1:
		date_string = "明天"
	else:
		# 使用本地时间戳获取日期
		var due_local_dict = Time.get_datetime_dict_from_unix_time(due_local_timestamp)
		date_string = "%02d-%02d" % [due_local_dict.month, due_local_dict.day]
	# 使用本地时间戳获取小时和分钟
	var due_local_dict = Time.get_datetime_dict_from_unix_time(due_local_timestamp)
	var time_string = "%02d:%02d" % [due_local_dict.hour, due_local_dict.minute]
	
	return "%s %s" % [date_string, time_string]
