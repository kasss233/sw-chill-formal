class_name ContextCollector extends Node
## 上下文收集器
## 负责从各个 State 单例收集当前状态信息，附加到 AI 请求中
##
## 使用场景:
##   当用户发送消息时，自动收集任务完成情况、音乐状态、番茄钟状态等
##   让 AI 能够感知用户当前的工作状态，提供更智能的响应

## 收集完成时发出
signal collection_completed(context: Dictionary)

## 是否启用各项收集（可在编辑器中配置）
@export_group("收集开关")
@export var collect_tasks: bool = true
@export var collect_music: bool = true
@export var collect_pomodoro: bool = true
@export var collect_environment: bool = true
@export var collect_notes: bool = false  ## 便签内容可能较大，默认关闭
@export var collect_habits: bool = true  ## 习惯状态
@export var collect_level: bool = true  ## 等级与经验
@export var collect_stats: bool = true  ## 专注统计


## 收集所有上下文信息
func collect() -> Dictionary:
	var context: Dictionary = {
		"timestamp": int(Time.get_unix_time_from_system()),
		"datetime": Time.get_datetime_string_from_system()
	}

	if collect_tasks:
		context["tasks"] = _collect_tasks()

	if collect_music:
		context["music"] = _collect_music()

	if collect_pomodoro:
		context["pomodoro"] = _collect_pomodoro()

	if collect_environment:
		context["environment"] = _collect_environment()

	if collect_notes:
		context["notes"] = _collect_notes()

	if collect_habits:
		context["habits"] = _collect_habits()

	if collect_level:
		context["level"] = _collect_level()

	if collect_stats:
		context["focus_stats"] = _collect_focus_stats()

	collection_completed.emit(context)
	return context


## 收集任务状态
func _collect_tasks() -> Dictionary:
	var all = TaskState.get_all_tasks()
	var incomplete = TaskState.get_incomplete_tasks()
	var completed = TaskState.get_completed_tasks()
	var overdue = TaskState.get_overdue_tasks()

	var recent: Array = []
	for t in incomplete.slice(0, 5):
		var item: Dictionary = {"id": t.id, "title": t.title, "due_timestamp": t.due_timestamp}
		recent.append(item)

	return {
		"total": all.size(),
		"completed": completed.size(),
		"pending": incomplete.size(),
		"overdue": overdue.size(),
		"recent_tasks": recent
	}


## 收集音乐状态
func _collect_music() -> Dictionary:
	return {
		"current_track": MusicState.current_track,
		"is_playing": MusicState.is_playing,
		"play_mode": MusicState.play_mode,
		"play_mode_name": MusicState.get_play_mode_name(),
		"current_playlist": MusicState.current_playlist
	}


## 收集番茄钟状态
func _collect_pomodoro() -> Dictionary:
	if PomodoroState.is_active():
		return PomodoroState.get_status()
	return {"is_running": false}


## 收集环境状态
func _collect_environment() -> Dictionary:
	return {
		"time_mode": SettingState.get_time_mode(),
		"weather_mode": SettingState.get_weather_mode()
	}


## 收集笔记/便签状态
func _collect_notes() -> Dictionary:
	var notes = NoteState.get_all_notes()
	var recent: Array = []
	for n in notes.slice(0, 5):
		recent.append({"id": n.id, "title": n.title})

	return {
		"count": notes.size(),
		"sticky_count": StickyNoteState.get_count(),
		"recent_notes": recent
	}


## 收集习惯状态
func _collect_habits() -> Dictionary:
	var habits = HabitState.get_active_habits()
	var week_key = HabitState.get_current_week_key()
	var stats = HabitState.get_week_stats(week_key)
	var recent: Array = []
	for h in habits.slice(0, 5):
		recent.append({"name": h.name, "minutes": h.estimated_minutes})
	return {
		"habit_count": habits.size(),
		"current_week": week_key,
		"week_completion_rate": stats.get("completion_rate", 0.0),
		"recent_habits": recent
	}


## 收集等级状态
func _collect_level() -> Dictionary:
	return LevelState.agent_get_level_info()


## 收集专注统计
func _collect_focus_stats() -> Dictionary:
	if not StatsState:
		return {}
	return StatsState.agent_get_focus_stats("week")


