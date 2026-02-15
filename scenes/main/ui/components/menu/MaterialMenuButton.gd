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
		if menu and menu.menu_closed.is_connected(_on_menu_closed):
			menu.menu_closed.disconnect(_on_menu_closed)

		menu = value

		# 连接新菜单的信号
		if menu:
			if not menu.item_pressed.is_connected(_on_menu_item_pressed):
				menu.item_pressed.connect(_on_menu_item_pressed)
			if not menu.menu_closed.is_connected(_on_menu_closed):
				menu.menu_closed.connect(_on_menu_closed)

## 菜单弹出位置
@export_enum("下方", "右侧", "鼠标位置", "上方", "左侧") var popup_position: int = 0

## 菜单偏移量
@export var menu_offset: Vector2 = Vector2(0, 4)

## 是否在按钮禁用时也禁用菜单
@export var disable_menu_when_disabled: bool = true

@export_group("展开图标")

## 展开图标 (右侧下拉箭头)
@export var dropdown_icon: Texture2D:
	set(value):
		dropdown_icon = value
		_update_dropdown_icon()

## 展开图标大小
@export_range(8, 32, 1) var dropdown_icon_size: int = 16:
	set(value):
		dropdown_icon_size = value
		_update_dropdown_icon()

## 展开图标与内容的间距
@export_range(0, 16, 1) var dropdown_icon_gap: int = 4:
	set(value):
		dropdown_icon_gap = value
		_update_dropdown_icon()

## 菜单打开时旋转展开图标 (度数)
@export_range(-180, 180, 1) var dropdown_icon_rotation_opened: float = 180.0

@export_group("选中同步")

## 是否在菜单项选中时同步更新按钮的图标和文字
@export var sync_selected_item: bool = false

## 当前选中的菜单项索引 (-1 表示未选中)
@export var selected_index: int = -1:
	set(value):
		selected_index = value
		_sync_selected_item_display()

@export_group("")

# 内部节点
var _dropdown_icon_rect: TextureRect
var _dropdown_tween: Tween

# 原始按钮属性（用于恢复）
var _original_text: String = ""
var _original_icon: Texture2D = null
var _is_menu_open: bool = false

func _ready() -> void:
	# 确保涟漪效果启用
	enable_ripple = true

	# 保存原始属性
	_original_text = text
	_original_icon = button_icon

	super._ready()

	# 创建展开图标
	_setup_dropdown_icon()

	# 连接按钮点击信号
	if not pressed.is_connected(_on_button_pressed):
		pressed.connect(_on_button_pressed)

	# 连接菜单信号
	if menu:
		if not menu.item_pressed.is_connected(_on_menu_item_pressed):
			menu.item_pressed.connect(_on_menu_item_pressed)
		if not menu.menu_closed.is_connected(_on_menu_closed):
			menu.menu_closed.connect(_on_menu_closed)

func _setup_dropdown_icon() -> void:
	if not _dropdown_icon_rect:
		_dropdown_icon_rect = TextureRect.new()
		_dropdown_icon_rect.name = "DropdownIcon"
		_dropdown_icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_dropdown_icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_dropdown_icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		add_child(_dropdown_icon_rect)

	_update_dropdown_icon()

func _update_dropdown_icon() -> void:
	if not is_inside_tree() or not _dropdown_icon_rect:
		return

	_dropdown_icon_rect.texture = dropdown_icon
	_dropdown_icon_rect.visible = dropdown_icon != null

	if dropdown_icon:
		_dropdown_icon_rect.custom_minimum_size = Vector2(dropdown_icon_size, dropdown_icon_size)
		_dropdown_icon_rect.size = Vector2(dropdown_icon_size, dropdown_icon_size)
		_update_dropdown_icon_position()

