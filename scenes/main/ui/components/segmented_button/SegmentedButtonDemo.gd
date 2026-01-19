extends Control

## MaterialSegmentedButton 分段选择器演示

var _segmented_basic: MaterialSegmentedButton
var _segmented_icons: MaterialSegmentedButton
var _segmented_dynamic: MaterialSegmentedButton

func _ready() -> void:
	_setup_demo_ui()
	# 等待一帧确保容器尺寸正确设置
	await get_tree().process_frame
	_update_container_size()

func _update_container_size() -> void:
	var main_container = get_child(0).get_child(0) if get_child_count() > 0 else null
	if main_container:
		main_container.offset_right = main_container.get_parent().size.x - 64

func _setup_demo_ui() -> void:
	# 创建滚动容器
	var scroll_container = ScrollContainer.new()
	scroll_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll_container.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll_container.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	add_child(scroll_container)

	# 主容器
	var main_container = VBoxContainer.new()
	main_container.set_anchors_preset(Control.PRESET_TOP_LEFT)
	main_container.offset_left = 32
	main_container.offset_top = 32
	main_container.offset_right = -32
	main_container.add_theme_constant_override("separation", 32)
	scroll_container.add_child(main_container)

	# 标题
	var title = Label.new()
	title.text = "MaterialSegmentedButton 分段选择器演示"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	main_container.add_child(title)

	# ========== 1. 基础分段选择器 ==========
	var section1 = _create_section("基础分段选择器（3选项）")
	main_container.add_child(section1)

	_segmented_basic = MaterialSegmentedButton.new()
	_segmented_basic.name = "SegmentedBasic"
	_segmented_basic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_segmented_basic.add_segment("日")
	_segmented_basic.add_segment("周")
	_segmented_basic.add_segment("月")
	_segmented_basic.selected_index = 0
	section1.add_child(_segmented_basic)

	var result_label1 = Label.new()
	result_label1.name = "Result1"
	result_label1.text = "当前选择: 日"
	result_label1.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	section1.add_child(result_label1)

	_segmented_basic.segment_selected.connect(func(index, text):
		result_label1.text = "当前选择: %s (索引: %d)" % [text, index]
	)

	# ========== 2. 自定义颜色 ==========
	var section2 = _create_section("自定义颜色样式")
	main_container.add_child(section2)

	var segmented_color = MaterialSegmentedButton.new()
	segmented_color.name = "SegmentedColor"
	segmented_color.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	segmented_color.background_color = Color(0.1, 0.1, 0.15, 1)
	segmented_color.selected_color = Color(0.3, 0.8, 0.4, 1)  # 绿色
	segmented_color.unselected_color = Color(0.5, 0.5, 0.5, 1)
	segmented_color.selected_text_color = Color.WHITE
	segmented_color.button_height = 40
	segmented_color.corner_radius = 24
	segmented_color.add_segment("小")
	segmented_color.add_segment("中")
	segmented_color.add_segment("大")
	segmented_color.selected_index = 1
	section2.add_child(segmented_color)

	var result_label2 = Label.new()
	result_label2.name = "Result2"
	result_label2.text = "当前选择: 中"
	result_label2.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	section2.add_child(result_label2)

	segmented_color.segment_selected.connect(func(index, text):
		result_label2.text = "当前选择: %s (索引: %d)" % [text, index]
	)

	# ========== 3. 更多选项 ==========
	var section3 = _create_section("更多选项（5选项）")
	main_container.add_child(section3)

	var segmented_many = MaterialSegmentedButton.new()
	segmented_many.name = "SegmentedMany"
	segmented_many.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	segmented_many.add_segment("非常简单")
	segmented_many.add_segment("简单")
	segmented_many.add_segment("普通")
	segmented_many.add_segment("困难")
	segmented_many.add_segment("非常困难")
	segmented_many.min_button_width = 100
	section3.add_child(segmented_many)

	var result_label3 = Label.new()
	result_label3.name = "Result3"
	result_label3.text = "当前选择: 未选择"
	result_label3.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	section3.add_child(result_label3)

	segmented_many.segment_selected.connect(func(index, text):
		result_label3.text = "当前选择: %s (索引: %d)" % [text, index]
	)

	# ========== 4. 动态操作 ==========
	var section4 = _create_section("动态添加/移除选项")
	main_container.add_child(section4)

	_segmented_dynamic = MaterialSegmentedButton.new()
	_segmented_dynamic.name = "SegmentedDynamic"
	_segmented_dynamic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_segmented_dynamic.add_segment("选项A")
	_segmented_dynamic.add_segment("选项B")
	section4.add_child(_segmented_dynamic)

	var result_label4 = Label.new()
	result_label4.name = "Result4"
	result_label4.text = "当前选择: 选项A"
	result_label4.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	section4.add_child(result_label4)

	# 按钮容器
	var button_row = HBoxContainer.new()
	button_row.add_theme_constant_override("separation", 12)
	section4.add_child(button_row)

	var btn_add = _create_control_button("添加选项")
	btn_add.pressed.connect(func():
		var new_text = "选项%c" % char(65 + _segmented_dynamic.get_segment_count())
		_segmented_dynamic.add_segment(new_text)
	)
	button_row.add_child(btn_add)

	var btn_remove = _create_control_button("移除末项")
	btn_remove.pressed.connect(func():
		if _segmented_dynamic.get_segment_count() > 1:
			_segmented_dynamic.remove_segment(_segmented_dynamic.get_segment_count() - 1)
	)
	button_row.add_child(btn_remove)

	var btn_clear = _create_control_button("清空")
	btn_clear.pressed.connect(func():
		_segmented_dynamic.clear_segments()
	)
	button_row.add_child(btn_clear)

	_segmented_dynamic.segment_selected.connect(func(index, text):
		result_label4.text = "当前选择: %s (索引: %d)" % [text, index]
	)

func _create_section(title: String) -> VBoxContainer:
	var section = VBoxContainer.new()
	section.add_theme_constant_override("separation", 12)

	var label = Label.new()
	label.text = title
	label.add_theme_color_override("font_color", Color(0.6, 0.8, 1.0))
	section.add_child(label)

	return section

func _create_control_button(text: String) -> Button:
	var btn = Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(80, 32)
	btn.focus_mode = Control.FOCUS_NONE

	# 添加 Material Design 风格的背景样式
	var btn_style = _create_button_style(Color(0.35, 0.65, 0.95, 1), 6)
	var btn_hover = _create_button_style(Color(0.4, 0.7, 1.0, 1), 6)
	var btn_pressed = _create_button_style(Color(0.3, 0.6, 0.9, 1), 6)

	btn.add_theme_stylebox_override("normal", btn_style)
	btn.add_theme_stylebox_override("hover", btn_hover)
	btn.add_theme_stylebox_override("pressed", btn_pressed)
	btn.add_theme_stylebox_override("focus", btn_style)

	return btn

func _create_button_style(bg_color: Color, radius: int) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = bg_color
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	return style
