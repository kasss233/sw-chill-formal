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
signal schedule_entry_added(entry) # HabitData.ScheduleEntry
signal schedule_entry_removed(entry_id: int)
signal schedule_updated(week_key: String)
signal schedule_cleared(week_key: String)
# --- 执行记录信号 ---
signal execution_updated(record) # HabitData.ExecutionRecord
# --- Agent 信号 ---
signal agent_schedule_generated(week_key: String)
# --- 通用 ---
signal data_loaded

# --- 内部状态 ---
var _habits: Array = [] # Array[HabitData]
var _time_slot_templates: Array = [] # Array[HabitData.TimeSlotTemplate]
var _schedule_entries: Array = [] # Array[HabitData.ScheduleEntry]
var _execution_records: Array = [] # Array[HabitData.ExecutionRecord]

var _next_habit_id: int = 1
var _next_slot_template_id: int = 1
var _next_entry_id: int = 1
var _next_record_id: int = 1
var _habit_id_index: Dictionary = {} # {int id → HabitData}
var _time_slot_id_index: Dictionary = {} # {int id → HabitData.TimeSlotTemplate}

const SAVE_PATH = "user://habit_data.json"
const SAVE_DEBOUNCE_SEC := 0.5
var _save_timer: SceneTreeTimer


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
	return _habit_id_index.get(id, null)


# ======================== 查询 API - 时间段 ========================

func get_time_slot_templates() -> Array:
	return _time_slot_templates.duplicate()


func get_time_slot_by_id(id: int) -> HabitData.TimeSlotTemplate:
	return _time_slot_id_index.get(id, null)


# ======================== 查询 API - 排期 ========================

func get_week_schedule(week_key: String) -> Array:
	var result: Array = []
	for e in _schedule_entries:
		if e.week_key == week_key:
			result.append(e)
	return result


func get_scheduled_week_keys() -> Array:
	var week_map := {}
	for e in _schedule_entries:
		week_map[e.week_key] = true
	var keys: Array = week_map.keys()
	keys.sort()
	return keys


func get_day_schedule(week_key: String, day: int) -> Array:
	var result: Array = []
	for e in _schedule_entries:
		if e.week_key == week_key and e.day_of_week == day:
			result.append(e)
	return result


func get_current_week_key() -> String:
	return DateUtil.get_current_week_key()


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


## 获取某天的习惯完成统计 {"total": int, "completed": int}
func get_day_completion(week_key: String, day: int) -> Dictionary:
	var day_entries := get_day_schedule(week_key, day)
	var date_key := DateUtil.week_key_to_date(week_key, day)
	var records := get_records_by_date(date_key)
	var completed: int = 0
	for r in records:
		if r.status == HabitData.ExecutionRecord.Status.COMPLETED:
			completed += 1
	return {"total": day_entries.size(), "completed": completed}


