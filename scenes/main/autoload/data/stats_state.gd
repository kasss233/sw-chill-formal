extends Node

## 统一统计单例
## 负责原始事件采集、聚合记录管理、事件上报和统计查询

signal event_added(event: StatsEvent)
signal event_queue_changed(queue_size: int)
signal record_added(record: StatsRecord)
signal record_removed(id: int)
signal data_loaded

const SAVE_PATH := "user://stats_data.json"
const EVENT_QUEUE_PATH := "user://stats_event_queue.json"
const EVENT_UPLOAD_ENDPOINT := "/sync/events"
const DEVICE_ID_PATH := "user://device_id.txt"
const SAVE_DEBOUNCE_SEC := 0.5

var _events: Array[StatsEvent] = []
var _pending_events: Array[StatsEvent] = []
var _records: Array[StatsRecord] = []

var _next_event_id: int = 1
var _next_record_id: int = 1
var _device_id: String = ""
var _save_timer: SceneTreeTimer
var _save_pending_timer: SceneTreeTimer

# work phase 是专注统计的基本单位，每个 session_id 对应一个 work phase
var _active_focus_sessions: Dictionary = {}


func _ready() -> void:
	_device_id = _load_or_create_device_id()
	_load_data()
	_load_pending_events()
	_connect_runtime_signals()
	data_loaded.emit()
	print("[StatsState] 初始化完成，events=%d records=%d pending=%d" % [
		_events.size(),
		_records.size(),
		_pending_events.size()
	])


func _connect_runtime_signals() -> void:
	if AuthState and AuthState.has_signal("auth_state_changed"):
		if not AuthState.auth_state_changed.is_connected(_on_auth_state_changed):
			AuthState.auth_state_changed.connect(_on_auth_state_changed)

	if AuthState and AuthState.is_logged_in():
		call_deferred("flush_pending_events")


func _on_auth_state_changed(is_logged_in: bool) -> void:
	if is_logged_in:
		call_deferred("flush_pending_events")


# ======================== 公共事件 API ========================

func generate_session_id() -> String:
	return _generate_uuid_v4()


func record_custom_event(event_type: String, payload: Dictionary = {}, session_id: String = "", source: String = "event_tracker") -> StatsEvent:
	return _append_event(event_type, session_id, source, payload)


func record_focus_started(session_id: String, meta: Dictionary = {}) -> void:
	if session_id.is_empty():
		return

	var normalized_meta := meta.duplicate(true)
	normalized_meta["started_at_ms"] = _now_ms()
	_active_focus_sessions[session_id] = {
		"started_at_ms": int(normalized_meta["started_at_ms"]),
		"pause_count": 0,
		"meta": normalized_meta,
	}

	_append_event("focus_session_started", session_id, "event_tracker", normalized_meta)


func record_focus_paused(session_id: String, phase: String = "work", meta: Dictionary = {}) -> void:
	if session_id.is_empty():
		return

	var payload := meta.duplicate(true)
	payload["phase"] = phase

	if _active_focus_sessions.has(session_id):
		_active_focus_sessions[session_id]["pause_count"] = int(_active_focus_sessions[session_id].get("pause_count", 0)) + 1

	_append_event("focus_session_paused", session_id, "event_tracker", payload)


func record_focus_resumed(session_id: String, phase: String = "work", meta: Dictionary = {}) -> void:
	if session_id.is_empty():
		return

	var payload := meta.duplicate(true)
	payload["phase"] = phase
	_append_event("focus_session_resumed", session_id, "event_tracker", payload)


