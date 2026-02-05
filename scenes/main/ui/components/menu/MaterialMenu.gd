@tool
class_name MaterialMenu
extends PanelContainer

## Material Design 风格弹出菜单
## 支持图标、快捷键、分隔线、子菜单、涟漪效果，遵循 Material Design 规范

signal item_pressed(index: int, item: MaterialMenuItem)
signal menu_closed()
signal menu_opened()

enum MenuSize {
	COMPACT,     ## 紧凑尺寸
	STANDARD,    ## 标准尺寸 (默认)
	COMFORTABLE  ## 舒适尺寸
}

## 编辑器配置的菜单项
@export var editor_items: Array[MaterialMenuItemConfig] = []:
	set(value):
		editor_items = value
		if Engine.is_editor_hint() and is_inside_tree():
			_rebuild_from_editor_items()

## 菜单尺寸
@export var menu_size: MenuSize = MenuSize.STANDARD:
	set(value):
		menu_size = value
		_update_style()

## 菜单最小宽度
@export_range(100, 400, 10) var min_width: int = 200:
	set(value):
		min_width = value
		custom_minimum_size.x = min_width

## 菜单最大宽度 (0 表示不限制)
@export_range(0, 600, 10) var max_width: int = 320:
	set(value):
		max_width = value

## 背景颜色
@export var background_color: Color = Color(0.15, 0.15, 0.15, 0.95):
	set(value):
		background_color = value
		_update_style()

## 边框颜色
@export var border_color: Color = Color(0.3, 0.3, 0.3, 0.5):
	set(value):
		border_color = value
		_update_style()

## 边框宽度
@export_range(0, 4, 1) var border_width: int = 1:
	set(value):
		border_width = value
		_update_style()

## 圆角半径
@export_range(0, 24, 1) var corner_radius: int = 8:
	set(value):
		corner_radius = value
		_update_style()

## 阴影颜色
@export var shadow_color: Color = Color(0, 0, 0, 0.3):
	set(value):
		shadow_color = value
		_update_style()

## 阴影大小
@export_range(0, 32, 1) var shadow_size: int = 8:
	set(value):
		shadow_size = value
		_update_style()

## 阴影偏移
@export var shadow_offset: Vector2 = Vector2(0, 4):
	set(value):
		shadow_offset = value
		_update_style()

## 内边距
@export_range(0, 16, 1) var padding: int = 8:
	set(value):
		padding = value
		_update_style()

## 是否自动隐藏 (点击菜单项后)
@export var auto_hide: bool = true

## 是否点击外部关闭
@export var close_on_click_outside: bool = true

## 显示动画时长
@export_range(0.0, 0.5, 0.01) var show_animation_duration: float = 0.15

## 隐藏动画时长
@export_range(0.0, 0.5, 0.01) var hide_animation_duration: float = 0.1

## 默认菜单项高度
@export_range(32, 64, 1) var item_height: int = 40

## 悬停颜色
@export var hover_color: Color = Color(0.4, 0.4, 0.4, 0.12):
	set(value):
		hover_color = value

## 涟漪颜色
@export var ripple_color: Color = Color(0.5, 0.5, 0.5, 0.3):
	set(value):
		ripple_color = value

## 选中图标 (用于可选中菜单项)
@export var default_check_icon: Texture2D = preload("res://assets/ui/icons/check_24dp_FFFFFF_FILL0_wght400_GRAD0_opsz24.svg")

## 子菜单箭头图标
@export var default_submenu_arrow: Texture2D

## 编辑器菜单项信号连接配置
## 格式: 每个元素为 "节点路径::方法名" 的形式
## 例如: [".:_on_menu_item_pressed", "../SomeNode:handle_menu"]
@export var editor_signal_connections: Array[String] = []

# 内部节点
var _items_container: VBoxContainer
var _show_tween: Tween
var _active_submenu: MaterialMenu = null
var _parent_menu: MaterialMenu = null
var _submenu_timer: Timer
var _hovered_item: MaterialMenuItem = null
var _background_blocker: Control = null  # 全屏背景层，用于阻止事件穿透
var _blocker_canvas_layer: CanvasLayer = null  # 背景层的 CanvasLayer

# 菜单项列表
var _items: Array[Control] = []

# 尺寸配置
const SIZE_MAP = {
	MenuSize.COMPACT: {"item_height": 32, "padding": 4, "corner": 4},
	MenuSize.STANDARD: {"item_height": 40, "padding": 8, "corner": 8},
	MenuSize.COMFORTABLE: {"item_height": 48, "padding": 12, "corner": 12}
}

