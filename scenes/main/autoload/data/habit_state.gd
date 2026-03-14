extends Node

## 习惯管理数据单例（Data Autoload）
## 唯一数据源，负责习惯库、时间段模板、课表排期和执行记录的管理与持久化

# --- 习惯库信号 ---
signal habit_added(habit: HabitData)
signal habit_removed(habit_id: int)
signal habit_updated(habit: HabitData)
# --- 时间段模板信号 ---
signal time_slot_template_changed
# --- 排期信号 ---
signal schedule_entry_added(entry)  # HabitData.ScheduleEntry
signal schedule_entry_removed(entry_id: int)
signal schedule_updated(week_key: String)
signal schedule_cleared(week_key: String)
# --- 执行记录信号 ---
signal execution_updated(record)  # HabitData.ExecutionRecord
# --- Agent 信号 ---
signal agent_schedule_generated(week_key: String)
# --- 通用 ---
signal data_loaded

# --- 内部状态 ---
var _habits: Array = []  # Array[HabitData]
var _time_slot_templates: Array = []  # Array[HabitData.TimeSlotTemplate]
var _schedule_entries: Array = []  # Array[HabitData.ScheduleEntry]
var _execution_records: Array = []  # Array[HabitData.ExecutionRecord]

var _next_habit_id: int = 1
var _next_slot_template_id: int = 1
var _next_entry_id: int = 1
var _next_record_id: int = 1

const SAVE_PATH = "user://habit_data.json"


func _ready() -> void:
	load_data()
	print("[HabitState] Initialized, habits=%d, templates=%d, entries=%d, records=%d" % [
		_habits.size(), _time_slot_templates.size(),
		_schedule_entries.size(), _execution_records.size()
	])


# ======================== 查询 API - 习惯库 ========================

func get_all_habits() -> Array:
	return _habits.duplicate()


func get_active_habits() -> Array:
	var result: Array = []
	for h in _habits:
		if h.is_active:
			result.append(h)
	return result


func get_habit_by_id(id: int) -> HabitData:
	for h in _habits:
		if h.id == id:
			return h
	return null


# ======================== 查询 API - 时间段 ========================

func get_time_slot_templates() -> Array:
	return _time_slot_templates.duplicate()


func get_time_slot_by_id(id: int) -> HabitData.TimeSlotTemplate:
	for s in _time_slot_templates:
		if s.id == id:
			return s
	return null


# ======================== 查询 API - 排期 ========================

func get_week_schedule(week_key: String) -> Array:
	var result: Array = []
	for e in _schedule_entries:
		if e.week_key == week_key:
			result.append(e)
	return result


func get_day_schedule(week_key: String, day: int) -> Array:
	var result: Array = []
	for e in _schedule_entries:
		if e.week_key == week_key and e.day_of_week == day:
			result.append(e)
	return result


func get_current_week_key() -> String:
	var now = Time.get_datetime_dict_from_system()
	# 计算 ISO 周数
	var date_str = "%04d-%02d-%02d" % [now["year"], now["month"], now["day"]]
	var unix = Time.get_unix_time_from_datetime_string(date_str + "T12:00:00")
	var dict = Time.get_datetime_dict_from_unix_time(unix)
	# weekday: 0=Sunday, 1=Monday ... 6=Saturday
	var weekday = dict["weekday"]
	# 转为 ISO: Monday=1 ... Sunday=7
	var iso_weekday = weekday if weekday != 0 else 7
	# ISO 周算法：找到本周四所在年的第几天
	var thursday_unix = unix + (4 - iso_weekday) * 86400
	var thursday_dict = Time.get_datetime_dict_from_unix_time(thursday_unix)
	var year = thursday_dict["year"]
	# 计算周四是今年第几天
	var jan1_str = "%04d-01-01T12:00:00" % year
	var jan1_unix = Time.get_unix_time_from_datetime_string(jan1_str)
	var day_of_year = int((thursday_unix - jan1_unix) / 86400) + 1
	var week_num = int((day_of_year - 1) / 7) + 1
	return "%04d-W%02d" % [year, week_num]


