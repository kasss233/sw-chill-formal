extends Node

## 聊天状态单例
## 管理聊天会话的运行时状态；「AI 对话后端模式」持久化至 user://chat_backend_prefs.cfg

## 后端对话路径（与 chill-backend 路由一致）
const CHAT_PATH_PERFORMANCE := "/chat"
const CHAT_PATH_QUALITY := "/agent/chat"

## 性能 = 直连 LLM（/chat）；质量 = Agent 编排（/agent/chat）
enum ChatBackendMode {
	PERFORMANCE = 0,
	QUALITY = 1,
}

const _CHAT_BACKEND_PREFS_PATH := "user://chat_backend_prefs.cfg"

## 聊天状态枚举
enum Status {IDLE, GENERATING, EXECUTING_FUNCTION, ERROR}

## AI 对话后端模式变更（性能=0，质量=1，与 ChatBackendMode 枚举值一致）
signal chat_backend_mode_changed(mode: int)

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
## 工具结果已回传，即将开始同一用户消息下的「下一轮」模型输出（网关多轮）；UI 应清空当前流式气泡正文，避免与上一轮拼接
signal assistant_followup_segment_started()
## 响应错误
signal response_error(message: String)

# ============ 函数调用信号（为 DialogueBox 扩展预留）============
## 函数调用开始
signal function_call_started(call_id: String, name: String)
## 函数调用完成
signal function_call_completed(call_id: String, name: String, success: bool)

## Agent SSE：环境/演出载荷（供 3D 或其它模块监听）
signal agent_environment_received(payload: Dictionary)
signal agent_action_received(payload: Dictionary)

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
## 语音对话 HTTP 完成（与 /api/v1/sound-to-text/messages 对应，body 为完整 SSE 文本）
signal talk_voice_chat_http_completed(result: int, response_code: int, body: PackedByteArray)
## 语音对话 HTTP 发起失败（配置缺失或 request() 返回错误）
signal talk_voice_chat_http_failed(message: String)
## 后端 speech_transcript 事件（识别出的用户话术，便于 UI 展示）
signal speech_transcript_received(text: String)

# ============ 状态 ============
var status: Status = Status.IDLE
var current_response_text: String = ""

## 当前对话后端模式（默认质量 / Agent）
var _chat_backend_mode: ChatBackendMode = ChatBackendMode.QUALITY

const _TALK_RECORD_BUS := "TalkRecord"

## 后端根 URL（与 [AuthState] 中「服务器地址」一致，可为 `https://host` 或已含 `/api/v1`）
var voice_chat_api_base_url: String = ""
## Bearer Token，与文本聊天一致
var voice_chat_access_token: String = ""
## 当前会话 ID，与 POST chat 一致；空则由后端新建会话
var voice_chat_session_id: String = ""
## 转写后转发目标："" 使用服务端默认配置；"openai" | "agent" 覆盖
var voice_chat_target: String = ""
## 与 SendMessageRequest.context 一致的可 JSON 序列化字典，可为空
var voice_chat_context: Dictionary = {}

var _talk_record_effect: AudioEffectRecord
var _talk_mic_player: AudioStreamPlayer
var _talk_preview_player: AudioStreamPlayer
var _is_talk_recording := false
var _last_talk_audio_payload: Dictionary = {}

var _voice_chat_http: HTTPRequest
var _voice_chat_in_flight: bool = false

## 语音合成播放（后端 tts_audio）；与录音预览共用 Master 总线
var _tts_output_player: AudioStreamPlayer
var _tts_pending_queue: Array[Dictionary] = []
var _tts_collect: Array[Dictionary] = []

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
	# 习惯/个人中心
	"add_habit": "profile_center", "remove_habit": "profile_center",
	"update_habit": "profile_center", "get_habits": "profile_center",
	"get_time_slots": "profile_center", "generate_week_schedule": "profile_center",
	"get_week_schedule": "profile_center", "set_habit_execution": "profile_center",
	"get_habit_stats": "profile_center",
}

# ============ 状态管理 API（供 ChatController 调用）============

func _init() -> void:
	_load_chat_backend_prefs_from_disk()


func _ready() -> void:
	_setup_talk_recording()
	_setup_voice_chat_http()
	call_deferred("sync_voice_credentials_from_auth")