func get_day_dashboard_data(date_key: String) -> Dictionary:
	var week_key := DateUtil.date_to_week_key(date_key)
	var day_of_week := DateUtil.get_day_of_week(date_key)
	var entries := get_day_schedule(week_key, day_of_week)
	var records := get_records_by_date(date_key)
	var record_map := {}
	for record in records:
		record_map[record.entry_id] = record

	var timeline: Array = []
	var top_cards: Array = []
	var completed: int = 0
	var pending: int = 0
	var skipped: int = 0
	var deferred: int = 0

	for entry in entries:
		var habit: HabitData = get_habit_by_id(entry.habit_id)
		if habit == null:
			continue
		var record: HabitData.ExecutionRecord = record_map.get(entry.id, null)
		var status := HabitData.ExecutionRecord.Status.PENDING
		if record != null:
			status = record.status

		match status:
			HabitData.ExecutionRecord.Status.COMPLETED:
				completed += 1
			HabitData.ExecutionRecord.Status.SKIPPED:
				skipped += 1
			HabitData.ExecutionRecord.Status.DEFERRED:
				deferred += 1
			_:
				pending += 1

		var slot: HabitData.TimeSlotTemplate = get_time_slot_by_id(entry.time_slot_id)
		var item := {
			"entry_id": entry.id,
			"habit_id": habit.id,
			"title": habit.name,
			"minutes": habit.estimated_minutes,
			"period_text": habit.get_period_name(),
			"time_text": _build_time_slot_label(slot),
			"color": habit.color,
			"status": status,
			"status_text": _execution_status_to_text(status),
			"can_start": status != HabitData.ExecutionRecord.Status.COMPLETED,
		}
		timeline.append(item)
		if top_cards.size() < 3 and status != HabitData.ExecutionRecord.Status.COMPLETED:
			top_cards.append(item)

	for habit in get_active_habits():
		if top_cards.size() >= 3:
			break
		var already_added := false
		for card in top_cards:
			if int(card.get("habit_id", -1)) == habit.id:
				already_added = true
				break
		if already_added:
			continue
		top_cards.append({
			"entry_id": - 1,
			"habit_id": habit.id,
			"title": habit.name,
			"minutes": habit.estimated_minutes,
			"period_text": habit.get_period_name(),
			"time_text": "可作为轻量安排",
			"color": habit.color,
			"status": HabitData.ExecutionRecord.Status.PENDING,
			"status_text": "可开始",
			"can_start": true,
		})

	var total_count := entries.size()
	var progress := 0.0
	if total_count > 0:
		progress = float(completed) / float(total_count)

	var stats_text := "今天还没有安排，适合先从一个小习惯开始。"
	if get_active_habits().is_empty():
		stats_text = "还没有习惯安排，先添加一个想坚持的小目标吧。"
	elif total_count == 0:
		stats_text = "今天比较轻松，可以补一个 15 分钟的小习惯。"
	elif completed == total_count:
		stats_text = "今天的计划已经完成啦，适合放松一下或写个小回顾。"
	elif pending > 0:
		stats_text = "今天还剩 %d 个小步骤，先做最轻松的一项就好。" % pending
	elif deferred > 0:
		stats_text = "今天有一些项目往后顺延了，慢慢调整节奏也没关系。"
	elif skipped > 0:
		stats_text = "今天有些项目跳过了，挑一个最容易恢复的小动作重新开始吧。"

	var dt := _date_key_to_dict(date_key)
	return {
		"date_key": date_key,
		"week_key": week_key,
		"day_of_week": day_of_week,
		"date_title": "%d 月 %d 日" % [dt.get("month", 0), dt.get("day", 0)],
		"status_text": stats_text,
		"progress": progress,
		"completed_count": completed,
		"total_count": total_count,
		"focus_minutes": _get_focus_minutes_for_date(date_key),
		"top_cards": top_cards,
		"timeline": timeline,
		"calendar_marks": get_month_calendar_marks(int(dt.get("year", 0)), int(dt.get("month", 0))),
	}


func get_week_rhythm_data(week_key: String) -> Dictionary:
	var entries := get_week_schedule(week_key)
	var daily_loads: Array = []
	var total_entries := 0
	var total_completed := 0
	var active_days := 0

	for day in range(7):
		var day_entries := get_day_schedule(week_key, day)
		var day_completed := get_day_completion(week_key, day)
		var completed := int(day_completed.get("completed", 0))
		var total := day_entries.size()
		if total > 0:
			active_days += 1
		total_entries += total
		total_completed += completed
		daily_loads.append({
			"day": day,
			"total": total,
			"completed": completed,
			"load_ratio": float(total) / 4.0,
		})

	var theme_title := "这一周节奏偏松"
	var theme_text := "这一周安排比较轻，可以保留一点弹性。"
	if total_entries >= 12:
		theme_title = "这一周节奏偏紧"
		theme_text = "安排比较充实，建议优先保证最重要的 1 到 2 件事。"
	elif total_entries >= 6:
		theme_title = "这一周节奏偏稳"
		theme_text = "安排和恢复比较平衡，适合按节奏稳稳推进。"

	if entries.is_empty():
		theme_text = "这一周还是空白的，先试试让 AI 给你生成一个轻松版建议。"

	return {
		"week_key": week_key,
		"theme_title": theme_title,
		"theme_text": theme_text,
		"total_entries": total_entries,
		"completed_entries": total_completed,
		"active_days": active_days,
		"daily_loads": daily_loads,
		"empty_state_text": "本周还没有安排，先生成一个建议节奏吧。",
	}


