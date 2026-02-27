extends Control

@onready var info_label: RichTextLabel = $MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/InfoLabel
@onready var title_input: LineEdit = $MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/InputSection/TitleInput
@onready var description_input: LineEdit = $MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/InputSection/DescriptionInput
@onready var item_id_input: LineEdit = $MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/InputSection/ItemIdInput
@onready var target_input: LineEdit = $MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/InputSection/TargetInput
@onready var current_input: LineEdit = $MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/InputSection/CurrentInput

@onready var add_daily_btn: Button = $MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/ButtonSection/AddDailyBtn
@onready var add_achievement_btn: Button = $MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/ButtonSection/AddAchievementBtn
@onready var set_daily_progress_btn: Button = $MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/ButtonSection/SetDailyProgressBtn
@onready var set_achievement_progress_btn: Button = $MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/ButtonSection/SetAchievementProgressBtn
@onready var mark_daily_completed_btn: Button = $MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/ButtonSection/MarkDailyCompletedBtn
@onready var mark_daily_uncompleted_btn: Button = $MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/ButtonSection/MarkDailyUncompletedBtn
@onready var mark_achievement_completed_btn: Button = $MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/ButtonSection/MarkAchievementCompletedBtn
@onready var mark_achievement_uncompleted_btn: Button = $MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/ButtonSection/MarkAchievementUncompletedBtn
@onready var claim_achievement_btn: Button = $MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/ButtonSection/ClaimAchievementBtn
@onready var remove_daily_btn: Button = $MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/ButtonSection/RemoveDailyBtn
@onready var remove_achievement_btn: Button = $MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/ButtonSection/RemoveAchievementBtn
@onready var get_all_btn: Button = $MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/ButtonSection/GetAllBtn
@onready var clear_daily_btn: Button = $MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/ButtonSection/ClearDailyBtn
@onready var clear_achievement_btn: Button = $MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/ButtonSection/ClearAchievementBtn

func _ready() -> void:
	add_daily_btn.pressed.connect(_on_add_daily_pressed)
	add_achievement_btn.pressed.connect(_on_add_achievement_pressed)
	set_daily_progress_btn.pressed.connect(_on_set_daily_progress_pressed)
	set_achievement_progress_btn.pressed.connect(_on_set_achievement_progress_pressed)
	mark_daily_completed_btn.pressed.connect(func() -> void: _on_set_daily_completed_pressed(true))
	mark_daily_uncompleted_btn.pressed.connect(func() -> void: _on_set_daily_completed_pressed(false))
	mark_achievement_completed_btn.pressed.connect(func() -> void: _on_set_achievement_completed_pressed(true))
	mark_achievement_uncompleted_btn.pressed.connect(func() -> void: _on_set_achievement_completed_pressed(false))
	claim_achievement_btn.pressed.connect(_on_claim_achievement_pressed)
	remove_daily_btn.pressed.connect(_on_remove_daily_pressed)
	remove_achievement_btn.pressed.connect(_on_remove_achievement_pressed)
	get_all_btn.pressed.connect(_on_get_all_pressed)
	clear_daily_btn.pressed.connect(_on_clear_daily_pressed)
	clear_achievement_btn.pressed.connect(_on_clear_achievement_pressed)

	AchievementState.daily_task_added.connect(_on_state_daily_task_added)
	AchievementState.daily_task_removed.connect(_on_state_daily_task_removed)
	AchievementState.daily_task_state_updated.connect(_on_state_daily_task_state_updated)
	AchievementState.daily_task_completed.connect(_on_state_daily_task_completed)
	AchievementState.daily_task_reward_claimed.connect(_on_state_daily_task_reward_claimed)
	AchievementState.achievement_added.connect(_on_state_achievement_added)
	AchievementState.achievement_removed.connect(_on_state_achievement_removed)
	AchievementState.achievement_state_updated.connect(_on_state_achievement_state_updated)
	AchievementState.achievement_completed.connect(_on_state_achievement_completed)
	AchievementState.achievement_reward_claimed.connect(_on_state_achievement_reward_claimed)

	_log_info("Achievement 调试面板已就绪")
	_log_info("当前数据: 每日任务=%d, 成就=%d" % [AchievementState.get_daily_task_count(), AchievementState.get_achievement_count()])

func _on_add_daily_pressed() -> void:
	var title := _read_title("测试每日任务")
	var description := description_input.text.strip_edges()
	var target := _read_target()
	var current := _read_current(target)
	var data := AchievementState.add_daily_task(title, description, target, current)
	item_id_input.text = str(data.get("id", -1))
	_log_success("添加每日任务成功: id=%d" % int(data.get("id", -1)))

func _on_add_achievement_pressed() -> void:
	var title := _read_title("测试成就")
	var description := description_input.text.strip_edges()
	var target := _read_target()
	var current := _read_current(target)
	var data := AchievementState.add_achievement(title, description, target, current)
	item_id_input.text = str(data.get("id", -1))
	_log_success("添加成就成功: id=%d" % int(data.get("id", -1)))

func _on_set_daily_progress_pressed() -> void:
	var item_id := item_id_input.text.to_int()
	var target := _read_target()
	var current := _read_current(target)
	var ok := AchievementState.set_daily_task_progress(item_id, current, target)
	if ok:
		_log_success("更新每日任务进度成功: id=%d, %d/%d" % [item_id, current, target])
	else:
		_log_error("更新每日任务进度失败，ID不存在")