func _load_chat_backend_prefs_from_disk() -> void:
	var config := ConfigFile.new()
	if config.load(_CHAT_BACKEND_PREFS_PATH) != OK:
		return
	var v = config.get_value("chat", "backend_mode", ChatBackendMode.QUALITY)
	if v is int:
		if v == ChatBackendMode.PERFORMANCE:
			_chat_backend_mode = ChatBackendMode.PERFORMANCE
		elif v == ChatBackendMode.QUALITY:
			_chat_backend_mode = ChatBackendMode.QUALITY


func _save_chat_backend_prefs_to_disk() -> void:
	var config := ConfigFile.new()
	config.set_value("chat", "backend_mode", _chat_backend_mode as int)
	config.save(_CHAT_BACKEND_PREFS_PATH)


func get_chat_backend_mode() -> ChatBackendMode:
	return _chat_backend_mode


## 供 CustomAPIAdapter：性能为 /chat，质量为 /agent/chat
func get_chat_path_prefix() -> String:
	return CHAT_PATH_QUALITY if _chat_backend_mode == ChatBackendMode.QUALITY else CHAT_PATH_PERFORMANCE


func set_chat_backend_mode(mode: ChatBackendMode) -> void:
	if mode == _chat_backend_mode:
		return
	_chat_backend_mode = mode
	_save_chat_backend_prefs_to_disk()
	chat_backend_mode_changed.emit(mode as int)


func set_chat_backend_mode_from_path(path: String) -> void:
	match path:
		CHAT_PATH_PERFORMANCE:
			set_chat_backend_mode(ChatBackendMode.PERFORMANCE)
		CHAT_PATH_QUALITY:
			set_chat_backend_mode(ChatBackendMode.QUALITY)
		_:
			pass


## 与 AuthState 对齐：语音 STT 与文本聊天共用同一服务地址与 Token
func sync_voice_credentials_from_auth() -> void:
	if not is_instance_valid(AuthState):
		return
	voice_chat_api_base_url = AuthState.get_base_url().rstrip("/")
	voice_chat_access_token = AuthState.get_access_token()


## POST `/api/v1/sound-to-text/messages` 的完整 URL（若 base 已以 `/api/v1` 结尾则不再重复前缀）
func get_voice_chat_post_url() -> String:
	var base := voice_chat_api_base_url.rstrip("/")
	if base.is_empty():
		return ""
	if base.ends_with("/api/v1"):
		return base + "/sound-to-text/messages"
	return base + "/api/v1/sound-to-text/messages"


## 与「性能/质量」对话模式对齐：质量→agent（TTS/编排），性能→openai
func _default_voice_chat_target_for_backend_mode() -> String:
	if _chat_backend_mode == ChatBackendMode.QUALITY:
		return "agent"
	if _chat_backend_mode == ChatBackendMode.PERFORMANCE:
		return "openai"
	return ""


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


func _setup_voice_chat_http() -> void:
	_voice_chat_http = HTTPRequest.new()
	_voice_chat_http.timeout = 120.0
	_voice_chat_http.request_completed.connect(_on_voice_chat_http_completed)
	add_child(_voice_chat_http)

	_tts_output_player = AudioStreamPlayer.new()
	_tts_output_player.bus = "Master"
	_tts_output_player.finished.connect(_on_tts_output_player_finished)
	add_child(_tts_output_player)


func _on_voice_chat_http_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	_voice_chat_in_flight = false

	if result != HTTPRequest.RESULT_SUCCESS:
		fail_response("语音对话网络错误: %d" % result)
	elif response_code < 200 or response_code >= 300:
		var hint := body.get_string_from_utf8()
		fail_response("语音对话 HTTP %d: %s" % [response_code, hint.left(400)])
	else:
		_parse_and_apply_voice_chat_sse(body.get_string_from_utf8())

	talk_voice_chat_http_completed.emit(result, response_code, body)


