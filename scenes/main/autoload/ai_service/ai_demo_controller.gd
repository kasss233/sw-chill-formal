extends Node

signal dialogue_visibility_requested(visible: bool)
signal demo_response_requested(text: String, append: bool)
signal demo_response_cleared

const DEMO_RESPONSE_SPEED := 0.05
const DEMO_DELAY_SCALE := 4
var DEMO_STEPS: Array[Dictionary] = [
	{
		"type": "set_time",
		"delay": 0.1,
		"record_restore": true,
		"args": {
			"mode": 0
		}
	},
	{
		"type": "set_time",
		"delay": 1,
		"record_restore": true,
		"args": {
			"mode": 1
		}
	},
	{
		"type": "set_time",
		"delay": 1,
		"record_restore": true,
		"args": {
			"mode": 2
		}
	},
	{
		"type": "set_time",
		"delay": 1,
		"record_restore": true,
		"args": {
			"mode": 3
		}
	},
	{
		"type": "set_time",
		"delay": 1,
		"record_restore": true,
		"args": {
			"mode": 2
		}
	},
]

var is_demo_running: bool = false
var is_restoring: bool = false
var current_demo_run_id: int = 0
var snapshot: Dictionary = {}
var applied_changes: Array[Dictionary] = []
var demo_steps: Array[Dictionary] = DEMO_STEPS.duplicate(true)

var _runtime_refs: Dictionary = {}
var _active_function_calls: Dictionary = {}
var _recorded_note_updates: Dictionary = {}
var _opened_modules: Dictionary = {}


func can_start_demo() -> bool:
	return not is_demo_running and not is_restoring


func can_restore_demo() -> bool:
	return not is_restoring and (is_demo_running or not snapshot.is_empty() or not applied_changes.is_empty())


func start_demo() -> bool:
	if not can_start_demo():
		print("[AIDemoController] 当前无法开始演示")
		return false

	is_demo_running = true
	current_demo_run_id += 1
	snapshot = _capture_snapshot()
	applied_changes.clear()
	_runtime_refs.clear()
	_active_function_calls.clear()
	_recorded_note_updates.clear()
	_opened_modules.clear()
	call_deferred("_run_demo_async", current_demo_run_id)
	print("[AIDemoController] 开始执行演示脚本")
	return true


func restore_demo() -> bool:
	if not can_restore_demo():
		print("[AIDemoController] 当前没有可恢复的演示状态")
		return false

	current_demo_run_id += 1
	is_demo_running = false
	is_restoring = true
	call_deferred("_run_restore_async", current_demo_run_id)
	print("[AIDemoController] 开始恢复演示前状态")
	return true


func _run_demo_async(run_id: int) -> void:
	for step in demo_steps:
		if run_id != current_demo_run_id:
			return

		print("[AIDemoController] 执行步骤: %s" % _describe_step(step))

		var delay := float(step.get("delay", 0.0)) * DEMO_DELAY_SCALE
		if delay > 0.0:
			await get_tree().create_timer(delay).timeout
			if run_id != current_demo_run_id:
				return

		var ok := await _execute_step(step, run_id)
		if not ok:
			print("[AIDemoController] 演示步骤执行失败: %s" % str(step))
			break

	if run_id == current_demo_run_id:
		is_demo_running = false
		print("[AIDemoController] 演示脚本执行完成")


func _run_restore_async(run_id: int) -> void:
	_force_finish_ui_effects()
	await _restore_modules()
	_restore_settings()
	_restore_notes()
	_restore_tasks()
	_restore_pomodoro()
	_restore_music()
	_reset_runtime_state()
	if run_id == current_demo_run_id:
		is_restoring = false
	print("[AIDemoController] 演示状态已恢复")


