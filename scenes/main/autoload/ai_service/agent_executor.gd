class_name AgentExecutor extends Node
## Agent 函数执行器
## 负责执行 AI 请求的函数调用（Function Calling / Tool Use）
##
## 功能:
##   1. 从 function_definitions.json 加载函数定义，自动注册
##   2. 执行 AI 发来的函数调用请求
##   3. 返回执行结果供回传给 AI

## 函数执行成功
signal function_executed(call_id: String, name: String, result: Variant)
## 函数执行失败
signal function_failed(call_id: String, name: String, error: String)
## 函数开始执行（用于 UI 反馈）
signal function_started(call_id: String, name: String)

## 是否启用函数执行（安全开关）
@export var enabled: bool = true

## 是否自动注册默认函数
@export var auto_register_defaults: bool = true

## 函数定义 JSON 文件路径
const FUNCTION_DEFINITIONS_PATH = "res://scenes/main/autoload/ai_service/function_definitions.json"

## 时区偏移量（UTC+8）
const TIMEZONE_OFFSET = 8 * 3600

## 已注册的函数 { name: { callable: Callable, definition: Dictionary } }
var _functions: Dictionary = {}


func _ready() -> void:
	call_deferred("_init_executor")


func _init_executor() -> void:
	if auto_register_defaults:
		_register_default_functions()
	print("[AgentExecutor] 初始化完成，已注册 %d 个函数" % _functions.size())


## 注册一个可调用函数
func register(name: String, callable: Callable, definition: Dictionary = {}) -> void:
	_functions[name] = {
		"callable": callable,
		"definition": definition
	}


## 注销函数
func unregister(name: String) -> void:
	_functions.erase(name)


## 检查函数是否已注册
func has_function(name: String) -> bool:
	return _functions.has(name)


## 执行函数调用
func execute(call_id: String, name: String, args: Dictionary) -> Dictionary:
	print("[AgentExecutor][DEBUG] execute() called: name=%s enabled=%s registered=%s args=%s" % [name, enabled, _functions.has(name), args])
	if not enabled:
		var error = "函数执行已禁用"
		function_failed.emit(call_id, name, error)
		return {"success": false, "error": error}

	if not _functions.has(name):
		var error = "未知函数: " + name
		print("[AgentExecutor][DEBUG] 已注册函数列表: %s" % str(_functions.keys()))
		function_failed.emit(call_id, name, error)
		return {"success": false, "error": error}

	function_started.emit(call_id, name)
	print("[AgentExecutor] 执行函数: %s (call_id: %s) args=%s" % [name, call_id, args])

	var callable: Callable = _functions[name]["callable"]
	var result: Dictionary = callable.call(args)

	if result.get("success", false):
		function_executed.emit(call_id, name, result)
	else:
		function_failed.emit(call_id, name, result.get("error", "未知错误"))

	return result


## 获取所有函数定义（用于发送给 AI）
func get_function_definitions() -> Array[Dictionary]:
	var definitions: Array[Dictionary] = []
	for name in _functions:
		var def = _functions[name].get("definition", {})
		if not def.is_empty():
			definitions.append(def)
	return definitions


## 获取已注册的函数名列表
func get_registered_functions() -> Array[String]:
	var names: Array[String] = []
	for name in _functions:
		names.append(name)
	return names


# ============================================================
# 从 JSON 加载函数定义并注册
# ============================================================

func _register_default_functions() -> void:
	var file = FileAccess.open(FUNCTION_DEFINITIONS_PATH, FileAccess.READ)
	if not file:
		push_error("[AgentExecutor] 无法打开函数定义文件: %s" % FUNCTION_DEFINITIONS_PATH)
		return

	var json = JSON.new()
	var err = json.parse(file.get_as_text())
	file.close()
	if err != OK:
		push_error("[AgentExecutor] 函数定义 JSON 解析失败: %s" % json.get_error_message())
		return

	var definitions: Array = json.data
	for def in definitions:
		var fn_name: String = def.get("name", "")
		if fn_name.is_empty():
			continue
		var method_name = "_fn_" + fn_name
		if not has_method(method_name):
			push_warning("[AgentExecutor] 未找到实现方法: %s" % method_name)
			continue
		register(fn_name, Callable(self , method_name), def)