func get_review_summary(period_type: String, period_key: String) -> Dictionary:
	var range_data: Dictionary = _resolve_period_range(period_type, period_key)
	var raw_date_keys: Array = range_data.get("date_keys", [])
	var date_keys: Array[String] = []
	for value in raw_date_keys:
		date_keys.append(str(value))
	var week_key: String = str(range_data.get("week_key", ""))
	var overview_completion: float = 0.0
	var completed_count: int = 0
	var total_count: int = 0
	var focus_minutes: int = 0
	var day_heatmap: Array[Dictionary] = []
	var habit_buckets: Dictionary = {}
	var period_counter: Dictionary = {"morning": 0, "afternoon": 0, "evening": 0}

	for date_key in date_keys:
		var date_key_str: String = date_key
		var dashboard: Dictionary = get_day_dashboard_data(date_key_str)
		total_count += int(dashboard.get("total_count", 0))
		completed_count += int(dashboard.get("completed_count", 0))
		focus_minutes += int(dashboard.get("focus_minutes", 0))
		day_heatmap.append({
			"date_key": date_key_str,
			"completed": int(dashboard.get("completed_count", 0)),
			"total": int(dashboard.get("total_count", 0)),
		})

		var records: Array = get_records_by_date(date_key_str)
		for record in records:
			if record.status != HabitData.ExecutionRecord.Status.COMPLETED:
				continue
			var habit: HabitData = get_habit_by_id(record.habit_id)
			if habit == null:
				continue
			if not habit_buckets.has(habit.id):
				habit_buckets[habit.id] = {
					"name": habit.name,
					"color": habit.color,
					"completed": 0,
					"planned": 0,
				}
			habit_buckets[habit.id]["completed"] += 1
			var start_hour := _extract_hour(habit.preferred_start_time)
			if start_hour < 12:
				period_counter["morning"] += 1
			elif start_hour < 18:
				period_counter["afternoon"] += 1
			else:
				period_counter["evening"] += 1

	var all_entries: Array = []
	if period_type == "week" and not week_key.is_empty():
		all_entries = get_week_schedule(week_key)
	else:
		for entry in _schedule_entries:
			var entry_date_key: String = DateUtil.week_key_to_date(entry.week_key, entry.day_of_week)
			if entry_date_key in date_keys:
				all_entries.append(entry)

	for entry in all_entries:
		var bucket = habit_buckets.get(entry.habit_id, null)
		if bucket == null:
			var habit := get_habit_by_id(entry.habit_id)
			if habit == null:
				continue
			bucket = {
				"name": habit.name,
				"color": habit.color,
				"completed": 0,
				"planned": 0,
			}
			habit_buckets[entry.habit_id] = bucket
		bucket["planned"] += 1

	if total_count > 0:
		overview_completion = float(completed_count) / float(total_count)

	var habit_chart: Array = []
	var strongest_habit := "还没有稳定习惯"
	var strongest_value := -1
	for habit_id in habit_buckets.keys():
		var bucket: Dictionary = habit_buckets[habit_id]
		var label: String = str(bucket.get("name", ""))
		var value: int = int(bucket.get("completed", 0))
		habit_chart.append({
			"label": label.left(4),
			"value": value,
			"full_label": label,
			"color": bucket.get("color", "#4CAF50"),
		})
		if value > strongest_value:
			strongest_value = value
			strongest_habit = label
	habit_chart.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.get("value", 0.0)) > float(b.get("value", 0.0))
	)
	if habit_chart.size() > 6:
		habit_chart = habit_chart.slice(0, 6)

	var focus_chart := _build_focus_chart(period_type, range_data)
	var trend_chart := _build_completion_trend_chart(period_type, range_data)
	var easiest_period := _pick_strongest_period(period_counter)
	var insights := [
		"这段时间最稳定的是 %s。" % strongest_habit,
		"你通常在%s更容易进入状态。" % easiest_period,
		"完成率是 %d%%，继续保持一点点连续性就很好。" % int(round(overview_completion * 100.0)),
	]

	return {
		"period_type": period_type,
		"period_key": period_key,
		"title": range_data.get("title", ""),
		"overview": {
			"completion_rate": overview_completion,
			"focus_minutes": focus_minutes,
			"best_habit_name": strongest_habit,
			"best_period_text": easiest_period,
		},
		"heatmap_days": day_heatmap,
		"habit_chart": habit_chart,
		"focus_chart": focus_chart,
		"trend_chart": trend_chart,
		"insights": insights,
		"reflection": get_period_reflection(period_type, period_key),
		"calendar_marks": get_month_calendar_marks(int(range_data.get("display_year", 0)), int(range_data.get("display_month", 0))),
	}


