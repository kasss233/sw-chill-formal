extends Control

## MaterialDialog Demo 对话框示例场景

func _ready() -> void:
	pass

func _on_show_info_pressed() -> void:
	var dialog = MaterialDialog.new()
	add_child(dialog)
	dialog.dialog_title = "信息"
	dialog.dialog_text = "这是一个信息对话框\n用于显示一般性的提示信息"
	dialog.dialog_type = MaterialDialog.DialogType.INFO
	dialog.show_dialog()

func _on_show_info_with_icon_pressed() -> void:
	var dialog = MaterialDialog.new()
	add_child(dialog)
	dialog.dialog_title = "信息"
	dialog.dialog_text = "这是一个带图标的信息对话框\n图标可以是对话框类型、自定义图标等"
	dialog.dialog_type = MaterialDialog.DialogType.INFO
	# 可以设置自定义图标
	# dialog.dialog_icon = preload("res://path/to/icon.svg")
	dialog.show_dialog()

func _on_show_warning_pressed() -> void:
	var dialog = MaterialDialog.new()
	add_child(dialog)
	dialog.dialog_title = "警告"
	dialog.dialog_text = "这是一个警告对话框\n用于提示用户注意某些事项\n操作可能导致不可逆的结果"
	dialog.dialog_type = MaterialDialog.DialogType.WARNING
	dialog.show_dialog()

func _on_show_error_pressed() -> void:
	var dialog = MaterialDialog.new()
	add_child(dialog)
	dialog.dialog_title = "错误"
	dialog.dialog_text = "这是一个错误对话框\n用于提示错误信息\n请检查输入并重试"
	dialog.dialog_type = MaterialDialog.DialogType.ERROR
	dialog.show_dialog()

func _on_show_question_pressed() -> void:
	var dialog = MaterialDialog.new()
	add_child(dialog)
	dialog.dialog_title = "确认操作"
	dialog.dialog_text = "您确定要执行此操作吗？\n此操作无法撤销"
	dialog.dialog_type = MaterialDialog.DialogType.QUESTION
	dialog.add_button("取消")
	dialog.add_button("确定")
	dialog.show_dialog()

func _on_show_custom_pressed() -> void:
	var dialog = MaterialDialog.new()
	add_child(dialog)
	dialog.dialog_title = "自定义样式"
	dialog.dialog_text = "这是一个自定义对话框\n你可以调整颜色、圆角、阴影等样式参数\n也可以添加自定义的按钮和图标"
	dialog.dialog_type = MaterialDialog.DialogType.CUSTOM
	# 调整一些样式参数
	dialog.tint_color = Color(0.1, 0.05, 0.15, 0.65)
	dialog.corner_radius = 16
	dialog.add_button("知道了")
	dialog.show_dialog()

func _on_show_three_pressed() -> void:
	var dialog = MaterialDialog.new()
	add_child(dialog)
	dialog.dialog_title = "选择操作"
	dialog.dialog_text = "请选择一个操作："
	dialog.dialog_type = MaterialDialog.DialogType.INFO
	dialog.add_button("删除")
	dialog.add_button("重命名")
	dialog.add_button("取消")
	dialog.show_dialog()

func _on_show_many_pressed() -> void:
	var dialog = MaterialDialog.new()
	add_child(dialog)
	dialog.dialog_title = "批量操作"
	dialog.dialog_text = "选择要执行的操作："
	dialog.dialog_type = MaterialDialog.DialogType.WARNING
	dialog.add_button("全部选中")
	dialog.add_button("全部取消")
	dialog.add_button("反选")
	dialog.add_button("删除选中项")
	dialog.add_button("导出数据")
	dialog.show_dialog()