# ============================================================
# 函数实现 — 任务管理（11 个）
# ============================================================

func _fn_add_task(args: Dictionary) -> Dictionary:
	var title = args.get("title", "")
	if title.is_empty():
		return {"success": false, "error": "任务标题不能为空"}
	var due = _resolve_due_timestamp(args)
	var task = TaskState.add_task(title, due)
	return {"success": true, "data": {"task_id": task.id, "title": task.title, "due_timestamp": task.due_timestamp}}


func _fn_remove_task(args: Dictionary) -> Dictionary:
	var ok = TaskState.remove_task(int(args.get("task_id", 0)))
	if ok:
		return {"success": true}
	return {"success": false, "error": "任务不存在"}


func _fn_update_task_title(args: Dictionary) -> Dictionary:
	var ok = TaskState.update_task_title(int(args.get("task_id", 0)), args.get("title", ""))
	if ok:
		return {"success": true}
	return {"success": false, "error": "任务不存在"}


func _fn_set_task_completed(args: Dictionary) -> Dictionary:
	var ok = TaskState.set_task_completed(int(args.get("task_id", 0)), args.get("completed", true))
	if ok:
		return {"success": true}
	return {"success": false, "error": "任务不存在"}


func _fn_set_task_due_time(args: Dictionary) -> Dictionary:
	var due = _resolve_due_timestamp(args)
	var ok = TaskState.set_task_due_time(int(args.get("task_id", 0)), due)
	if ok:
		return {"success": true}
	return {"success": false, "error": "任务不存在"}


func _fn_clear_completed_tasks(args: Dictionary) -> Dictionary:
	var count = TaskState.clear_completed()
	return {"success": true, "data": {"removed_count": count}}


func _fn_get_all_tasks(_args: Dictionary) -> Dictionary:
	var tasks = TaskState.get_all_tasks()
	var list: Array = []
	for t in tasks:
		list.append({"id": t.id, "title": t.title, "is_completed": t.is_completed, "due_timestamp": t.due_timestamp})
	return {"success": true, "data": list}


func _fn_get_incomplete_tasks(_args: Dictionary) -> Dictionary:
	var tasks = TaskState.get_incomplete_tasks()
	var list: Array = []
	for t in tasks:
		list.append({"id": t.id, "title": t.title, "due_timestamp": t.due_timestamp})
	return {"success": true, "data": list}


func _fn_get_completed_tasks(_args: Dictionary) -> Dictionary:
	var tasks = TaskState.get_completed_tasks()
	var list: Array = []
	for t in tasks:
		list.append({"id": t.id, "title": t.title, "finish_timestamp": t.finish_timestamp})
	return {"success": true, "data": list}


func _fn_get_overdue_tasks(_args: Dictionary) -> Dictionary:
	var tasks = TaskState.get_overdue_tasks()
	return {"success": true, "data": tasks}


func _fn_reorder_task(args: Dictionary) -> Dictionary:
	var ok = TaskState.reorder_task(
		int(args.get("task_id", 0)),
		int(args.get("new_position", 0)),
		args.get("is_completed", false)
	)
	if ok:
		return {"success": true}
	return {"success": false, "error": "任务不存在"}


# ============================================================
# 函数实现 — 笔记管理（14 个）
# ============================================================

func _fn_create_note(args: Dictionary) -> Dictionary:
	var note = NoteState.agent_create_note(
		args.get("title", ""),
		args.get("content", ""),
		args.get("category", "")
	)
	if note:
		return {"success": true, "data": {"note_id": note.id, "title": note.title}}
	return {"success": false, "error": "笔记创建失败"}


func _fn_write_note_content(args: Dictionary) -> Dictionary:
	var ok = NoteState.agent_write_content(int(args.get("note_id", 0)), args.get("content", ""))
	if ok:
		return {"success": true}
	return {"success": false, "error": "笔记不存在"}