func record_focus_finished(session_id: String, completed: bool, meta: Dictionary = {}) -> StatsRecord:
	if session_id.is_empty():
		return null

	var session_state: Dictionary = _active_focus_sessions.get(session_id, {})
	var started_at_ms: int = int(session_state.get("started_at_ms", 0))
	var duration_seconds := 0
	if started_at_ms > 0:
		duration_seconds = max(0, int((_now_ms() - started_at_ms) / 1000))

	var interruptions_count := int(session_state.get("pause_count", meta.get("interruptions_count", 0)))
	var merged_meta: Dictionary = {}
	if session_state.has("meta") and session_state["meta"] is Dictionary:
		merged_meta = session_state["meta"].duplicate(true)
	for key in meta:
		merged_meta[key] = meta[key]

	var payload := merged_meta.duplicate(true)
	payload["completed"] = completed
	payload["duration_seconds"] = duration_seconds
	payload["duration_ms"] = duration_seconds * 1000
	payload["interruptions_count"] = interruptions_count

	_append_event("focus_session_finished", session_id, "event_tracker", payload)
	_active_focus_sessions.erase(session_id)

	if duration_seconds < 60:
		print("[StatsState] 专注时长不足 60 秒，不生成聚合记录: %s" % session_id)
		return null

	var date_key = DateUtil.get_today_key()
	var record_data := {
		"session_id": session_id,
		"start_timestamp": int(started_at_ms / 1000),
		"duration_seconds": duration_seconds,
		"completed": completed,
		"interruptions_count": interruptions_count,
		"work_duration": int(merged_meta.get("work_duration", 0)) * 60,
		"rest_duration": int(merged_meta.get("rest_duration", 0)) * 60,
		"total_loops": int(merged_meta.get("total_loops", 1)),
		"loop_index": int(merged_meta.get("loop_index", 1)),
	}
	return add_record("focus", date_key, record_data, float(duration_seconds))


func record_task_completed(task_id: int, meta: Dictionary = {}) -> StatsRecord:
	var payload := meta.duplicate(true)
	payload["task_id"] = task_id
	_append_event("task_completed", "", "event_tracker", payload)

	var date_key = DateUtil.get_today_key()
	var record_data := payload.duplicate(true)
	record_data["count"] = 1
	return add_record("task", date_key, record_data, 1.0)


func record_habit_execution(record) -> StatsRecord:
	if record == null:
		return null

	var payload := {
		"record_id": record.id,
		"entry_id": record.entry_id,
		"habit_id": record.habit_id,
		"date_key": record.date_key,
		"status": record.status,
		"completed_at": record.completed_at,
	}
	_append_event("habit_execution_recorded", "", "event_tracker", payload)

	var record_data := payload.duplicate(true)
	record_data["count"] = 1
	var value := 1.0 if int(record.status) == HabitData.ExecutionRecord.Status.COMPLETED else 0.0
	return add_record("habit", record.date_key, record_data, value)


func record_ai_function_result(call_id: String, name: String, success: bool, meta: Dictionary = {}) -> StatsRecord:
	var payload := meta.duplicate(true)
	payload["call_id"] = call_id
	payload["function_name"] = name
	payload["success"] = success

	var event_type := "ai_function_succeeded" if success else "ai_function_failed"
	_append_event(event_type, "", "event_tracker", payload)

	var date_key = DateUtil.get_today_key()
	var record_data := payload.duplicate(true)
	record_data["count"] = 1
	return add_record("ai", date_key, record_data, 1.0 if success else 0.0)


func record_ai_function_rejected(name: String, meta: Dictionary = {}) -> void:
	var payload := meta.duplicate(true)
	payload["function_name"] = name
	_append_event("ai_function_rejected", "", "event_tracker", payload)


func flush_pending_events() -> void:
	await _flush_pending_events()


func get_pending_event_count() -> int:
	return _pending_events.size()


# ======================== 记录 API ========================

func add_record(record_type: String, date_key: String, record_data: Dictionary, value: float = 0.0) -> StatsRecord:
	var record = StatsRecord.new()
	record.id = _next_record_id
	_next_record_id += 1
	record.record_type = record_type
	record.date_key = date_key
	record.value = value
	record.data = record_data
	record.created_at = int(Time.get_unix_time_from_system())
	_records.append(record)
	_queue_save()
	record_added.emit(record)
	return record


func remove_record(id: int) -> bool:
	for i in range(_records.size()):
		if _records[i].id == id:
			_records.remove_at(i)
			_queue_save()
			record_removed.emit(id)
			return true
	return false


func get_records(record_type: String, date_key: String = "") -> Array:
	var result: Array = []
	for record in _records:
		if record.record_type != record_type:
			continue
		if date_key != "" and record.date_key != date_key:
			continue
		result.append(record)
	return result


func get_records_in_range(record_type: String, from_date: String, to_date: String) -> Array:
	var result: Array = []
	for record in _records:
		if record.record_type != record_type:
			continue
		if record.date_key >= from_date and record.date_key <= to_date:
			result.append(record)
	return result