func get_month_calendar_marks(year: int, month: int) -> Dictionary:
	var marks := {}
	if year <= 0 or month <= 0:
		return marks
	var days_in_month := DateUtil.get_days_in_month(year, month)
	for day in range(1, days_in_month + 1):
		var date_key := "%04d-%02d-%02d" % [year, month, day]
		var week_key := DateUtil.date_to_week_key(date_key)
		var day_of_week := DateUtil.get_day_of_week(date_key)
		var completion := get_day_completion(week_key, day_of_week)
		var total := int(completion.get("total", 0))
		var completed := int(completion.get("completed", 0))
		var completion_ratio := 0.0
		if total > 0:
			completion_ratio = float(completed) / float(total)

		var focus_minutes := _get_focus_minutes_for_date(date_key)
		var reflection_text := _find_period_reflection_text("day", date_key)
		marks[date_key] = {
			"completion_ratio": completion_ratio,
			"focus_minutes": focus_minutes,
			"has_reflection": not reflection_text.is_empty(),
			"has_peak": completed >= 2 or focus_minutes >= 45,
		}
	return marks


func get_period_reflection(period_type: String, period_key: String) -> Dictionary:
	var content := _find_period_reflection_text(period_type, period_key)
	if content.is_empty():
		return {
			"title": "还没有回顾",
			"content": "先看看图表，再生成一段温和的回顾也不错。",
			"source": "empty",
		}
	return {
		"title": _period_title(period_type, period_key),
		"content": content,
		"source": "note",
	}


# ======================== 修改 API - 习惯库 ========================

func add_habit(
	p_name: String,
	p_minutes: int = 30,
	p_period: int = 0,
	p_frequency: int = 0,
	p_color: String = "#4CAF50",
	p_selected_week_days: Array = [],
	p_preferred_time_slot_id: int = -1,
	p_preferred_start_time: String = "08:00",
	p_preferred_end_time: String = "09:00"
) -> HabitData:
	var habit = HabitData.new(_next_habit_id, p_name, p_minutes, p_period, p_frequency, p_color)
	habit.set_selected_week_days(p_selected_week_days)
	habit.preferred_time_slot_id = p_preferred_time_slot_id
	habit.preferred_start_time = p_preferred_start_time
	habit.preferred_end_time = p_preferred_end_time
	habit.estimated_minutes = _duration_minutes_from_time_range(habit.preferred_start_time, habit.preferred_end_time)
	_next_habit_id += 1
	_habits.append(habit)
	_habit_id_index[habit.id] = habit
	var week_key := get_current_week_key()
	_auto_sync_habit_schedule_for_week(habit, week_key)
	_queue_save()
	habit_added.emit(habit)
	schedule_updated.emit(week_key)
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
	if fields.has("preferred_time_slot_id"):
		habit.preferred_time_slot_id = int(fields["preferred_time_slot_id"])
	if fields.has("preferred_start_time"):
		habit.preferred_start_time = str(fields["preferred_start_time"])
	if fields.has("preferred_end_time"):
		habit.preferred_end_time = str(fields["preferred_end_time"])
	if fields.has("preferred_start_time") or fields.has("preferred_end_time"):
		habit.estimated_minutes = _duration_minutes_from_time_range(habit.preferred_start_time, habit.preferred_end_time)
	if fields.has("frequency"):
		habit.frequency = int(fields["frequency"])
	if fields.has("selected_week_days"):
		habit.set_selected_week_days(fields["selected_week_days"])
	if fields.has("color"):
		habit.color = fields["color"]
	if fields.has("is_active"):
		habit.is_active = fields["is_active"]
	var week_key := get_current_week_key()
	_auto_sync_habit_schedule_for_week(habit, week_key)
	habit.updated_at = int(Time.get_unix_time_from_system())
	_queue_save()
	habit_updated.emit(habit)
	schedule_updated.emit(week_key)
	print("[HabitState] Updated habit(id: %d)" % id)
	return true


func remove_habit(id: int) -> bool:
	for i in range(_habits.size()):
		if _habits[i].id == id:
			_habit_id_index.erase(id)
			_habits.remove_at(i)
			# 同时移除关联的排期和执行记录
			_remove_entries_by_habit(id)
			_queue_save()
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
	_time_slot_id_index[slot.id] = slot
	var week_key := get_current_week_key()
	_auto_sync_all_habits_for_week(week_key)
	_queue_save()
	time_slot_template_changed.emit()
	schedule_updated.emit(week_key)
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
	var week_key := get_current_week_key()
	_auto_sync_all_habits_for_week(week_key)
	_queue_save()
	time_slot_template_changed.emit()
	schedule_updated.emit(week_key)
	return true


