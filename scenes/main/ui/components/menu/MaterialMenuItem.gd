@tool
class_name MaterialMenuItem
extends Control

## Material Design 风格菜单项
## 支持图标、文字、快捷键显示、子菜单，遵循 Material Design 规范

signal pressed()
signal hovered()

enum MenuItemType {
	NORMAL,      ## 普通菜单项
	CHECKABLE,   ## 可选中的菜单项
	SUBMENU      ## 带子菜单的菜单项
}

## 菜单项类型
@export var item_type: MenuItemType = MenuItemType.NORMAL:
	set(value):
		item_type = value
		_update_layout()

## 菜单项文字
@export var label_text: String = "":
	set(value):
		label_text = value
		_update_label()

## 菜单项图标
@export var icon: Texture2D:
	set(value):
		icon = value
		_update_icon()

## 图标大小
@export_range(12, 32, 1) var icon_size: int = 20:
	set(value):
		icon_size = value
		_update_icon()

## 快捷键文字
@export var shortcut_text: String = "":
	set(value):
		shortcut_text = value
		_update_shortcut()

## 是否选中 (仅对 CHECKABLE 类型有效)
@export var checked: bool = false:
	set(value):
		checked = value
		_update_check_icon()

## 是否禁用
@export var disabled: bool = false:
	set(value):
		disabled = value
		_update_disabled_state()

## 子菜单 (仅对 SUBMENU 类型有效)
var submenu: Control = null

## 是否启用涟漪效果
@export var enable_ripple: bool = true

## 涟漪颜色
@export var ripple_color: Color = Color(0.5, 0.5, 0.5, 0.3):
	set(value):
		ripple_color = value
		if _ripple_mixin:
			_ripple_mixin.set_ripple_color(ripple_color)

## 悬停背景颜色
@export var hover_color: Color = Color(0.4, 0.4, 0.4, 0.12):
	set(value):
		hover_color = value

## 菜单项高度
@export_range(32, 64, 1) var item_height: int = 40:
	set(value):
		item_height = value
		custom_minimum_size.y = item_height
		_update_layout()

## 水平内边距
@export_range(8, 32, 1) var padding_horizontal: int = 16:
	set(value):
		padding_horizontal = value
		_update_layout()

## 选中图标
@export var check_icon: Texture2D:
	set(value):
		check_icon = value
		_update_check_icon()

## 子菜单箭头图标
@export var submenu_arrow_icon: Texture2D:
	set(value):
		submenu_arrow_icon = value
		_update_submenu_arrow()

# 内部节点
var _background: ColorRect
var _icon_rect: TextureRect
var _label: Label
var _shortcut_label: Label
var _check_icon_rect: TextureRect
var _submenu_arrow_rect: TextureRect
var _ripple_mixin: MaterialRippleMixin
var _is_hovered: bool = false

# 布局常量
const ICON_LABEL_GAP: int = 12
const LABEL_SHORTCUT_GAP: int = 24
const CHECK_ICON_SIZE: int = 18
const SUBMENU_ARROW_SIZE: int = 16

func _ready() -> void:
	_setup_item()
	_update_layout()
	
	# 编辑器模式下的额外处理
	if Engine.is_editor_hint():
		# 确保在编辑器中可见
		visible = true

