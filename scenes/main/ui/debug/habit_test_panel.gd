extends Control

## HabitModule测试页 - 测试 HabitState 单例 + Agent API + FnCall 链路

# UI节点引用 - 输入框
@onready var habit_name_input: LineEdit = $MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/InputSection/HabitNameInput
@onready var habit_id_input: LineEdit = $MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/InputSection/HabitIdInput
@onready var week_key_input: LineEdit = $MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/InputSection/WeekKeyInput
@onready var entry_id_input: LineEdit = $MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/InputSection/EntryIdInput
@onready var date_key_input: LineEdit = $MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/InputSection/DateKeyInput

# 习惯库 API 按钮
@onready var add_habit_btn: Button = $MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/HabitSection/AddHabitBtn
@onready var get_all_habits_btn: Button = $MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/HabitSection/GetAllHabitsBtn
@onready var update_habit_btn: Button = $MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/HabitSection/UpdateHabitBtn
@onready var remove_habit_btn: Button = $MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/HabitSection/RemoveHabitBtn
@onready var toggle_active_btn: Button = $MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/HabitSection/ToggleActiveBtn

# 时间段 API 按钮
@onready var get_time_slots_btn: Button = $MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/SlotSection/GetTimeSlotsBtn

# 排期 API 按钮
@onready var get_week_schedule_btn: Button = $MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/ScheduleSection/GetWeekScheduleBtn
@onready var clear_week_btn: Button = $MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/ScheduleSection/ClearWeekBtn
@onready var copy_week_btn: Button = $MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/ScheduleSection/CopyWeekBtn

# 执行记录 API 按钮
@onready var mark_completed_btn: Button = $MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/ExecutionSection/MarkCompletedBtn
@onready var mark_skipped_btn: Button = $MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/ExecutionSection/MarkSkippedBtn
@onready var get_day_records_btn: Button = $MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/ExecutionSection/GetDayRecordsBtn
@onready var get_week_stats_btn: Button = $MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/ExecutionSection/GetWeekStatsBtn

# Agent API 按钮
@onready var agent_add_habit_btn: Button = $MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/AgentSection/AgentAddHabitBtn
@onready var agent_get_habits_btn: Button = $MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/AgentSection/AgentGetHabitsBtn
@onready var agent_get_time_slots_btn: Button = $MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/AgentSection/AgentGetTimeSlotsBtn
@onready var agent_get_schedule_btn: Button = $MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/AgentSection/AgentGetScheduleBtn
@onready var agent_get_stats_btn: Button = $MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/AgentSection/AgentGetStatsBtn
@onready var agent_set_execution_btn: Button = $MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/AgentSection/AgentSetExecutionBtn

# FnCall 链路按钮
@onready var fn_add_habit_btn: Button = $MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/FnCallSection/FnAddHabitBtn
@onready var fn_get_habits_btn: Button = $MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/FnCallSection/FnGetHabitsBtn
@onready var fn_gen_schedule_btn: Button = $MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/FnCallSection/FnGenScheduleBtn
@onready var fn_get_stats_btn: Button = $MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/FnCallSection/FnGetStatsBtn

# 日志输出
@onready var info_label: RichTextLabel = $MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/InfoLabel