func remove_time_slot_template(id: int) -> bool:
	for i in range(_time_slot_templates.size()):
		if _time_slot_templates[i].id == id:
			_time_slot_id_index.erase(id)
			_time_slot_templates.remove_at(i)
			_update_slot_orders()
			# 移除使用该时间段的排期
			_remove_entries_by_slot(id)
			var week_key := get_current_week_key()
			_auto_sync_all_habits_for_week(week_key)
			_queue_save()
			time_slot_template_changed.emit()
			schedule_updated.emit(week_key)
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
	# 重建 time_slot 索引
	_time_slot_id_index.clear()
	for s in _time_slot_templates:
		_time_slot_id_index[s.id] = s
	var week_key := get_current_week_key()
	_auto_sync_all_habits_for_week(week_key)
	_queue_save()
	time_slot_template_changed.emit()
	schedule_updated.emit(week_key)


# ======================== 修改 API - 排期 ========================

func add_schedule_entry(habit_id: int, week_key: String, day: int, time_slot_id: int, allow_overlap: bool = false) -> HabitData.ScheduleEntry:
	if not allow_overlap and check_conflict(week_key, day, time_slot_id):
		push_warning("[HabitState] Schedule conflict: week=%s day=%d slot=%d" % [week_key, day, time_slot_id])
		return null
	var entry = HabitData.ScheduleEntry.new(_next_entry_id, habit_id, week_key, day, time_slot_id)
	_next_entry_id += 1
	_schedule_entries.append(entry)
	_queue_save()
	schedule_entry_added.emit(entry)
	print("[HabitState] Added schedule entry(id: %d, habit: %d, week: %s, day: %d, slot: %d)" % [entry.id, habit_id, week_key, day, time_slot_id])
	return entry


func remove_schedule_entry(id: int) -> bool:
	for i in range(_schedule_entries.size()):
		if _schedule_entries[i].id == id:
			_schedule_entries.remove_at(i)
			# 移除关联的执行记录
			_remove_records_by_entry(id)
			_queue_save()
			schedule_entry_removed.emit(id)
			print("[HabitState] Removed schedule entry(id: %d)" % id)
			return true
	return false


func add_habit_to_day_schedule(habit_id: int, week_key: String, day: int) -> HabitData.ScheduleEntry:
	var habit := get_habit_by_id(habit_id)
	if habit == null:
		return null
	var slot_id := _pick_slot_for_time_range(habit.preferred_start_time, habit.preferred_end_time)
	if slot_id < 0:
		return null
	return add_schedule_entry(habit_id, week_key, day, slot_id, true)


func remove_habit_from_day_schedule(habit_id: int, week_key: String, day: int) -> void:
	var i := _schedule_entries.size() - 1
	while i >= 0:
		var entry = _schedule_entries[i]
		if entry.habit_id == habit_id and entry.week_key == week_key and entry.day_of_week == day:
			var entry_id :int= entry.id
			_schedule_entries.remove_at(i)
			_remove_records_by_entry(entry_id)
			schedule_entry_removed.emit(entry_id)
		i -= 1
	_queue_save()
	schedule_updated.emit(week_key)


func clear_week_schedule(week_key: String) -> void:
	var i = _schedule_entries.size() - 1
	while i >= 0:
		if _schedule_entries[i].week_key == week_key:
			var entry_id = _schedule_entries[i].id
			_schedule_entries.remove_at(i)
			_remove_records_by_entry(entry_id)
		i -= 1
	_queue_save()
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
			_queue_save()
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
	_queue_save()
	execution_updated.emit(record)
	print("[HabitState] Set execution: entry=%d date=%s status=%d" % [entry_id, date_key, status])
	return record


func ensure_daily_records(date_key: String) -> void:
	# 获取当前周 key
	var week_key = DateUtil.date_to_week_key(date_key)
	var day = DateUtil.get_day_of_week(date_key)
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
	_queue_save()


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