func check_conflict(week_key: String, day: int, time_slot_id: int, exclude_id: int = -1) -> bool:
	for e in _schedule_entries:
		if e.week_key == week_key and e.day_of_week == day and e.time_slot_id == time_slot_id:
			if e.id != exclude_id:
				return true
	return false


# ======================== 查询 API - 执行记录 ========================

func get_records_by_date(date_key: String) -> Array:
	var result: Array = []
	for r in _execution_records:
		if r.date_key == date_key:
			result.append(r)
	return result


func get_records_by_week(week_key: String) -> Array:
	var entries = get_week_schedule(week_key)
	var entry_ids: Array = []
	for e in entries:
		entry_ids.append(e.id)
	var result: Array = []
	for r in _execution_records:
		if r.entry_id in entry_ids:
			result.append(r)
	return result


func get_records_by_habit(habit_id: int) -> Array:
	var result: Array = []
	for r in _execution_records:
		if r.habit_id == habit_id:
			result.append(r)
	return result


# ======================== 查询 API - 统计 ========================

func get_habit_completion_rate(habit_id: int, week_key: String) -> float:
	var records = get_records_by_week(week_key)
	var total: int = 0
	var completed: int = 0
	for r in records:
		if r.habit_id == habit_id:
			total += 1
			if r.status == HabitData.ExecutionRecord.Status.COMPLETED:
				completed += 1
	if total == 0:
		return 0.0
	return float(completed) / float(total)


func get_week_completion_rate(week_key: String) -> float:
	var records = get_records_by_week(week_key)
	if records.is_empty():
		return 0.0
	var completed: int = 0
	for r in records:
		if r.status == HabitData.ExecutionRecord.Status.COMPLETED:
			completed += 1
	return float(completed) / float(records.size())


func get_week_stats(week_key: String) -> Dictionary:
	var entries = get_week_schedule(week_key)
	var records = get_records_by_week(week_key)
	var total = records.size()
	var completed: int = 0
	var skipped: int = 0
	var deferred: int = 0
	var pending: int = 0
	for r in records:
		match r.status:
			HabitData.ExecutionRecord.Status.COMPLETED: completed += 1
			HabitData.ExecutionRecord.Status.SKIPPED: skipped += 1
			HabitData.ExecutionRecord.Status.DEFERRED: deferred += 1
			_: pending += 1
	return {
		"total_entries": entries.size(),
		"total_records": total,
		"completed": completed,
		"skipped": skipped,
		"deferred": deferred,
		"pending": pending,
		"completion_rate": get_week_completion_rate(week_key),
	}


# ======================== 修改 API - 习惯库 ========================

func add_habit(p_name: String, p_minutes: int = 30, p_period: int = 0, p_frequency: int = 0, p_color: String = "#4CAF50") -> HabitData:
	var habit = HabitData.new(_next_habit_id, p_name, p_minutes, p_period, p_frequency, p_color)
	_next_habit_id += 1
	_habits.append(habit)
	_save_data()
	habit_added.emit(habit)
	print("[HabitState] Added habit(id: %d, name: %s)" % [habit.id, habit.name])
	return habit


func update_habit(id: int, fields: Dictionary) -> bool:
	var habit = get_habit_by_id(id)
	if habit == null:
		return false
	if fields.has("name"):
		habit.name = fields["name"]
	if fields.has("estimated_minutes"):
		habit.estimated_minutes = int(fields["estimated_minutes"])
	if fields.has("preferred_period"):
		habit.preferred_period = int(fields["preferred_period"])
	if fields.has("frequency"):
		habit.frequency = int(fields["frequency"])
	if fields.has("color"):
		habit.color = fields["color"]
	if fields.has("is_active"):
		habit.is_active = fields["is_active"]
	habit.updated_at = int(Time.get_unix_time_from_system())
	_save_data()
	habit_updated.emit(habit)
	print("[HabitState] Updated habit(id: %d)" % id)
	return true


