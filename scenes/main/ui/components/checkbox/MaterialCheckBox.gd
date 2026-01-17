@tool
class_name MaterialCheckbox
extends CheckBox

## Material Design 风格复选框
## 支持自定义图标、涟漪效果，遵循 Material Design 规范

enum CheckboxSize {
	SMALL32,      ## 32dp 高度
	STANDARD36,   ## 36dp 高度 (默认)
	MEDIUM40,     ## 40dp 高度
	LARGE48,      ## 48dp 高度
	EXTRA_LARGE56 ## 56dp 高度
}

## 复选框尺寸
@export var checkbox_size: CheckboxSize = CheckboxSize.STANDARD36:
	set(value):
		checkbox_size = value
		_update_checkbox_style()
		_update_layout()

## 未选中状态图标
@export var unchecked_icon: Texture2D:
	set(value):
		unchecked_icon = value
		_update_icon_display()

## 选中状态图标
@export var checked_icon: Texture2D:
	set(value):
		checked_icon = value
		_update_icon_display()

## 图标大小 (默认会根据尺寸自动调整，设为0使用自动值)
@export_range(0, 48, 1) var icon_size: int = 0:
	set(value):
		icon_size = value
		_update_icon_display()

## 图标与文字间距
@export_range(0, 128, 1) var icon_text_gap: int = 8:
	set(value):
		icon_text_gap = value
		_update_layout()

## 是否启用涟漪效果
@export var enable_ripple: bool = true

## 涟漪颜色 (默认淡灰色)
@export var ripple_color: Color = Color(0.5, 0.5, 0.5, 0.3):
	set(value):
		ripple_color = value
		if _ripple_mixin:
			_ripple_mixin.set_ripple_color(ripple_color)

## 背景颜色 (默认透明)
@export var background_color: Color = Color.TRANSPARENT:
	set(value):
		background_color = value
		_update_checkbox_style()

## 圆角半径 (自动根据尺寸计算，设为-1使用自动值)
@export var corner_radius: int = -1:
	set(value):
		corner_radius = value
		_update_checkbox_style()

## 内部边距 (水平)
@export_range(4, 32, 1) var padding_horizontal: int = 8:
	set(value):
		padding_horizontal = value
		_update_layout()

## 内部边距 (垂直)
@export_range(2, 16, 1) var padding_vertical: int = 4:
	set(value):
		padding_vertical = value
		_update_layout()

## 选中状态颜色（用于图标着色）
@export var checked_color: Color = Color(0.4, 0.6, 1.0):
	set(value):
		checked_color = value
		_update_icon_display()

## 未选中状态颜色
@export var unchecked_color: Color = Color(0.6, 0.6, 0.6):
	set(value):
		unchecked_color = value
		_update_icon_display()

# 内部节点
var _icon_texture_rect: TextureRect
var _ripple_mixin: MaterialRippleMixin
var _updating: bool = false

# Material Design尺寸定义 (dp)
const SIZE_MAP = {
	CheckboxSize.SMALL32: {"height": 32, "icon": 18, "padding_h": 8, "padding_v": 4, "corner": 4},
	CheckboxSize.STANDARD36: {"height": 36, "icon": 20, "padding_h": 10, "padding_v": 5, "corner": 6},
	CheckboxSize.MEDIUM40: {"height": 40, "icon": 24, "padding_h": 12, "padding_v": 6, "corner": 6},
	CheckboxSize.LARGE48: {"height": 48, "icon": 24, "padding_h": 14, "padding_v": 8, "corner": 8},
	CheckboxSize.EXTRA_LARGE56: {"height": 56, "icon": 28, "padding_h": 16, "padding_v": 10, "corner": 8}
}

func _ready() -> void:
	_setup_checkbox()
	_update_checkbox_style()
	_update_icon_display()
	_update_layout()
	
	# 连接信号
	if not toggled.is_connected(_on_toggled):
		toggled.connect(_on_toggled)
	
	if enable_ripple:
		if not button_down.is_connected(_on_button_down):
			button_down.connect(_on_button_down)
		if not button_up.is_connected(_on_button_up):
			button_up.connect(_on_button_up)

