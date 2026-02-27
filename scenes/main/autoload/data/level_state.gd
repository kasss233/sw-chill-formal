extends Node

# ===== 信号（对外） =====
# 升级时触发，参数为升级后的等级
signal level_up(new_level: int)
# 任意等级状态变化后触发，携带完整状态与本次增量上下文
signal level_state_changed(data: Dictionary)
# 数据加载完成后触发（首次启动/读档后）
signal data_loaded

# ===== 运行时状态 =====
var level: int = 1
var xp: int = 0

# 本次加经验的临时上下文（用于 UI 提示来源）
var _pending_gain_amount: int = 0
var _pending_gain_source: String = ""
var _pending_show_gain_source: bool = false

const SAVE_PATH := "user://level_data.json"


# ===== 生命周期 =====
func _ready() -> void:
	load_data()
	_connect_signals()


# ===== 对外接口（UI/模块可调用） =====
# 增加经验。
# source: 经验来源描述（如“完成任务”）
# show_source: 是否允许 UI 显示来源
func add_xp(amount: int, source: String = "", show_source: bool = false) -> void:
	if amount <= 0:
		return

	_pending_gain_amount = amount
	_pending_gain_source = source.strip_edges()
	_pending_show_gain_source = show_source and not _pending_gain_source.is_empty()

	xp += amount
	while xp >= get_xp_for_next_level(level):
		xp -= get_xp_for_next_level(level)
		level += 1
		level_up.emit(level)

	save_data()
	_emit_state_changed()


# 重置等级与经验（调试或特殊场景使用）
func reset_level_and_xp() -> void:
	level = 1
	xp = 0
	_clear_pending_gain_context()
	save_data()
	_emit_state_changed()


# 获取指定等级升到下一级所需经验
func get_xp_for_next_level(target_level: int = level) -> int:
	return max(100, target_level * 100)


# 获取当前等级进度（0.0 ~ 1.0）
func get_progress() -> float:
	var xp_for_next_level := get_xp_for_next_level(level)
	if xp_for_next_level <= 0:
		return 0.0
	return clampf(float(xp) / float(xp_for_next_level), 0.0, 1.0)


# 立即保存当前等级数据到本地
func save_data() -> void:
	var data := {
		"version": 1,
		"level": level,
		"xp": xp
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data))


# 从本地加载等级数据（会广播状态并发出 data_loaded）
func load_data() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		_clear_pending_gain_context()
		_emit_state_changed()
		call_deferred("emit_signal", "data_loaded")
		return

	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file:
		var content := file.get_as_text()
		var json := JSON.new()
		if json.parse(content) == OK and typeof(json.data) == TYPE_DICTIONARY:
			var data: Dictionary = json.data
			level = max(1, int(data.get("level", 1)))
			xp = max(0, int(data.get("xp", 0)))
			var xp_for_next_level := get_xp_for_next_level(level)
			if xp >= xp_for_next_level:
				xp = xp % xp_for_next_level

	_clear_pending_gain_context()
	_emit_state_changed()
	call_deferred("emit_signal", "data_loaded")


# ===== 内部方法（仅本脚本使用） =====
# 统一发出状态变化信号，并附带本次加经验上下文
func _emit_state_changed() -> void:
	level_state_changed.emit({
		"level": level,
		"xp": xp,
		"xp_for_next_level": get_xp_for_next_level(level),
		"progress": get_progress(),
		"gain_amount": _pending_gain_amount,
		"gain_source": _pending_gain_source,
		"show_gain_source": _pending_show_gain_source
	})
	_clear_pending_gain_context()


# 清空本次加经验上下文，避免污染后续非加经验状态变更
func _clear_pending_gain_context() -> void:
	_pending_gain_amount = 0
	_pending_gain_source = ""
	_pending_show_gain_source = false


func _connect_signals() -> void:
	if AchievementState and AchievementState.has_signal("daily_task_reward_claimed"):
		if not AchievementState.daily_task_reward_claimed.is_connected(_on_daily_task_reward_claimed):
			AchievementState.daily_task_reward_claimed.connect(_on_daily_task_reward_claimed)

func _on_daily_task_reward_claimed(_data: Dictionary) -> void:
	add_xp(50, "完成每日任务奖励", true)