func _ready() -> void:
	# 连接习惯库 API 按钮
	add_habit_btn.pressed.connect(_on_add_habit_pressed)
	get_all_habits_btn.pressed.connect(_on_get_all_habits_pressed)
	update_habit_btn.pressed.connect(_on_update_habit_pressed)
	remove_habit_btn.pressed.connect(_on_remove_habit_pressed)
	toggle_active_btn.pressed.connect(_on_toggle_active_pressed)

	# 连接时间段 API 按钮
	get_time_slots_btn.pressed.connect(_on_get_time_slots_pressed)

	# 连接排期 API 按钮
	get_week_schedule_btn.pressed.connect(_on_get_week_schedule_pressed)
	clear_week_btn.pressed.connect(_on_clear_week_pressed)
	copy_week_btn.pressed.connect(_on_copy_week_pressed)

	# 连接执行记录 API 按钮
	mark_completed_btn.pressed.connect(_on_mark_completed_pressed)
	mark_skipped_btn.pressed.connect(_on_mark_skipped_pressed)
	get_day_records_btn.pressed.connect(_on_get_day_records_pressed)
	get_week_stats_btn.pressed.connect(_on_get_week_stats_pressed)

	# 连接 Agent API 按钮
	agent_add_habit_btn.pressed.connect(_on_agent_add_habit_pressed)
	agent_get_habits_btn.pressed.connect(_on_agent_get_habits_pressed)
	agent_get_time_slots_btn.pressed.connect(_on_agent_get_time_slots_pressed)
	agent_get_schedule_btn.pressed.connect(_on_agent_get_schedule_pressed)
	agent_get_stats_btn.pressed.connect(_on_agent_get_stats_pressed)
	agent_set_execution_btn.pressed.connect(_on_agent_set_execution_pressed)

	# 连接 FnCall 链路按钮
	fn_add_habit_btn.pressed.connect(_on_fn_add_habit_pressed)
	fn_get_habits_btn.pressed.connect(_on_fn_get_habits_pressed)
	fn_gen_schedule_btn.pressed.connect(_on_fn_gen_schedule_pressed)
	fn_get_stats_btn.pressed.connect(_on_fn_get_stats_pressed)

	# 监听 HabitState 信号
	HabitState.habit_added.connect(func(h): _log_data("信号 habit_added: id=%d name=%s" % [h.id, h.name]))
	HabitState.habit_removed.connect(func(id): _log_data("信号 habit_removed: id=%d" % id))
	HabitState.habit_updated.connect(func(h): _log_data("信号 habit_updated: id=%d name=%s" % [h.id, h.name]))
	HabitState.schedule_updated.connect(func(wk): _log_data("信号 schedule_updated: %s" % wk))
	HabitState.schedule_cleared.connect(func(wk): _log_data("信号 schedule_cleared: %s" % wk))
	HabitState.execution_updated.connect(func(r): _log_data("信号 execution_updated: entry=%d status=%d" % [r.entry_id, r.status]))
	HabitState.agent_schedule_generated.connect(func(wk): _log_data("信号 agent_schedule_generated: %s" % wk))
	HabitState.data_loaded.connect(func(): _log_data("信号 data_loaded"))

	# 设置默认值
	week_key_input.text = HabitState.get_current_week_key()
	var now = Time.get_datetime_dict_from_system()
	date_key_input.text = "%04d-%02d-%02d" % [now["year"], now["month"], now["day"]]

	_log_info("HabitModule测试面板已就绪")


# ======================== 辅助 ========================

func _get_week_key() -> String:
	var wk = week_key_input.text.strip_edges()
	if wk.is_empty():
		wk = HabitState.get_current_week_key()
	return wk


func _get_date_key() -> String:
	var dk = date_key_input.text.strip_edges()
	if dk.is_empty():
		var now = Time.get_datetime_dict_from_system()
		dk = "%04d-%02d-%02d" % [now["year"], now["month"], now["day"]]
	return dk


# ======================== 习惯库 API ========================

func _on_add_habit_pressed() -> void:
	var habit_name = habit_name_input.text.strip_edges()
	if habit_name.is_empty():
		habit_name = "测试习惯 " + str(Time.get_ticks_msec())
	_log_info("调用 HabitState.add_habit(name='%s')" % habit_name)
	var habit = HabitState.add_habit(habit_name)
	_log_success("习惯已添加，ID: %d" % habit.id)
	habit_id_input.text = str(habit.id)


func _on_get_all_habits_pressed() -> void:
	_log_info("调用 HabitState.get_all_habits()")
	var habits = HabitState.get_all_habits()
	_log_success("共有 %d 个习惯:" % habits.size())
	for h in habits:
		_log_data("  - [%d] %s (活跃: %s, 时长: %dmin)" % [h.id, h.name, h.is_active, h.estimated_minutes])


func _on_update_habit_pressed() -> void:
	var id = habit_id_input.text.to_int()
	var new_name = habit_name_input.text.strip_edges()
	if new_name.is_empty():
		_log_error("请输入新名称")
		return
	_log_info("调用 HabitState.update_habit(id=%d, name='%s')" % [id, new_name])
	var ok = HabitState.update_habit(id, {"name": new_name})
	if ok:
		_log_success("习惯已更新")
	else:
		_log_error("更新失败，习惯ID不存在")


func _on_remove_habit_pressed() -> void:
	var id = habit_id_input.text.to_int()
	_log_info("调用 HabitState.remove_habit(id=%d)" % id)
	var ok = HabitState.remove_habit(id)
	if ok:
		_log_success("习惯已删除")
	else:
		_log_error("删除失败，习惯ID不存在")


func _on_toggle_active_pressed() -> void:
	var id = habit_id_input.text.to_int()
	var habit = HabitState.get_habit_by_id(id)
	if habit == null:
		_log_error("习惯不存在 id=%d" % id)
		return
	var new_active = not habit.is_active
	_log_info("调用 HabitState.set_habit_active(id=%d, active=%s)" % [id, new_active])
	var ok = HabitState.set_habit_active(id, new_active)
	if ok:
		_log_success("激活状态已切换为 %s" % new_active)
	else:
		_log_error("操作失败")