## 解析 ChillBackend SSE（含 speech_transcript、tts_audio，与 /api/v1/agent/chat 一致）
func _parse_and_apply_voice_chat_sse(raw: String) -> void:
	_tts_collect.clear()
	_tts_pending_queue.clear()
	if _tts_output_player != null and _tts_output_player.playing:
		_tts_output_player.stop()

	var had_error := false
	var saw_done := false
	var saw_response_start := false

	for block in raw.split("\n\n"):
		var b := block.strip_edges()
		if b.is_empty() or b.begins_with(":"):
			continue
		var ev := ""
		var data_str := ""
		for line in b.split("\n"):
			if line.begins_with("event:"):
				ev = line.substr(6).strip_edges()
			elif line.begins_with("data:"):
				# 只取首行 data（与当前后端一致）
				if data_str.is_empty():
					data_str = line.substr(5).strip_edges()
		if ev.is_empty() or data_str.is_empty():
			continue

		var j: Variant = JSON.parse_string(data_str)
		if typeof(j) != TYPE_DICTIONARY:
			continue
		var d: Dictionary = j

		match ev:
			"speech_transcript":
				var st: String = str(d.get("text", ""))
				if not st.is_empty():
					speech_transcript_received.emit(st)
					input_text_requested.emit(st)
			"session_start":
				var sid: String = str(d.get("session_id", ""))
				if not sid.is_empty():
					voice_chat_session_id = sid
				if not saw_response_start:
					saw_response_start = true
					start_response()
			"text_delta":
				if not saw_response_start:
					saw_response_start = true
					start_response()
				var part: String = str(d.get("content", ""))
				if not part.is_empty():
					append_response_text(part)
			"text_done":
				var full_td: String = str(d.get("content", ""))
				if not full_td.is_empty():
					set_response_text(full_td)
			"function_call":
				var fc_id: String = str(d.get("id", ""))
				if fc_id.is_empty():
					fc_id = "fc_%d" % Time.get_ticks_msec()
				var fname: String = str(d.get("name", ""))
				notify_function_call_started(fc_id, fname)
			"tts_audio":
				var b64: String = str(d.get("audio_base64", ""))
				var mime: String = str(d.get("mime_type", "audio/wav"))
				var seg_idx: int = int(d.get("segment_index", 0))
				if b64.is_empty():
					continue
				var audio_bytes: PackedByteArray = Marshalls.base64_to_raw(b64)
				if audio_bytes.is_empty():
					continue
				_tts_collect.append({"segment_index": seg_idx, "bytes": audio_bytes, "mime": mime})
			"error":
				had_error = true
				_stop_and_clear_tts_voice()
				var code: int = int(d.get("code", 0))
				var msg: String = str(d.get("message", "未知错误"))
				fail_response("[%d] %s" % [code, msg])
			"done":
				saw_done = true
				var dsid: String = str(d.get("session_id", ""))
				if not dsid.is_empty():
					voice_chat_session_id = dsid
				if not had_error:
					complete_response(current_response_text)
					_queue_tts_from_collect()
				else:
					_stop_and_clear_tts_voice()

	if had_error:
		return
	if saw_response_start and not saw_done:
		complete_response(current_response_text)
		_queue_tts_from_collect()
	elif not saw_response_start and not _tts_collect.is_empty():
		_queue_tts_from_collect()


func _stop_and_clear_tts_voice() -> void:
	_tts_collect.clear()
	_tts_pending_queue.clear()
	if _tts_output_player != null and _tts_output_player.playing:
		_tts_output_player.stop()


func _queue_tts_from_collect() -> void:
	if _tts_collect.is_empty():
		return
	_tts_collect.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("segment_index", 0)) < int(b.get("segment_index", 0))
	)
	_tts_pending_queue.clear()
	for item in _tts_collect:
		_tts_pending_queue.append(item)
	_tts_collect.clear()
	if _tts_output_player != null and not _tts_output_player.playing:
		_play_next_tts_chunk()


func _play_next_tts_chunk() -> void:
	if _tts_output_player == null:
		return
	if _tts_pending_queue.is_empty():
		return
	var item: Dictionary = _tts_pending_queue.pop_front()
	var raw: PackedByteArray = item.get("bytes", PackedByteArray())
	var mime: String = str(item.get("mime", "audio/wav"))
	if raw.is_empty():
		call_deferred("_play_next_tts_chunk")
		return
	var err: int = _load_stream_and_play_tts(raw, mime)
	if err != OK:
		push_warning("[ChatState] TTS 片段解码失败: %d" % err)
		call_deferred("_play_next_tts_chunk")


func _load_stream_and_play_tts(raw: PackedByteArray, mime: String) -> int:
	var mlow := mime.to_lower()
	if mlow.contains("mpeg") or mlow.contains("mp3"):
		var mp3 := AudioStreamMP3.new()
		mp3.data = raw
		_tts_output_player.stream = mp3
		_tts_output_player.play()
		return OK
	var path := "user://_chatstate_tts_%d.wav" % Time.get_ticks_msec()
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return ERR_CANT_CREATE
	f.store_buffer(raw)
	f.close()
	var loaded: Variant = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
	if loaded == null or not (loaded is AudioStream):
		return ERR_INVALID_DATA
	_tts_output_player.stream = loaded as AudioStream
	_tts_output_player.play()
	return OK


func _on_tts_output_player_finished() -> void:
	_play_next_tts_chunk()