func _on_set_achievement_progress_pressed() -> void:
	var item_id := item_id_input.text.to_int()
	var target := _read_target()
	var current := _read_current(target)
	var ok := AchievementState.set_achievement_progress(item_id, current, target)
	if ok:
		_log_success("更新成就进度成功: id=%d, %d/%d" % [item_id, current, target])
	else:
		_log_error("更新成就进度失败，ID不存在")

func _on_set_daily_completed_pressed(completed: bool) -> void:
	var item_id := item_id_input.text.to_int()
	var ok := AchievementState.set_daily_task_completed(item_id, completed)
	if ok:
		_log_success("设置每日任务完成状态成功: id=%d, completed=%s" % [item_id, completed])
	else:
		_log_error("设置每日任务完成状态失败，ID不存在")

func _on_set_achievement_completed_pressed(completed: bool) -> void:
	var item_id := item_id_input.text.to_int()
	var ok := AchievementState.set_achievement_completed(item_id, completed)
	if ok:
		_log_success("设置成就完成状态成功: id=%d, completed=%s" % [item_id, completed])
	else:
		_log_error("设置成就完成状态失败，ID不存在")

func _on_claim_achievement_pressed() -> void:
	var item_id := item_id_input.text.to_int()
	var ok := AchievementState.claim_achievement(item_id)
	if ok:
		_log_success("领取成就奖励成功: id=%d" % item_id)
	else:
		_log_error("领取失败（可能ID不存在/未完成/已领取）")

func _on_remove_daily_pressed() -> void:
	var item_id := item_id_input.text.to_int()
	var ok := AchievementState.remove_daily_task(item_id)
	if ok:
		_log_success("删除每日任务成功: id=%d" % item_id)
	else:
		_log_error("删除每日任务失败，ID不存在")

func _on_remove_achievement_pressed() -> void:
	var item_id := item_id_input.text.to_int()
	var ok := AchievementState.remove_achievement(item_id)
	if ok:
		_log_success("删除成就成功: id=%d" % item_id)
	else:
		_log_error("删除成就失败，ID不存在")

func _on_get_all_pressed() -> void:
	var daily_tasks := AchievementState.get_daily_tasks()
	var achievements := AchievementState.get_achievements()
	_log_success("每日任务(%d), 成就(%d)" % [daily_tasks.size(), achievements.size()])
	_log_data("daily_tasks = %s" % JSON.stringify(daily_tasks))
	_log_data("achievements = %s" % JSON.stringify(achievements))

func _on_clear_daily_pressed() -> void:
	var count := AchievementState.clear_daily_tasks()
	_log_success("已清空每日任务: %d 条" % count)

func _on_clear_achievement_pressed() -> void:
	var count := AchievementState.clear_achievements()
	_log_success("已清空成就: %d 条" % count)

func _on_state_daily_task_added(data: Dictionary) -> void:
	_log_info("[signal] daily_task_added -> id=%d" % int(data.get("id", -1)))

func _on_state_daily_task_removed(item_id: int) -> void:
	_log_info("[signal] daily_task_removed -> id=%d" % item_id)

func _on_state_daily_task_state_updated(data: Dictionary) -> void:
	_log_info("[signal] daily_task_state_updated -> id=%d" % int(data.get("id", -1)))

func _on_state_daily_task_completed(data: Dictionary) -> void:
	_log_info("[signal] daily_task_completed -> id=%d" % int(data.get("id", -1)))

func _on_state_daily_task_reward_claimed(data: Dictionary) -> void:
	_log_info("[signal] daily_task_reward_claimed -> id=%d" % int(data.get("id", -1)))

func _on_state_achievement_added(data: Dictionary) -> void:
	_log_info("[signal] achievement_added -> id=%d" % int(data.get("id", -1)))

func _on_state_achievement_removed(item_id: int) -> void:
	_log_info("[signal] achievement_removed -> id=%d" % item_id)

func _on_state_achievement_state_updated(data: Dictionary) -> void:
	_log_info("[signal] achievement_state_updated -> id=%d" % int(data.get("id", -1)))

func _on_state_achievement_completed(data: Dictionary) -> void:
	_log_info("[signal] achievement_completed -> id=%d" % int(data.get("id", -1)))

func _on_state_achievement_reward_claimed(data: Dictionary) -> void:
	_log_info("[signal] achievement_reward_claimed -> id=%d" % int(data.get("id", -1)))

func _read_title(prefix: String) -> String:
	var title := title_input.text.strip_edges()
	if title.is_empty():
		title = "%s_%d" % [prefix, Time.get_ticks_msec()]
	return title

func _read_target() -> int:
	return max(1, target_input.text.to_int())

func _read_current(target: int) -> int:
	return clampi(current_input.text.to_int(), 0, target)

func _log_info(message: String) -> void:
	info_label.append_text("[color=white]%s[/color]\n" % message)
	print("[AchievementTest] %s" % message)

func _log_success(message: String) -> void:
	info_label.append_text("[color=green]%s[/color]\n" % message)
	print("[AchievementTest] %s" % message)

func _log_error(message: String) -> void:
	info_label.append_text("[color=red]%s[/color]\n" % message)
	print("[AchievementTest] ERROR: %s" % message)

func _log_data(message: String) -> void:
	info_label.append_text("[color=cyan]%s[/color]\n" % message)
	print("[AchievementTest] %s" % message)