# ======================== 时间段 API ========================

func _on_get_time_slots_pressed() -> void:
	_log_info("调用 HabitState.get_time_slot_templates()")
	var slots = HabitState.get_time_slot_templates()
	_log_success("共有 %d 个时间段模板:" % slots.size())
	for s in slots:
		_log_data("  - [%d] %s (%s ~ %s)" % [s.id, s.name, s.start_time, s.end_time])


# ======================== 排期 API ========================

func _on_get_week_schedule_pressed() -> void:
	var wk = _get_week_key()
	_log_info("调用 HabitState.get_week_schedule(week_key='%s')" % wk)
	var entries = HabitState.get_week_schedule(wk)
	_log_success("周排期共 %d 条:" % entries.size())
	for e in entries:
		var habit = HabitState.get_habit_by_id(e.habit_id)
		var slot = HabitState.get_time_slot_by_id(e.time_slot_id)
		_log_data("  - [entry=%d] 习惯=%s 周%d 时段=%s" % [
			e.id,
			habit.name if habit else "未知(%d)" % e.habit_id,
			e.day_of_week + 1,
			slot.name if slot else "未知(%d)" % e.time_slot_id,
		])


func _on_clear_week_pressed() -> void:
	var wk = _get_week_key()
	_log_info("调用 HabitState.clear_week_schedule(week_key='%s')" % wk)
	HabitState.clear_week_schedule(wk)
	_log_success("已清空周排期: %s" % wk)


func _on_copy_week_pressed() -> void:
	var from_wk = _get_week_key()
	# 简单计算下一周的 week_key
	var parts = from_wk.split("-W")
	if parts.size() != 2:
		_log_error("周标识格式错误，应为 YYYY-WNN")
		return
	var year = parts[0].to_int()
	var week = parts[1].to_int() + 1
	if week > 52:
		week = 1
		year += 1
	var to_wk = "%04d-W%02d" % [year, week]
	_log_info("调用 HabitState.copy_week_schedule(from='%s', to='%s')" % [from_wk, to_wk])
	HabitState.copy_week_schedule(from_wk, to_wk)
	_log_success("已复制排期到 %s" % to_wk)


# ======================== 执行记录 API ========================

func _on_mark_completed_pressed() -> void:
	var eid = entry_id_input.text.to_int()
	var dk = _get_date_key()
	_log_info("调用 HabitState.set_execution_status(entry=%d, date='%s', status=COMPLETED)" % [eid, dk])
	var record = HabitState.set_execution_status(eid, dk, HabitData.ExecutionRecord.Status.COMPLETED)
	if record:
		_log_success("已标记完成: record_id=%d" % record.id)
	else:
		_log_error("设置失败，排期条目不存在")


func _on_mark_skipped_pressed() -> void:
	var eid = entry_id_input.text.to_int()
	var dk = _get_date_key()
	_log_info("调用 HabitState.set_execution_status(entry=%d, date='%s', status=SKIPPED)" % [eid, dk])
	var record = HabitState.set_execution_status(eid, dk, HabitData.ExecutionRecord.Status.SKIPPED)
	if record:
		_log_success("已标记跳过: record_id=%d" % record.id)
	else:
		_log_error("设置失败，排期条目不存在")


func _on_get_day_records_pressed() -> void:
	var dk = _get_date_key()
	_log_info("调用 HabitState.get_records_by_date(date='%s')" % dk)
	var records = HabitState.get_records_by_date(dk)
	_log_success("当日共 %d 条记录:" % records.size())
	for r in records:
		var status_names = ["PENDING", "COMPLETED", "SKIPPED", "DEFERRED"]
		var status_name = status_names[r.status] if r.status < status_names.size() else "UNKNOWN"
		_log_data("  - [record=%d] entry=%d habit=%d status=%s" % [r.id, r.entry_id, r.habit_id, status_name])


func _on_get_week_stats_pressed() -> void:
	var wk = _get_week_key()
	_log_info("调用 HabitState.get_week_stats(week_key='%s')" % wk)
	var stats = HabitState.get_week_stats(wk)
	_log_success("周统计:")
	_log_data(JSON.stringify(stats, "  "))


# ======================== Agent API ========================