func _setup_item() -> void:
	# 设置基础属性
	custom_minimum_size.y = item_height
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	
	# 查找或创建背景
	_background = get_node_or_null("Background")
	if not _background:
		_background = ColorRect.new()
		_background.name = "Background"
		_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_background.color = Color.TRANSPARENT
		add_child(_background)
		_background.set_anchors_preset(Control.PRESET_FULL_RECT)
	
	# 创建涟漪效果（仅运行时）
	if enable_ripple and not _ripple_mixin and not Engine.is_editor_hint():
		_ripple_mixin = MaterialRippleMixin.new()
		_ripple_mixin.ripple_color = ripple_color
		_ripple_mixin.setup(self)
	
	# 查找或创建选中图标 (左侧)
	_check_icon_rect = get_node_or_null("CheckIcon")
	if not _check_icon_rect:
		_check_icon_rect = TextureRect.new()
		_check_icon_rect.name = "CheckIcon"
		_check_icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_check_icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_check_icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_check_icon_rect.visible = false
		add_child(_check_icon_rect)
	
	# 查找或创建图标
	_icon_rect = get_node_or_null("Icon")
	if not _icon_rect:
		_icon_rect = TextureRect.new()
		_icon_rect.name = "Icon"
		_icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		add_child(_icon_rect)
	
	# 查找或创建文字标签
	_label = get_node_or_null("Label")
	if not _label:
		_label = Label.new()
		_label.name = "Label"
		_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		add_child(_label)
	
	# 查找或创建快捷键标签
	_shortcut_label = get_node_or_null("ShortcutLabel")
	if not _shortcut_label:
		_shortcut_label = Label.new()
		_shortcut_label.name = "ShortcutLabel"
		_shortcut_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_shortcut_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_shortcut_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		_shortcut_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		add_child(_shortcut_label)
	
	# 查找或创建子菜单箭头
	_submenu_arrow_rect = get_node_or_null("SubmenuArrow")
	if not _submenu_arrow_rect:
		_submenu_arrow_rect = TextureRect.new()
		_submenu_arrow_rect.name = "SubmenuArrow"
		_submenu_arrow_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_submenu_arrow_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_submenu_arrow_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_submenu_arrow_rect.visible = false
		add_child(_submenu_arrow_rect)
	
	_update_icon()
	_update_label()
	_update_shortcut()
	_update_check_icon()
	_update_submenu_arrow()

func _update_layout() -> void:
	if not is_inside_tree():
		return
	
	var current_x = padding_horizontal
	var center_y = item_height / 2.0
	
	# 选中图标位置 (仅 CHECKABLE 类型显示)
	if _check_icon_rect:
		_check_icon_rect.visible = (item_type == MenuItemType.CHECKABLE) and checked and check_icon != null
		_check_icon_rect.custom_minimum_size = Vector2(CHECK_ICON_SIZE, CHECK_ICON_SIZE)
		_check_icon_rect.size = Vector2(CHECK_ICON_SIZE, CHECK_ICON_SIZE)
		_check_icon_rect.position = Vector2(current_x, center_y - CHECK_ICON_SIZE / 2.0)
	
	# 如果是 CHECKABLE 类型，为选中图标预留空间
	if item_type == MenuItemType.CHECKABLE:
		current_x += CHECK_ICON_SIZE + ICON_LABEL_GAP
	
	# 图标位置
	if _icon_rect:
		_icon_rect.visible = icon != null
		_icon_rect.custom_minimum_size = Vector2(icon_size, icon_size)
		_icon_rect.size = Vector2(icon_size, icon_size)
		_icon_rect.position = Vector2(current_x, center_y - icon_size / 2.0)
		
		if icon != null:
			current_x += icon_size + ICON_LABEL_GAP
	
	# 计算右侧内容宽度
	var right_content_width = padding_horizontal
	
	# 子菜单箭头
	if _submenu_arrow_rect:
		_submenu_arrow_rect.visible = (item_type == MenuItemType.SUBMENU)
		if item_type == MenuItemType.SUBMENU:
			_submenu_arrow_rect.custom_minimum_size = Vector2(SUBMENU_ARROW_SIZE, SUBMENU_ARROW_SIZE)
			_submenu_arrow_rect.size = Vector2(SUBMENU_ARROW_SIZE, SUBMENU_ARROW_SIZE)
			right_content_width += SUBMENU_ARROW_SIZE
	
	# 快捷键标签
	if _shortcut_label:
		_shortcut_label.visible = shortcut_text != "" and item_type != MenuItemType.SUBMENU
		if _shortcut_label.visible:
			_shortcut_label.size = _shortcut_label.get_minimum_size()
			right_content_width += _shortcut_label.size.x + LABEL_SHORTCUT_GAP
	
	# 文字标签位置
	if _label:
		_label.position = Vector2(current_x, 0)
		_label.size = Vector2(size.x - current_x - right_content_width, item_height)
	
	# 快捷键和箭头位置 (靠右)
	var right_x = size.x - padding_horizontal
	
	if _submenu_arrow_rect and _submenu_arrow_rect.visible:
		_submenu_arrow_rect.position = Vector2(right_x - SUBMENU_ARROW_SIZE, center_y - SUBMENU_ARROW_SIZE / 2.0)
		right_x -= SUBMENU_ARROW_SIZE + ICON_LABEL_GAP
	
	if _shortcut_label and _shortcut_label.visible:
		_shortcut_label.position = Vector2(right_x - _shortcut_label.size.x, center_y - _shortcut_label.size.y / 2.0)

