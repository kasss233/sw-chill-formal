class_name HabitData
extends RefCounted

## 习惯库条目

var id: int = 0
var name: String = ""
var estimated_minutes: int = 30
var preferred_period: int = 0  # 0=早晨, 1=下午, 2=晚间
var frequency: int = 0  # 0=每天, 1=隔天, 2=仅工作日
var color: String = "#4CAF50"
var is_active: bool = true
var created_at: int = 0
var updated_at: int = 0


func _init(p_id: int = 0, p_name: String = "", p_minutes: int = 30, p_period: int = 0, p_frequency: int = 0, p_color: String = "#4CAF50") -> void:
	id = p_id
	name = p_name
	estimated_minutes = p_minutes
	preferred_period = p_period
	frequency = p_frequency
	color = p_color
	created_at = int(Time.get_unix_time_from_system())
	updated_at = int(Time.get_unix_time_from_system())


func to_dict() -> Dictionary:
	return {
		"id": id,
		"name": name,
		"estimated_minutes": estimated_minutes,
		"preferred_period": preferred_period,
		"frequency": frequency,
		"color": color,
		"is_active": is_active,
		"created_at": created_at,
		"updated_at": updated_at,
	}


static func from_dict(d: Dictionary) -> HabitData:
	var h = HabitData.new(
		d.get("id", 0),
		d.get("name", ""),
		d.get("estimated_minutes", 30),
		d.get("preferred_period", 0),
		d.get("frequency", 0),
		d.get("color", "#4CAF50"),
	)
	h.is_active = d.get("is_active", true)
	h.created_at = d.get("created_at", 0)
	h.updated_at = d.get("updated_at", 0)
	return h


func get_period_name() -> String:
	match preferred_period:
		0: return "早晨"
		1: return "下午"
		2: return "晚间"
		_: return "未知"


func get_frequency_name() -> String:
	match frequency:
		0: return "每天"
		1: return "隔天"
		2: return "仅工作日"
		_: return "未知"


# ============================================================

class TimeSlotTemplate:
	extends RefCounted
	## 自定义时间段模板（课表模式）

	var id: int = 0
	var name: String = ""
	var start_time: String = "08:00"  # HH:MM
	var end_time: String = "10:00"
	var order: int = 0

	func _init(p_id: int = 0, p_name: String = "", p_start: String = "08:00", p_end: String = "10:00", p_order: int = 0) -> void:
		id = p_id
		name = p_name
		start_time = p_start
		end_time = p_end
		order = p_order

	func to_dict() -> Dictionary:
		return {
			"id": id,
			"name": name,
			"start_time": start_time,
			"end_time": end_time,
			"order": order,
		}

	static func from_dict(d: Dictionary) -> TimeSlotTemplate:
		return TimeSlotTemplate.new(
			d.get("id", 0),
			d.get("name", ""),
			d.get("start_time", "08:00"),
			d.get("end_time", "10:00"),
			d.get("order", 0),
		)


# ============================================================

class ScheduleEntry:
	extends RefCounted
	## 课表条目（哪个时间段放什么习惯）

	var id: int = 0
	var habit_id: int = 0
	var week_key: String = ""  # "2026-W10"
	var day_of_week: int = 0   # 0=周一 ~ 6=周日
	var time_slot_id: int = 0
	var created_at: int = 0

	func _init(p_id: int = 0, p_habit_id: int = 0, p_week_key: String = "", p_day: int = 0, p_slot_id: int = 0) -> void:
		id = p_id
		habit_id = p_habit_id
		week_key = p_week_key
		day_of_week = p_day
		time_slot_id = p_slot_id
		created_at = int(Time.get_unix_time_from_system())

	func to_dict() -> Dictionary:
		return {
			"id": id,
			"habit_id": habit_id,
			"week_key": week_key,
			"day_of_week": day_of_week,
			"time_slot_id": time_slot_id,
			"created_at": created_at,
		}

	static func from_dict(d: Dictionary) -> ScheduleEntry:
		var e = ScheduleEntry.new(
			d.get("id", 0),
			d.get("habit_id", 0),
			d.get("week_key", ""),
			d.get("day_of_week", 0),
			d.get("time_slot_id", 0),
		)
		e.created_at = d.get("created_at", 0)
		return e


# ============================================================

class ExecutionRecord:
	extends RefCounted
	## 执行记录

	enum Status { PENDING = 0, COMPLETED = 1, SKIPPED = 2, DEFERRED = 3 }

	var id: int = 0
	var entry_id: int = 0
	var habit_id: int = 0  # 冗余，方便查询
	var date_key: String = ""  # "2026-03-07"
	var status: int = Status.PENDING
	var completed_at: int = 0

	func _init(p_id: int = 0, p_entry_id: int = 0, p_habit_id: int = 0, p_date_key: String = "", p_status: int = Status.PENDING) -> void:
		id = p_id
		entry_id = p_entry_id
		habit_id = p_habit_id
		date_key = p_date_key
		status = p_status

	func to_dict() -> Dictionary:
		return {
			"id": id,
			"entry_id": entry_id,
			"habit_id": habit_id,
			"date_key": date_key,
			"status": status,
			"completed_at": completed_at,
		}

	static func from_dict(d: Dictionary) -> ExecutionRecord:
		var r = ExecutionRecord.new(
			d.get("id", 0),
			d.get("entry_id", 0),
			d.get("habit_id", 0),
			d.get("date_key", ""),
			d.get("status", 0),
		)
		r.completed_at = d.get("completed_at", 0)
		return r