func _on_agent_add_habit_pressed() -> void:
	var habit_name = habit_name_input.text.strip_edges()
	if habit_name.is_empty():
		habit_name = "Agent测试习惯 " + str(Time.get_ticks_msec())
	_log_info("调用 HabitState.agent_add_habit(name='%s')" % habit_name)
	var result = HabitState.agent_add_habit(habit_name)
	_log_success("Agent 返回:")
	_log_data(JSON.stringify(result, "  "))
	if result.has("id"):
		habit_id_input.text = str(result["id"])


func _on_agent_get_habits_pressed() -> void:
	_log_info("调用 HabitState.agent_get_habits()")
	var result = HabitState.agent_get_habits()
	_log_success("Agent 返回 %d 个习惯:" % result.size())
	_log_data(JSON.stringify(result, "  "))


func _on_agent_get_time_slots_pressed() -> void:
	_log_info("调用 HabitState.agent_get_time_slots()")
	var result = HabitState.agent_get_time_slots()
	_log_success("Agent 返回 %d 个时间段:" % result.size())
	_log_data(JSON.stringify(result, "  "))


func _on_agent_get_schedule_pressed() -> void:
	var wk = _get_week_key()
	_log_info("调用 HabitState.agent_get_week_schedule(week_key='%s')" % wk)
	var result = HabitState.agent_get_week_schedule(wk)
	_log_success("Agent 返回 %d 条排期:" % result.size())
	_log_data(JSON.stringify(result, "  "))


func _on_agent_get_stats_pressed() -> void:
	var wk = _get_week_key()
	_log_info("调用 HabitState.agent_get_habit_stats(week_key='%s')" % wk)
	var result = HabitState.agent_get_habit_stats(wk)
	_log_success("Agent 返回统计:")
	_log_data(JSON.stringify(result, "  "))


func _on_agent_set_execution_pressed() -> void:
	var eid = entry_id_input.text.to_int()
	var dk = _get_date_key()
	_log_info("调用 HabitState.agent_set_execution(entry=%d, date='%s', status=COMPLETED)" % [eid, dk])
	var ok = HabitState.agent_set_execution(eid, dk, HabitData.ExecutionRecord.Status.COMPLETED)
	if ok:
		_log_success("Agent 设置执行状态成功")
	else:
		_log_error("Agent 设置执行状态失败")


# ======================== FnCall 链路测试 ========================

func _on_fn_add_habit_pressed() -> void:
	var habit_name = habit_name_input.text.strip_edges()
	if habit_name.is_empty():
		habit_name = "FnCall测试习惯 " + str(Time.get_ticks_msec())
	_log_info("FnCall execute: add_habit(name='%s')" % habit_name)
	var executor = ChatController.agent_executor
	var result = executor.execute("test_%d" % Time.get_ticks_msec(), "add_habit", {"name": habit_name})
	_log_data("FnCall 结果: %s" % JSON.stringify(result))


func _on_fn_get_habits_pressed() -> void:
	_log_info("FnCall execute: get_habits()")
	var executor = ChatController.agent_executor
	var result = executor.execute("test_%d" % Time.get_ticks_msec(), "get_habits", {})
	_log_data("FnCall 结果: %s" % JSON.stringify(result))


func _on_fn_gen_schedule_pressed() -> void:
	var wk = _get_week_key()
	_log_info("FnCall execute: generate_week_schedule(week_key='%s', entries=[])" % wk)
	var executor = ChatController.agent_executor
	var result = executor.execute("test_%d" % Time.get_ticks_msec(), "generate_week_schedule", {"week_key": wk, "entries": []})
	_log_data("FnCall 结果: %s" % JSON.stringify(result))


func _on_fn_get_stats_pressed() -> void:
	var wk = _get_week_key()
	_log_info("FnCall execute: get_habit_stats(week_key='%s')" % wk)
	var executor = ChatController.agent_executor
	var result = executor.execute("test_%d" % Time.get_ticks_msec(), "get_habit_stats", {"week_key": wk})
	_log_data("FnCall 结果: %s" % JSON.stringify(result))


# ======================== 日志系统 ========================

func _log_info(message: String) -> void:
	info_label.append_text("[color=white]%s[/color]\n" % message)
	print("[HabitTest] %s" % message)


func _log_success(message: String) -> void:
	info_label.append_text("[color=green]%s[/color]\n" % message)
	print("[HabitTest] %s" % message)


func _log_error(message: String) -> void:
	info_label.append_text("[color=red]%s[/color]\n" % message)
	print("[HabitTest] ERROR: %s" % message)


func _log_data(message: String) -> void:
	info_label.append_text("[color=cyan]%s[/color]\n" % message)
	print("[HabitTest] %s" % message)