func _setup_checkbox() -> void:
	# 设置基础属性
	clip_contents = false
	focus_mode = Control.FOCUS_ALL
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	
	# 完全隐藏默认的 CheckBox 图标
	# 使用空的 ImageTexture 而不是 PlaceholderTexture2D，确保不占用任何空间
	var empty_texture = ImageTexture.new()
	add_theme_icon_override("checked", empty_texture)
	add_theme_icon_override("unchecked", empty_texture)
	add_theme_icon_override("checked_disabled", empty_texture)
	add_theme_icon_override("unchecked_disabled", empty_texture)
	
	# 关键：设置 h_separation 为负值来抵消内置图标的空间
	# 或者直接设为 0，然后通过 content_margin 控制
	add_theme_constant_override("h_separation", 0)
	add_theme_constant_override("check_v_offset", 0)
	# 将内置图标宽度设为 0
	add_theme_constant_override("icon_max_width", 0)
	
	# 创建涟漪效果
	if enable_ripple and not _ripple_mixin:
		_ripple_mixin = MaterialRippleMixin.new()
		_ripple_mixin.ripple_color = ripple_color
		_ripple_mixin.setup(self)
	
	# 创建自定义图标
	if not _icon_texture_rect:
		_icon_texture_rect = TextureRect.new()
		_icon_texture_rect.name = "CheckboxIcon"
		_icon_texture_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_icon_texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_icon_texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		add_child(_icon_texture_rect)

func _update_checkbox_style() -> void:
	if not is_inside_tree() or _updating:
		return
	
	var size_config = SIZE_MAP.get(checkbox_size, SIZE_MAP[CheckboxSize.STANDARD36])
	
	# 设置最小尺寸
	custom_minimum_size.y = size_config["height"]
	
	# 设置圆角
	var radius = corner_radius if corner_radius >= 0 else size_config["corner"]
	
	# 同步更新涟漪的圆角和尺寸
	if _ripple_mixin:
		_ripple_mixin.set_corner_radius(float(radius))
		_ripple_mixin.update_size(size)
	
	# 创建基础样式（左边距会在 _update_layout 中调整）
	_create_stylebox("normal", background_color, radius)
	_create_stylebox("hover", background_color.lightened(0.1) if background_color.a > 0 else Color(0.4, 0.4, 0.4, 0.12), radius)
	_create_stylebox("pressed", background_color.darkened(0.1) if background_color.a > 0 else Color(0.35, 0.35, 0.35, 0.10), radius)
	_create_stylebox("hover_pressed", background_color.lightened(0.1) if background_color.a > 0 else Color(0.4, 0.4, 0.4, 0.12), radius)
	_create_stylebox("focus", background_color, radius)
	_create_stylebox("disabled", background_color.darkened(0.3) if background_color.a > 0 else Color(0.2, 0.2, 0.2, 0.06), radius)

func _create_stylebox(state: String, color: Color, radius: int) -> void:
	var style = StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	style.content_margin_left = padding_horizontal
	style.content_margin_right = padding_horizontal
	style.content_margin_top = padding_vertical
	style.content_margin_bottom = padding_vertical
	add_theme_stylebox_override(state, style)

func _update_icon_display() -> void:
	if not is_inside_tree() or not _icon_texture_rect:
		return
	
	# 根据选中状态显示对应图标
	var current_icon = checked_icon if button_pressed else unchecked_icon
	_icon_texture_rect.texture = current_icon
	_icon_texture_rect.visible = current_icon != null
	
	# 设置图标颜色
	var icon_color = checked_color if button_pressed else unchecked_color
	_icon_texture_rect.modulate = icon_color
	
	var size_config = SIZE_MAP.get(checkbox_size, SIZE_MAP[CheckboxSize.STANDARD36])
	var actual_icon_size = icon_size if icon_size > 0 else size_config["icon"]
	
	_icon_texture_rect.custom_minimum_size = Vector2(actual_icon_size, actual_icon_size)
	_icon_texture_rect.size = Vector2(actual_icon_size, actual_icon_size)
	
	# 更新布局
	_update_layout()

