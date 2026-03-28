extends Node

## 聊天状态单例
## 纯内存状态（不持久化），管理聊天会话的运行时状态

## 聊天状态枚举
enum Status {IDLE, GENERATING, EXECUTING_FUNCTION, ERROR}

# ============ 状态变化信号 ============
## 聊天状态变化（IDLE/GENERATING/EXECUTING_FUNCTION/ERROR）
signal chat_status_changed(new_status: Status)

# ============ 响应内容信号 ============
## 新响应开始（UI 应清空并显示对话框）
signal response_started()
## 响应文本增量（流式追加）
signal response_text_delta(delta: String)
## 响应文本整体替换
signal response_text_set(text: String)
## 响应完成
signal response_completed(full_text: String)
## 响应内容清空
signal response_cleared()
## 响应错误
signal response_error(message: String)

# ============ 函数调用信号（为 DialogueBox 扩展预留）============
## 函数调用开始
signal function_call_started(call_id: String, name: String)
## 函数调用完成
signal function_call_completed(call_id: String, name: String, success: bool)

## AI 流光开始（模块级）
signal ai_glow_started(module_key: String)
## AI 流光结束（模块级）
signal ai_glow_stopped(module_key: String)

# ============ 用户输入信号（InputBox -> ChatController）============
## 用户提交文本（由 InputBox 发出，ChatController 监听）
signal text_submitted(text: String, attachments: Array)
## 用户请求停止生成（由 InputBox 发出，ChatController 监听）
signal generation_stop_requested()

# ============ 输入控制信号（Agent -> InputBox）============
## 请求设置输入框文本
signal input_text_requested(text: String)
## 请求清空输入框
signal input_clear_requested()

# ============ 语音录音信号（InputBox TalkButton -> ChatState）============
## 按住说话开始录音
signal talk_recording_started()
## 按住说话结束录音并生成内存音频
signal talk_recording_ready(byte_size: int)
## 录音失败
signal talk_recording_failed(message: String)
## 请求上传语音到 STT 后端（后端接入方监听）
signal talk_stt_upload_requested(payload: Dictionary)

# ============ 状态 ============
var status: Status = Status.IDLE
var current_response_text: String = ""

const _TALK_RECORD_BUS := "TalkRecord"

var _talk_record_effect: AudioEffectRecord
var _talk_mic_player: AudioStreamPlayer
var _talk_preview_player: AudioStreamPlayer
var _is_talk_recording := false
var _last_talk_audio_payload: Dictionary = {}

# 函数名 → 模块 key 映射（用于流光定位）
const _FUNC_MODULE_MAP: Dictionary = {
	# 任务
	"add_task": "task", "remove_task": "task", "update_task_title": "task",
	"set_task_completed": "task", "set_task_due_time": "task",
	"clear_completed_tasks": "task", "get_all_tasks": "task",
	"get_incomplete_tasks": "task", "get_completed_tasks": "task",
	"get_overdue_tasks": "task", "reorder_task": "task",
	# 笔记
	"create_note": "notebook", "write_note_content": "notebook",
	"open_note": "notebook", "close_note": "notebook",
	"remove_note": "notebook", "update_note": "notebook",
	"search_notes": "notebook", "get_all_notes": "notebook",
	"take_note": "notebook", "get_note_by_id": "notebook",
	"add_category": "notebook", "remove_category": "notebook",
	"toggle_note_category": "notebook", "get_categories": "notebook",
	# 音乐
	"play_music": "music", "pause_music": "music",
	"toggle_playback": "music", "play_next": "music",
	"play_previous": "music", "set_play_mode": "music",
	"set_bgm_volume": "music", "get_music_state": "music",
	"switch_playlist": "music", "create_playlist": "music",
	"delete_playlist": "music", "add_track_to_playlist": "music",
	"remove_track_from_playlist": "music", "get_all_playlists": "music",
	"get_playlist_tracks": "music", "get_all_playlists_data": "music",
	# 番茄钟
	"start_pomodoro": "pomodoro", "stop_pomodoro": "pomodoro",
	"toggle_pomodoro_pause": "pomodoro", "set_work_duration": "pomodoro",
	"set_rest_duration": "pomodoro", "get_pomodoro_status": "pomodoro",
	"get_pomodoro_remaining_time": "pomodoro",
	# 环境设置
	"set_time": "setting", "set_weather": "setting",
	# 房间装饰
	"add_room_decor_item": "room_decor", "select_room_decor_item": "room_decor",
	# 习惯/日历
	"add_habit": "calendar", "remove_habit": "calendar",
	"update_habit": "calendar", "get_habits": "calendar",
	"get_time_slots": "calendar", "generate_week_schedule": "calendar",
	"get_week_schedule": "calendar", "set_habit_execution": "calendar",
	"get_habit_stats": "calendar",
}

# ============ 状态管理 API（供 ChatController 调用）============

func _ready() -> void:
	_setup_talk_recording()