func _fn_open_note(args: Dictionary) -> Dictionary:
	var ok = NoteState.agent_open_note(int(args.get("note_id", 0)))
	if ok:
		return {"success": true}
	return {"success": false, "error": "笔记不存在"}


func _fn_close_note(_args: Dictionary) -> Dictionary:
	NoteState.agent_close_note()
	return {"success": true}


func _fn_remove_note(args: Dictionary) -> Dictionary:
	var ok = NoteState.remove_note(int(args.get("note_id", 0)))
	if ok:
		return {"success": true}
	return {"success": false, "error": "笔记不存在"}


func _fn_update_note(args: Dictionary) -> Dictionary:
	var note_id = int(args.get("note_id", 0))
	var note = NoteState.get_note_by_id(note_id)
	if not note:
		return {"success": false, "error": "笔记不存在"}
	var title = args.get("title", note.title)
	var content = args.get("content", note.content)
	var ok = NoteState.update_note(note_id, title, content)
	if ok:
		return {"success": true}
	return {"success": false, "error": "更新失败"}


func _fn_search_notes(args: Dictionary) -> Dictionary:
	var notes = NoteState.search_notes(args.get("query", ""))
	var list: Array = []
	for n in notes:
		list.append({"id": n.id, "title": n.title, "content": n.content, "categories": n.categories})
	return {"success": true, "data": list}


func _fn_get_all_notes(_args: Dictionary) -> Dictionary:
	var notes = NoteState.get_all_notes()
	var list: Array = []
	for n in notes:
		list.append({"id": n.id, "title": n.title, "content": n.content, "categories": n.categories})
	return {"success": true, "data": list}


func _fn_take_note(args: Dictionary) -> Dictionary:
	var text = args.get("text", args.get("content", ""))
	var ok = StickyNoteState.agent_take_note(text)
	if ok:
		return {"success": true}
	return {"success": false, "error": "便签创建失败（可能已达上限或内容为空）"}


func _fn_get_note_by_id(args: Dictionary) -> Dictionary:
	var note = NoteState.get_note_by_id(int(args.get("note_id", 0)))
	if note:
		return {"success": true, "data": {"id": note.id, "title": note.title, "content": note.content, "categories": note.categories}}
	return {"success": false, "error": "笔记不存在"}


func _fn_add_category(args: Dictionary) -> Dictionary:
	var ok = NoteState.add_category(args.get("category", ""))
	if ok:
		return {"success": true}
	return {"success": false, "error": "分类添加失败（可能已存在或名称为空）"}


func _fn_remove_category(args: Dictionary) -> Dictionary:
	var ok = NoteState.remove_category(args.get("category", ""))
	if ok:
		return {"success": true}
	return {"success": false, "error": "分类不存在"}


func _fn_toggle_note_category(args: Dictionary) -> Dictionary:
	var ok = NoteState.toggle_note_category(int(args.get("note_id", 0)), args.get("category", ""))
	if ok:
		return {"success": true}
	return {"success": false, "error": "操作失败（笔记或分类不存在）"}


func _fn_get_categories(_args: Dictionary) -> Dictionary:
	var categories = NoteState.get_categories()
	return {"success": true, "data": categories}


# ============================================================
# 函数实现 — 音乐控制（16 个）
# ============================================================

func _fn_play_music(args: Dictionary) -> Dictionary:
	var track = args.get("track_name", "")
	if not track.is_empty():
		MusicState.set_track(track)
	MusicState.set_playing(true)
	return {"success": true}


func _fn_pause_music(_args: Dictionary) -> Dictionary:
	MusicState.set_playing(false)
	return {"success": true}


func _fn_toggle_playback(_args: Dictionary) -> Dictionary:
	MusicState.toggle_playback()
	return {"success": true, "data": {"is_playing": MusicState.is_playing}}


func _fn_play_next(_args: Dictionary) -> Dictionary:
	var ok = MusicState.play_next()
	if ok:
		return {"success": true, "data": {"current_track": MusicState.current_track}}
	return {"success": false, "error": "无法播放下一首（播放列表可能为空）"}