func _update_dropdown_icon_position() -> void:
	if not _dropdown_icon_rect or not dropdown_icon:
		return

	var button_height = size.y if size.y > 0 else custom_minimum_size.y
	var button_width = size.x if size.x > 0 else custom_minimum_size.x

	# 展开图标放在按钮右侧，使用较小的边距
	var right_margin = padding_horizontal / 2.0
	var icon_x = button_width - right_margin - dropdown_icon_size
	var icon_y = (button_height - dropdown_icon_size) / 2.0

	_dropdown_icon_rect.position = Vector2(icon_x, icon_y)

	# 设置旋转中心点
	_dropdown_icon_rect.pivot_offset = Vector2(dropdown_icon_size / 2.0, dropdown_icon_size / 2.0)

func _notification(what: int) -> void:
	super._notification(what)
	if what == NOTIFICATION_RESIZED:
		_update_dropdown_icon_position()

func _draw() -> void:
	# 如果有展开图标，用背景色遮挡可能溢出的文字
	if dropdown_icon and _dropdown_icon_rect:
		var button_height = size.y
		var button_width = size.x
		var right_margin = padding_horizontal / 2.0

		# 计算遮挡区域（展开图标左侧到按钮右边缘）
		var mask_x = button_width - right_margin - dropdown_icon_size - dropdown_icon_gap
		var mask_width = dropdown_icon_size + dropdown_icon_gap + right_margin

		# 获取当前背景色
		var bg_color = background_color
		if bg_color.a > 0:
			draw_rect(Rect2(mask_x, 0, mask_width, button_height), bg_color)

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

	_is_menu_open = true
	_animate_dropdown_icon(true)

	match popup_position:
		0:  # 下方
			menu.popup_below(self, menu_offset)
		1:  # 右侧
			menu.popup_beside(self, menu_offset)
		2:  # 鼠标位置
			menu.popup_at_mouse()
		3:  # 上方
			menu.popup_above(self, menu_offset)
		4:  # 左侧
			menu.popup_beside_left(self, menu_offset)

func _on_menu_closed() -> void:
	_is_menu_open = false
	_animate_dropdown_icon(false)

func _animate_dropdown_icon(opening: bool) -> void:
	if not _dropdown_icon_rect or not dropdown_icon:
		return

	if _dropdown_tween and _dropdown_tween.is_valid():
		_dropdown_tween.kill()

	_dropdown_tween = create_tween()
	_dropdown_tween.set_ease(Tween.EASE_OUT)
	_dropdown_tween.set_trans(Tween.TRANS_CUBIC)

	var target_rotation = deg_to_rad(dropdown_icon_rotation_opened) if opening else 0.0
	_dropdown_tween.tween_property(_dropdown_icon_rect, "rotation", target_rotation, 0.2)

func _on_menu_item_pressed(index: int, item: MaterialMenuItem) -> void:
	# 如果启用了选中同步，更新按钮显示
	if sync_selected_item:
		# 对于 CHECKABLE 类型，只有选中状态才同步
		if item.item_type == MaterialMenuItem.MenuItemType.CHECKABLE:
			if item.checked:
				selected_index = index
		else:
			# 普通菜单项直接同步
			selected_index = index

	menu_item_pressed.emit(index, item)

func _sync_selected_item_display() -> void:
	if not sync_selected_item or not menu or selected_index < 0:
		return

	# 获取选中的菜单项
	var items = menu.get_items()
	if selected_index >= items.size():
		return

	var selected_item = items[selected_index]
	if selected_item is MaterialMenuItem:
		# 更新按钮的文字
		text = selected_item.label_text
		# 只有菜单项有图标时才更新，否则保留原始图标
		if selected_item.icon:
			button_icon = selected_item.icon

## 重置为原始显示
func reset_display() -> void:
	text = _original_text
	button_icon = _original_icon
	selected_index = -1

## 设置原始显示属性
func set_original_display(original_text: String, original_icon: Texture2D = null) -> void:
	_original_text = original_text
	_original_icon = original_icon

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
