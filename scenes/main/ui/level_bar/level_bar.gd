extends Control

# ===== 节点引用 =====
@export var bar: MaterialProgressIndicator
@export var level_label: Label
@export var xp_level: Label
@export var msg_label: Label
@export var msg_panel: FrostedPanel

# 经验提示停留时长（秒）
@export var msg_show_duration: float = 1.2

# ===== 运行时状态 =====
var _msg_tween: Tween


# 生命周期：初始化信号与 UI 初始状态
func _ready() -> void:
	if LevelState.has_signal("level_state_changed") and not LevelState.level_state_changed.is_connected(_on_level_state_changed):
		LevelState.level_state_changed.connect(_on_level_state_changed)

	if msg_panel:
		msg_panel.visible = false
		msg_panel.modulate.a = 0.0

	update_bar()


# 生命周期：退出时断开信号并清理动画
func _exit_tree() -> void:
	if LevelState.has_signal("level_state_changed") and LevelState.level_state_changed.is_connected(_on_level_state_changed):
		LevelState.level_state_changed.disconnect(_on_level_state_changed)

	if _msg_tween and _msg_tween.is_valid():
		_msg_tween.kill()


# State 回调：同步进度条 + 处理经验提示
func _on_level_state_changed(data: Dictionary) -> void:
	_handle_xp_gain_message(data)
	update_bar()


# 刷新等级与经验进度显示
func update_bar() -> void:
	var xp_for_next_level := LevelState.get_xp_for_next_level(LevelState.level)
	var progress := 0.0
	if xp_for_next_level > 0:
		progress = clampf(float(LevelState.xp) / float(xp_for_next_level), 0.0, 1.0)

	bar.set_progress_value(progress, true)
	level_label.text = "Lv.%d" % LevelState.level
	xp_level.text = "%d/%d XP" % [LevelState.xp, xp_for_next_level]


# 计算“本次增加经验”并触发提示（支持跨等级）
func _handle_xp_gain_message(data: Dictionary) -> void:
	var gained: int = int(data.get("gain_amount", 0))
	if gained <= 0:
		return

	var source: String = str(data.get("gain_source", "")).strip_edges()
	var show_source: bool = bool(data.get("show_gain_source", false))
	_show_xp_message(gained, source, show_source)


# 显示经验提示：淡入 -> 停留 -> 淡出 -> 隐藏
func _show_xp_message(amount: int, source: String = "", show_source: bool = false) -> void:
	if msg_label:
		var msg_text := "经验+%d" % amount
		if show_source and not source.is_empty():
			msg_text += "（%s）" % source
		msg_label.text = msg_text

	if not msg_panel:
		return

	if _msg_tween and _msg_tween.is_valid():
		_msg_tween.kill()

	msg_panel.visible = true
	msg_panel.modulate.a = 0.0

	_msg_tween = create_tween()
	_msg_tween.tween_property(msg_panel, "modulate:a", 1.0, 0.15)
	_msg_tween.tween_interval(max(msg_show_duration, 0.1))
	_msg_tween.tween_property(msg_panel, "modulate:a", 0.0, 0.2)
	_msg_tween.finished.connect(func() -> void:
		if msg_panel:
			msg_panel.visible = false
	)