## 格式化上下文为提示词片段
## 将收集的上下文转换为自然语言描述，可直接插入 system prompt
func format_as_prompt(context: Dictionary = {}) -> String:
	if context.is_empty():
		context = collect()

	var parts: Array[String] = []

	# 时间
	if context.has("datetime"):
		parts.append("当前时间: " + str(context["datetime"]) + "（UTC+8）")

	# 任务
	if context.has("tasks") and not context["tasks"].is_empty():
		var tasks: Dictionary = context["tasks"]
		var total: int = tasks.get("total", 0)
		if total > 0:
			var task_line = "任务: 共 %d 个，未完成 %d 个" % [total, tasks.get("pending", 0)]
			var overdue_count: int = tasks.get("overdue", 0)
			if overdue_count > 0:
				task_line += "，逾期 %d 个" % overdue_count
			parts.append(task_line)

			# 列出最近的未完成任务
			var recent: Array = tasks.get("recent_tasks", [])
			for t in recent:
				var item_text = "  - " + str(t.get("title", ""))
				var due: int = t.get("due_timestamp", 0)
				if due > 0:
					# 转换为本地时间显示（UTC+8）
					var due_local = due + 8 * 3600
					var due_dict = Time.get_datetime_dict_from_unix_time(due_local)
					item_text += "（截止: %d-%02d-%02d %02d:%02d）" % [
						due_dict.get("year", 0), due_dict.get("month", 0), due_dict.get("day", 0),
						due_dict.get("hour", 0), due_dict.get("minute", 0)
					]
				parts.append(item_text)

	# 音乐
	if context.has("music") and not context["music"].is_empty():
		var music: Dictionary = context["music"]
		if music.get("is_playing", false):
			var mode_name: String = music.get("play_mode_name", "顺序播放")
			parts.append("音乐: 正在播放 %s（%s）" % [music.get("current_track", "未知"), mode_name])
		else:
			if not music.get("current_track", "").is_empty():
				parts.append("音乐: 已暂停（%s）" % music.get("current_track", ""))

	# 番茄钟
	if context.has("pomodoro") and not context["pomodoro"].is_empty():
		var pomo: Dictionary = context["pomodoro"]
		if pomo.get("is_running", false) or pomo.get("is_paused", false):
			var mode_text = "工作" if pomo.get("is_work_mode", true) else "休息"
			var remaining: int = pomo.get("remaining_seconds", 0)
			var min_left: int = remaining / 60
			var loop_text = "第 %d/%d 轮" % [pomo.get("current_loop", 1), pomo.get("total_loops", 1)]
			if pomo.get("is_paused", false):
				parts.append("番茄钟: %s阶段（已暂停），剩余 %d 分钟（%s）" % [mode_text, min_left, loop_text])
			else:
				parts.append("番茄钟: %s阶段，剩余 %d 分钟（%s）" % [mode_text, min_left, loop_text])

	# 笔记
	if context.has("notes") and not context["notes"].is_empty():
		var notes: Dictionary = context["notes"]
		var note_count: int = notes.get("count", 0)
		var sticky_count: int = notes.get("sticky_count", 0)
		if note_count > 0 or sticky_count > 0:
			parts.append("笔记: %d 条笔记，%d 条便签" % [note_count, sticky_count])

	# 环境
	if context.has("environment") and not context["environment"].is_empty():
		var env: Dictionary = context["environment"]
		var time_names = ["白天", "黄昏", "夜晚", "同步系统"]
		var weather_names = ["晴天", "雨天", "雪天", "同步系统"]
		var time_mode: int = env.get("time_mode", 0)
		var weather_mode: int = env.get("weather_mode", 0)
		var time_text = time_names[time_mode] if time_mode < time_names.size() else "未知"
		var weather_text = weather_names[weather_mode] if weather_mode < weather_names.size() else "未知"
		parts.append("环境: %s / %s" % [time_text, weather_text])

	# 习惯
	if context.has("habits") and not context["habits"].is_empty():
		var habits: Dictionary = context["habits"]
		var habit_count: int = habits.get("habit_count", 0)
		if habit_count > 0:
			var rate: float = habits.get("week_completion_rate", 0.0)
			parts.append("习惯: %d 个活跃习惯，本周完成率 %d%%（%s）" % [
				habit_count, int(rate * 100), habits.get("current_week", "")])
			var recent_habits: Array = habits.get("recent_habits", [])
			for h in recent_habits:
				parts.append("  - %s（%d分钟）" % [h.get("name", ""), h.get("minutes", 0)])

	# 等级
	if context.has("level") and not context["level"].is_empty():
		var lvl: Dictionary = context["level"]
		parts.append("等级: Lv.%d（%d/%d XP，进度 %d%%）" % [
			lvl.get("level", 1), lvl.get("xp", 0),
			lvl.get("xp_for_next_level", 100),
			int(lvl.get("progress", 0.0) * 100)])

	# 专注统计
	if context.has("focus_stats") and not context["focus_stats"].is_empty():
		var fs: Dictionary = context["focus_stats"]
		var today_str: String = fs.get("today_formatted", "0 分钟")
		var avg_str: String = fs.get("daily_avg_formatted", "0 分钟")
		parts.append("专注: 今日 %s，本周日均 %s" % [today_str, avg_str])

	if parts.is_empty():
		return ""

	return "[当前用户状态]\n" + "\n".join(parts)