func agent_generate_week_schedule(week_key: String, style: String = "relaxed") -> bool:
	if not ChatState:
		return false
	var style_text := "轻松版" if style == "relaxed" else "自律版"
	var habits := agent_get_habits()
	var summary := JSON.stringify(habits)
	var prompt := "请根据我的习惯库和现有节奏，为 %s 生成一份%s周安排。请优先输出可落到日历中的课表建议，兼顾恢复感。习惯数据：%s" % [week_key, style_text, summary]
	return ChatState.agent_set_input_text(prompt)


func agent_generate_period_reflection(period_type: String, period_key: String) -> bool:
	if not ChatState:
		return false
	var summary := get_review_summary(period_type, period_key)
	var prompt := "请根据我的%s数据，生成一段温和、鼓励式的回顾总结。请包含亮点、节奏观察和下一步一小步建议。数据摘要：%s" % [
		_period_title(period_type, period_key),
		JSON.stringify(summary),
	]
	return ChatState.agent_set_input_text(prompt)


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

func _queue_save() -> void:
	if _save_timer and _save_timer.time_left > 0.0:
		return
	_save_timer = get_tree().create_timer(SAVE_DEBOUNCE_SEC)
	_save_timer.timeout.connect(_save_data, CONNECT_ONE_SHOT)

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
		_rebuild_habit_index()
		data_loaded.emit()
		return

	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		push_error("[HabitState] Failed to open save file")
		_init_default_templates()
		_rebuild_habit_index()
		data_loaded.emit()
		return

	var json_string = file.get_as_text()
	file.close()

	var json = JSON.new()
	var error = json.parse(json_string)
	if error != OK:
		push_error("[HabitState] Failed to parse save file: %s" % json.get_error_message())
		_init_default_templates()
		_rebuild_habit_index()
		data_loaded.emit()
		return

	var data = json.get_data()
	if not data is Dictionary:
		push_error("[HabitState] Invalid save data format")
		_init_default_templates()
		_rebuild_habit_index()
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

	_rebuild_habit_index()
	_auto_sync_all_habits_for_week(get_current_week_key())
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


## 重建索引（load/import 后调用）
func _rebuild_habit_index() -> void:
	_habit_id_index.clear()
	_time_slot_id_index.clear()
	for h in _habits:
		_habit_id_index[h.id] = h
	for s in _time_slot_templates:
		_time_slot_id_index[s.id] = s


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


func _auto_sync_all_habits_for_week(week_key: String) -> void:
	for habit in _habits:
		_auto_sync_habit_schedule_for_week(habit, week_key)


func _auto_sync_habit_schedule_for_week(habit: HabitData, week_key: String) -> void:
	if habit == null:
		return
	_remove_habit_entries_by_week(habit.id, week_key)
	if not habit.is_active:
		return

	var day_list: Array[int] = habit.get_selected_week_days()
	var slot_id := _pick_slot_for_time_range(habit.preferred_start_time, habit.preferred_end_time)
	if slot_id < 0:
		return
	for day in day_list:
		if day < 0 or day > 6:
			continue
		add_schedule_entry(habit.id, week_key, day, slot_id, true)


func _remove_habit_entries_by_week(habit_id: int, week_key: String) -> void:
	var i := _schedule_entries.size() - 1
	while i >= 0:
		var entry = _schedule_entries[i]
		if entry.habit_id == habit_id and entry.week_key == week_key:
			var entry_id: int = entry.id
			_schedule_entries.remove_at(i)
			_remove_records_by_entry(entry_id)
			schedule_entry_removed.emit(entry_id)
		i -= 1


func _get_all_slot_ids_ordered() -> Array[int]:
	var slots := _time_slot_templates.duplicate()
	slots.sort_custom(func(a, b):
		return a.order < b.order
	)
	var result: Array[int] = []
	for slot in slots:
		result.append(slot.id)
	return result


func _get_slot_ids_by_time_range(start_time: String, end_time: String) -> Array[int]:
	var range_start := _time_to_minutes(start_time)
	var range_end := _time_to_minutes(end_time)
	if range_start < 0 or range_end <= range_start:
		return _get_all_slot_ids_ordered()
	var slots := _time_slot_templates.duplicate()
	slots.sort_custom(func(a, b):
		return a.order < b.order
	)
	var result: Array[int] = []
	for slot in slots:
		var slot_start := _time_to_minutes(slot.start_time)
		var slot_end := _time_to_minutes(slot.end_time)
		if slot_start < 0 or slot_end <= slot_start:
			continue
		if slot_start < range_end and range_start < slot_end:
			result.append(slot.id)
	if result.is_empty():
		return _get_all_slot_ids_ordered()
	return result


