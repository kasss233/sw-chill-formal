class_name TaskData
extends RefCounted

#自增id
var id: int = 0
var title: String = "新任务"
var due_timestamp: int  = 0 #使用 Unix 时间戳
var finish_timestamp: int = 0 #真实完成时间
var is_completed: bool = false
var order: int = 0 # 排序用
var created_at: int = 0 # 创建时间戳
var server_id: int = 0 # 服务器端 ID（0 = 未同步）
var updated_at: int = 0 # 最后修改时间戳（秒级）


func _init(p_id: int, p_title: String, p_timestamp: int, p_completed: bool = false):
	self.id = p_id
	self.title = p_title
	self.due_timestamp = p_timestamp
	self.is_completed = p_completed
	self.created_at = int(Time.get_unix_time_from_system())
	self.updated_at = int(Time.get_unix_time_from_system())

static func create_example(id:int):
	return TaskData.new(id,"新任务",0,false)

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

## 序列化为字典
func to_dict() -> Dictionary:
	return {
		"id": id,
		"title": title,
		"due_timestamp": due_timestamp,
		"finish_timestamp": finish_timestamp,
		"is_completed": is_completed,
		"created_at": created_at,
		"order": order,
		"server_id": server_id,
		"updated_at": updated_at
	}

## 从字典反序列化
static func from_dict(d: Dictionary) -> TaskData:
	var task = TaskData.new(
		d.get("id", 0),
		d.get("title", "新任务"),
		d.get("due_timestamp", 0),
		d.get("is_completed", false)
	)
	task.finish_timestamp = d.get("finish_timestamp", 0)
	task.created_at = d.get("created_at", 0)
	task.order = d.get("order", 0)
	task.server_id = d.get("server_id", 0)
	task.updated_at = d.get("updated_at", 0)
	return task