func _update_layout() -> void:
	if not is_inside_tree() or not _icon_texture_rect or _updating:
		return
	
	_updating = true
	
	var has_text = text != null and text.length() > 0
	var has_icon = (checked_icon != null) or (unchecked_icon != null)
	
	var size_config = SIZE_MAP.get(checkbox_size, SIZE_MAP[CheckboxSize.STANDARD36])
	var actual_icon_size = icon_size if icon_size > 0 else size_config["icon"]
	var checkbox_height = size_config["height"]
	var radius = corner_radius if corner_radius >= 0 else size_config["corner"]
	
	if has_icon:
		if has_text:
			# 图标 + 文字模式
			alignment = HORIZONTAL_ALIGNMENT_LEFT
			custom_minimum_size.x = 0  # 允许根据内容自动调整宽度
			
			# 图标在左侧，垂直居中
			_icon_texture_rect.position = Vector2(
				padding_horizontal,
				(checkbox_height - actual_icon_size) / 2.0
			)
			
			# 重新创建所有状态的样式，确保左边距正确
			var left_margin = padding_horizontal + actual_icon_size + icon_text_gap
			_create_stylebox_ex("normal", background_color, radius, left_margin)
			_create_stylebox_ex("hover", background_color.lightened(0.1) if background_color.a > 0 else Color(0.4, 0.4, 0.4, 0.12), radius, left_margin)
			_create_stylebox_ex("hover_pressed", background_color.lightened(0.1) if background_color.a > 0 else Color(0.4, 0.4, 0.4, 0.12), radius, left_margin)
			_create_stylebox_ex("pressed", background_color.darkened(0.1) if background_color.a > 0 else Color(0.35, 0.35, 0.35, 0.10), radius, left_margin)
			_create_stylebox_ex("focus", background_color, radius, left_margin)
			_create_stylebox_ex("disabled", background_color.darkened(0.3) if background_color.a > 0 else Color(0.2, 0.2, 0.2, 0.06), radius, left_margin)
			
			if _ripple_mixin:
				_ripple_mixin.set_corner_radius(float(radius))
		else:
			# 只有图标，设为方形圆形按钮
			alignment = HORIZONTAL_ALIGNMENT_CENTER
			custom_minimum_size.x = checkbox_height
			
			# 图标居中
			_icon_texture_rect.position = Vector2(
				(checkbox_height - actual_icon_size) / 2.0,
				(checkbox_height - actual_icon_size) / 2.0
			)
			
			# 设置为圆形，边距为0
			var circle_radius = int(checkbox_height / 2.0)
			_create_stylebox_circle("normal", background_color, circle_radius)
			_create_stylebox_circle("hover", background_color.lightened(0.1) if background_color.a > 0 else Color(0.4, 0.4, 0.4, 0.12), circle_radius)
			_create_stylebox_circle("hover_pressed", background_color.lightened(0.1) if background_color.a > 0 else Color(0.4, 0.4, 0.4, 0.12), circle_radius)
			_create_stylebox_circle("pressed", background_color.darkened(0.1) if background_color.a > 0 else Color(0.35, 0.35, 0.35, 0.10), circle_radius)
			_create_stylebox_circle("focus", background_color, circle_radius)
			_create_stylebox_circle("disabled", background_color.darkened(0.3) if background_color.a > 0 else Color(0.2, 0.2, 0.2, 0.06), circle_radius)
			
			if _ripple_mixin:
				_ripple_mixin.set_corner_radius(float(circle_radius))
	else:
		# 没有图标，只有文字
		alignment = HORIZONTAL_ALIGNMENT_CENTER
		custom_minimum_size.x = 0
		
		_create_stylebox("normal", background_color, radius)
		_create_stylebox("hover_pressed", background_color.lightened(0.1) if background_color.a > 0 else Color(0.4, 0.4, 0.4, 0.12), radius)
		_create_stylebox("hover", background_color.lightened(0.1) if background_color.a > 0 else Color(0.4, 0.4, 0.4, 0.12), radius)
		_create_stylebox("pressed", background_color.darkened(0.1) if background_color.a > 0 else Color(0.35, 0.35, 0.35, 0.10), radius)
		_create_stylebox("focus", background_color, radius)
		_create_stylebox("disabled", background_color.darkened(0.3) if background_color.a > 0 else Color(0.2, 0.2, 0.2, 0.06), radius)
		
		if _ripple_mixin:
			_ripple_mixin.set_corner_radius(float(radius))
	
	_updating = false

## 创建带自定义左边距的样式
func _create_stylebox_ex(state: String, color: Color, radius: int, left_margin: int) -> void:
	var style = StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	style.content_margin_left = left_margin
	style.content_margin_right = padding_horizontal
	style.content_margin_top = padding_vertical
	style.content_margin_bottom = padding_vertical
	add_theme_stylebox_override(state, style)