func _fn_play_previous(_args: Dictionary) -> Dictionary:
	var ok = MusicState.play_previous()
	if ok:
		return {"success": true, "data": {"current_track": MusicState.current_track}}
	return {"success": false, "error": "无法播放上一首（播放列表可能为空）"}


func _fn_set_play_mode(args: Dictionary) -> Dictionary:
	var mode = int(args.get("mode", 0))
	MusicState.set_play_mode(mode)
	return {"success": true, "data": {"play_mode": mode, "play_mode_name": MusicState.get_play_mode_name()}}


func _fn_set_bgm_volume(args: Dictionary) -> Dictionary:
	var volume = float(args.get("volume", 0.5))
	AudioPlayer.set_bgm_volume(volume)
	return {"success": true}


func _fn_get_music_state(_args: Dictionary) -> Dictionary:
	return {"success": true, "data": {
		"current_track": MusicState.current_track,
		"is_playing": MusicState.is_playing,
		"play_mode": MusicState.play_mode,
		"play_mode_name": MusicState.get_play_mode_name(),
		"current_playlist": MusicState.current_playlist
	}}


func _fn_switch_playlist(args: Dictionary) -> Dictionary:
	MusicState.set_playlist(args.get("playlist_name", ""))
	return {"success": true}


func _fn_create_playlist(args: Dictionary) -> Dictionary:
	var ok = MusicState.create_playlist(args.get("name", ""))
	if ok:
		return {"success": true}
	return {"success": false, "error": "歌单创建失败（可能已存在）"}


func _fn_delete_playlist(args: Dictionary) -> Dictionary:
	var ok = MusicState.delete_playlist(args.get("name", ""))
	if ok:
		return {"success": true}
	return {"success": false, "error": "歌单删除失败（可能不存在或为保护歌单）"}


func _fn_add_track_to_playlist(args: Dictionary) -> Dictionary:
	var ok = MusicState.add_track_to_playlist(args.get("playlist_name", ""), args.get("track_name", ""))
	if ok:
		return {"success": true}
	return {"success": false, "error": "添加失败（歌单可能不存在）"}


func _fn_remove_track_from_playlist(args: Dictionary) -> Dictionary:
	var ok = MusicState.remove_track_from_playlist(args.get("playlist_name", ""), args.get("track_name", ""))
	if ok:
		return {"success": true}
	return {"success": false, "error": "移除失败（歌单或曲目不存在）"}


func _fn_get_all_playlists(_args: Dictionary) -> Dictionary:
	var names = MusicState.get_all_playlist_names()
	return {"success": true, "data": names}


func _fn_get_playlist_tracks(args: Dictionary) -> Dictionary:
	var tracks = MusicState.get_playlist_tracks(args.get("playlist_name", ""))
	return {"success": true, "data": tracks}


func _fn_get_all_playlists_data(_args: Dictionary) -> Dictionary:
	var data = MusicState.get_all_playlists_data()
	return {"success": true, "data": data}


# ============================================================
# 函数实现 — 番茄钟（7 个）
# ============================================================

func _fn_start_pomodoro(args: Dictionary) -> Dictionary:
	var ok = PomodoroState.agent_start_pomodoro(
		int(args.get("work_minutes", 25)),
		int(args.get("rest_minutes", 5)),
		int(args.get("loop_times", 1))
	)
	if ok:
		return {"success": true}
	return {"success": false, "error": "番茄钟启动失败"}


func _fn_stop_pomodoro(_args: Dictionary) -> Dictionary:
	var ok = PomodoroState.agent_stop()
	if ok:
		return {"success": true}
	return {"success": false, "error": "番茄钟停止失败"}


func _fn_toggle_pomodoro_pause(_args: Dictionary) -> Dictionary:
	var ok = PomodoroState.agent_toggle_pause()
	if ok:
		return {"success": true, "data": {"is_paused": PomodoroState.is_paused()}}
	return {"success": false, "error": "番茄钟未运行"}


func _fn_set_work_duration(args: Dictionary) -> Dictionary:
	var ok = PomodoroState.agent_set_work_duration(int(args.get("minutes", 25)))
	if ok:
		return {"success": true}
	return {"success": false, "error": "工作时间设置失败"}