func _setup_talk_recording() -> void:
	if not ProjectSettings.get_setting("audio/driver/enable_input", false):
		var msg := "未开启音频输入，请在项目设置中启用后重启"
		print("[ChatState] " + msg)
		talk_recording_failed.emit(msg)
		return

	var bus_idx := AudioServer.get_bus_index(_TALK_RECORD_BUS)
	if bus_idx == -1:
		AudioServer.add_bus(AudioServer.get_bus_count())
		bus_idx = AudioServer.get_bus_count() - 1
		AudioServer.set_bus_name(bus_idx, _TALK_RECORD_BUS)

	if AudioServer.get_bus_effect_count(bus_idx) == 0:
		AudioServer.add_bus_effect(bus_idx, AudioEffectRecord.new(), 0)
	elif not (AudioServer.get_bus_effect(bus_idx, 0) is AudioEffectRecord):
		AudioServer.remove_bus_effect(bus_idx, 0)
		AudioServer.add_bus_effect(bus_idx, AudioEffectRecord.new(), 0)

	_talk_record_effect = AudioServer.get_bus_effect(bus_idx, 0) as AudioEffectRecord
	if _talk_record_effect != null:
		_talk_record_effect.format = AudioStreamWAV.FORMAT_16_BITS

	_talk_mic_player = AudioStreamPlayer.new()
	_talk_mic_player.stream = AudioStreamMicrophone.new()
	_talk_mic_player.bus = _TALK_RECORD_BUS
	add_child(_talk_mic_player)

	_talk_preview_player = AudioStreamPlayer.new()
	_talk_preview_player.bus = "Master"
	add_child(_talk_preview_player)

func set_status(new_status: Status) -> void:
	if status != new_status:
		var old_name = Status.keys()[status]
		var new_name = Status.keys()[new_status]
		print("[ChatState] 状态变更: %s -> %s" % [old_name, new_name])
		status = new_status
		chat_status_changed.emit(new_status)


func start_talk_recording() -> int:
	if _talk_record_effect == null or _talk_mic_player == null:
		var msg := "录音器未初始化"
		print("[ChatState] " + msg)
		talk_recording_failed.emit(msg)
		return ERR_UNCONFIGURED

	_apply_audio_devices_from_setting()

	if _is_talk_recording:
		return OK

	_talk_record_effect.set_recording_active(true)
	_talk_mic_player.play()
	_is_talk_recording = true
	print("[ChatState] start_talk_recording()")
	talk_recording_started.emit()
	return OK


func stop_talk_recording() -> Dictionary:
	if not _is_talk_recording:
		return {"ok": false, "error": "当前未在录音"}

	_talk_mic_player.stop()
	_talk_record_effect.set_recording_active(false)
	_is_talk_recording = false

	var wav_stream := _talk_record_effect.get_recording() as AudioStreamWAV
	if wav_stream == null or wav_stream.data.is_empty():
		var empty_msg := "录音数据为空"
		print("[ChatState] " + empty_msg)
		talk_recording_failed.emit(empty_msg)
		return {"ok": false, "error": empty_msg}

	var payload := _build_talk_stt_payload(wav_stream)
	if payload.is_empty():
		var build_msg := "构建音频上传载荷失败"
		print("[ChatState] " + build_msg)
		talk_recording_failed.emit(build_msg)
		return {"ok": false, "error": build_msg}

	_last_talk_audio_payload = payload
	var byte_size: int = payload.get("audio_bytes", PackedByteArray()).size()
	print("[ChatState] 录音已就绪，字节数=%d" % byte_size)
	talk_recording_ready.emit(byte_size)
	talk_stt_upload_requested.emit(payload)

	if _should_preview_talk_recording() and _talk_preview_player != null:
		_talk_preview_player.stop()
		_talk_preview_player.stream = wav_stream
		_talk_preview_player.play()

	# 预留后端接口：当前仅返回未实现状态。
	var stt_result := request_talk_stt(payload)
	return {
		"ok": true,
		"stt_sent": stt_result.get("ok", false),
		"error": stt_result.get("error", ""),
		"bytes": byte_size
	}


func request_talk_stt(_payload: Dictionary) -> Dictionary:
	return {
		"ok": false,
		"error": "STT 后端接口未实现"
	}


func get_last_talk_audio_payload() -> Dictionary:
	return _last_talk_audio_payload.duplicate(true)


func _build_talk_stt_payload(wav_stream: AudioStreamWAV) -> Dictionary:
	if wav_stream.format != AudioStreamWAV.FORMAT_16_BITS:
		return {}

	var channels := 2 if wav_stream.stereo else 1
	var sample_rate := maxi(1, wav_stream.mix_rate)
	var bits_per_sample := 16
	var pcm_data: PackedByteArray = wav_stream.data
	var wav_bytes := _build_wav_bytes(pcm_data, sample_rate, channels, bits_per_sample)

	return {
		"mime_type": "audio/wav",
		"file_name": "talk_%s.wav" % Time.get_datetime_string_from_system().replace(":", "-").replace(" ", "_"),
		"sample_rate": sample_rate,
		"channels": channels,
		"bits_per_sample": bits_per_sample,
		"audio_bytes": wav_bytes
	}


