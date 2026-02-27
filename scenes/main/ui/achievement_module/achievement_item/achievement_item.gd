extends Control

signal claim_requested(item_id: int, category: String)
signal item_pressed(item_id: int, category: String)


@onready var title_label: Label = $MarginContainer/PanelContainer/VBoxContainer/TopRow/TitleLabel
@onready var status_label: Label = $MarginContainer/PanelContainer/VBoxContainer/TopRow/StatusLabel
@onready var claim_button: Button = $MarginContainer/PanelContainer/VBoxContainer/TopRow/OperationContainer/ClaimButton

@onready var description_label: Label = $MarginContainer/PanelContainer/VBoxContainer/DescriptionLabel
@onready var progress_bar: ProgressBar = $MarginContainer/PanelContainer/VBoxContainer/ProgressRow/ProgressBar
@onready var progress_label: Label = $MarginContainer/PanelContainer/VBoxContainer/ProgressRow/ProgressLabel

var _data: Dictionary = {}
var _category: String = "daily_task"
var _is_updating: bool = false

func set_data(data: Dictionary) -> void:
	_data = data.duplicate(true)
	_category = str(_data.get("category", "daily_task"))
	_update_display()

func update_display(data: Dictionary) -> void:
	set_data(data)

func get_item_id() -> int:
	return int(_data.get("id", -1))

func get_data() -> Dictionary:
	return _data.duplicate(true)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		item_pressed.emit(get_item_id(), _category)


func _on_claim_button_pressed() -> void:
	claim_requested.emit(get_item_id(), _category)

func _update_display() -> void:
	var title: String = str(_data.get("title", "未命名项目"))
	var description: String = str(_data.get("description", ""))
	var target: int = max(1, int(_data.get("target", 1)))
	var current: int = clampi(int(_data.get("current", 0)), 0, target)
	var completed: bool = bool(_data.get("completed", false))
	var reward_claimed: bool = bool(_data.get("reward_claimed", false))

	if completed:
		current = target

	title_label.text = title
	description_label.text = description
	description_label.visible = description != ""

	progress_bar.max_value = float(target)
	progress_bar.value = float(current)
	progress_label.text = "%d/%d" % [current, target]

	_is_updating = true
	_is_updating = false

	if _category == "daily_task":
		claim_button.visible = completed and not reward_claimed
		if reward_claimed:
			status_label.text = "已领取"
		elif completed:
			status_label.text = "可领取"
		else:
			status_label.text = "进行中"
	else:
		claim_button.visible = completed and not reward_claimed
		if reward_claimed:
			status_label.text = "已领取"
		elif completed:
			status_label.text = "可领取"
		else:
			status_label.text = "进行中"