func _pick_slot_for_time_range(start_time: String, end_time: String) -> int:
	var slot_ids := _get_slot_ids_by_time_range(start_time, end_time)
	if slot_ids.is_empty():
		return -1
	return int(slot_ids[0])


func _extract_hour(time_text: String) -> int:
	var parts := time_text.split(":")
	if parts.size() < 2:
		return 0
	return clampi(int(parts[0]), 0, 23)


func _time_to_minutes(time_text: String) -> int:
	var parts := time_text.split(":")
	if parts.size() < 2:
		return -1
	var hour := int(parts[0])
	var minute := int(parts[1])
	if hour < 0 or hour > 23 or minute < 0 or minute > 59:
		return -1
	return hour * 60 + minute


func _duration_minutes_from_time_range(start_time: String, end_time: String) -> int:
	var start_minutes := _time_to_minutes(start_time)
	var end_minutes := _time_to_minutes(end_time)
	if start_minutes < 0 or end_minutes <= start_minutes:
		return 30
	return maxi(end_minutes - start_minutes, 30)


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
	_rebuild_habit_index()
	data_loaded.emit()


## 同步导入数据（比较 updated_at 决定是否覆盖）
func import_sync_data(data: Dictionary) -> void:
	if not data.has("habits"):
		return
	# 比较 bundle 级 updated_at（取 habits 中最大值）
	var remote_max_updated: int = _get_max_updated_at_from_data(data)
	var local_max_updated: int = get_max_updated_at()
	if remote_max_updated > local_max_updated:
		import_data(data)
		print("[HabitState] 同步覆盖本地数据 (remote=%d > local=%d)" % [remote_max_updated, local_max_updated])


## 获取本地数据最大 updated_at
func get_max_updated_at() -> int:
	var max_val: int = 0
	for h in _habits:
		if h.updated_at > max_val:
			max_val = h.updated_at
	return max_val


## 从导出数据中提取最大 updated_at
func _get_max_updated_at_from_data(data: Dictionary) -> int:
	var max_val: int = 0
	for h in data.get("habits", []):
		if h is Dictionary:
			var val = int(h.get("updated_at", 0))
			if val > max_val:
				max_val = val
	return max_val


func _build_time_slot_label(slot: HabitData.TimeSlotTemplate) -> String:
	if slot == null:
		return "今天"
	return "%s %s-%s" % [slot.name, slot.start_time, slot.end_time]


func _execution_status_to_text(status: int) -> String:
	match status:
		HabitData.ExecutionRecord.Status.COMPLETED:
			return "已完成"
		HabitData.ExecutionRecord.Status.SKIPPED:
			return "已跳过"
		HabitData.ExecutionRecord.Status.DEFERRED:
			return "稍后处理"
		_:
			return "待进行"


func _date_key_to_dict(date_key: String) -> Dictionary:
	var parts := date_key.split("-")
	if parts.size() != 3:
		return {"year": 0, "month": 0, "day": 0}
	return {
		"year": int(parts[0]),
		"month": int(parts[1]),
		"day": int(parts[2]),
	}


func _resolve_period_range(period_type: String, period_key: String) -> Dictionary:
	var result := {
		"date_keys": [],
		"week_key": "",
		"title": "",
		"display_year": 0,
		"display_month": 0,
	}

	match period_type:
		"month":
			var parts := period_key.split("-")
			var now_dict: Dictionary = Time.get_datetime_dict_from_system()
			var year: int = int(parts[0]) if parts.size() >= 2 else int(now_dict.get("year", 0))
			var month: int = int(parts[1]) if parts.size() >= 2 else int(now_dict.get("month", 0))
			var days_in_month := DateUtil.get_days_in_month(year, month)
			for day in range(1, days_in_month + 1):
				result["date_keys"].append("%04d-%02d-%02d" % [year, month, day])
			result["title"] = "%d 年 %d 月回顾" % [year, month]
			result["display_year"] = year
			result["display_month"] = month
		"recent30":
			var end_date := period_key if not period_key.is_empty() else DateUtil.get_today_key()
			for offset in range(29, -1, -1):
				result["date_keys"].append(DateUtil.offset_date(end_date, -offset))
			var end_dict := _date_key_to_dict(end_date)
			result["title"] = "最近 30 天回顾"
			result["display_year"] = int(end_dict.get("year", 0))
			result["display_month"] = int(end_dict.get("month", 0))
		_:
			var week_key := period_key if not period_key.is_empty() else get_current_week_key()
			for day in range(7):
				result["date_keys"].append(DateUtil.week_key_to_date(week_key, day))
			var monday := _date_key_to_dict(DateUtil.week_key_to_date(week_key, 0))
			result["week_key"] = week_key
			result["title"] = "%s 回顾" % week_key
			result["display_year"] = int(monday.get("year", 0))
			result["display_month"] = int(monday.get("month", 0))
	return result