func _on_show_long_text_pressed() -> void:
	var dialog = MaterialDialog.new()
	add_child(dialog)
	dialog.dialog_title = "使用说明"
	dialog.dialog_text = "这是一段较长的文本内容，用于测试对话框在内容较多时的显示效果。\n\n对话框会自动调整高度以适应内容，同时保持合理的宽度和内边距。\n\n如果内容非常长，可以考虑使用可滚动的文本区域，或者将内容分段显示。"
	dialog.dialog_type = MaterialDialog.DialogType.INFO
	dialog.show_dialog()

## 显示带 LineEdit 的对话框
func _on_show_line_edit_dialog() -> void:
	var dialog = MaterialDialog.new()
	add_child(dialog)
	dialog.dialog_title = "输入名称"

	# 创建包含标签和输入框的容器
	var vbox = VBoxContainer.new()
	vbox.name = "InputContent"

	# 添加说明标签
	var hint_label = Label.new()
	hint_label.text = "请输入您的名称："
	hint_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	hint_label.add_theme_font_size_override("font_size", 14)
	vbox.add_child(hint_label)

	# 添加输入框
	var line_edit = LineEdit.new()
	line_edit.placeholder_text = "在此输入..."
	line_edit.custom_minimum_size = Vector2(200, 36)
	vbox.add_child(line_edit)

	# 设置为自定义内容
	dialog.set_custom_content(vbox)

	# 添加按钮
	dialog.add_button("取消")
	var confirm_btn = dialog.add_button("确定")
	confirm_btn.pressed.connect(func():
		print("用户输入的名称: ", line_edit.text)
	)

	dialog.show_dialog()

## 显示带 SpinBox 的对话框
func _on_show_spin_box_dialog() -> void:
	var dialog = MaterialDialog.new()
	add_child(dialog)
	dialog.dialog_title = "选择数量"

	# 创建包含标签和数字输入框的容器
	var vbox = VBoxContainer.new()
	vbox.name = "SpinBoxContent"

	# 添加说明标签
	var hint_label = Label.new()
	hint_label.text = "请选择要添加的项目数量："
	hint_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	hint_label.add_theme_font_size_override("font_size", 14)
	vbox.add_child(hint_label)

	# 添加数字输入框
	var spin_box = SpinBox.new()
	spin_box.min_value = 1
	spin_box.max_value = 100
	spin_box.value = 10
	spin_box.custom_minimum_size = Vector2(150, 36)
	vbox.add_child(spin_box)

	# 设置为自定义内容
	dialog.set_custom_content(vbox)

	# 添加按钮
	dialog.add_button("取消")
	var confirm_btn = dialog.add_button("确定")
	confirm_btn.pressed.connect(func():
		print("用户选择的数量: ", spin_box.value)
	)

	dialog.show_dialog()

## 显示带 CheckBox 的对话框
func _on_show_check_box_dialog() -> void:
	var dialog = MaterialDialog.new()
	add_child(dialog)
	dialog.dialog_title = "设置选项"

	# 创建包含多个复选框的容器
	var vbox = VBoxContainer.new()
	vbox.name = "CheckBoxContent"
	vbox.add_theme_constant_override("separation", 12)

	# 添加说明标签
	var hint_label = Label.new()
	hint_label.text = "请选择您需要的选项："
	hint_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	hint_label.add_theme_font_size_override("font_size", 14)
	vbox.add_child(hint_label)

	# 创建复选框
	var check1 = CheckBox.new()
	check1.text = "启用自动保存"
	check1.button_pressed = true
	vbox.add_child(check1)

	var check2 = CheckBox.new()
	check2.text = "显示通知"
	check2.button_pressed = true
	vbox.add_child(check2)

	var check3 = CheckBox.new()
	check3.text = "启用声音效果"
	vbox.add_child(check3)

	# 设置为自定义内容
	dialog.set_custom_content(vbox)

	# 添加按钮
	dialog.add_button("取消")
	var confirm_btn = dialog.add_button("保存")
	confirm_btn.pressed.connect(func():
		print("自动保存: ", check1.button_pressed)
		print("显示通知: ", check2.button_pressed)
		print("声音效果: ", check3.button_pressed)
	)

	dialog.show_dialog()
