@tool
class_name MaterialMenuButton
extends MaterialButton

## Material Design 风格菜单按钮
## 点击时弹出下拉菜单

signal menu_item_pressed(index: int, item: MaterialMenuItem)

## 关联的菜单
@export var menu: MaterialMenu:
	set(value):
		# 断开旧菜单的信号
		if menu and menu.item_pressed.is_connected(_on_menu_item_pressed):
			menu.item_pressed.disconnect(_on_menu_item_pressed)

		menu = value

		# 连接新菜单的信号
		if menu and not menu.item_pressed.is_connected(_on_menu_item_pressed):
			menu.item_pressed.connect(_on_menu_item_pressed)

## 菜单弹出位置
@export_enum("下方", "右侧", "鼠标位置") var popup_position: int = 0

## 菜单偏移量
@export var menu_offset: Vector2 = Vector2(0, 4)

## 是否在按钮禁用时也禁用菜单
@export var disable_menu_when_disabled: bool = true

func _ready() -> void:
	# 确保涟漪效果启用
	enable_ripple = true

	super._ready()

	# 连接按钮点击信号
	if not pressed.is_connected(_on_button_pressed):
		pressed.connect(_on_button_pressed)

	# 连接菜单信号
	if menu and not menu.item_pressed.is_connected(_on_menu_item_pressed):
		menu.item_pressed.connect(_on_menu_item_pressed)

func _on_button_pressed() -> void:
	if not menu:
		return

	if disable_menu_when_disabled and disabled:
		return

	if menu.visible:
		menu.hide_menu()
	else:
		_show_menu()

func _show_menu() -> void:
	if not menu:
		return

	match popup_position:
		0:  # 下方
			menu.popup_below(self, menu_offset)
		1:  # 右侧
			menu.popup_beside(self, menu_offset)
		2:  # 鼠标位置
			menu.popup_at_mouse()

func _on_menu_item_pressed(index: int, item: MaterialMenuItem) -> void:
	menu_item_pressed.emit(index, item)

# ============ 便捷方法 ============

## 创建并设置菜单
func create_menu() -> MaterialMenu:
	if not menu:
		menu = MaterialMenu.new()
		menu.name = "DropdownMenu"
		
		# 添加到按钮自身作为子节点
		if is_inside_tree():
			add_child(menu)
			# 设置为顶层节点，确保 global_position 正确工作
			menu.set_as_top_level(true)
	
	return menu

## 添加菜单项
func add_menu_item(text: String, icon: Texture2D = null, shortcut: String = "") -> MaterialMenuItem:
	if not menu:
		create_menu()
	
	return menu.add_item(text, icon, shortcut)

## 添加可选中菜单项
func add_check_menu_item(text: String, is_checked: bool = false, icon: Texture2D = null) -> MaterialMenuItem:
	if not menu:
		create_menu()
	
	return menu.add_check_item(text, is_checked, icon)

## 添加分隔线
func add_menu_separator() -> MaterialMenuSeparator:
	if not menu:
		create_menu()
	
	return menu.add_separator()

## 清空菜单
func clear_menu() -> void:
	if menu:
		menu.clear_items()

## 显示菜单
func show_menu() -> void:
	_show_menu()

## 隐藏菜单
func hide_menu() -> void:
	if menu:
		menu.hide_menu()
