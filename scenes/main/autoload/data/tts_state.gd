extends Node

## TTSState — TTS 用户偏好与策略的单一数据源（Autoload）
## - 持久化到 `user://tts_state.json`
## - UI / Agent 只通过本类公开 API 修改；`TTSPlayer` / `ChatController` 读取此处配置
## - 与 `ChatState` 分工：`ChatState` 管对话流与录音；本类只管「是否播 TTS、怎么播」

const SAVE_PATH := "user://tts_state.json"
const CURRENT_VERSION := 1

const VOLUME_MIN := 0.0
const VOLUME_MAX := 1.0
const SPEECH_RATE_MIN := 0.5
const SPEECH_RATE_MAX := 2.0

# ============ 信号 ============
## 首次加载磁盘配置后发出（无论是否使用默认值）
signal data_loaded
## 任一字段变化时发出，便于一次性刷新设置页
signal tts_state_changed(data: Dictionary)
signal tts_enabled_changed(enabled: bool)
signal volume_changed(volume: float)
## 后端语音 ID（空字符串表示服务端默认）
signal voice_id_changed(voice_id: String)
## 语速倍率，供后端或未来本地引擎使用
signal speech_rate_changed(rate: float)
## `AudioStreamPlayer.bus`，须为已存在的 AudioBus 名
signal audio_bus_changed(bus_name: String)
## 是否与 `TTSPlayer.queue_enabled` 同步
signal queue_enabled_changed(enabled: bool)
## 新一段 TTS 到达时是否先停止当前播放与队列
signal interrupt_on_new_reply_changed(enabled: bool)

# ============ 内部状态 ============
var _tts_enabled: bool = true
var _volume: float = 1.0
var _voice_id: String = ""
var _speech_rate: float = 1.0
var _audio_bus: String = "Master"
var _queue_enabled: bool = true
var _interrupt_on_new_reply: bool = false

var _save_timer: SceneTreeTimer
const SAVE_DEBOUNCE_SEC := 0.25


func _ready() -> void:
	_load()
	data_loaded.emit()
	_emit_snapshot()


func _queue_save() -> void:
	if _save_timer and _save_timer.time_left > 0.0:
		return
	_save_timer = get_tree().create_timer(SAVE_DEBOUNCE_SEC)
	_save_timer.timeout.connect(_save, CONNECT_ONE_SHOT)


func _save() -> void:
	var data := {
		"version": CURRENT_VERSION,
		"tts_enabled": _tts_enabled,
		"volume": _volume,
		"voice_id": _voice_id,
		"speech_rate": _speech_rate,
		"audio_bus": _audio_bus,
		"queue_enabled": _queue_enabled,
		"interrupt_on_new_reply": _interrupt_on_new_reply,
	}
	var json_string := JSON.stringify(data, "\t")
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(json_string)
		file.close()
	else:
		push_error("[TTSState] 保存失败: %s" % SAVE_PATH)


func _load() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		push_error("[TTSState] 读取失败")
		return
	var json_string := file.get_as_text()
	file.close()
	var json := JSON.new()
	if json.parse(json_string) != OK:
		push_error("[TTSState] JSON 解析失败")
		return
	var raw = json.get_data()
	if not raw is Dictionary:
		return
	var d: Dictionary = raw
	_tts_enabled = bool(d.get("tts_enabled", true))
	_volume = clampf(float(d.get("volume", 1.0)), VOLUME_MIN, VOLUME_MAX)
	_voice_id = str(d.get("voice_id", ""))
	_speech_rate = clampf(float(d.get("speech_rate", 1.0)), SPEECH_RATE_MIN, SPEECH_RATE_MAX)
	_audio_bus = str(d.get("audio_bus", "Master"))
	_queue_enabled = bool(d.get("queue_enabled", true))
	_interrupt_on_new_reply = bool(d.get("interrupt_on_new_reply", false))


func _emit_snapshot() -> void:
	tts_state_changed.emit(get_snapshot())


# ============ 查询 API ============
func is_tts_enabled() -> bool:
	return _tts_enabled


func get_volume() -> float:
	return _volume


