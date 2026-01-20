extends Control

## Material Dialog 组件演示
## 展示 MaterialDialog 的各种使用方法和对话框类型

var _dialog: MaterialDialog

func _ready() -> void:
	# 创建演示界面
	_setup_ui()

func _setup_ui() -> void:
	# 创建主容器
	var main_container = VBoxContainer.new()
	main_container.set_anchors_preset(Control.PRESET_CENTER)
	main_container.add_theme_constant_override("separation", 20)
	add_child(main_container)
	
	# 标题
	var title = Label.new()
	title.text = "Material Design Dialog 演示"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color.WHITE)
	main_container.add_child(title)
	
	# ========== 1. 信息对话框 ==========
	var info_section = _create_section("信息对话框")
	main_container.add_child(info_section)
	
	var info_button = MaterialButton.new()
	info_button.text = "显示信息对话框"
	info_button.button_size = MaterialButton.ButtonSize.MEDIUM40
	info_button.custom_minimum_size.x = 200
	info_button.pressed.connect(_on_info_button_pressed)
	info_section.add_child(info_button)
	
	# ========== 2. 确认对话框 ==========
	var confirm_section = _create_section("确认对话框")
	main_container.add_child(confirm_section)
	
	var confirm_button = MaterialButton.new()
	confirm_button.text = "显示确认对话框"
	confirm_button.button_size = MaterialButton.ButtonSize.MEDIUM40
	confirm_button.custom_minimum_size.x = 200
	confirm_button.pressed.connect(_on_confirm_button_pressed)
	confirm_section.add_child(confirm_button)
	
	# ========== 3. 警告对话框 ==========
	var warning_section = _create_section("警告对话框")
	main_container.add_child(warning_section)
	
	var warning_button = MaterialButton.new()
	warning_button.text = "显示警告对话框"
	warning_button.button_size = MaterialButton.ButtonSize.MEDIUM40
	warning_button.custom_minimum_size.x = 200
	warning_button.pressed.connect(_on_warning_button_pressed)
	warning_section.add_child(warning_button)
	
	# ========== 4. 错误对话框 ==========
	var error_section = _create_section("错误对话框")
	main_container.add_child(error_section)
	
	var error_button = MaterialButton.new()
	error_button.text = "显示错误对话框"
	error_button.button_size = MaterialButton.ButtonSize.MEDIUM40
	error_button.custom_minimum_size.x = 200
	error_button.pressed.connect(_on_error_button_pressed)
	error_section.add_child(error_button)
	
	# ========== 5. 自定义对话框 ==========
	var custom_section = _create_section("自定义对话框")
	main_container.add_child(custom_section)
	
	var custom_button = MaterialButton.new()
	custom_button.text = "显示自定义对话框"
	custom_button.button_size = MaterialButton.ButtonSize.MEDIUM40
	custom_button.custom_minimum_size.x = 200
	custom_button.pressed.connect(_on_custom_button_pressed)
	custom_section.add_child(custom_button)
	
	# ========== 6. 多按钮对话框 ==========
	var multi_button_section = _create_section("多按钮对话框")
	main_container.add_child(multi_button_section)
	
	var multi_button = MaterialButton.new()
	multi_button.text = "显示多按钮对话框"
	multi_button.button_size = MaterialButton.ButtonSize.MEDIUM40
	multi_button.custom_minimum_size.x = 200
	multi_button.pressed.connect(_on_multi_button_pressed)
	multi_button_section.add_child(multi_button)
	
	# ========== 7. 不同尺寸对话框 ==========
	var size_section = _create_section("不同尺寸对话框")
	main_container.add_child(size_section)
	
	var size_container = HBoxContainer.new()
	size_container.add_theme_constant_override("separation", 8)
	
	var small_button = MaterialButton.new()
	small_button.text = "小尺寸"
	small_button.button_size = MaterialButton.ButtonSize.STANDARD36
	small_button.pressed.connect(_on_size_button_pressed.bind(MaterialDialog.DialogSize.SMALL))
	size_container.add_child(small_button)
	
	var medium_button = MaterialButton.new()
	medium_button.text = "中等"
	medium_button.button_size = MaterialButton.ButtonSize.STANDARD36
	medium_button.pressed.connect(_on_size_button_pressed.bind(MaterialDialog.DialogSize.MEDIUM))
	size_container.add_child(medium_button)
	
	var large_button = MaterialButton.new()
	large_button.text = "大尺寸"
	large_button.button_size = MaterialButton.ButtonSize.STANDARD36
	large_button.pressed.connect(_on_size_button_pressed.bind(MaterialDialog.DialogSize.LARGE))
	size_container.add_child(large_button)
	
	size_section.add_child(size_container)
	
	# 状态显示
	var status_section = _create_section("状态")
	main_container.add_child(status_section)
	
	var status_label = Label.new()
	status_label.name = "StatusLabel"
	status_label.text = "等待操作..."
	status_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	status_section.add_child(status_label)
	
	# 创建对话框实例（可复用）
	_dialog = MaterialDialog.new()
	_dialog.name = "DemoDialog"
	add_child(_dialog)
	
	# 连接信号
	_dialog.dialog_confirmed.connect(_on_dialog_confirmed)
	_dialog.dialog_cancelled.connect(_on_dialog_cancelled)
	_dialog.dialog_closed.connect(_on_dialog_closed)
	_dialog.button_pressed.connect(_on_dialog_button_pressed)