func _build_focus_chart(period_type: String, range_data: Dictionary) -> Array:
	var chart: Array = []
	match period_type:
		"month":
			var year := int(range_data.get("display_year", 0))
			var month := int(range_data.get("display_month", 0))
			if StatsState:
				for item in StatsState.get_month_daily_totals("focus", year, month, "duration_seconds"):
					var date_key: String = item.get("date", "")
					var day := int(date_key.get_slice("-", 2))
					chart.append({"label": str(day), "value": float(item.get("value", 0.0)) / 3600.0})
		"recent30":
			for date_key in range_data.get("date_keys", []):
				var date_key_str: String = str(date_key)
				var day_label: String = date_key_str.substr(max(date_key_str.length() - 5, 0), 5)
				chart.append({"label": day_label, "value": float(_get_focus_minutes_for_date(date_key_str)) / 60.0})
		_:
			var week_key: String = str(range_data.get("week_key", get_current_week_key()))
			var labels: Array[String] = ["一", "二", "三", "四", "五", "六", "日"]
			for day in range(7):
				var date_key: String = DateUtil.week_key_to_date(week_key, day)
				chart.append({"label": labels[day], "value": float(_get_focus_minutes_for_date(date_key)) / 60.0})
	return chart


func _build_completion_trend_chart(period_type: String, range_data: Dictionary) -> Array:
	var chart: Array = []
	match period_type:
		"month", "recent30":
			for date_key in range_data.get("date_keys", []):
				var date_key_str: String = str(date_key)
				var week_key: String = DateUtil.date_to_week_key(date_key_str)
				var day: int = DateUtil.get_day_of_week(date_key_str)
				var completion := get_day_completion(week_key, day)
				var total := int(completion.get("total", 0))
				var completed := int(completion.get("completed", 0))
				var ratio: float = 0.0 if total == 0 else float(completed) / float(total)
				var short_label: String = date_key_str.substr(max(date_key_str.length() - 5, 0), 5)
				chart.append({"label": short_label, "value": ratio * 100.0})
		_:
			var base_week: String = str(range_data.get("week_key", get_current_week_key()))
			for offset in range(-3, 1):
				var week_key: String = DateUtil.offset_week(base_week, offset)
				var rate: float = get_week_completion_rate(week_key) * 100.0
				chart.append({"label": week_key.right(3), "value": rate})
	return chart


func _pick_strongest_period(period_counter: Dictionary) -> String:
	var best_key := "morning"
	var best_value := -1
	for key in period_counter.keys():
		var value := int(period_counter[key])
		if value > best_value:
			best_value = value
			best_key = key
	match best_key:
		"afternoon":
			return "下午"
		"evening":
			return "晚上"
		_:
			return "早晨"


func _get_focus_minutes_for_date(date_key: String) -> int:
	if not StatsState:
		return 0
	return int(round(float(StatsState.get_day_total("focus", date_key, "duration_seconds")) / 60.0))


func _period_title(period_type: String, period_key: String) -> String:
	match period_type:
		"month":
			return "%s 月度回顾" % period_key
		"recent30":
			return "最近30天回顾"
		"day":
			return "%s 当日回顾" % period_key
		_:
			return "%s 周回顾" % period_key


func _find_period_reflection_text(period_type: String, period_key: String) -> String:
	if not NoteState:
		return ""
	var notes = NoteState.get_notes_by_category("反思总结")
	for note in notes:
		var haystack := "%s\n%s" % [note.title, note.content]
		if haystack.find(period_key) >= 0:
			return note.content
		if period_type == "recent30" and haystack.find("最近30天") >= 0:
			return note.content
	return ""