func _update_icon() -> void:
	if not _icon_rect:
		return
	
	_icon_rect.texture = icon
	_update_layout()

func _update_label() -> void:
	if not _label:
		return
	
	_label.text = label_text
	_update_layout()

func _update_shortcut() -> void:
	if not _shortcut_label:
		return
	
	_shortcut_label.text = shortcut_text
	_update_layout()

func _update_check_icon() -> void:
	if not _check_icon_rect:
		return
	
	_check_icon_rect.texture = check_icon
	_check_icon_rect.visible = (item_type == MenuItemType.CHECKABLE) and checked and check_icon != null
	_update_layout()

func _update_submenu_arrow() -> void:
	if not _submenu_arrow_rect:
		return
	
	_submenu_arrow_rect.texture = submenu_arrow_icon
	_update_layout()

func _update_disabled_state() -> void:
	if disabled:
		modulate.a = 0.4
		mouse_default_cursor_shape = Control.CURSOR_ARROW
	else:
		modulate.a = 1.0
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

func _notification(what: int) -> void:
	match what:
		NOTIFICATION_RESIZED:
			_update_layout()
			if _ripple_mixin:
				_ripple_mixin.update_size(size)
		NOTIFICATION_MOUSE_ENTER:
			if not disabled:
				_is_hovered = true
				if _background:
					_background.color = hover_color
				hovered.emit()
		NOTIFICATION_MOUSE_EXIT:
			_is_hovered = false
			if _background:
				_background.color = Color.TRANSPARENT

func _gui_input(event: InputEvent) -> void:
	# 编辑器模式下不处理输入
	if Engine.is_editor_hint():
		return
	
	if disabled:
		return
	
	if event is InputEventMouseButton:
		var mb = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				if enable_ripple and _ripple_mixin:
					_ripple_mixin.trigger_ripple(get_local_mouse_position())
			else:
				if enable_ripple and _ripple_mixin:
					_ripple_mixin.fade_ripple()
				
				# 只有普通菜单项和可选中项点击时发送信号
				if item_type != MenuItemType.SUBMENU:
					if item_type == MenuItemType.CHECKABLE:
						checked = not checked
					pressed.emit()

## 设置菜单项
func set_item(text: String, item_icon: Texture2D = null, shortcut: String = "") -> void:
	label_text = text
	icon = item_icon
	shortcut_text = shortcut

## 设置为可选中类型
func set_checkable(is_checked: bool = false, check_tex: Texture2D = null) -> void:
	item_type = MenuItemType.CHECKABLE
	checked = is_checked
	# 如果没有提供check图标，使用默认的
	if check_tex:
		check_icon = check_tex
	elif not check_icon:
		check_icon = preload("res://assets/ui/icons/check_24dp_FFFFFF_FILL0_wght400_GRAD0_opsz24.svg")

## 设置为子菜单类型
func set_submenu(sub: Control, arrow_tex: Texture2D = null) -> void:
	item_type = MenuItemType.SUBMENU
	submenu = sub
	submenu_arrow_icon = arrow_tex