func _ready() -> void:
	_setup_menu()
	_update_style()
	
	# 编辑器模式下保持可见，运行时才隐藏
	if not Engine.is_editor_hint():
		visible = false
		modulate.a = 0
	
	# 从编辑器配置创建菜单项
	if editor_items.size() > 0:
		_rebuild_from_editor_items()
	
	# 收集已有的子节点作为菜单项
	_collect_existing_items()

func _setup_menu() -> void:
	# 设置基础属性
	custom_minimum_size.x = min_width
	mouse_filter = Control.MOUSE_FILTER_STOP
	
	# 初始化容器
	_ensure_container()

## 确保菜单容器已初始化
func _ensure_container() -> void:
	if _items_container:
		return
	
	# 查找或创建菜单项容器
	_items_container = get_node_or_null("ItemsContainer")
	if not _items_container:
		_items_container = VBoxContainer.new()
		_items_container.name = "ItemsContainer"
		_items_container.add_theme_constant_override("separation", 0)
		_items_container.mouse_filter = Control.MOUSE_FILTER_STOP
		add_child(_items_container)
	
	# 查找或创建子菜单延迟显示定时器
	_submenu_timer = get_node_or_null("SubmenuTimer")
	if not _submenu_timer:
		_submenu_timer = Timer.new()
		_submenu_timer.name = "SubmenuTimer"
		_submenu_timer.one_shot = true
		_submenu_timer.wait_time = 0.2
		add_child(_submenu_timer)
	
	if not _submenu_timer.timeout.is_connected(_on_submenu_timer_timeout):
		_submenu_timer.timeout.connect(_on_submenu_timer_timeout)

func _update_style() -> void:
	if not is_inside_tree():
		return
	
	var size_config = SIZE_MAP.get(menu_size, SIZE_MAP[MenuSize.STANDARD])
	var radius = corner_radius if corner_radius > 0 else size_config["corner"]
	var pad = padding if padding > 0 else size_config["padding"]
	
	# 创建面板样式
	var style = StyleBoxFlat.new()
	style.bg_color = background_color
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	
	# 边框
	style.border_color = border_color
	style.border_width_left = border_width
	style.border_width_right = border_width
	style.border_width_top = border_width
	style.border_width_bottom = border_width
	
	# 阴影
	style.shadow_color = shadow_color
	style.shadow_size = shadow_size
	style.shadow_offset = shadow_offset
	
	# 内边距
	style.content_margin_left = pad
	style.content_margin_right = pad
	style.content_margin_top = pad
	style.content_margin_bottom = pad
	
	add_theme_stylebox_override("panel", style)

func _input(event: InputEvent) -> void:
	if not visible:
		return
	
	# 只有没有背景层时才需要在这里处理点击外部关闭
	if _background_blocker:
		return
	
	# 点击外部关闭（备用逻辑，当没有背景层时使用）
	if close_on_click_outside and event is InputEventMouseButton:
		var mb = event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			var local_pos = get_local_mouse_position()
			var rect = Rect2(Vector2.ZERO, size)
			
			# 检查是否点击在菜单外部
			if not rect.has_point(local_pos):
				# 检查是否点击在子菜单内
				if _active_submenu and _active_submenu.visible:
					var submenu_pos = _active_submenu.get_local_mouse_position()
					var submenu_rect = Rect2(Vector2.ZERO, _active_submenu.size)
					if submenu_rect.has_point(submenu_pos):
						return
				
				hide_menu()
				get_viewport().set_input_as_handled()

# ============ 公共 API ============

## 添加菜单项
func add_item(text: String, icon: Texture2D = null, shortcut: String = "") -> MaterialMenuItem:
	# 确保容器已初始化
	_ensure_container()
	
	var item = MaterialMenuItem.new()
	item.set_item(text, icon, shortcut)
	item.item_height = _get_item_height()
	item.hover_color = hover_color
	item.ripple_color = ripple_color
	
	item.pressed.connect(_on_item_pressed.bind(_items.size()))
	item.hovered.connect(_on_item_hovered.bind(item))
	
	_items_container.add_child(item)
	_items.append(item)
	
	return item