# ======================== 聚合查询 API ========================

func get_day_total(record_type: String, date_key: String, value_key: String) -> float:
	var total: float = 0.0
	for record in _records:
		if record.record_type != record_type or record.date_key != date_key:
			continue
		if value_key == "value":
			total += record.value
		else:
			total += float(record.data.get(value_key, 0))
	return total


func get_week_daily_totals(record_type: String, monday_date: String, value_key: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var monday_unix = DateUtil.date_str_to_unix(monday_date)
	for i in range(7):
		var day_unix = monday_unix + i * 86400
		var day_dict = Time.get_datetime_dict_from_unix_time(day_unix)
		var date_key = "%04d-%02d-%02d" % [day_dict["year"], day_dict["month"], day_dict["day"]]
		result.append({
			"date": date_key,
			"value": get_day_total(record_type, date_key, value_key),
		})
	return result


func get_month_daily_totals(record_type: String, year: int, month: int, value_key: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var days_in_month = DateUtil.get_days_in_month(year, month)
	for day in range(1, days_in_month + 1):
		var date_key = "%04d-%02d-%02d" % [year, month, day]
		result.append({
			"date": date_key,
			"value": get_day_total(record_type, date_key, value_key),
		})
	return result


func get_year_monthly_totals(record_type: String, year: int, value_key: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for month in range(1, 13):
		var month_total: float = 0.0
		var days_in_month = DateUtil.get_days_in_month(year, month)
		for day in range(1, days_in_month + 1):
			var date_key = "%04d-%02d-%02d" % [year, month, day]
			month_total += get_day_total(record_type, date_key, value_key)
		result.append({
			"month": month,
			"value": month_total,
		})
	return result


func get_period_totals(record_type: String, period: String, reference: Dictionary = {}, value_key: String = "value") -> Array[Dictionary]:
	match period:
		"week":
			var monday = reference.get("monday_date", DateUtil.get_monday_for_week(DateUtil.get_current_week_key()))
			return get_week_daily_totals(record_type, monday, value_key)
		"month":
			var month_ref = reference if not reference.is_empty() else DateUtil.get_month_for_offset(0)
			return get_month_daily_totals(record_type, int(month_ref.get("year", 0)), int(month_ref.get("month", 0)), value_key)
		"year":
			var now = Time.get_datetime_dict_from_system()
			var year = int(reference.get("year", now["year"]))
			return get_year_monthly_totals(record_type, year, value_key)
		_:
			return []


func get_today_focus_seconds() -> int:
	return int(get_day_total("focus", DateUtil.get_today_key(), "duration_seconds"))


func get_week_focus_totals(monday_date: String) -> Array[Dictionary]:
	var raw = get_week_daily_totals("focus", monday_date, "duration_seconds")
	var result: Array[Dictionary] = []
	for item in raw:
		result.append({
			"date": item["date"],
			"value": float(item["value"]) / 3600.0,
		})
	return result


func get_focus_totals(period: String, reference: Dictionary = {}) -> Array[Dictionary]:
	return get_period_totals("focus", period, reference, "duration_seconds")


func get_task_completion_totals(period: String, reference: Dictionary = {}) -> Array[Dictionary]:
	return get_period_totals("task", period, reference, "value")


func get_ai_call_stats(period: String, reference: Dictionary = {}) -> Dictionary:
	var totals = get_period_totals("ai", period, reference, "value")
	var success_count: float = 0.0
	for item in totals:
		success_count += float(item["value"])

	var failure_count := 0
	match period:
		"week":
			var monday = reference.get("monday_date", DateUtil.get_monday_for_week(DateUtil.get_current_week_key()))
			var sunday = _get_end_date_for_week(monday)
			for record in get_records_in_range("ai", monday, sunday):
				if not record.data.get("success", false):
					failure_count += 1
		"month":
			var month_ref = reference if not reference.is_empty() else DateUtil.get_month_for_offset(0)
			for record in _records:
				if record.record_type != "ai":
					continue
				var parts = record.date_key.split("-")
				if parts.size() != 3:
					continue
				if int(parts[0]) == int(month_ref.get("year", 0)) and int(parts[1]) == int(month_ref.get("month", 0)) and not record.data.get("success", false):
					failure_count += 1
		"year":
			var now = Time.get_datetime_dict_from_system()
			var year = int(reference.get("year", now["year"]))
			for record in _records:
				if record.record_type != "ai":
					continue
				var parts = record.date_key.split("-")
				if parts.size() != 3:
					continue
				if int(parts[0]) == year and not record.data.get("success", false):
					failure_count += 1

	return {
		"success_count": int(success_count),
		"failure_count": failure_count,
	}


# ======================== 持久化 ========================

func _queue_save() -> void:
	if _save_timer and _save_timer.time_left > 0.0:
		return
	_save_timer = get_tree().create_timer(SAVE_DEBOUNCE_SEC)
	_save_timer.timeout.connect(_save_data, CONNECT_ONE_SHOT)

func _queue_save_pending() -> void:
	if _save_pending_timer and _save_pending_timer.time_left > 0.0:
		return
	_save_pending_timer = get_tree().create_timer(SAVE_DEBOUNCE_SEC)
	_save_pending_timer.timeout.connect(_save_pending_events, CONNECT_ONE_SHOT)

func _save_data() -> void:
	var events_array: Array = []
	for event in _events:
		events_array.append(event.to_dict())

	var records_array: Array = []
	for record in _records:
		records_array.append(record.to_dict())

	var data := {
		"version": 2,
		"next_event_id": _next_event_id,
		"next_record_id": _next_record_id,
		"events": events_array,
		"records": records_array,
	}

	var json_string = JSON.stringify(data, "\t")
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(json_string)
		file.close()
	else:
		push_error("[StatsState] 保存失败: %s" % SAVE_PATH)


func _save_pending_events() -> void:
	var event_array: Array = []
	for event in _pending_events:
		event_array.append(event.to_dict())

	var data := {
		"version": 1,
		"events": event_array,
	}

	var json_string = JSON.stringify(data, "\t")
	var file = FileAccess.open(EVENT_QUEUE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(json_string)
		file.close()
	else:
		push_error("[StatsState] 待上传事件保存失败: %s" % EVENT_QUEUE_PATH)

	event_queue_changed.emit(_pending_events.size())


func _load_data() -> void:
	_events.clear()
	_records.clear()
	_next_event_id = 1
	_next_record_id = 1

	if not FileAccess.file_exists(SAVE_PATH):
		return

	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		push_error("[StatsState] 读取失败")
		return

	var json_string = file.get_as_text()
	file.close()

	var json = JSON.new()
	if json.parse(json_string) != OK:
		push_error("[StatsState] 解析失败: %s" % json.get_error_message())
		return

	var data = json.get_data()
	if not data is Dictionary:
		push_error("[StatsState] 格式无效")
		return

	if int(data.get("version", 1)) <= 1 and data.has("records") and not data.has("events"):
		_load_legacy_records(data)
		return

	_next_event_id = int(data.get("next_event_id", 1))
	_next_record_id = int(data.get("next_record_id", data.get("next_id", 1)))

	for event_dict in data.get("events", []):
		if event_dict is Dictionary:
			_events.append(StatsEvent.from_dict(event_dict))

	for record_dict in data.get("records", []):
		if record_dict is Dictionary:
			_records.append(StatsRecord.from_dict(record_dict))


func _load_legacy_records(data: Dictionary) -> void:
	_next_record_id = int(data.get("next_id", 1))
	for record_dict in data.get("records", []):
		if record_dict is Dictionary:
			_records.append(StatsRecord.from_dict(record_dict))
	_save_data()


func _load_pending_events() -> void:
	_pending_events.clear()

	if not FileAccess.file_exists(EVENT_QUEUE_PATH):
		return

	var file = FileAccess.open(EVENT_QUEUE_PATH, FileAccess.READ)
	if not file:
		return

	var json_string = file.get_as_text()
	file.close()

	var json = JSON.new()
	if json.parse(json_string) != OK:
		return

	var data = json.get_data()
	var source_events: Array = []
	if data is Dictionary:
		source_events = data.get("events", [])
	elif data is Array:
		source_events = data

	for event_dict in source_events:
		if event_dict is Dictionary:
			_pending_events.append(StatsEvent.from_dict(event_dict))

	event_queue_changed.emit(_pending_events.size())


# ======================== 同步 API ========================

func export_data() -> Dictionary:
	var records_array: Array = []
	for record in _records:
		records_array.append(record.to_dict())

	return {
		"version": 2,
		"next_record_id": _next_record_id,
		"records": records_array,
	}


func import_sync_data(data: Dictionary) -> void:
	var server_records = data.get("records", [])
	var local_keys: Dictionary = {}
	for record in _records:
		var key = "%s_%s_%d" % [record.record_type, record.date_key, record.created_at]
		local_keys[key] = true

	var added := 0
	for server_record in server_records:
		if not server_record is Dictionary:
			continue
		var key = "%s_%s_%d" % [
			server_record.get("record_type", ""),
			server_record.get("date_key", ""),
			int(server_record.get("created_at", 0))
		]
		if local_keys.has(key):
			continue

		var record = StatsRecord.from_dict(server_record)
		record.id = _next_record_id
		_next_record_id += 1
		_records.append(record)
		added += 1

	if added > 0:
		_save_data()
		print("[StatsState] 同步导入 %d 条新记录" % added)


# ======================== 内部实现 ========================

func _append_event(event_type: String, session_id: String, source: String, payload: Dictionary) -> StatsEvent:
	var event = StatsEvent.new()
	event.id = _next_event_id
	_next_event_id += 1
	event.event_type = event_type
	event.occurred_at = _now_ms()
	event.session_id = session_id
	event.source = source
	event.payload = payload.duplicate(true)

	_events.append(event)
	_pending_events.append(event)
	_queue_save()
	_queue_save_pending()
	event_added.emit(event)
	return event


func _flush_pending_events() -> void:
	if _pending_events.is_empty():
		return

	if not AuthState or not AuthState.is_logged_in():
		return

	var events_to_send := _pending_events.duplicate()
	var body_events: Array = []
	for event in events_to_send:
		body_events.append({
			"event_type": event.event_type,
			"timestamp": event.occurred_at,
			"session_id": event.session_id,
			"source": event.source,
			"data": event.payload,
		})

	var result = await ApiClient.api_post(EVENT_UPLOAD_ENDPOINT, {
		"device_id": _device_id,
		"events": body_events,
	})
	if not result.success:
		print("[StatsState] 事件上传失败: %s" % result.message)
		return

	var sent_ids: Dictionary = {}
	for event in events_to_send:
		sent_ids[event.id] = true

	var remaining_events: Array[StatsEvent] = []
	for event in _pending_events:
		if not sent_ids.has(event.id):
			remaining_events.append(event)
	_pending_events = remaining_events
	_save_pending_events()
	print("[StatsState] 事件上传成功: %d 条" % events_to_send.size())


func _get_end_date_for_week(monday_date: String) -> String:
	var monday_unix = DateUtil.date_str_to_unix(monday_date)
	var sunday_unix = monday_unix + 6 * 86400
	var sunday_dict = Time.get_datetime_dict_from_unix_time(sunday_unix)
	return "%04d-%02d-%02d" % [sunday_dict["year"], sunday_dict["month"], sunday_dict["day"]]


func _now_ms() -> int:
	return int(Time.get_unix_time_from_system() * 1000)


func _generate_uuid_v4() -> String:
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	var bytes := PackedByteArray()
	for _i in range(16):
		bytes.append(rng.randi() % 256)

	bytes[6] = (bytes[6] & 0x0F) | 0x40
	bytes[8] = (bytes[8] & 0x3F) | 0x80

	return "%02x%02x%02x%02x-%02x%02x-%02x%02x-%02x%02x-%02x%02x%02x%02x%02x%02x" % [
		bytes[0], bytes[1], bytes[2], bytes[3],
		bytes[4], bytes[5],
		bytes[6], bytes[7],
		bytes[8], bytes[9],
		bytes[10], bytes[11], bytes[12], bytes[13], bytes[14], bytes[15]
	]


func _load_or_create_device_id() -> String:
	if FileAccess.file_exists(DEVICE_ID_PATH):
		var read_file = FileAccess.open(DEVICE_ID_PATH, FileAccess.READ)
		if read_file:
			var existing_id = read_file.get_as_text().strip_edges()
			if not existing_id.is_empty():
				return existing_id

	var new_id = _generate_uuid_v4()
	var write_file = FileAccess.open(DEVICE_ID_PATH, FileAccess.WRITE)
	if write_file:
		write_file.store_string(new_id)
	return new_id