func remove_habit(id: int) -> bool:
	for i in range(_habits.size()):
		if _habits[i].id == id:
			_habits.remove_at(i)
			# 同时移除关联的排期和执行记录
			_remove_entries_by_habit(id)
			_save_data()
			habit_removed.emit(id)
			print("[HabitState] Removed habit(id: %d)" % id)
			return true
	return false


func set_habit_active(id: int, active: bool) -> bool:
	return update_habit(id, {"is_active": active})


# ======================== 修改 API - 时间段模板 ========================

func add_time_slot_template(p_name: String, p_start: String, p_end: String) -> HabitData.TimeSlotTemplate:
	var slot = HabitData.TimeSlotTemplate.new(_next_slot_template_id, p_name, p_start, p_end, _time_slot_templates.size())
	_next_slot_template_id += 1
	_time_slot_templates.append(slot)
	_save_data()
	time_slot_template_changed.emit()
	print("[HabitState] Added time slot template(id: %d, name: %s)" % [slot.id, slot.name])
	return slot


func update_time_slot_template(id: int, fields: Dictionary) -> bool:
	var slot = get_time_slot_by_id(id)
	if slot == null:
		return false
	if fields.has("name"):
		slot.name = fields["name"]
	if fields.has("start_time"):
		slot.start_time = fields["start_time"]
	if fields.has("end_time"):
		slot.end_time = fields["end_time"]
	_save_data()
	time_slot_template_changed.emit()
	return true


func remove_time_slot_template(id: int) -> bool:
	for i in range(_time_slot_templates.size()):
		if _time_slot_templates[i].id == id:
			_time_slot_templates.remove_at(i)
			_update_slot_orders()
			# 移除使用该时间段的排期
			_remove_entries_by_slot(id)
			_save_data()
			time_slot_template_changed.emit()
			print("[HabitState] Removed time slot template(id: %d)" % id)
			return true
	return false


func reorder_time_slot_templates(ids: Array) -> void:
	var reordered: Array = []
	for target_id in ids:
		var slot = get_time_slot_by_id(int(target_id))
		if slot:
			reordered.append(slot)
	_time_slot_templates = reordered
	_update_slot_orders()
	_save_data()
	time_slot_template_changed.emit()


# ======================== 修改 API - 排期 ========================

func add_schedule_entry(habit_id: int, week_key: String, day: int, time_slot_id: int) -> HabitData.ScheduleEntry:
	if check_conflict(week_key, day, time_slot_id):
		push_warning("[HabitState] Schedule conflict: week=%s day=%d slot=%d" % [week_key, day, time_slot_id])
		return null
	var entry = HabitData.ScheduleEntry.new(_next_entry_id, habit_id, week_key, day, time_slot_id)
	_next_entry_id += 1
	_schedule_entries.append(entry)
	_save_data()
	schedule_entry_added.emit(entry)
	print("[HabitState] Added schedule entry(id: %d, habit: %d, week: %s, day: %d, slot: %d)" % [entry.id, habit_id, week_key, day, time_slot_id])
	return entry


func remove_schedule_entry(id: int) -> bool:
	for i in range(_schedule_entries.size()):
		if _schedule_entries[i].id == id:
			_schedule_entries.remove_at(i)
			# 移除关联的执行记录
			_remove_records_by_entry(id)
			_save_data()
			schedule_entry_removed.emit(id)
			print("[HabitState] Removed schedule entry(id: %d)" % id)
			return true
	return false


func clear_week_schedule(week_key: String) -> void:
	var i = _schedule_entries.size() - 1
	while i >= 0:
		if _schedule_entries[i].week_key == week_key:
			var entry_id = _schedule_entries[i].id
			_schedule_entries.remove_at(i)
			_remove_records_by_entry(entry_id)
		i -= 1
	_save_data()
	schedule_cleared.emit(week_key)
	print("[HabitState] Cleared week schedule: %s" % week_key)


