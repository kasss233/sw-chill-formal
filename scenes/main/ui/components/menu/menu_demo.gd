extends Control

## Material Menu 组件演示
## 展示 MaterialMenu、MaterialMenuButton、MaterialContextMenu 的使用方法

var _dropdown_menu: MaterialMenu
var _context_menu: MaterialContextMenu
var _submenu: MaterialMenu

func _ready() -> void:
	# 创建演示界面
	_setup_ui()

func _setup_ui() -> void:
	# 创建主容器
	var main_container = VBoxContainer.new()
	main_container.set_anchors_preset(Control.PRESET_TOP_LEFT)
	main_container.add_theme_constant_override("separation", 20)
	add_child(main_container)
	
	# 标题
	var title = Label.new()
	title.text = "Material Design Menu 演示"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	main_container.add_child(title)
	
	# ========== 1. 下拉菜单按钮演示 ==========
	var dropdown_section = _create_section("下拉菜单按钮")
	main_container.add_child(dropdown_section)
	
	var menu_button = MaterialMenuButton.new()
	menu_button.text = "点击打开菜单"
	menu_button.button_size = MaterialButton.ButtonSize.MEDIUM40
	menu_button.custom_minimum_size.x = 160
	dropdown_section.add_child(menu_button)
	
	# 创建下拉菜单
	_dropdown_menu = MaterialMenu.new()
	_dropdown_menu.name = "DropdownMenu"
	add_child(_dropdown_menu)
	
	# 添加菜单项
	_dropdown_menu.add_item("新建文件", null, "Ctrl+N")
	_dropdown_menu.add_item("打开文件", null, "Ctrl+O")
	_dropdown_menu.add_item("保存", null, "Ctrl+S")
	_dropdown_menu.add_separator()
	_dropdown_menu.add_check_item("自动保存", true)
	_dropdown_menu.add_check_item("显示行号", false)
	_dropdown_menu.add_separator()
	
	# 创建子菜单
	_submenu = MaterialMenu.new()
	_submenu.name = "RecentFilesSubmenu"
	_submenu.add_item("project.gd")
	_submenu.add_item("main.tscn")
	_submenu.add_item("settings.cfg")
	add_child(_submenu)
	
	_dropdown_menu.add_submenu("最近打开", _submenu)
	_dropdown_menu.add_separator()
	_dropdown_menu.add_item("退出", null, "Alt+F4")
	
	# 连接菜单到按钮
	menu_button.menu = _dropdown_menu
	
	# 连接信号
	_dropdown_menu.item_pressed.connect(_on_dropdown_item_pressed)
	
	# ========== 2. 右键菜单演示 ==========
	var context_section = _create_section("右键菜单 (在下方区域右键点击)")
	main_container.add_child(context_section)
	
	var context_area = Panel.new()
	context_area.custom_minimum_size = Vector2(300, 100)
	
	var context_style = StyleBoxFlat.new()
	context_style.bg_color = Color(0.2, 0.2, 0.2, 0.8)
	context_style.corner_radius_top_left = 8
	context_style.corner_radius_top_right = 8
	context_style.corner_radius_bottom_left = 8
	context_style.corner_radius_bottom_right = 8
	context_style.border_color = Color(0.4, 0.4, 0.4)
	context_style.border_width_left = 1
	context_style.border_width_right = 1
	context_style.border_width_top = 1
	context_style.border_width_bottom = 1
	context_area.add_theme_stylebox_override("panel", context_style)
	
	var context_label = Label.new()
	context_label.text = "在此区域右键点击"
	context_label.set_anchors_preset(Control.PRESET_CENTER)
	context_area.add_child(context_label)
	
	context_section.add_child(context_area)
	
	# 创建右键菜单
	_context_menu = MaterialContextMenu.new()
	_context_menu.name = "ContextMenu"
	_context_menu.attach_to(context_area)
	add_child(_context_menu)
	
	_context_menu.add_item("复制", null, "Ctrl+C")
	_context_menu.add_item("粘贴", null, "Ctrl+V")
	_context_menu.add_item("剪切", null, "Ctrl+X")
	_context_menu.add_separator()
	_context_menu.add_item("全选", null, "Ctrl+A")
	_context_menu.add_separator()
	_context_menu.add_item("删除")
	
	_context_menu.item_pressed.connect(_on_context_item_pressed)
	
	# ========== 3. 直接弹出菜单演示 ==========
	var popup_section = _create_section("在按钮位置弹出菜单")
	main_container.add_child(popup_section)
	
	var popup_button = MaterialButton.new()
	popup_button.text = "在此按钮下方弹出"
	popup_button.button_size = MaterialButton.ButtonSize.MEDIUM40
	popup_button.custom_minimum_size.x = 180
	popup_button.pressed.connect(_on_popup_button_pressed.bind(popup_button))
	popup_section.add_child(popup_button)
	
	# 状态显示
	var status_section = _create_section("状态")
	main_container.add_child(status_section)
	
	var status_label = Label.new()
	status_label.name = "StatusLabel"
	status_label.text = "等待操作..."
	status_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	status_section.add_child(status_label)

func _create_section(title: String) -> VBoxContainer:
	var section = VBoxContainer.new()
	section.add_theme_constant_override("separation", 8)
	
	var label = Label.new()
	label.text = title
	label.add_theme_color_override("font_color", Color(0.6, 0.8, 1.0))
	section.add_child(label)
	
	return section

func _on_dropdown_item_pressed(index: int, item: MaterialMenuItem) -> void:
	_update_status("下拉菜单: 选择了 \"%s\" (索引: %d)" % [item.label_text, index])

func _on_context_item_pressed(index: int, item: MaterialMenuItem) -> void:
	_update_status("右键菜单: 选择了 \"%s\" (索引: %d)" % [item.label_text, index])

func _on_popup_button_pressed(button: MaterialButton) -> void:
	# 创建临时菜单
	var popup_menu = MaterialMenu.new()
	popup_menu.add_item("选项 1")
	popup_menu.add_item("选项 2")
	popup_menu.add_item("选项 3")
	add_child(popup_menu)
	
	popup_menu.item_pressed.connect(func(index: int, item: MaterialMenuItem):
		_update_status("弹出菜单: 选择了 \"%s\"" % item.label_text)
	)
	
	popup_menu.menu_closed.connect(func():
		# 菜单关闭后延迟删除
		await get_tree().create_timer(0.5).timeout
		popup_menu.queue_free()
	)
	
	popup_menu.popup_below(button)

func _update_status(message: String) -> void:
	var status_label = get_node_or_null("VBoxContainer/VBoxContainer/StatusLabel")
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
