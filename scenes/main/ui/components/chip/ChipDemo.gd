extends Control

## MaterialChip 演示场景脚本
## 展示所有 Chip 类型和样式的使用方式

@onready var log_label: Label = $VBoxContainer/LogLabel
@onready var suggestion_chips: HFlowContainer = $VBoxContainer/SuggestionSection/SuggestionChips
@onready var filter_chips: HFlowContainer = $VBoxContainer/FilterSection/FilterChips
@onready var input_chips: HFlowContainer = $VBoxContainer/InputSection/InputChips
@onready var assist_chips: HFlowContainer = $VBoxContainer/AssistSection/AssistChips
@onready var style_chips: HFlowContainer = $VBoxContainer/StyleSection/StyleChips

# 预加载图标
var _music_icon: Texture2D
var _search_icon: Texture2D
var _info_icon: Texture2D
var _add_icon: Texture2D

func _ready() -> void:
	_load_icons()
	_create_demo_chips()

func _load_icons() -> void:
	# 加载项目中的 Material Design 图标
	_music_icon = load("res://assets/ui/icons/music_note_24dp_FFFFFF_FILL0_wght400_GRAD0_opsz24.svg")
	_search_icon = load("res://assets/ui/icons/search_24dp_FFFFFF_FILL0_wght400_GRAD0_opsz24.svg")
	_info_icon = load("res://assets/ui/icons/info_24dp_FFFFFF_FILL0_wght400_GRAD0_opsz24.svg")
	_add_icon = load("res://assets/ui/icons/add_24dp_FFFFFF_FILL0_wght400_GRAD0_opsz24.svg")

func _create_demo_chips() -> void:
	# 创建 Suggestion Chips（纯文字）
	var suggestions = ["推荐", "热门", "最新", "精选"]
	for text in suggestions:
		var chip = _create_chip(text, MaterialChip.ChipType.SUGGESTION)
		suggestion_chips.add_child(chip)

	# 创建 Filter Chips（可选中，支持图标）
	var filters = [
		{"text": "音乐", "icon": _music_icon},
		{"text": "搜索", "icon": _search_icon},
		{"text": "电影", "icon": null},
		{"text": "阅读", "icon": null},
		{"text": "运动", "icon": null}
	]
	for i in range(filters.size()):
		var chip = _create_chip(filters[i]["text"], MaterialChip.ChipType.FILTER)
		if filters[i]["icon"]:
			chip.chip_icon = filters[i]["icon"]
		if i == 0:
			chip.is_selected = true  # 默认选中第一个
		filter_chips.add_child(chip)

	# 创建 Input Chips（可删除，支持图标）
	var inputs = [
		{"text": "标签1", "icon": null},
		{"text": "音乐文件", "icon": _music_icon},
		{"text": "用户输入", "icon": null},
		{"text": "可删除", "icon": null}
	]
	for item in inputs:
		var chip = _create_chip(item["text"], MaterialChip.ChipType.INPUT)
		if item["icon"]:
			chip.chip_icon = item["icon"]
		input_chips.add_child(chip)

	# 创建 Assist Chips（带图标的辅助操作）
	var assists = [
		{"text": "帮助", "icon": _info_icon},
		{"text": "搜索", "icon": _search_icon},
		{"text": "添加", "icon": _add_icon}
	]
	for item in assists:
		var chip = _create_chip(item["text"], MaterialChip.ChipType.ASSIST)
		if item["icon"]:
			chip.chip_icon = item["icon"]
		assist_chips.add_child(chip)

	# 创建样式对比 Chips
	var outlined_chip = _create_chip("Outlined", MaterialChip.ChipType.SUGGESTION)
	outlined_chip.chip_style = MaterialChip.ChipStyle.OUTLINED
	style_chips.add_child(outlined_chip)

	var filled_chip = _create_chip("Filled", MaterialChip.ChipType.SUGGESTION)
	filled_chip.chip_style = MaterialChip.ChipStyle.FILLED
	style_chips.add_child(filled_chip)

	# 带图标的 Filled 样式
	var filled_icon_chip = _create_chip("带图标", MaterialChip.ChipType.SUGGESTION)
	filled_icon_chip.chip_style = MaterialChip.ChipStyle.FILLED
	filled_icon_chip.chip_icon = _music_icon
	style_chips.add_child(filled_icon_chip)

	# 尺寸对比
	var small_chip = _create_chip("Small", MaterialChip.ChipType.SUGGESTION)
	small_chip.chip_size = MaterialChip.ChipSize.SMALL
	small_chip.chip_icon = _info_icon
	style_chips.add_child(small_chip)

	var standard_chip = _create_chip("Standard", MaterialChip.ChipType.SUGGESTION)
	standard_chip.chip_size = MaterialChip.ChipSize.STANDARD
	standard_chip.chip_icon = _info_icon
	style_chips.add_child(standard_chip)

	var large_chip = _create_chip("Large", MaterialChip.ChipType.SUGGESTION)
	large_chip.chip_size = MaterialChip.ChipSize.LARGE
	large_chip.chip_icon = _info_icon
	style_chips.add_child(large_chip)

func _create_chip(text: String, type: MaterialChip.ChipType) -> MaterialChip:
	var chip = MaterialChip.new()
	chip.text = text
	chip.chip_type = type

	# 连接信号
	chip.pressed.connect(_on_chip_pressed.bind(chip))
	chip.selected.connect(_on_chip_selected.bind(chip))
	chip.deleted.connect(_on_chip_deleted.bind(chip))

	return chip

func _on_chip_pressed(chip: MaterialChip) -> void:
	_log("按下: %s (类型: %s)" % [chip.text, _get_type_name(chip.chip_type)])

func _on_chip_selected(is_selected: bool, chip: MaterialChip) -> void:
	var state = "选中" if is_selected else "取消选中"
	_log("%s: %s" % [state, chip.text])

func _on_chip_deleted(chip: MaterialChip) -> void:
	_log("删除: %s" % chip.text)
	# 演示删除效果
	chip.queue_free()

func _get_type_name(type: MaterialChip.ChipType) -> String:
	match type:
		MaterialChip.ChipType.ASSIST:
			return "Assist"
		MaterialChip.ChipType.FILTER:
			return "Filter"
		MaterialChip.ChipType.INPUT:
			return "Input"
		MaterialChip.ChipType.SUGGESTION:
			return "Suggestion"
	return "Unknown"

func _log(message: String) -> void:
	if log_label:
		log_label.text = message
		print("[ChipDemo] ", message)
