extends Node

## 统一统计数据单例（Data Autoload）
## 管理所有类型的统计记录（focus, habit, task 等）
## 持久化到 user://stats_data.json

signal record_added(record: StatsRecord)
signal record_removed(id: int)
signal data_loaded

const SAVE_PATH = "user://stats_data.json"

var _records: Array[StatsRecord] = []
var _next_id: int = 1

# focus 类型内部状态
var _focus_start_time: int = 0
var _focus_work_duration: int = 0


func _ready() -> void:
	_load_data()
	data_loaded.emit()

	# 连接 PomodoroState 信号采集 focus 数据
	if PomodoroState:
		PomodoroState.work_phase_started.connect(_on_work_phase_started)
		PomodoroState.work_phase_completed.connect(_on_work_phase_completed)
		PomodoroState.work_phase_stopped.connect(_on_work_phase_stopped)
		PomodoroState.all_completed.connect(_on_all_completed)

	print("[StatsState] 初始化完成，记录数: %d" % _records.size())


# ======================== 通用记录 API ========================

func add_record(record_type: String, date_key: String, record_data: Dictionary) -> StatsRecord:
	var record = StatsRecord.new()
	record.id = _next_id
	_next_id += 1
	record.record_type = record_type
	record.date_key = date_key
	record.data = record_data
	record.created_at = int(Time.get_unix_time_from_system())
	_records.append(record)
	_save_data()
	record_added.emit(record)
	return record


func remove_record(id: int) -> bool:
	for i in range(_records.size()):
		if _records[i].id == id:
			_records.remove_at(i)
			_save_data()
			record_removed.emit(id)
			return true
	return false


func get_records(record_type: String, date_key: String = "") -> Array:
	var result: Array = []
	for r in _records:
		if r.record_type != record_type:
			continue
		if date_key != "" and r.date_key != date_key:
			continue
		result.append(r)
	return result


func get_records_in_range(record_type: String, from_date: String, to_date: String) -> Array:
	var result: Array = []
	for r in _records:
		if r.record_type != record_type:
			continue
		if r.date_key >= from_date and r.date_key <= to_date:
			result.append(r)
	return result


# ======================== 聚合查询 API ========================

func get_day_total(record_type: String, date_key: String, value_key: String) -> float:
	var total: float = 0.0
	for r in _records:
		if r.record_type == record_type and r.date_key == date_key:
			total += float(r.data.get(value_key, 0))
	return total


