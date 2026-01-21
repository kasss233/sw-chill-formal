extends Control

## FrostedPanel 磨砂玻璃面板演示场景

func _ready() -> void:
	_setup_demo_ui()

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
	title.text = "FrostedPanel 磨砂玻璃面板演示"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	main_container.add_child(title)

	# ========== 1. 基础面板 ==========
	var section1 = _create_section("基础磨砂玻璃面板")
	main_container.add_child(section1)

	var panel1 = FrostedPanel.new()
	panel1.custom_minimum_size = Vector2(300, 120)
	section1.add_child(panel1)

	var label1 = Label.new()
	label1.text = "这是一个基础的 FrostedPanel\n带有磨砂玻璃效果、圆角和阴影"
	label1.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label1.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	panel1.add_child(label1)
	label1.set_anchors_preset(Control.PRESET_FULL_RECT)

	# ========== 2. 不同模糊程度 ==========
	var section2 = _create_section("不同模糊程度")
	main_container.add_child(section2)

	var blur_row = HBoxContainer.new()
	blur_row.add_theme_constant_override("separation", 16)
	section2.add_child(blur_row)

	var blurs = [0.0, 1.0, 2.0, 3.0, 5.0]

	for blur in blurs:
		var container = VBoxContainer.new()
		container.add_theme_constant_override("separation", 8)
		blur_row.add_child(container)

		var label = Label.new()
		label.text = "Blur %.1f" % blur
		label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
		container.add_child(label)

		var panel = FrostedPanel.new()
		panel.blur_amount = blur
		panel.custom_minimum_size = Vector2(80, 80)
		container.add_child(panel)

	# ========== 3. 不同圆角 ==========
	var section3 = _create_section("不同圆角半径")
	main_container.add_child(section3)

	var corner_row = HBoxContainer.new()
	corner_row.add_theme_constant_override("separation", 16)
	section3.add_child(corner_row)

	var radii = [0, 8, 12, 20, 32]

	for radius in radii:
		var container = VBoxContainer.new()
		container.add_theme_constant_override("separation", 8)
		corner_row.add_child(container)

		var label = Label.new()
		label.text = "R%d" % radius
		label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
		container.add_child(label)

		var panel = FrostedPanel.new()
		panel.corner_radius = radius
		panel.custom_minimum_size = Vector2(80, 80)
		container.add_child(panel)

	# ========== 4. 不同色调 ==========
	var section4 = _create_section("不同色调颜色")
	main_container.add_child(section4)

	var tint_row = HBoxContainer.new()
	tint_row.add_theme_constant_override("separation", 16)
	section4.add_child(tint_row)

	var tints = [
		Color(0, 0, 0, 0.2),
		Color(0, 0, 0, 0.5),
		Color(0.2, 0, 0, 0.3),
		Color(0, 0, 0.2, 0.3),
		Color(0.1, 0.1, 0.2, 0.4)
	]

	for i in range(tints.size()):
		var container = VBoxContainer.new()
		container.add_theme_constant_override("separation", 8)
		tint_row.add_child(container)

		var label = Label.new()
		label.text = ["浅黑", "深黑", "红色", "蓝色", "紫调"][i]
		label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
		container.add_child(label)

		var panel = FrostedPanel.new()
		panel.tint_color = tints[i]
		panel.custom_minimum_size = Vector2(80, 80)
		container.add_child(panel)

	# ========== 5. 不同边框 ==========
	var section5 = _create_section("不同边框样式")
	main_container.add_child(section5)

	var border_row = HBoxContainer.new()
	border_row.add_theme_constant_override("separation", 16)
	section5.add_child(border_row)

	# 无边框
	var container1 = VBoxContainer.new()
	container1.add_theme_constant_override("separation", 8)
	border_row.add_child(container1)
	var l1 = Label.new()
	l1.text = "无边框"
	l1.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	container1.add_child(l1)
	var p1 = FrostedPanel.new()
	p1.border_width = 0
	p1.custom_minimum_size = Vector2(80, 80)
	container1.add_child(p1)

	# 细边框
	var container2 = VBoxContainer.new()
	container2.add_theme_constant_override("separation", 8)
	border_row.add_child(container2)
	var l2 = Label.new()
	l2.text = "细边框"
	l2.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	container2.add_child(l2)
	var p2 = FrostedPanel.new()
	p2.border_width = 1
	p2.custom_minimum_size = Vector2(80, 80)
	container2.add_child(p2)

	# 粗边框
	var container3 = VBoxContainer.new()
	container3.add_theme_constant_override("separation", 8)
	border_row.add_child(container3)
	var l3 = Label.new()
	l3.text = "粗边框"
	l3.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	container3.add_child(l3)
	var p3 = FrostedPanel.new()
	p3.border_width = 3
	p3.custom_minimum_size = Vector2(80, 80)
	container3.add_child(p3)

	# 高亮边框
	var container4 = VBoxContainer.new()
	container4.add_theme_constant_override("separation", 8)
	border_row.add_child(container4)
	var l4 = Label.new()
	l4.text = "高亮"
	l4.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	container4.add_child(l4)
	var p4 = FrostedPanel.new()
	p4.border_width = 2
	p4.border_color = Color(0.35, 0.65, 0.95, 0.6)
	p4.custom_minimum_size = Vector2(80, 80)
	container4.add_child(p4)

	# ========== 6. 带内容的面板 ==========
	var section6 = _create_section("带内容的面板")
	main_container.add_child(section6)

	var content_panel = FrostedPanel.new()
	content_panel.custom_minimum_size = Vector2(400, 150)
	section6.add_child(content_panel)

	var content_vbox = VBoxContainer.new()
	content_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	content_vbox.offset_left = 24
	content_vbox.offset_top = 24
	content_vbox.offset_right = -24
	content_vbox.offset_bottom = -24
	content_vbox.add_theme_constant_override("separation", 12)
	content_panel.add_child(content_vbox)

	var content_title = Label.new()
	content_title.text = "面板标题"
	content_title.add_theme_font_size_override("font_size", 20)
	content_vbox.add_child(content_title)

	var content_desc = Label.new()
	content_desc.text = "FrostedPanel 使用 shader 实现磨砂玻璃效果。\n支持模糊程度、色调、边框和阴影的自定义配置。"
	content_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content_vbox.add_child(content_desc)

	# ========== 7. 卡片组 ==========
	var section7 = _create_section("卡片组")
	main_container.add_child(section7)

	var card_row = HBoxContainer.new()
	card_row.add_theme_constant_override("separation", 16)
	section7.add_child(card_row)

	for i in range(3):
		var card = FrostedPanel.new()
		card.custom_minimum_size = Vector2(120, 140)
		card_row.add_child(card)

		var card_vbox = VBoxContainer.new()
		card_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
		card_vbox.offset_left = 16
		card_vbox.offset_top = 16
		card_vbox.offset_right = -16
		card_vbox.offset_bottom = -16
		card_vbox.add_theme_constant_override("separation", 8)
		card.add_child(card_vbox)

		var icon = ColorRect.new()
		icon.custom_minimum_size = Vector2(40, 40)
		icon.color = Color(0.35, 0.65, 0.95, 0.3)
		card_vbox.add_child(icon)

		var card_title = Label.new()
		card_title.text = "卡片 %d" % (i + 1)
		card_title.add_theme_font_size_override("font_size", 16)
		card_vbox.add_child(card_title)

		var card_desc = Label.new()
		card_desc.text = "这是一张卡片的内容描述"
		card_desc.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
		card_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		card_vbox.add_child(card_desc)

	# ========== 8. 交互控制 ==========
	var section8 = _create_section("交互控制")
	main_container.add_child(section8)

	var demo_panel = FrostedPanel.new()
	demo_panel.name = "DemoPanel"
	demo_panel.corner_radius = 16
	demo_panel.border_width = 2
	demo_panel.custom_minimum_size = Vector2(300, 100)
	section8.add_child(demo_panel)

	var demo_label = Label.new()
	demo_label.text = "演示面板\n模糊: 3.0, 圆角: 16"
	demo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	demo_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	demo_panel.add_child(demo_label)
	demo_label.set_anchors_preset(Control.PRESET_FULL_RECT)

	var control_row = HBoxContainer.new()
	control_row.add_theme_constant_override("separation", 12)
	section8.add_child(control_row)

	var btn_blur = _create_control_button("调整模糊")
	btn_blur.pressed.connect(func():
		demo_panel.blur_amount = fmod(demo_panel.blur_amount + 1.0, 6.0)
		demo_label.text = "演示面板\n模糊: %.1f, 圆角: %.0f" % [demo_panel.blur_amount, demo_panel.corner_radius]
	)
	control_row.add_child(btn_blur)

	var btn_corner = _create_control_button("调整圆角")
	btn_corner.pressed.connect(func():
		demo_panel.corner_radius = fmod(demo_panel.corner_radius + 4, 36)
		demo_label.text = "演示面板\n模糊: %.1f, 圆角: %.0f" % [demo_panel.blur_amount, demo_panel.corner_radius]
	)
	control_row.add_child(btn_corner)

	var btn_tint = _create_control_button("切换色调")
	btn_tint.pressed.connect(func():
		demo_panel.tint_color = Color(0, 0, 0, 0.6) if demo_panel.tint_color.a < 0.5 else Color(0.2, 0, 0, 0.4)
	)
	control_row.add_child(btn_tint)

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
	btn.custom_minimum_size = Vector2(100, 36)
	btn.focus_mode = Control.FOCUS_NONE

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.35, 0.65, 0.95, 1)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6

	btn.add_theme_stylebox_override("normal", style)
	return btn
