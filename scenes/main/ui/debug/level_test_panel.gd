extends Control

@onready var info_label: RichTextLabel = $MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/InfoLabel
@onready var state_label: Label = $MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/StateSection/StateLabel
@onready var custom_xp_input: LineEdit = $MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/InputSection/CustomXpInput
@onready var source_input: LineEdit = $MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/InputSection/SourceInput
@onready var show_source_check: CheckBox = $MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/InputSection/ShowSourceCheck

@onready var add_10_btn: Button = $MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/ButtonSection/Add10Btn
@onready var add_50_btn: Button = $MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/ButtonSection/Add50Btn
@onready var add_100_btn: Button = $MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/ButtonSection/Add100Btn
@onready var add_500_btn: Button = $MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/ButtonSection/Add500Btn
@onready var add_custom_btn: Button = $MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/ButtonSection/AddCustomBtn
@onready var reset_btn: Button = $MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/ButtonSection/ResetLevelXpBtn

func _ready() -> void:
	add_10_btn.pressed.connect(func() -> void: _add_xp_and_log(10))
	add_50_btn.pressed.connect(func() -> void: _add_xp_and_log(50))
	add_100_btn.pressed.connect(func() -> void: _add_xp_and_log(100))
	add_500_btn.pressed.connect(func() -> void: _add_xp_and_log(500))
	add_custom_btn.pressed.connect(_on_add_custom_pressed)
	reset_btn.pressed.connect(_on_reset_pressed)

	if LevelState.has_signal("level_state_changed") and not LevelState.level_state_changed.is_connected(_on_level_state_changed):
		LevelState.level_state_changed.connect(_on_level_state_changed)
	if LevelState.has_signal("level_up") and not LevelState.level_up.is_connected(_on_level_up):
		LevelState.level_up.connect(_on_level_up)

	_refresh_state()
	_log_info("经验调试面板已就绪")

func _exit_tree() -> void:
	if LevelState.has_signal("level_state_changed") and LevelState.level_state_changed.is_connected(_on_level_state_changed):
		LevelState.level_state_changed.disconnect(_on_level_state_changed)
	if LevelState.has_signal("level_up") and LevelState.level_up.is_connected(_on_level_up):
		LevelState.level_up.disconnect(_on_level_up)

func _on_add_custom_pressed() -> void:
	var amount := custom_xp_input.text.to_int()
	if amount <= 0:
		_log_error("请输入大于0的经验值")
		return
	_add_xp_and_log(amount)

func _add_xp_and_log(amount: int) -> void:
	var before_level := LevelState.level
	var before_xp := LevelState.xp
	var source := source_input.text.strip_edges()
	var show_source := show_source_check.button_pressed

	LevelState.add_xp(amount, source, show_source)

	var source_log := ""
	if not source.is_empty():
		source_log = ",来源: %s%s" % [source, "(显示)" if show_source else "(不显示)"]
	_log_success("增加经验: +%d（Lv.%d %dXP -> Lv.%d %dXP%s）" % [amount, before_level, before_xp, LevelState.level, LevelState.xp, source_log])

func _on_reset_pressed() -> void:
	var before_level := LevelState.level
	var before_xp := LevelState.xp
	LevelState.reset_level_and_xp()
	_log_success("已重置等级经验（Lv.%d %dXP -> Lv.%d %dXP）" % [before_level, before_xp, LevelState.level, LevelState.xp])

func _on_level_state_changed(_data: Dictionary) -> void:
	_refresh_state()

func _on_level_up(new_level: int) -> void:
	_log_success("升级成功！当前等级: Lv.%d" % new_level)

func _refresh_state() -> void:
	var need := LevelState.get_xp_for_next_level(LevelState.level)
	var progress := int(round(LevelState.get_progress() * 100.0))
	state_label.text = "当前等级: Lv.%d    当前经验: %d/%d    进度: %d%%" % [LevelState.level, LevelState.xp, need, progress]

func _log_info(message: String) -> void:
	info_label.append_text("[color=white]%s[/color]\n" % message)
	print("[LevelTest] %s" % message)

func _log_success(message: String) -> void:
	info_label.append_text("[color=green]%s[/color]\n" % message)
	print("[LevelTest] %s" % message)

func _log_error(message: String) -> void:
	info_label.append_text("[color=red]%s[/color]\n" % message)
	print("[LevelTest] ERROR: %s" % message)