## 添加可选中菜单项
func add_check_item(text: String, is_checked: bool = false, icon: Texture2D = null) -> MaterialMenuItem:
	var item = add_item(text, icon)
	# 确保使用默认check图标（如果没有提供）
	var check_tex = default_check_icon if default_check_icon else preload("res://assets/ui/icons/check_24dp_FFFFFF_FILL0_wght400_GRAD0_opsz24.svg")
	item.set_checkable(is_checked, check_tex)
	return item

## 在指定位置插入菜单项
func insert_item(index: int, text: String, icon: Texture2D = null, shortcut: String = "") -> MaterialMenuItem:
	# 确保容器已初始化
	_ensure_container()

	# 限制索引范围
	index = clampi(index, 0, _items.size())

	var item = MaterialMenuItem.new()
	item.set_item(text, icon, shortcut)
	item.item_height = _get_item_height()
	item.hover_color = hover_color
	item.ripple_color = ripple_color

	# 先添加到容器末尾
	_items_container.add_child(item)

	# 移动到正确位置
	if index < _items.size():
		_items_container.move_child(item, index)

	# 插入到数组
	_items.insert(index, item)

	# 重新连接所有菜单项的信号（因为索引改变了）
	_reconnect_all_item_signals()

	return item

## 在指定位置插入可选中菜单项
func insert_check_item(index: int, text: String, is_checked: bool = false, icon: Texture2D = null) -> MaterialMenuItem:
	var item = insert_item(index, text, icon)
	# 确保使用默认check图标（如果没有提供）
	var check_tex = default_check_icon if default_check_icon else preload("res://assets/ui/icons/check_24dp_FFFFFF_FILL0_wght400_GRAD0_opsz24.svg")
	item.set_checkable(is_checked, check_tex)
	return item

## 重新连接所有菜单项的信号
func _reconnect_all_item_signals() -> void:
	for i in range(_items.size()):
		var item = _items[i]
		if item is MaterialMenuItem:
			# 断开旧的信号连接
			if item.pressed.is_connected(_on_item_pressed):
				item.pressed.disconnect(_on_item_pressed)
			if item.hovered.is_connected(_on_item_hovered):
				item.hovered.disconnect(_on_item_hovered)

			# 重新连接信号，使用正确的索引
			item.pressed.connect(_on_item_pressed.bind(i))
			item.hovered.connect(_on_item_hovered.bind(item))

## 添加子菜单
func add_submenu(text: String, sub_menu: MaterialMenu, icon: Texture2D = null) -> MaterialMenuItem:
	var item = add_item(text, icon)
	item.set_submenu(sub_menu, default_submenu_arrow)
	sub_menu._parent_menu = self
	sub_menu.visible = false
	return item

## 添加分隔线
func add_separator() -> MaterialMenuSeparator:
	# 确保容器已初始化
	_ensure_container()
	
	var separator = MaterialMenuSeparator.new()
	_items_container.add_child(separator)
	_items.append(separator)
	return separator

## 清空所有菜单项
func clear_items() -> void:
	for item in _items:
		if is_instance_valid(item):
			# 先从容器中移除，再释放
			if item.get_parent() == _items_container:
				_items_container.remove_child(item)
			item.queue_free()
	_items.clear()

	# 强制更新容器布局
	if _items_container:
		_items_container.queue_sort()
		# 重置尺寸
		custom_minimum_size.y = 0
		size.y = 0

## 获取菜单项数量
func get_item_count() -> int:
	return _items.size()

## 获取菜单项
func get_item(index: int) -> Control:
	if index >= 0 and index < _items.size():
		return _items[index]
	return null

## 获取所有菜单项
func get_items() -> Array[Control]:
	return _items

## 设置菜单项文字
func set_item_text(index: int, text: String) -> void:
	var item = get_item(index)
	if item is MaterialMenuItem:
		item.label_text = text

## 设置菜单项图标
func set_item_icon(index: int, icon: Texture2D) -> void:
	var item = get_item(index)
	if item is MaterialMenuItem:
		item.icon = icon

## 设置菜单项禁用状态
func set_item_disabled(index: int, disabled: bool) -> void:
	var item = get_item(index)
	if item is MaterialMenuItem:
		item.disabled = disabled

## 设置菜单项选中状态 (仅对 CHECKABLE 类型有效)
func set_item_checked(index: int, checked: bool) -> void:
	var item = get_item(index)
	if item is MaterialMenuItem:
		item.checked = checked

## 获取菜单项选中状态
func is_item_checked(index: int) -> bool:
	var item = get_item(index)
	if item is MaterialMenuItem:
		return item.checked
	return false