func _execute_step(step: Dictionary, run_id: int) -> bool:
	var step_type := str(step.get("type", ""))
	var args: Dictionary = step.get("args", {})
	var should_record := bool(step.get("record_restore", false))

	match step_type:
		"enter_dialogue_mode":
			dialogue_visibility_requested.emit(true)
			return true
		"show_response_text":
			return await _step_show_response_text(args, run_id)
		"show_function_call_start":
			return _step_show_function_call_start(args)
		"show_function_call_end":
			return _step_show_function_call_end(args)
		"show_module":
			return _step_show_module(args, should_record)
		"hide_module":
			return _step_hide_module(args)
		"set_input_text":
			return ChatState.agent_set_input_text(str(args.get("text", "")))
		"clear_input":
			return ChatState.agent_clear_input()
		"add_task":
			return _step_add_task(args, should_record)
		"complete_task":
			return _step_complete_task(args, should_record)
		"create_note":
			return _step_create_note(args, should_record)
		"write_note":
			return _step_write_note(args, should_record)
		"start_pomodoro":
			return _step_start_pomodoro(args)
		"stop_pomodoro":
			return _step_stop_pomodoro()
		"set_time":
			return _step_set_time(args)
		"set_weather":
			return _step_set_weather(args)
		"add_category":
			return _step_add_category(args, should_record)
		"toggle_note_category":
			return _step_toggle_note_category(args, should_record)
		"play_track":
			return _step_play_track(args, should_record)
		"set_play_mode":
			return _step_set_play_mode(args)
		"wait":
			return true
		_:
			print("[AIDemoController] 未知演示步骤类型: %s" % step_type)
			return false


func _describe_step(step: Dictionary) -> String:
	var step_type := str(step.get("type", ""))
	var args: Dictionary = step.get("args", {})
	match step_type:
		"show_module", "hide_module":
			return "%s(%s)" % [step_type, str(args.get("module_name", ""))]
		"show_function_call_start", "show_function_call_end":
			return "%s(%s)" % [step_type, str(args.get("name", ""))]
		"add_task":
			return "%s(%s)" % [step_type, str(args.get("title", ""))]
		"create_note":
			return "%s(%s)" % [step_type, str(args.get("title", ""))]
		"play_track":
			return "%s(%s)" % [step_type, str(args.get("track_name", ""))]
		"set_play_mode":
			var mode_names = ["顺序播放", "随机播放", "单曲循环"]
			var mode = int(args.get("mode", 0))
			return "%s(%s)" % [step_type, mode_names[mode] if mode < mode_names.size() else "未知"]
		_:
			return step_type


func _step_show_response_text(args: Dictionary, run_id: int) -> bool:
	var text := str(args.get("text", ""))
	var append := bool(args.get("append", false))
	if run_id != current_demo_run_id:
		return false
	demo_response_requested.emit(text, append)
	return true


func _step_show_function_call_start(args: Dictionary) -> bool:
	var call_id := str(args.get("call_id", "demo_call_%d" % Time.get_ticks_msec()))
	var name := str(args.get("name", "unknown_function"))
	_active_function_calls[call_id] = name
	ChatState.notify_function_call_started(call_id, name)
	return true


func _step_show_function_call_end(args: Dictionary) -> bool:
	var call_id := str(args.get("call_id", ""))
	if call_id.is_empty():
		return false
	var name := str(args.get("name", _active_function_calls.get(call_id, "")))
	var success := bool(args.get("success", true))
	_active_function_calls.erase(call_id)
	ChatState.notify_function_call_completed(call_id, name, success)
	return true


func _step_show_module(args: Dictionary, should_record: bool) -> bool:
	var module_name := str(args.get("module_name", ""))
	if module_name.is_empty():
		return false
	LayerManager.agent_show_module(module_name)
	if should_record and not _opened_modules.has(module_name):
		_opened_modules[module_name] = true
		applied_changes.append({
			"kind": "module_opened",
			"module_name": module_name
		})
	return true


func _step_hide_module(args: Dictionary) -> bool:
	var module_name := str(args.get("module_name", ""))
	if module_name.is_empty():
		return false
	LayerManager.agent_hide_module(module_name)
	return true


func _step_add_task(args: Dictionary, should_record: bool) -> bool:
	var title := str(args.get("title", "")).strip_edges()
	if title.is_empty():
		return false
	var due_timestamp := int(args.get("due_timestamp", 0))
	var task := TaskState.add_task(title, due_timestamp)
	var save_as := str(args.get("save_as", ""))
	if not save_as.is_empty():
		_runtime_refs[save_as] = task.id
	if should_record:
		applied_changes.append({
			"kind": "task_added",
			"task_id": task.id
		})
	return true