func copy_week_schedule(from_week: String, to_week: String) -> void:
	clear_week_schedule(to_week)
	var source = get_week_schedule(from_week)
	for e in source:
		add_schedule_entry(e.habit_id, to_week, e.day_of_week, e.time_slot_id)
	schedule_updated.emit(to_week)
	print("[HabitState] Copied schedule from %s to %s (%d entries)" % [from_week, to_week, source.size()])


func apply_schedule_batch(week_key: String, entries: Array) -> void:
	clear_week_schedule(week_key)
	for entry_data in entries:
		add_schedule_entry(
			int(entry_data.get("habit_id", 0)),
			week_key,
			int(entry_data.get("day_of_week", 0)),
			int(entry_data.get("time_slot_id", 0)),
		)
	schedule_updated.emit(week_key)


# ======================== 修改 API - 执行记录 ========================

func set_execution_status(entry_id: int, date_key: String, status: int) -> HabitData.ExecutionRecord:
	# 查找已有记录
	for r in _execution_records:
		if r.entry_id == entry_id and r.date_key == date_key:
			r.status = status
			if status == HabitData.ExecutionRecord.Status.COMPLETED:
				r.completed_at = int(Time.get_unix_time_from_system())
			else:
				r.completed_at = 0
			_save_data()
			execution_updated.emit(r)
			return r

	# 没有找到，创建新记录
	var entry = _get_entry_by_id(entry_id)
	if entry == null:
		return null
	var record = HabitData.ExecutionRecord.new(_next_record_id, entry_id, entry.habit_id, date_key, status)
	_next_record_id += 1
	if status == HabitData.ExecutionRecord.Status.COMPLETED:
		record.completed_at = int(Time.get_unix_time_from_system())
	_execution_records.append(record)
	_save_data()
	execution_updated.emit(record)
	print("[HabitState] Set execution: entry=%d date=%s status=%d" % [entry_id, date_key, status])
	return record


func ensure_daily_records(date_key: String) -> void:
	# 获取当前周 key
	var week_key = _date_key_to_week_key(date_key)
	var day = _date_key_to_day_of_week(date_key)
	var day_entries = get_day_schedule(week_key, day)

	for entry in day_entries:
		var found = false
		for r in _execution_records:
			if r.entry_id == entry.id and r.date_key == date_key:
				found = true
				break
		if not found:
			var record = HabitData.ExecutionRecord.new(_next_record_id, entry.id, entry.habit_id, date_key, HabitData.ExecutionRecord.Status.PENDING)
			_next_record_id += 1
			_execution_records.append(record)
	_save_data()


# ======================== Agent API ========================

func agent_add_habit(p_name: String, p_minutes: int = 30, p_period: int = 0, p_frequency: int = 0) -> Dictionary:
	var habit = add_habit(p_name, p_minutes, p_period, p_frequency)
	return habit.to_dict()


func agent_get_habits() -> Array:
	var result: Array = []
	for h in get_active_habits():
		result.append(h.to_dict())
	return result


func agent_generate_schedule(week_key: String, entries: Array) -> bool:
	apply_schedule_batch(week_key, entries)
	agent_schedule_generated.emit(week_key)
	return true


func agent_get_week_schedule(week_key: String) -> Array:
	var result: Array = []
	var entries = get_week_schedule(week_key)
	for e in entries:
		var habit = get_habit_by_id(e.habit_id)
		var slot = get_time_slot_by_id(e.time_slot_id)
		result.append({
			"entry_id": e.id,
			"habit_id": e.habit_id,
			"habit_name": habit.name if habit else "未知",
			"day_of_week": e.day_of_week,
			"time_slot_id": e.time_slot_id,
			"time_slot_name": slot.name if slot else "未知",
			"start_time": slot.start_time if slot else "",
			"end_time": slot.end_time if slot else "",
		})
	return result


func agent_get_habit_stats(week_key: String) -> Dictionary:
	return get_week_stats(week_key)