func _fn_set_rest_duration(args: Dictionary) -> Dictionary:
	var ok = PomodoroState.agent_set_rest_duration(int(args.get("minutes", 5)))
	if ok:
		return {"success": true}
	return {"success": false, "error": "休息时间设置失败"}


func _fn_get_pomodoro_status(_args: Dictionary) -> Dictionary:
	return {"success": true, "data": PomodoroState.agent_get_status()}


func _fn_get_pomodoro_remaining_time(_args: Dictionary) -> Dictionary:
	return {"success": true, "data": PomodoroState.agent_get_remaining_time()}


# ============================================================
# 函数实现 — 环境设置（2 个）
# ============================================================

func _fn_set_time(args: Dictionary) -> Dictionary:
	SettingState.set_time(int(args.get("mode", 0)))
	return {"success": true}


func _fn_set_weather(args: Dictionary) -> Dictionary:
	SettingState.set_weather(int(args.get("mode", 0)))
	return {"success": true}


# ============================================================
# 函数实现 — 对话控制（3 个）
# ============================================================

func _fn_get_input_status(_args: Dictionary) -> Dictionary:
	return {"success": true, "data": ChatState.agent_get_chat_status()}


func _fn_set_input_text(args: Dictionary) -> Dictionary:
	var ok = ChatState.agent_set_input_text(args.get("text", ""))
	return {"success": ok}


func _fn_clear_input(_args: Dictionary) -> Dictionary:
	var ok = ChatState.agent_clear_input()
	return {"success": ok}


# ============================================================
# 函数实现 — 房间装饰（2 个）
# ============================================================

func _fn_add_room_decor_item(args: Dictionary) -> Dictionary:
	var name := str(args.get("name", "")).strip_edges()
	if name.is_empty():
		return {"success": false, "error": "物品名称不能为空"}
	var category := str(args.get("category", "")).strip_edges()
	if category.is_empty():
		return {"success": false, "error": "位置分类不能为空"}

	var required_level := int(args.get("required_level", 1))
	var icon_path := str(args.get("icon_path", ""))
	var data := RoomDecorState.agent_add_room_decor_item(name, category, required_level, icon_path)
	if data.is_empty():
		return {"success": false, "error": "添加失败"}
	return {"success": true, "data": data}


func _fn_select_room_decor_item(args: Dictionary) -> Dictionary:
	var item_id := int(args.get("item_id", 0))
	var ok := RoomDecorState.agent_select_room_decor_item(item_id)
	if not ok:
		return {"success": false, "error": "选择失败（物品不存在或未解锁）"}
	return {"success": true, "data": {"item_id": item_id}}


# ============================================================
# 函数实现 — 习惯管理（9 个）
# ============================================================

func _fn_add_habit(args: Dictionary) -> Dictionary:
	var habit_name = args.get("name", "")
	if habit_name.is_empty():
		return {"success": false, "error": "习惯名称不能为空"}
	var data = HabitState.agent_add_habit(
		habit_name,
		int(args.get("estimated_minutes", 30)),
		int(args.get("preferred_period", 0)),
		int(args.get("frequency", 0)),
	)
	return {"success": true, "data": data}


func _fn_remove_habit(args: Dictionary) -> Dictionary:
	var ok = HabitState.remove_habit(int(args.get("habit_id", 0)))
	if ok:
		return {"success": true}
	return {"success": false, "error": "习惯不存在"}


func _fn_update_habit(args: Dictionary) -> Dictionary:
	var habit_id = int(args.get("habit_id", 0))
	var fields: Dictionary = {}
	if args.has("name"):
		fields["name"] = args["name"]
	if args.has("estimated_minutes"):
		fields["estimated_minutes"] = int(args["estimated_minutes"])
	if args.has("preferred_period"):
		fields["preferred_period"] = int(args["preferred_period"])
	if args.has("frequency"):
		fields["frequency"] = int(args["frequency"])
	if args.has("is_active"):
		fields["is_active"] = args["is_active"]
	var ok = HabitState.update_habit(habit_id, fields)
	if ok:
		return {"success": true}
	return {"success": false, "error": "习惯不存在"}