func _step_complete_task(args: Dictionary, should_record: bool) -> bool:
	var task_id := _resolve_ref_id(args, "task")
	if task_id <= 0:
		return false
	var task = TaskState.get_task_by_id(task_id)
	if task == null:
		return false
	if should_record:
		applied_changes.append({
			"kind": "task_completed",
			"task_id": task.id,
			"old_completed": task.is_completed,
			"old_due_timestamp": task.due_timestamp
		})
	return TaskState.set_task_completed(task_id, bool(args.get("completed", true)))


func _step_create_note(args: Dictionary, should_record: bool) -> bool:
	var note := NoteState.agent_create_note(
		str(args.get("title", "")),
		str(args.get("content", "")),
		str(args.get("category", ""))
	)
	if note == null:
		return false
	var save_as := str(args.get("save_as", ""))
	if not save_as.is_empty():
		_runtime_refs[save_as] = note.id
	if should_record:
		applied_changes.append({
			"kind": "note_added",
			"note_id": note.id
		})
	return true


func _step_write_note(args: Dictionary, should_record: bool) -> bool:
	var note_id := _resolve_ref_id(args, "note")
	if note_id <= 0:
		return false
	var note := NoteState.get_note_by_id(note_id)
	if note == null:
		return false
	if should_record and not _recorded_note_updates.has(note_id) and not _was_note_added_by_demo(note_id):
		_recorded_note_updates[note_id] = true
		applied_changes.append({
			"kind": "note_updated",
			"note_id": note.id,
			"old_title": note.title,
			"old_content": note.content
		})
	return NoteState.agent_write_content(note_id, str(args.get("content", "")))


func _step_start_pomodoro(args: Dictionary) -> bool:
	return PomodoroState.agent_start_pomodoro(
		int(args.get("work_min", 15)),
		int(args.get("rest_min", 5)),
		int(args.get("loops", 1))
	)


func _step_stop_pomodoro() -> bool:
	return PomodoroState.agent_stop()


func _step_set_time(args: Dictionary) -> bool:
	SettingState.set_time(int(args.get("mode", 0)))
	return true


func _step_set_weather(args: Dictionary) -> bool:
	SettingState.set_weather(int(args.get("mode", 0)))
	return true


func _step_play_track(args: Dictionary, should_record: bool) -> bool:
	var track_name := str(args.get("track_name", "")).strip_edges()
	if track_name.is_empty():
		return false
	var success = MusicState.agent_play_track(track_name)
	if should_record and success:
		applied_changes.append({
			"kind": "track_played",
			"track_name": track_name
		})
	return success


func _step_set_play_mode(args: Dictionary) -> bool:
	var mode := int(args.get("mode", 0))
	return MusicState.agent_set_play_mode(mode)


func _restore_modules() -> void:
	for i in range(applied_changes.size() - 1, -1, -1):
		var change := applied_changes[i]
		if str(change.get("kind", "")) == "module_opened":
			LayerManager.agent_hide_module(str(change.get("module_name", "")))
			await get_tree().process_frame


func _restore_settings() -> void:
	var settings: Dictionary = snapshot.get("settings", {})
	if settings.is_empty():
		return
	SettingState.set_time(int(settings.get("time_mode", SettingState.get_time_mode())))
	SettingState.set_weather(int(settings.get("weather_mode", SettingState.get_weather_mode())))


func _restore_notes() -> void:
	for i in range(applied_changes.size() - 1, -1, -1):
		var change := applied_changes[i]
		match str(change.get("kind", "")):
			"note_added":
				NoteState.remove_note(int(change.get("note_id", 0)))
			"note_updated":
				var note_id := int(change.get("note_id", 0))
				if NoteState.get_note_by_id(note_id) != null:
					NoteState.update_note(
						note_id,
						str(change.get("old_title", "")),
						str(change.get("old_content", ""))
					)
			"category_added":
				var cat := str(change.get("category", "")).strip_edges()
				if not cat.is_empty() and NoteState.has_category(cat):
					NoteState.remove_category(cat)
			"note_categories_changed":
				var note_id := int(change.get("note_id", 0))
				var old_categories: Array = change.get("old_categories", [])
				_restore_note_categories(note_id, old_categories)


func _restore_note_categories(note_id: int, old_categories: Array) -> void:
	var note := NoteState.get_note_by_id(note_id)
	if note == null:
		return
	# 用 NoteState API 恢复（先清空，再逐个添加），避免直接改数据
	NoteState.set_note_category(note_id, "")
	for cat in old_categories:
		var cat_name := str(cat).strip_edges()
		if not cat_name.is_empty():
			NoteState.toggle_note_category(note_id, cat_name)