## 显示菜单
func show_menu(at_position: Vector2 = Vector2.ZERO) -> void:
	# 只有根菜单（非子菜单）才创建背景层
	if not _parent_menu:
		_create_background_blocker()

	# 设置位置
	if at_position != Vector2.ZERO:
		global_position = at_position
	
	# 设置高层级，确保菜单在所有元素之上
	z_index = 1000
	
	# 将菜单移到父节点的最后，确保在所有兄弟节点之上渲染
	var parent = get_parent()
	if parent:
		parent.move_child(self, parent.get_child_count() - 1)
	
	# 确保菜单在屏幕内
	_clamp_to_screen()
	
	# 停止之前的动画
	if _show_tween and _show_tween.is_valid():
		_show_tween.kill()
	
	# 显示动画
	visible = true
	modulate.a = 0
	scale = Vector2(0.95, 0.95)
	pivot_offset = size / 2
	
	_show_tween = create_tween()
	_show_tween.set_parallel(true)
	_show_tween.set_ease(Tween.EASE_OUT)
	_show_tween.set_trans(Tween.TRANS_CUBIC)
	_show_tween.tween_property(self, "modulate:a", 1.0, show_animation_duration)
	_show_tween.tween_property(self, "scale", Vector2.ONE, show_animation_duration)
	
	menu_opened.emit()

## 隐藏菜单
func hide_menu() -> void:
	# 先关闭子菜单
	_close_active_submenu()
	
	# 移除背景层（只有根菜单才有）
	if not _parent_menu:
		_remove_background_blocker()
	
	# 停止之前的动画
	if _show_tween and _show_tween.is_valid():
		_show_tween.kill()
	
	# 隐藏动画
	_show_tween = create_tween()
	_show_tween.set_parallel(true)
	_show_tween.set_ease(Tween.EASE_IN)
	_show_tween.set_trans(Tween.TRANS_CUBIC)
	_show_tween.tween_property(self, "modulate:a", 0.0, hide_animation_duration)
	_show_tween.tween_property(self, "scale", Vector2(0.95, 0.95), hide_animation_duration)
	_show_tween.tween_callback(func(): visible = false)
	
	menu_closed.emit()
	
	# 通知父菜单
	if _parent_menu:
		_parent_menu._active_submenu = null

## 在指定控件下方弹出菜单
func popup_below(control: Control, offset: Vector2 = Vector2.ZERO) -> void:
	var pos = control.global_position + Vector2(0, control.size.y) + offset
	show_menu(pos)

## 在指定控件右侧弹出菜单 (用于子菜单)
func popup_beside(control: Control, offset: Vector2 = Vector2.ZERO) -> void:
	var pos = control.global_position + Vector2(control.size.x, 0) + offset
	show_menu(pos)

## 在鼠标位置弹出菜单
func popup_at_mouse() -> void:
	var mouse_pos = get_viewport().get_mouse_position()
	show_menu(mouse_pos)

# ============ 私有方法 ============

func _get_item_height() -> int:
	var size_config = SIZE_MAP.get(menu_size, SIZE_MAP[MenuSize.STANDARD])
	return item_height if item_height > 0 else size_config["item_height"]

func _clamp_to_screen() -> void:
	# 等待一帧确保 size 已更新
	await get_tree().process_frame
	
	var viewport_size = get_viewport_rect().size
	var menu_rect = Rect2(global_position, size)
	
	# 右边界
	if menu_rect.end.x > viewport_size.x:
		global_position.x = viewport_size.x - size.x - 8
	
	# 下边界
	if menu_rect.end.y > viewport_size.y:
		global_position.y = viewport_size.y - size.y - 8
	
	# 左边界
	if global_position.x < 8:
		global_position.x = 8
	
	# 上边界
	if global_position.y < 8:
		global_position.y = 8

func _on_item_pressed(index: int) -> void:
	var item = get_item(index)
	if item is MaterialMenuItem:
		item_pressed.emit(index, item)
		
		if auto_hide and item.item_type != MaterialMenuItem.MenuItemType.SUBMENU:
			# 关闭所有菜单（包括父菜单）
			_close_all_menus()

func _on_item_hovered(item: MaterialMenuItem) -> void:
	_hovered_item = item
	
	# 如果悬停的是子菜单项，准备显示子菜单
	if item.item_type == MaterialMenuItem.MenuItemType.SUBMENU and item.submenu:
		_submenu_timer.start()
	else:
		_submenu_timer.stop()
		# 关闭当前打开的子菜单
		if _active_submenu:
			_close_active_submenu()