func _fn_get_habits(_args: Dictionary) -> Dictionary:
	var data = HabitState.agent_get_habits()
	return {"success": true, "data": data}


func _fn_get_time_slots(_args: Dictionary) -> Dictionary:
	var data = HabitState.agent_get_time_slots()
	return {"success": true, "data": data}


func _fn_generate_week_schedule(args: Dictionary) -> Dictionary:
	var week_key = args.get("week_key", "")
	if week_key.is_empty():
		return {"success": false, "error": "week_key 不能为空"}
	var entries = args.get("entries", [])
	var ok = HabitState.agent_generate_schedule(week_key, entries)
	if ok:
		return {"success": true, "data": {"week_key": week_key, "entry_count": entries.size()}}
	return {"success": false, "error": "排期生成失败"}


func _fn_get_week_schedule(args: Dictionary) -> Dictionary:
	var week_key = args.get("week_key", "")
	if week_key.is_empty():
		return {"success": false, "error": "week_key 不能为空"}
	var data = HabitState.agent_get_week_schedule(week_key)
	return {"success": true, "data": data}


func _fn_set_habit_execution(args: Dictionary) -> Dictionary:
	var ok = HabitState.agent_set_execution(
		int(args.get("entry_id", 0)),
		args.get("date_key", ""),
		int(args.get("status", 0)),
	)
	if ok:
		return {"success": true}
	return {"success": false, "error": "设置执行状态失败"}


func _fn_get_habit_stats(args: Dictionary) -> Dictionary:
	var week_key = args.get("week_key", "")
	if week_key.is_empty():
		return {"success": false, "error": "week_key 不能为空"}
	var data = HabitState.agent_get_habit_stats(week_key)
	return {"success": true, "data": data}


# ============================================================
# 辅助函数
# ============================================================

## 将本地时间 datetime 字符串解析为 UTC Unix 时间戳
## 格式: "YYYY-MM-DDTHH:MM:SS" 或 "YYYY-MM-DD HH:MM:SS"
## 返回 0 表示无截止时间或解析失败
func _parse_deadline_to_timestamp(deadline_str: String) -> int:
	if deadline_str.is_empty():
		return 0

	# 兼容 "T" 和空格分隔
	var date_time_part = deadline_str.split(".")[0].strip_edges()
	var separator = "T" if date_time_part.contains("T") else " "
	var parts = date_time_part.split(separator)
	if parts.size() != 2:
		push_warning("[AgentExecutor] deadline 格式错误: %s" % deadline_str)
		return 0

	var date_parts = parts[0].split("-")
	var time_parts = parts[1].split(":")
	if date_parts.size() != 3 or time_parts.size() < 2:
		push_warning("[AgentExecutor] deadline 格式错误: %s" % deadline_str)
		return 0

	var datetime_dict = {
		"year": date_parts[0].to_int(),
		"month": date_parts[1].to_int(),
		"day": date_parts[2].to_int(),
		"hour": time_parts[0].to_int(),
		"minute": time_parts[1].to_int(),
		"second": time_parts[2].to_int() if time_parts.size() >= 3 else 0
	}

	# get_unix_time_from_datetime_dict 将输入视为 UTC
	# 由于输入是本地时间（UTC+8），需减去时区偏移得到真正的 UTC 时间戳
	var local_as_utc = Time.get_unix_time_from_datetime_dict(datetime_dict)
	return int(local_as_utc) - TIMEZONE_OFFSET


## 从参数中解析截止时间，兼容新旧两种格式
## 优先使用 deadline（字符串），fallback 到 due_timestamp（整数）
func _resolve_due_timestamp(args: Dictionary) -> int:
	# 优先：新格式 deadline 字符串
	var deadline_str = str(args.get("deadline", ""))
	if not deadline_str.is_empty():
		return _parse_deadline_to_timestamp(deadline_str)
	# 兼容：旧格式 due_timestamp 整数
	var due_raw = args.get("due_timestamp", 0)
	return int(due_raw)