func _step_add_category(args: Dictionary, should_record: bool) -> bool:
	var category := str(args.get("category", "")).strip_edges()
	if category.is_empty():
		return false
	var ok := NoteState.add_category(category)
	if should_record and ok:
		applied_changes.append({
			"kind": "category_added",
			"category": category
		})
	return ok


func _step_toggle_note_category(args: Dictionary, should_record: bool) -> bool:
	var note_id := _resolve_ref_id(args, "note")
	if note_id <= 0:
		return false
	var category := str(args.get("category", "")).strip_edges()
	if category.is_empty():
		return false
	var note := NoteState.get_note_by_id(note_id)
	if note == null:
		return false
	var old_categories := note.categories.duplicate()
	var ok := NoteState.toggle_note_category(note_id, category)
	if should_record and ok:
		applied_changes.append({
			"kind": "note_categories_changed",
			"note_id": note_id,
			"old_categories": old_categories
		})
	return ok


func _restore_tasks() -> void:
	for i in range(applied_changes.size() - 1, -1, -1):
		var change := applied_changes[i]
		match str(change.get("kind", "")):
			"task_added":
				TaskState.remove_task(int(change.get("task_id", 0)))
			"task_completed":
				var task_id := int(change.get("task_id", 0))
				if TaskState.get_task_by_id(task_id) != null:
					TaskState.set_task_completed(task_id, bool(change.get("old_completed", false)))
					TaskState.set_task_due_time(task_id, int(change.get("old_due_timestamp", 0)))


func _restore_pomodoro() -> void:
	var pomodoro_state: Dictionary = snapshot.get("pomodoro", {})
	if pomodoro_state.is_empty():
		return
	PomodoroState.agent_restore_snapshot(pomodoro_state)


func _restore_music() -> void:
	var music_state: Dictionary = snapshot.get("music", {})
	if music_state.is_empty():
		return
	# 恢复播放列表
	var playlist_name := str(music_state.get("current_playlist", ""))
	if not playlist_name.is_empty():
		MusicState.agent_set_playlist(playlist_name)
	# 恢复播放模式
	var play_mode := int(music_state.get("play_mode", 0))
	MusicState.agent_set_play_mode(play_mode)
	# 恢复曲目和播放状态
	var track_name := str(music_state.get("current_track", ""))
	var is_playing := bool(music_state.get("is_playing", false))
	if not track_name.is_empty():
		MusicState.set_track(track_name)
	MusicState.agent_set_playing(is_playing)


func _force_finish_ui_effects() -> void:
	for call_id in _active_function_calls.keys():
		var name := str(_active_function_calls[call_id])
		ChatState.notify_function_call_completed(str(call_id), name, false)
	_active_function_calls.clear()
	ChatState.agent_clear_input()
	ChatState.set_status(ChatState.Status.IDLE)
	demo_response_cleared.emit()
	dialogue_visibility_requested.emit(false)


func _capture_snapshot() -> Dictionary:
	return {
		"settings": {
			"time_mode": SettingState.get_time_mode(),
			"weather_mode": SettingState.get_weather_mode()
		},
		"pomodoro": PomodoroState.get_status(),
		"music": {
			"current_track": MusicState.current_track,
			"is_playing": MusicState.is_playing,
			"play_mode": MusicState.play_mode,
			"current_playlist": MusicState.current_playlist
		}
	}


func _resolve_ref_id(args: Dictionary, ref_prefix: String) -> int:
	var direct_key := "%s_id" % ref_prefix
	if args.has(direct_key):
		return int(args.get(direct_key, 0))
	var ref_key := "%s_ref" % ref_prefix
	var ref_name := str(args.get(ref_key, ""))
	if ref_name.is_empty():
		return 0
	return int(_runtime_refs.get(ref_name, 0))


func _was_note_added_by_demo(note_id: int) -> bool:
	for change in applied_changes:
		if str(change.get("kind", "")) == "note_added" and int(change.get("note_id", 0)) == note_id:
			return true
	return false


func _reset_runtime_state() -> void:
	is_demo_running = false
	is_restoring = false
	snapshot.clear()
	applied_changes.clear()
	_runtime_refs.clear()
	_active_function_calls.clear()
	_recorded_note_updates.clear()
	_opened_modules.clear()
