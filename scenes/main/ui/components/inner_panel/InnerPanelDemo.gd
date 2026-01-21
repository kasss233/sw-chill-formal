extends Control

## InnerPanel 内部子面板演示场景

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
	title.text = "InnerPanel 内部子面板演示"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	main_container.add_child(title)

	# ========== 1. 基础面板 ==========
	var section1 = _create_section("基础面板")
	main_container.add_child(section1)

	var panel1 = InnerPanel.new()
	panel1.custom_minimum_size = Vector2(300, 120)
	section1.add_child(panel1)

	var label1 = Label.new()
	label1.text = "这是一个基础的 InnerPanel\n带有圆角和边框效果\n可用于在 FrostedPanel 内部作为子容器"
	label1.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label1.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	panel1.add_child(label1)
	label1.set_anchors_preset(Control.PRESET_FULL_RECT)

	# ========== 2. 不同圆角 ==========
	var section2 = _create_section("不同圆角半径")
	main_container.add_child(section2)

	var corner_row = HBoxContainer.new()
	corner_row.add_theme_constant_override("separation", 16)
	section2.add_child(corner_row)

	var radii = [0, 4, 8, 16, 24]

	for radius in radii:
		var container = VBoxContainer.new()
		container.add_theme_constant_override("separation", 8)
		corner_row.add_child(container)

		var label = Label.new()
		label.text = "R%d" % radius
		label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
		container.add_child(label)

		var panel = InnerPanel.new()
		panel.corner_radius = radius
		panel.custom_minimum_size = Vector2(80, 80)
		container.add_child(panel)

	# ========== 3. 不同边框宽度 ==========
	var section3 = _create_section("不同边框宽度")
	main_container.add_child(section3)

	var border_row = HBoxContainer.new()
	border_row.add_theme_constant_override("separation", 16)
	section3.add_child(border_row)

	var border_widths = [0, 1, 2, 4, 6]

	for width in border_widths:
		var container = VBoxContainer.new()
		container.add_theme_constant_override("separation", 8)
		border_row.add_child(container)

		var label = Label.new()
		label.text = "%dpx" % width
		label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
		container.add_child(label)

		var panel = InnerPanel.new()
		panel.border_width = width
		panel.custom_minimum_size = Vector2(80, 80)
		container.add_child(panel)

	# ========== 4. 不同背景透明度 ==========
	var section4 = _create_section("不同背景透明度")
	main_container.add_child(section4)

	var alpha_row = HBoxContainer.new()
	alpha_row.add_theme_constant_override("separation", 16)
	section4.add_child(alpha_row)

	var alphas = [0.0, 0.05, 0.1, 0.2, 0.4]

	for alpha in alphas:
		var container = VBoxContainer.new()
		container.add_theme_constant_override("separation", 8)
		alpha_row.add_child(container)

		var label = Label.new()
		label.text = "%.2f" % alpha
		label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
		container.add_child(label)

		var panel = InnerPanel.new()
		panel.background_color = Color(1, 1, 1, alpha)
		panel.custom_minimum_size = Vector2(80, 80)
		container.add_child(panel)

	# ========== 5. 带内容的面板 ==========
	var section5 = _create_section("带内容的面板")
	main_container.add_child(section5)

	var content_panel = InnerPanel.new()
	content_panel.custom_minimum_size = Vector2(400, 150)
	section5.add_child(content_panel)

	var content_vbox = VBoxContainer.new()
	content_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	content_vbox.offset_left = 16
	content_vbox.offset_top = 16
	content_vbox.offset_right = -16
	content_vbox.offset_bottom = -16
	content_vbox.add_theme_constant_override("separation", 12)
	content_panel.add_child(content_vbox)

	var content_title = Label.new()
	content_title.text = "面板标题"
	content_title.add_theme_font_size_override("font_size", 18)
	content_vbox.add_child(content_title)

	var content_desc = Label.new()
	content_desc.text = "这是一个带有内容的 InnerPanel 示例。\nInnerPanel 使用 shader 实现圆角和边框效果，\n适合作为 FrostedPanel 等外部面板的内部容器。"
	content_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content_vbox.add_child(content_desc)

	# ========== 6. 嵌套面板 ==========
	var section6 = _create_section("嵌套面板")
	main_container.add_child(section6)

	var outer_panel = InnerPanel.new()
	outer_panel.corner_radius = 16
	outer_panel.border_color = Color(0.5, 0.5, 0.5, 0.3)
	outer_panel.custom_minimum_size = Vector2(400, 200)
	section6.add_child(outer_panel)

	var outer_vbox = VBoxContainer.new()
	outer_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	outer_vbox.offset_left = 16
	outer_vbox.offset_top = 16
	outer_vbox.offset_right = -16
	outer_vbox.offset_bottom = -16
	outer_vbox.add_theme_constant_override("separation", 12)
	outer_panel.add_child(outer_vbox)

	var outer_label = Label.new()
	outer_label.text = "外部面板"
	outer_label.add_theme_font_size_override("font_size", 16)
	outer_vbox.add_child(outer_label)

	var inner_panel = InnerPanel.new()
	inner_panel.corner_radius = 8
	inner_panel.border_color = Color(0.35, 0.65, 0.95, 0.5)
	inner_panel.custom_minimum_size = Vector2(0, 80)
	outer_vbox.add_child(inner_panel)

	var inner_label = Label.new()
	inner_label.text = "内部嵌套的面板"
	inner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	inner_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	inner_panel.add_child(inner_label)
	inner_label.set_anchors_preset(Control.PRESET_FULL_RECT)

	# ========== 7. 交互控制 ==========
	var section7 = _create_section("交互控制")
	main_container.add_child(section7)

	var demo_panel = InnerPanel.new()
	demo_panel.name = "DemoPanel"
	demo_panel.corner_radius = 12
	demo_panel.border_width = 2
	demo_panel.custom_minimum_size = Vector2(300, 100)
	section7.add_child(demo_panel)

	var demo_label = Label.new()
	demo_label.text = "演示面板\n圆角: 12, 边框: 2px"
	demo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	demo_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	demo_panel.add_child(demo_label)
	demo_label.set_anchors_preset(Control.PRESET_FULL_RECT)

	var control_row = HBoxContainer.new()
	control_row.add_theme_constant_override("separation", 12)
	section7.add_child(control_row)

	var btn_increase = _create_control_button("增加圆角")
	btn_increase.pressed.connect(func():
		demo_panel.corner_radius = mini(demo_panel.corner_radius + 4, 32)
		demo_label.text = "演示面板\n圆角: %d, 边框: %.0fpx" % [demo_panel.corner_radius, demo_panel.border_width]
	)
	control_row.add_child(btn_increase)

	var btn_decrease = _create_control_button("减小圆角")
	btn_decrease.pressed.connect(func():
		demo_panel.corner_radius = maxi(demo_panel.corner_radius - 4, 0)
		demo_label.text = "演示面板\n圆角: %d, 边框: %.0fpx" % [demo_panel.corner_radius, demo_panel.border_width]
	)
	control_row.add_child(btn_decrease)

	var btn_border = _create_control_button("切换边框")
	btn_border.pressed.connect(func():
		demo_panel.border_width = 4.0 if demo_panel.border_width == 2.0 else 2.0
		demo_label.text = "演示面板\n圆角: %d, 边框: %.0fpx" % [demo_panel.corner_radius, demo_panel.border_width]
	)
	control_row.add_child(btn_border)

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