func get_voice_id() -> String:
	return _voice_id


func get_speech_rate() -> float:
	return _speech_rate


func get_audio_bus() -> String:
	return _audio_bus


func is_queue_enabled() -> bool:
	return _queue_enabled


func get_interrupt_on_new_reply() -> bool:
	return _interrupt_on_new_reply


## 供设置页或调试：一次性取全量
func get_snapshot() -> Dictionary:
	return {
		"tts_enabled": _tts_enabled,
		"volume": _volume,
		"voice_id": _voice_id,
		"speech_rate": _speech_rate,
		"audio_bus": _audio_bus,
		"queue_enabled": _queue_enabled,
		"interrupt_on_new_reply": _interrupt_on_new_reply,
	}


# ============ 修改 API ============
func set_tts_enabled(enabled: bool) -> void:
	if _tts_enabled == enabled:
		return
	_tts_enabled = enabled
	tts_enabled_changed.emit(enabled)
	_queue_save()
	_emit_snapshot()


func set_volume(value: float) -> void:
	value = clampf(value, VOLUME_MIN, VOLUME_MAX)
	if is_equal_approx(_volume, value):
		return
	_volume = value
	volume_changed.emit(_volume)
	_queue_save()
	_emit_snapshot()


func set_voice_id(id: String) -> void:
	if _voice_id == id:
		return
	_voice_id = id
	voice_id_changed.emit(id)
	_queue_save()
	_emit_snapshot()


func set_speech_rate(rate: float) -> void:
	rate = clampf(rate, SPEECH_RATE_MIN, SPEECH_RATE_MAX)
	if is_equal_approx(_speech_rate, rate):
		return
	_speech_rate = rate
	speech_rate_changed.emit(_speech_rate)
	_queue_save()
	_emit_snapshot()


func set_audio_bus(bus_name: String) -> void:
	if bus_name.is_empty():
		bus_name = "Master"
	if _audio_bus == bus_name:
		return
	_audio_bus = bus_name
	audio_bus_changed.emit(_audio_bus)
	_queue_save()
	_emit_snapshot()


func set_queue_enabled(enabled: bool) -> void:
	if _queue_enabled == enabled:
		return
	_queue_enabled = enabled
	queue_enabled_changed.emit(enabled)
	_queue_save()
	_emit_snapshot()


func set_interrupt_on_new_reply(enabled: bool) -> void:
	if _interrupt_on_new_reply == enabled:
		return
	_interrupt_on_new_reply = enabled
	interrupt_on_new_reply_changed.emit(enabled)
	_queue_save()
	_emit_snapshot()


## 恢复默认并持久化
func reset_to_defaults() -> void:
	_tts_enabled = true
	_volume = 1.0
	_voice_id = ""
	_speech_rate = 1.0
	_audio_bus = "Master"
	_queue_enabled = true
	_interrupt_on_new_reply = false
	_save()
	tts_enabled_changed.emit(_tts_enabled)
	volume_changed.emit(_volume)
	voice_id_changed.emit(_voice_id)
	speech_rate_changed.emit(_speech_rate)
	audio_bus_changed.emit(_audio_bus)
	queue_enabled_changed.emit(_queue_enabled)
	interrupt_on_new_reply_changed.emit(_interrupt_on_new_reply)
	_emit_snapshot()


# ============ Agent API（Parser / 外部自动化调用）============
func agent_set_tts_enabled(enabled: bool) -> bool:
	set_tts_enabled(enabled)
	return true


func agent_set_volume(value: float) -> bool:
	set_volume(value)
	return true


func agent_set_voice_id(id: String) -> bool:
	set_voice_id(id)
	return true


func agent_set_speech_rate(rate: float) -> bool:
	set_speech_rate(rate)
	return true


func agent_set_queue_enabled(enabled: bool) -> bool:
	set_queue_enabled(enabled)
	return true


func agent_set_interrupt_on_new_reply(enabled: bool) -> bool:
	set_interrupt_on_new_reply(enabled)
	return true


func agent_get_snapshot() -> Dictionary:
	return get_snapshot()