func set_status(new_status: Status) -> void:
	if status != new_status:
		var old_name = Status.keys()[status]
		var new_name = Status.keys()[new_status]
		print("[ChatState] 状态变更: %s -> %s" % [old_name, new_name])
		status = new_status
	# 始终广播，便于 InputBox 等与状态同步：Agent 多轮/重复 start_response 时可能仍为 GENERATING，
	# 若此处不 emit，提交钮不会切到「停止」态。
	chat_status_changed.emit(status)


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

	var stt_result := request_talk_stt(payload)
	return {
		"ok": true,
		"stt_sent": stt_result.get("ok", false),
		"error": stt_result.get("error", ""),
		"bytes": byte_size
	}


func request_talk_stt(payload: Dictionary) -> Dictionary:
	# POST …/api/v1/sound-to-text/messages，响应为 text/event-stream（整包缓冲完成后回调）。
	sync_voice_credentials_from_auth()
	var url := get_voice_chat_post_url()
	if url.is_empty() or voice_chat_access_token.is_empty():
		var skip := "语音对话未配置：请在设置中填写后端地址并登录（与文本聊天相同）"
		print("[ChatState] " + skip)
		talk_voice_chat_http_failed.emit(skip)
		return {"ok": false, "error": skip}
	var b64 := Marshalls.raw_to_base64(payload.get("audio_bytes", PackedByteArray()))
	var body: Dictionary = {
		"audio_base64": b64,
		"mime_type": payload.get("mime_type", "audio/wav"),
		"stream": true,
	}
	var fn: Variant = payload.get("file_name", "")
	if typeof(fn) == TYPE_STRING and str(fn) != "":
		body["file_name"] = str(fn)
	if voice_chat_session_id != "":
		body["session_id"] = voice_chat_session_id
	var ct := voice_chat_target.strip_edges()
	if ct.is_empty():
		ct = _default_voice_chat_target_for_backend_mode()
	if not ct.is_empty():
		body["chat_target"] = ct
	if not voice_chat_context.is_empty():
		body["context"] = voice_chat_context

	var json_str := JSON.stringify(body)
	if json_str.is_empty():
		var err_build := "构建语音对话 JSON 失败"
		talk_voice_chat_http_failed.emit(err_build)
		return {"ok": false, "error": err_build}

	var headers: PackedStringArray = [
		"Authorization: Bearer " + voice_chat_access_token,
		"Content-Type: application/json",
		"Accept: text/event-stream",
	]
	if _voice_chat_in_flight:
		var busy := "语音对话请求进行中，请稍后再试"
		talk_voice_chat_http_failed.emit(busy)
		return {"ok": false, "error": busy}

	var err: int = _voice_chat_http.request(url, headers, HTTPClient.METHOD_POST, json_str)
	if err != OK:
		var msg := "语音对话 HTTP 发起失败: %d" % err
		print("[ChatState] " + msg)
		talk_voice_chat_http_failed.emit(msg)
		return {"ok": false, "error": msg}

	_voice_chat_in_flight = true
	var audio_len := int(payload.get("audio_bytes", PackedByteArray()).size())
	print("[ChatState] 已请求语音对话: %s (audio ~%d bytes, chat_target=%s)" % [
		url, audio_len, str(body.get("chat_target", ""))
	])
	return {"ok": true, "error": ""}


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
	var block_align: int = int(round(float(channels * bits_per_sample) / 8.0))
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


## 网关多轮：function-results 成功后、下一轮模型 SSE 到达前调用，避免续轮 text_delta 拼在上一轮正文后
func begin_followup_assistant_segment() -> void:
	print("[ChatState] begin_followup_assistant_segment()")
	current_response_text = ""
	assistant_followup_segment_started.emit()


func notify_function_call_started(call_id: String, fname: String) -> void:
	print("[ChatState] function_call_started: %s (call_id: %s)" % [fname, call_id])
	set_status(Status.EXECUTING_FUNCTION)
	function_call_started.emit(call_id, fname)
	var module_key: String = _FUNC_MODULE_MAP.get(fname, "")
	if not module_key.is_empty():
		ai_glow_started.emit(module_key)


func notify_agent_environment(payload: Dictionary) -> void:
	if payload.is_empty():
		return
	print("[ChatState] agent_environment: %s" % payload)
	agent_environment_received.emit(payload)


func notify_agent_action(payload: Dictionary) -> void:
	if payload.is_empty():
		return
	print("[ChatState] agent_action: %s" % payload)
	agent_action_received.emit(payload)


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