func _build_wav_bytes(pcm_data: PackedByteArray, sample_rate: int, channels: int, bits_per_sample: int) -> PackedByteArray:
	var data_size := pcm_data.size()
	var block_align := channels * bits_per_sample / 8
	var byte_rate := sample_rate * block_align
	var riff_size := 36 + data_size

	var bytes := PackedByteArray()
	bytes.append_array("RIFF".to_ascii_buffer())
	_append_u32_le(bytes, riff_size)
	bytes.append_array("WAVE".to_ascii_buffer())
	bytes.append_array("fmt ".to_ascii_buffer())
	_append_u32_le(bytes, 16)
	_append_u16_le(bytes, 1)
	_append_u16_le(bytes, channels)
	_append_u32_le(bytes, sample_rate)
	_append_u32_le(bytes, byte_rate)
	_append_u16_le(bytes, block_align)
	_append_u16_le(bytes, bits_per_sample)
	bytes.append_array("data".to_ascii_buffer())
	_append_u32_le(bytes, data_size)
	bytes.append_array(pcm_data)
	return bytes


func _append_u16_le(bytes: PackedByteArray, value: int) -> void:
	bytes.append(value & 0xFF)
	bytes.append((value >> 8) & 0xFF)


func _append_u32_le(bytes: PackedByteArray, value: int) -> void:
	bytes.append(value & 0xFF)
	bytes.append((value >> 8) & 0xFF)
	bytes.append((value >> 16) & 0xFF)
	bytes.append((value >> 24) & 0xFF)


func _apply_audio_devices_from_setting() -> void:
	if not is_instance_valid(SettingState):
		return

	var input_name := SettingState.get_audio_input_device()
	if input_name != "" and AudioServer.get_input_device_list().has(input_name):
		AudioServer.set_input_device(input_name)

	var output_name := SettingState.get_audio_output_device()
	if output_name != "" and AudioServer.get_output_device_list().has(output_name):
		AudioServer.set_output_device(output_name)


func _should_preview_talk_recording() -> bool:
	if not is_instance_valid(SettingState):
		return false
	return SettingState.get_talk_record_preview_enabled()


func start_response() -> void:
	print("[ChatState] start_response()")
	current_response_text = ""
	set_status(Status.GENERATING)
	response_started.emit()


func append_response_text(delta: String) -> void:
	current_response_text += delta
	response_text_delta.emit(delta)


func set_response_text(text: String) -> void:
	print("[ChatState] set_response_text() len=%d" % text.length())
	current_response_text = text
	response_text_set.emit(text)


func complete_response(full_text: String) -> void:
	print("[ChatState] complete_response() len=%d" % full_text.length())
	current_response_text = full_text
	set_status(Status.IDLE)
	response_completed.emit(full_text)


func fail_response(error: String) -> void:
	print("[ChatState] fail_response(): %s" % error)
	set_status(Status.ERROR)
	response_error.emit(error)


func clear_response() -> void:
	print("[ChatState] clear_response()")
	current_response_text = ""
	response_cleared.emit()


func notify_function_call_started(call_id: String, fname: String) -> void:
	print("[ChatState] function_call_started: %s (call_id: %s)" % [fname, call_id])
	set_status(Status.EXECUTING_FUNCTION)
	function_call_started.emit(call_id, fname)
	var module_key: String = _FUNC_MODULE_MAP.get(fname, "")
	if not module_key.is_empty():
		ai_glow_started.emit(module_key)


func notify_function_call_completed(call_id: String, fname: String, success: bool) -> void:
	print("[ChatState] function_call_completed: %s success=%s" % [fname, success])
	set_status(Status.GENERATING)
	function_call_completed.emit(call_id, fname, success)
	var module_key: String = _FUNC_MODULE_MAP.get(fname, "")
	if not module_key.is_empty():
		ai_glow_stopped.emit(module_key)

# ============ Agent API（供 AgentExecutor 调用）============

func agent_get_chat_status() -> Dictionary:
	print("[ChatState] agent_get_chat_status() -> %s" % Status.keys()[status])
	return {
		"status": Status.keys()[status],
		"is_generating": status == Status.GENERATING,
		"is_idle": status == Status.IDLE,
		"current_response_length": current_response_text.length()
	}


func agent_set_input_text(text: String) -> bool:
	print("[ChatState] agent_set_input_text(): '%s'" % text)
	input_text_requested.emit(text)
	return true


func agent_clear_input() -> bool:
	print("[ChatState] agent_clear_input()")
	input_clear_requested.emit()
	return true

# ============ 用户输入 API（供 InputBox 调用）============

func submit_text(text: String, attachments: Array) -> void:
	print("[ChatState] submit_text(): '%s' attachments=%d" % [text.left(20), attachments.size()])
	text_submitted.emit(text, attachments)


func request_stop_generation() -> void:
	print("[ChatState] request_stop_generation()")
	generation_stop_requested.emit()