## 创建圆形按钮样式（无边距）
func _create_stylebox_circle(state: String, color: Color, radius: int) -> void:
	var style = StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	style.content_margin_left = 0
	style.content_margin_right = 0
	style.content_margin_top = 0
	style.content_margin_bottom = 0
	add_theme_stylebox_override(state, style)

## 设置状态但不发送信号（替代 set_pressed_no_signal，会正确更新外观）
## 注意：Godot 4 不允许覆写 set_pressed_no_signal
func set_checked_no_signal(p_pressed: bool) -> void:
	set_pressed_no_signal(p_pressed)
	_update_icon_display()

func _on_toggled(_pressed: bool) -> void:
	_update_icon_display()

func _on_button_down() -> void:
	if not enable_ripple or not _ripple_mixin:
		return
	
	var local_pos = get_local_mouse_position()
	
	# 更新圆角参数
	var has_text = text != null and text.length() > 0
	var has_icon = (checked_icon != null) or (unchecked_icon != null)
	var current_radius: float
	
	if has_icon and not has_text:
		current_radius = custom_minimum_size.y / 2.0
	else:
		current_radius = float(corner_radius if corner_radius >= 0 else SIZE_MAP[checkbox_size]["corner"])
	
	_ripple_mixin.set_corner_radius(current_radius)
	_ripple_mixin.trigger_ripple(local_pos)

func _on_button_up() -> void:
	if not enable_ripple or not _ripple_mixin:
		return
	
	_ripple_mixin.fade_ripple()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_update_layout()
		if _ripple_mixin:
			_ripple_mixin.update_size(size)
			var radius = corner_radius if corner_radius >= 0 else SIZE_MAP[checkbox_size]["corner"]
			_ripple_mixin.set_corner_radius(float(radius))

# ============ 公共方法 ============

## 设置复选框样式
func set_material_style(cb_size: CheckboxSize, checked_tex: Texture2D = null, unchecked_tex: Texture2D = null, label: String = "") -> void:
	checkbox_size = cb_size
	checked_icon = checked_tex
	unchecked_icon = unchecked_tex
	text = label

## 设置为 filled 风格 (Material Design)
func set_filled_style(bg_color: Color = Color(0.4, 0.6, 1.0)) -> void:
	var radius = corner_radius if corner_radius >= 0 else SIZE_MAP[checkbox_size]["corner"]
	_create_stylebox("normal", bg_color, radius)
	_create_stylebox("hover", bg_color.lightened(0.1), radius)
	_create_stylebox("pressed", bg_color.darkened(0.1), radius)
	_update_layout()

## 设置为 outlined 风格 (Material Design)
func set_outlined_style(border_color: Color = Color(0.4, 0.6, 1.0), border_width: int = 2) -> void:
	var radius = corner_radius if corner_radius >= 0 else SIZE_MAP[checkbox_size]["corner"]
	
	for state in ["normal", "hover", "pressed"]:
		var style = StyleBoxFlat.new()
		style.bg_color = Color.TRANSPARENT
		style.border_color = border_color
		style.border_width_left = border_width
		style.border_width_right = border_width
		style.border_width_top = border_width
		style.border_width_bottom = border_width
		style.corner_radius_top_left = radius
		style.corner_radius_top_right = radius
		style.corner_radius_bottom_left = radius
		style.corner_radius_bottom_right = radius
		style.content_margin_left = padding_horizontal
		style.content_margin_right = padding_horizontal
		style.content_margin_top = padding_vertical
		style.content_margin_bottom = padding_vertical
		
		if state == "hover":
			style.bg_color = border_color
			style.bg_color.a = 0.08
		elif state == "pressed":
			style.bg_color = border_color
			style.bg_color.a = 0.12
		
		add_theme_stylebox_override(state, style)
	
	_update_layout()

## 设置为 text 风格 (Material Design)
func set_text_style(text_color: Color = Color(0.4, 0.6, 1.0)) -> void:
	var radius = corner_radius if corner_radius >= 0 else SIZE_MAP[checkbox_size]["corner"]
	
	_create_stylebox("normal", Color.TRANSPARENT, radius)
	_create_stylebox("hover", Color(text_color.r, text_color.g, text_color.b, 0.08), radius)
	_create_stylebox("pressed", Color(text_color.r, text_color.g, text_color.b, 0.12), radius)
	
	add_theme_color_override("font_color", text_color)
	_update_layout()

## 设置选中/未选中颜色
func set_state_colors(checked: Color, unchecked: Color) -> void:
	checked_color = checked
	unchecked_color = unchecked