func _on_submenu_timer_timeout() -> void:
	if _hovered_item and _hovered_item.item_type == MaterialMenuItem.MenuItemType.SUBMENU:
		_show_submenu(_hovered_item)

func _show_submenu(item: MaterialMenuItem) -> void:
	if not item.submenu:
		return
	
	# 关闭当前打开的子菜单
	if _active_submenu and _active_submenu != item.submenu:
		_close_active_submenu()
	
	_active_submenu = item.submenu
	
	# 确保子菜单是当前菜单的兄弟节点
	if item.submenu.get_parent() != get_parent():
		if item.submenu.get_parent():
			item.submenu.get_parent().remove_child(item.submenu)
		get_parent().add_child(item.submenu)
	
	# 子菜单层级应该比父菜单更高
	item.submenu.z_index = z_index + 1
	
	# 在菜单项右侧显示子菜单
	var submenu_pos = item.global_position + Vector2(size.x - padding, 0)
	item.submenu.show_menu(submenu_pos)

func _close_active_submenu() -> void:
	if _active_submenu:
		_active_submenu.hide_menu()
		_active_submenu = null

func _close_all_menus() -> void:
	# 递归关闭所有父菜单
	if _parent_menu:
		_parent_menu._close_all_menus()
	else:
		hide_menu()

## 创建全屏背景层，用于阻止鼠标事件穿透到菜单下方
func _create_background_blocker() -> void:
	if _background_blocker:
		return
	
	# 编辑器模式下不创建背景层
	if Engine.is_editor_hint():
		return
	
	# 使用 CanvasLayer 确保背景层覆盖整个屏幕
	_blocker_canvas_layer = CanvasLayer.new()
	_blocker_canvas_layer.name = "MenuBlockerCanvasLayer"
	_blocker_canvas_layer.layer = 99  # 高层级，但低于菜单
	get_tree().root.add_child(_blocker_canvas_layer)
	
	_background_blocker = Control.new()
	_background_blocker.name = "MenuBackgroundBlocker"
	_background_blocker.set_anchors_preset(Control.PRESET_FULL_RECT)
	_background_blocker.mouse_filter = Control.MOUSE_FILTER_STOP
	
	# 点击背景层关闭菜单
	_background_blocker.gui_input.connect(_on_background_blocker_input)
	
	_blocker_canvas_layer.add_child(_background_blocker)
	
	# 将菜单移到更高的 CanvasLayer
	z_index = 0  # 重置 z_index，因为我们用 CanvasLayer 控制层级
	if not get_parent() is CanvasLayer or get_parent().layer < 100:
		# 如果菜单不在足够高的 CanvasLayer 中，创建一个
		var menu_canvas = CanvasLayer.new()
		menu_canvas.name = "MenuCanvasLayer"
		menu_canvas.layer = 100
		get_tree().root.add_child(menu_canvas)
		
		var old_parent = get_parent()
		var old_global_pos = global_position
		old_parent.remove_child(self)
		menu_canvas.add_child(self)
		global_position = old_global_pos
		
		# 保存原始父节点以便恢复
		set_meta("_original_parent", old_parent)

## 移除背景层
func _remove_background_blocker() -> void:
	# 恢复菜单到原始父节点
	if has_meta("_original_parent"):
		var original_parent = get_meta("_original_parent")
		if is_instance_valid(original_parent):
			var current_canvas = get_parent()
			var old_global_pos = global_position
			current_canvas.remove_child(self)
			original_parent.add_child(self)
			global_position = old_global_pos
			
			# 清理菜单的 CanvasLayer
			if current_canvas is CanvasLayer and current_canvas.name == "MenuCanvasLayer":
				current_canvas.queue_free()
		remove_meta("_original_parent")
	
	if _background_blocker and is_instance_valid(_background_blocker):
		_background_blocker.queue_free()
		_background_blocker = null
	
	if _blocker_canvas_layer and is_instance_valid(_blocker_canvas_layer):
		_blocker_canvas_layer.queue_free()
		_blocker_canvas_layer = null

## 处理背景层的输入事件
func _on_background_blocker_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb = event as InputEventMouseButton
		if mb.pressed:
			# 点击背景层关闭菜单
			if close_on_click_outside:
				hide_menu()
	elif event is InputEventMouseMotion:
		# 消费鼠标移动事件，防止hover效果穿透
		if _background_blocker and is_instance_valid(_background_blocker):
			_background_blocker.accept_event()