func agent_set_execution(entry_id: int, date_key: String, status: int) -> bool:
	var record = set_execution_status(entry_id, date_key, status)
	return record != null


func agent_get_time_slots() -> Array:
	var result: Array = []
	for s in _time_slot_templates:
		result.append(s.to_dict())
	return result


# ======================== 持久化 ========================

func _save_data() -> void:
	var data = {
		"version": 1,
		"next_habit_id": _next_habit_id,
		"next_slot_template_id": _next_slot_template_id,
		"next_entry_id": _next_entry_id,
		"next_record_id": _next_record_id,
		"habits": [],
		"time_slot_templates": [],
		"schedule_entries": [],
		"execution_records": [],
	}
	for h in _habits:
		data["habits"].append(h.to_dict())
	for s in _time_slot_templates:
		data["time_slot_templates"].append(s.to_dict())
	for e in _schedule_entries:
		data["schedule_entries"].append(e.to_dict())
	for r in _execution_records:
		data["execution_records"].append(r.to_dict())

	var json_string = JSON.stringify(data, "\t")
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(json_string)
		file.close()
	else:
		push_error("[HabitState] Failed to save data to %s" % SAVE_PATH)


func load_data() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		print("[HabitState] No save file found, initializing defaults")
		_init_default_templates()
		_save_data()
		data_loaded.emit()
		return

	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		push_error("[HabitState] Failed to open save file")
		_init_default_templates()
		data_loaded.emit()
		return

	var json_string = file.get_as_text()
	file.close()

	var json = JSON.new()
	var error = json.parse(json_string)
	if error != OK:
		push_error("[HabitState] Failed to parse save file: %s" % json.get_error_message())
		_init_default_templates()
		data_loaded.emit()
		return

	var data = json.get_data()
	if not data is Dictionary:
		push_error("[HabitState] Invalid save data format")
		_init_default_templates()
		data_loaded.emit()
		return

	_next_habit_id = data.get("next_habit_id", 1)
	_next_slot_template_id = data.get("next_slot_template_id", 1)
	_next_entry_id = data.get("next_entry_id", 1)
	_next_record_id = data.get("next_record_id", 1)

	_habits.clear()
	for d in data.get("habits", []):
		_habits.append(HabitData.from_dict(d))

	_time_slot_templates.clear()
	for d in data.get("time_slot_templates", []):
		_time_slot_templates.append(HabitData.TimeSlotTemplate.from_dict(d))

	_schedule_entries.clear()
	for d in data.get("schedule_entries", []):
		_schedule_entries.append(HabitData.ScheduleEntry.from_dict(d))

	_execution_records.clear()
	for d in data.get("execution_records", []):
		_execution_records.append(HabitData.ExecutionRecord.from_dict(d))

	# 如果没有时间段模板，初始化默认
	if _time_slot_templates.is_empty():
		_init_default_templates()

	data_loaded.emit()


# ======================== 内部辅助 ========================

func _init_default_templates() -> void:
	var defaults = [
		["早晨", "06:00", "08:00"],
		["上午前段", "08:00", "10:00"],
		["上午后段", "10:00", "12:00"],
		["下午前段", "14:00", "16:00"],
		["下午后段", "16:00", "18:00"],
		["晚间前段", "19:00", "21:00"],
		["晚间后段", "21:00", "23:00"],
	]
	for i in range(defaults.size()):
		var d = defaults[i]
		var slot = HabitData.TimeSlotTemplate.new(_next_slot_template_id, d[0], d[1], d[2], i)
		_next_slot_template_id += 1
		_time_slot_templates.append(slot)
	print("[HabitState] Initialized %d default time slot templates" % _time_slot_templates.size())


func _update_slot_orders() -> void:
	for i in range(_time_slot_templates.size()):
		_time_slot_templates[i].order = i


func _get_entry_by_id(id: int) -> HabitData.ScheduleEntry:
	for e in _schedule_entries:
		if e.id == id:
			return e
	return null