func get_week_daily_totals(record_type: String, monday_date: String, value_key: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var monday_unix = DateUtil.date_str_to_unix(monday_date)
	for i in range(7):
		var day_unix = monday_unix + i * 86400
		var day_dict = Time.get_datetime_dict_from_unix_time(day_unix)
		var dk = "%04d-%02d-%02d" % [day_dict["year"], day_dict["month"], day_dict["day"]]
		var total = get_day_total(record_type, dk, value_key)
		result.append({"date": dk, "value": total})
	return result


func get_month_daily_totals(record_type: String, year: int, month: int, value_key: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var days_in_month = DateUtil.get_days_in_month(year, month)
	for day in range(1, days_in_month + 1):
		var dk = "%04d-%02d-%02d" % [year, month, day]
		var total = get_day_total(record_type, dk, value_key)
		result.append({"date": dk, "value": total})
	return result


func get_year_monthly_totals(record_type: String, year: int, value_key: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for month in range(1, 13):
		var total: float = 0.0
		var days_in_month = DateUtil.get_days_in_month(year, month)
		for day in range(1, days_in_month + 1):
			var dk = "%04d-%02d-%02d" % [year, month, day]
			total += get_day_total(record_type, dk, value_key)
		result.append({"month": month, "value": total})
	return result


# ======================== Focus 便捷方法 ========================

func get_today_focus_seconds() -> int:
	var today = DateUtil.get_today_key()
	return int(get_day_total("focus", today, "duration_seconds"))


func get_week_focus_totals(monday_date: String) -> Array[Dictionary]:
	var raw = get_week_daily_totals("focus", monday_date, "duration_seconds")
	var result: Array[Dictionary] = []
	for item in raw:
		result.append({"date": item["date"], "value": float(item["value"]) / 3600.0})
	return result


# ======================== Focus 数据采集 ========================

func _on_work_phase_started() -> void:
	_focus_start_time = int(Time.get_unix_time_from_system())
	_focus_work_duration = PomodoroState.work_duration * 60
	print("[StatsState] 专注开始: %d" % _focus_start_time)


func _on_work_phase_completed() -> void:
	_record_focus_session(true)


func _on_work_phase_stopped() -> void:
	_record_focus_session(false)


func _on_all_completed() -> void:
	# all_completed 在最后一个 work_phase_completed 之后触发，
	# 此时 _focus_start_time 已被 _on_work_phase_completed 重置，无需重复记录
	pass


func _record_focus_session(completed: bool) -> void:
	if _focus_start_time == 0:
		return
	var now = int(Time.get_unix_time_from_system())
	var duration = now - _focus_start_time
	if duration < 60:
		print("[StatsState] 专注时间不足60秒，不记录")
		_focus_start_time = 0
		return
	var date_key = DateUtil.get_today_key()
	var record_data = {
		"start_timestamp": _focus_start_time,
		"duration_seconds": duration,
		"completed": completed,
		"work_duration": _focus_work_duration,
	}
	add_record("focus", date_key, record_data)
	print("[StatsState] 记录专注: %d秒, 完成: %s" % [duration, str(completed)])
	_focus_start_time = 0


# ======================== 持久化 ========================

func _save_data() -> void:
	var records_array: Array = []
	for r in _records:
		records_array.append(r.to_dict())
	var data = {
		"version": 1,
		"next_id": _next_id,
		"records": records_array,
	}
	var json_string = JSON.stringify(data, "\t")
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(json_string)
		file.close()
	else:
		push_error("[StatsState] 保存失败: %s" % SAVE_PATH)


func _load_data() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		print("[StatsState] 无数据文件，使用默认值")
		return
	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		push_error("[StatsState] 读取失败")
		return
	var json_string = file.get_as_text()
	file.close()
	var json = JSON.new()
	var error = json.parse(json_string)
	if error != OK:
		push_error("[StatsState] 解析失败: %s" % json.get_error_message())
		return
	var data = json.get_data()
	if not data is Dictionary:
		push_error("[StatsState] 格式无效")
		return
	_next_id = data.get("next_id", 1)
	var records_array = data.get("records", [])
	_records.clear()
	for d in records_array:
		_records.append(StatsRecord.from_dict(d))
	print("[StatsState] 已加载 %d 条记录" % _records.size())


# ======================== 同步 API ========================

func export_data() -> Dictionary:
	var records_array: Array = []
	for r in _records:
		records_array.append(r.to_dict())
	return {
		"version": 1,
		"next_id": _next_id,
		"records": records_array,
	}


func import_sync_data(data: Dictionary) -> void:
	# 统计记录只追加，合并策略：取并集（用三元组去重）
	var server_records = data.get("records", [])
	var local_keys: Dictionary = {}
	for r in _records:
		var key = "%s_%s_%d" % [r.record_type, r.date_key, r.created_at]
		local_keys[key] = true
	var added: int = 0
	for sr in server_records:
		if not sr is Dictionary:
			continue
		var key = "%s_%s_%d" % [sr.get("record_type", ""), sr.get("date_key", ""), int(sr.get("created_at", 0))]
		if not local_keys.has(key):
			var record = StatsRecord.from_dict(sr)
			record.id = _next_id
			_next_id += 1
			_records.append(record)
			added += 1
	if added > 0:
		_save_data()
		print("[StatsState] 同步导入 %d 条新记录" % added)