## 收集编辑器中手动添加的子节点
func _collect_existing_items() -> void:
	if not _items_container:
		return
	
	# 遍历容器中的子节点
	for child in _items_container.get_children():
		if child is MaterialMenuItem:
			if child not in _items:
				_items.append(child)
				# 连接信号
				var index = _items.size() - 1
				if not child.pressed.is_connected(_on_item_pressed):
					child.pressed.connect(_on_item_pressed.bind(index))
				if not child.hovered.is_connected(_on_item_hovered):
					child.hovered.connect(_on_item_hovered.bind(child))
				# 应用样式
				child.item_height = _get_item_height()
				child.hover_color = hover_color
				child.ripple_color = ripple_color
		elif child is MaterialMenuSeparator:
			if child not in _items:
				_items.append(child)

## 从编辑器配置重建菜单项
func _rebuild_from_editor_items() -> void:
	if not _items_container:
		return
	
	# 清除现有的编辑器生成的项（标记为编辑器项）
	for item in _items:
		if is_instance_valid(item) and item.has_meta("from_editor"):
			item.queue_free()
	_items.clear()
	
	# 从配置数组创建菜单项
	for item_config in editor_items:
		if not item_config:
			continue
		
		var item: Control = null
		
		if item_config.type == MaterialMenuItemConfig.ItemType.SEPARATOR:
			# 添加分隔线
			item = MaterialMenuSeparator.new()
		else:
			# 添加普通菜单项
			var menu_item = MaterialMenuItem.new()
			
			menu_item.set_item(item_config.text, item_config.icon, item_config.shortcut)
			menu_item.item_height = _get_item_height()
			menu_item.hover_color = hover_color
			menu_item.ripple_color = ripple_color
			
			# 设置可选中
			if item_config.type == MaterialMenuItemConfig.ItemType.CHECKABLE:
				var check_tex = default_check_icon if default_check_icon else preload("res://assets/ui/icons/check_24dp_FFFFFF_FILL0_wght400_GRAD0_opsz24.svg")
				menu_item.set_checkable(item_config.is_checked, check_tex)
			
			# 设置禁用状态
			if item_config.is_disabled:
				menu_item.disabled = true
			
			# 连接信号
			var index = _items.size()
			menu_item.pressed.connect(_on_item_pressed.bind(index))
			menu_item.hovered.connect(_on_item_hovered.bind(menu_item))
			
			item = menu_item
		
		if item:
			item.set_meta("from_editor", true)
			_items_container.add_child(item)
			_items.append(item)
	
	# 连接编辑器配置的信号
	_connect_editor_signals()

## 连接编辑器配置的信号
func _connect_editor_signals() -> void:
	if editor_signal_connections.is_empty():
		return
	
	for connection_str in editor_signal_connections:
		if connection_str.is_empty():
			continue
		
		# 解析格式: "节点路径::方法名"
		var parts = connection_str.split("::")
		if parts.size() != 2:
			push_warning("MaterialMenu: 无效的信号连接格式: %s，应为 '节点路径::方法名'" % connection_str)
			continue
		
		var node_path = parts[0].strip_edges()
		var method_name = parts[1].strip_edges()
		
		if node_path.is_empty() or method_name.is_empty():
			push_warning("MaterialMenu: 信号连接配置不完整: %s" % connection_str)
			continue
		
		# 获取目标节点
		var target_node = get_node_or_null(node_path)
		if not target_node:
			push_warning("MaterialMenu: 找不到目标节点: %s" % node_path)
			continue
		
		# 检查方法是否存在
		if not target_node.has_method(method_name):
			push_warning("MaterialMenu: 目标节点 %s 没有方法: %s" % [node_path, method_name])
			continue
		
		# 连接信号（避免重复连接）
		if not item_pressed.is_connected(target_node.get(method_name)):
			var callable = Callable(target_node, method_name)
			if not item_pressed.is_connected(callable):
				item_pressed.connect(callable)
				print("MaterialMenu: 已连接信号 item_pressed 到 %s::%s" % [node_path, method_name])

## 在编辑器中节点树变化时重新收集
func _notification(what: int) -> void:
	if what == NOTIFICATION_CHILD_ORDER_CHANGED:
		if Engine.is_editor_hint() and is_inside_tree():
			# 延迟收集，确保节点已完全添加
			call_deferred("_collect_existing_items")