func _remove_entries_by_habit(habit_id: int) -> void:
	var i = _schedule_entries.size() - 1
	while i >= 0:
		if _schedule_entries[i].habit_id == habit_id:
			var entry_id = _schedule_entries[i].id
			_schedule_entries.remove_at(i)
			_remove_records_by_entry(entry_id)
		i -= 1


func _remove_entries_by_slot(slot_id: int) -> void:
	var i = _schedule_entries.size() - 1
	while i >= 0:
		if _schedule_entries[i].time_slot_id == slot_id:
			var entry_id = _schedule_entries[i].id
			_schedule_entries.remove_at(i)
			_remove_records_by_entry(entry_id)
		i -= 1


func _remove_records_by_entry(entry_id: int) -> void:
	var i = _execution_records.size() - 1
	while i >= 0:
		if _execution_records[i].entry_id == entry_id:
			_execution_records.remove_at(i)
		i -= 1


func _date_key_to_week_key(date_key: String) -> String:
	var unix = Time.get_unix_time_from_datetime_string(date_key + "T12:00:00")
	var dict = Time.get_datetime_dict_from_unix_time(unix)
	var weekday = dict["weekday"]
	var iso_weekday = weekday if weekday != 0 else 7
	var thursday_unix = unix + (4 - iso_weekday) * 86400
	var thursday_dict = Time.get_datetime_dict_from_unix_time(thursday_unix)
	var year = thursday_dict["year"]
	var jan1_str = "%04d-01-01T12:00:00" % year
	var jan1_unix = Time.get_unix_time_from_datetime_string(jan1_str)
	var day_of_year = int((thursday_unix - jan1_unix) / 86400) + 1
	var week_num = int((day_of_year - 1) / 7) + 1
	return "%04d-W%02d" % [year, week_num]


func _date_key_to_day_of_week(date_key: String) -> int:
	var unix = Time.get_unix_time_from_datetime_string(date_key + "T12:00:00")
	var dict = Time.get_datetime_dict_from_unix_time(unix)
	var weekday = dict["weekday"]  # 0=Sunday
	# 转为 0=Monday ... 6=Sunday
	if weekday == 0:
		return 6
	return weekday - 1


## 导出数据
func export_data() -> Dictionary:
	var data = {
		"version": 1,
		"next_habit_id": _next_habit_id,
		"next_slot_template_id": _next_slot_template_id,
		"next_entry_id": _next_entry_id,
		"next_record_id": _next_record_id,
		"habits": [],
		"time_slot_templates": [],
		"schedule_entries": [],
		"execution_records": [],
	}
	for h in _habits:
		data["habits"].append(h.to_dict())
	for s in _time_slot_templates:
		data["time_slot_templates"].append(s.to_dict())
	for e in _schedule_entries:
		data["schedule_entries"].append(e.to_dict())
	for r in _execution_records:
		data["execution_records"].append(r.to_dict())
	return data


## 导入数据
func import_data(data: Dictionary) -> void:
	if not data.has("habits"):
		push_error("[HabitState] Invalid import data")
		return
	_next_habit_id = data.get("next_habit_id", 1)
	_next_slot_template_id = data.get("next_slot_template_id", 1)
	_next_entry_id = data.get("next_entry_id", 1)
	_next_record_id = data.get("next_record_id", 1)
	_habits.clear()
	_time_slot_templates.clear()
	_schedule_entries.clear()
	_execution_records.clear()
	for d in data.get("habits", []):
		_habits.append(HabitData.from_dict(d))
	for d in data.get("time_slot_templates", []):
		_time_slot_templates.append(HabitData.TimeSlotTemplate.from_dict(d))
	for d in data.get("schedule_entries", []):
		_schedule_entries.append(HabitData.ScheduleEntry.from_dict(d))
	for d in data.get("execution_records", []):
		_execution_records.append(HabitData.ExecutionRecord.from_dict(d))
	_save_data()
	print("[HabitState] Imported data")
	data_loaded.emit()