func _create_section(title: String) -> VBoxContainer:
	var section = VBoxContainer.new()
	section.add_theme_constant_override("separation", 8)
	
	var label = Label.new()
	label.text = title
	label.add_theme_color_override("font_color", Color(0.6, 0.8, 1.0))
	section.add_child(label)
	
	return section

func _on_info_button_pressed() -> void:
	_dialog.show_info_dialog(
		"信息",
		"这是一个信息对话框示例。\n用于向用户展示一般性的信息。"
	)

func _on_confirm_button_pressed() -> void:
	_dialog.show_confirm_dialog(
		"确认操作",
		"确定要执行此操作吗？\n此操作不可撤销。"
	)

func _on_warning_button_pressed() -> void:
	_dialog.show_warning_dialog(
		"警告",
		"请注意：此操作可能会产生不可预期的结果。\n请谨慎操作。"
	)

func _on_error_button_pressed() -> void:
	_dialog.show_error_dialog(
		"错误",
		"发生了一个错误。\n请检查您的操作并重试。"
	)

func _on_custom_button_pressed() -> void:
	# 创建自定义对话框
	_dialog.dialog_title = "自定义对话框"
	_dialog.dialog_text = "这是一个自定义对话框示例。\n支持自定义标题、内容和按钮。"
	_dialog.dialog_type = MaterialDialog.DialogType.CUSTOM
	_dialog.dialog_size = MaterialDialog.DialogSize.MEDIUM
	
	# 清空并添加自定义按钮
	_dialog.clear_buttons()
	
	var save_btn = _dialog.add_button("保存", null, func(): _update_status("点击了保存按钮"))
	var cancel_btn = _dialog.add_button("取消", null, func(): _update_status("点击了取消按钮"))
	var delete_btn = _dialog.add_button("删除", null, func(): _update_status("点击了删除按钮"))
	
	# 可以设置按钮样式
	delete_btn.background_color = Color(0.8, 0.2, 0.2, 0.3)
	
	_dialog.show_dialog()

func _on_multi_button_pressed() -> void:
	_dialog.dialog_title = "多按钮对话框"
	_dialog.dialog_text = "这个对话框包含多个按钮，每个按钮都可以有独立的回调函数。"
	_dialog.dialog_type = MaterialDialog.DialogType.CUSTOM
	_dialog.clear_buttons()
	
	_dialog.add_button("选项 1", null, func(): _update_status("选择了选项 1"))
	_dialog.add_button("选项 2", null, func(): _update_status("选择了选项 2"))
	_dialog.add_button("选项 3", null, func(): _update_status("选择了选项 3"))
	_dialog.add_button("取消", null, func(): _update_status("取消了操作"))
	
	_dialog.show_dialog()

func _on_size_button_pressed(size: MaterialDialog.DialogSize) -> void:
	_dialog.dialog_size = size
	_dialog.dialog_title = "尺寸演示"
	_dialog.dialog_text = "这是 %s 尺寸的对话框。" % ["小", "中等", "大"][size]
	_dialog.clear_buttons()
	_dialog.add_button("确定")
	_dialog.show_dialog()

func _on_dialog_confirmed() -> void:
	_update_status("对话框已确认")

func _on_dialog_cancelled() -> void:
	_update_status("对话框已取消")

func _on_dialog_closed() -> void:
	_update_status("对话框已关闭")

func _on_dialog_button_pressed(button_index: int, button_text: String) -> void:
	_update_status("点击了按钮: %s (索引: %d)" % [button_text, button_index])

func _update_status(message: String) -> void:
	var status_label = get_node_or_null("VBoxContainer/StatusLabel")
	if not status_label:
		# 尝试其他路径
		for child in get_children():
			if child is VBoxContainer:
				for subchild in child.get_children():
					if subchild is VBoxContainer:
						for label in subchild.get_children():
							if label is Label and label.name == "StatusLabel":
								status_label = label
								break
	
	if status_label:
		status_label.text = message
	
	print(message)
