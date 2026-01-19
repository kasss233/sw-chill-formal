extends Control

## MaterialTextField 演示场景

var _default_field: MaterialTextField
var _transparent_field: MaterialTextField
var _frosted_field: MaterialTextField

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
	title.text = "MaterialTextField 输入框演示"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	main_container.add_child(title)

	# ========== 1. 纯色背景 ==========
	var section1 = _create_section("纯色背景 (SOLID)")
	main_container.add_child(section1)

	_default_field = MaterialTextField.new()
	_default_field.name = "DefaultField"
	_default_field.placeholder_text = "请输入内容..."
	_default_field.custom_minimum_size.x = 300
	section1.add_child(_default_field)

	var result_label1 = Label.new()
	result_label1.name = "Result1"
	result_label1.text = "等待输入..."
	result_label1.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	section1.add_child(result_label1)

	_default_field.text_changed.connect(func(text):
		result_label1.text = "输入内容: \"%s\"" % text
	)
	_default_field.text_submitted.connect(func(text):
		result_label1.text = "提交内容: \"%s\"" % text
		print("文本提交: ", text)
	)

	# ========== 2. 半透明背景 ==========
	var section2 = _create_section("半透明背景 (TRANSPARENT)")
	main_container.add_child(section2)

	_transparent_field = MaterialTextField.new()
	_transparent_field.name = "TransparentField"
	_transparent_field.placeholder_text = "半透明输入框..."
	_transparent_field.background_style = MaterialTextField.BackgroundStyle.TRANSPARENT
	_transparent_field.bg_opacity = 0.5
	_transparent_field.border_color = Color(1, 1, 1, 0.5)
	_transparent_field.border_color_focus = Color(0.35, 0.65, 0.95, 0.8)
	_transparent_field.custom_minimum_size.x = 300
	section2.add_child(_transparent_field)

	# ========== 3. 磨砂玻璃效果 ==========
	var section3 = _create_section("磨砂玻璃效果 (FROSTED)")
	main_container.add_child(section3)

	_frosted_field = MaterialTextField.new()
	_frosted_field.name = "FrostedField"
	_frosted_field.placeholder_text = "磨砂玻璃输入框..."
	_frosted_field.background_style = MaterialTextField.BackgroundStyle.FROSTED
	_frosted_field.bg_color = Color.WHITE
	_frosted_field.tint_color = Color(0, 0, 0, 0.2)
	_frosted_field.blur_amount = 3.0
	_frosted_field.custom_minimum_size.x = 300
	section3.add_child(_frosted_field)

	# ========== 4. 密码输入框 ==========
	var section4 = _create_section("密码输入框")
	main_container.add_child(section4)

	var password_field = MaterialTextField.new()
	password_field.name = "PasswordField"
	password_field.placeholder_text = "请输入密码..."
	password_field.is_password = true
	password_field.custom_minimum_size.x = 300
	section4.add_child(password_field)

	# ========== 5. 带图标的输入框 ==========
	var section5 = _create_section("带图标搜索框")
	main_container.add_child(section5)

	var search_field = MaterialTextField.new()
	search_field.name = "SearchField"
	search_field.placeholder_text = "搜索..."
	search_field.custom_minimum_size.x = 300
	section5.add_child(search_field)

	# 创建搜索图标
	var search_icon = _create_search_icon()
	search_field.icon = search_icon

	# ========== 6. 不同边框粗细 ==========
	var section6 = _create_section("不同边框粗细")
	main_container.add_child(section6)

	var border_row = HBoxContainer.new()
	border_row.add_theme_constant_override("separation", 16)
	section6.add_child(border_row)

	# 细边框
	var thin_field = MaterialTextField.new()
	thin_field.placeholder_text = "细边框 (1px)"
	thin_field.border_width = 1.0
	thin_field.custom_minimum_size.x = 180
	border_row.add_child(thin_field)

	# 标准边框
	var normal_field = MaterialTextField.new()
	normal_field.placeholder_text = "标准 (2px)"
	normal_field.border_width = 2.0
	normal_field.custom_minimum_size.x = 180
	border_row.add_child(normal_field)

	# 粗边框
	var thick_field = MaterialTextField.new()
	thick_field.placeholder_text = "粗边框 (4px)"
	thick_field.border_width = 4.0
	thick_field.custom_minimum_size.x = 180
	border_row.add_child(thick_field)

	# ========== 7. 不同高度 ==========
	var section7 = _create_section("不同高度")
	main_container.add_child(section7)

	var height_row = HBoxContainer.new()
	height_row.add_theme_constant_override("separation", 16)
	section7.add_child(height_row)

	# 紧凑型
	var compact_field = MaterialTextField.new()
	compact_field.placeholder_text = "紧凑 (36px)"
	compact_field.text_field_height = 36
	compact_field.custom_minimum_size.x = 180
	height_row.add_child(compact_field)

	# 标准型
	var standard_field = MaterialTextField.new()
	standard_field.placeholder_text = "标准 (48px)"
	standard_field.text_field_height = 48
	standard_field.custom_minimum_size.x = 180
	height_row.add_child(standard_field)

	# 大号
	var large_field = MaterialTextField.new()
	large_field.placeholder_text = "大号 (60px)"
	large_field.text_field_height = 60
	large_field.custom_minimum_size.x = 180
	height_row.add_child(large_field)

	# ========== 8. 交互控制 ==========
	var section8 = _create_section("交互控制")
	main_container.add_child(section8)

	var control_row = HBoxContainer.new()
	control_row.add_theme_constant_override("separation", 12)
	section8.add_child(control_row)

	var btn_clear = _create_button("清空输入")
	btn_clear.pressed.connect(func():
		_default_field.clear()
	)
	control_row.add_child(btn_clear)

	var btn_focus = _create_button("聚焦输入框")
	btn_focus.pressed.connect(func():
		_default_field.focus_text_field()
	)
	control_row.add_child(btn_focus)

	var btn_get_text = _create_button("获取文本")
	btn_get_text.pressed.connect(func():
		print("当前文本: ", _default_field.get_text())
	)
	control_row.add_child(btn_get_text)

func _create_section(title: String) -> VBoxContainer:
	var section = VBoxContainer.new()
	section.add_theme_constant_override("separation", 12)

	var label = Label.new()
	label.text = title
	label.add_theme_color_override("font_color", Color(0.6, 0.8, 1.0))
	section.add_child(label)

	return section

func _create_button(text: String) -> Button:
	var btn = Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(100, 36)
	btn.focus_mode = Control.FOCUS_NONE

	# 添加简单样式
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.35, 0.65, 0.95, 1)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6

	btn.add_theme_stylebox_override("normal", style)
	return btn

func _create_search_icon() -> Texture2D:
	# 创建一个简单的搜索图标
	var image = Image.new()
	image.create(24, 24, false, Image.FORMAT_RGBA8)

	# 填充透明背景
	image.fill(Color(0, 0, 0, 0))

	# 绘制简单的搜索放大镜图标
	for x in range(24):
		for y in range(24):
			var dx = x - 10
			var dy = y - 10
			var dist = sqrt(dx * dx + dy * dy)

			# 外圆
			if dist >= 5 and dist <= 7:
				image.set_pixel(x, y, Color(0.6, 0.6, 0.6, 1))

	# 手柄
	for x in range(14, 20):
		for y in range(14, 20):
			if abs(x - 17 - (y - 17)) < 1.5:
				image.set_pixel(x, y, Color(0.6, 0.6, 0.6, 1))

	var texture = ImageTexture.new()
	texture.set_image(image)
	return texture
