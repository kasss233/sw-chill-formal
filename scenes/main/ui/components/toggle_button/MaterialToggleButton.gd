@tool
class_name MaterialToggleButton
extends Button

## Material Design 风格多状态按钮
## 支持多个状态切换，每个状态可配置独立的图标、文字和颜色
## 遵循 Material Design 规范

## 状态改变信号
signal state_changed(old_state: int, new_state: int)

enum ButtonSize {
	SMALL32,      ## 32dp 高度
	STANDARD36,   ## 36dp 高度 (默认)
	MEDIUM40,     ## 40dp 高度
	LARGE48,      ## 48dp 高度
	EXTRA_LARGE56 ## 56dp 高度
}

enum IconLayoutMode {
	ICON_LEFT,    ## 图标在左 (默认)
	ICON_TOP      ## 图标在上
}

enum CycleMode {
	FORWARD,      ## 正向循环 (0 -> 1 -> 2 -> ... -> 0)
	BACKWARD,     ## 反向循环 (0 -> n -> n-1 -> ... -> 0)
	PING_PONG     ## 来回循环 (0 -> 1 -> 2 -> 1 -> 0 -> ...)
}

## 状态配置资源
@export var states: Array[ToggleButtonState] = []:
	set(value):
		states = value
		_update_state_display()

## 当前状态索引
@export var current_state: int = 0:
	set(value):
		var old_state = current_state
		current_state = clampi(value, 0, maxi(0, states.size() - 1))
		if old_state != current_state:
			state_changed.emit(old_state, current_state)
		_update_state_display()

## 循环模式
@export var cycle_mode: CycleMode = CycleMode.FORWARD

## 按钮尺寸
@export var button_size: ButtonSize = ButtonSize.STANDARD36:
	set(value):
		button_size = value
		_update_button_style()

## 图标大小 (默认根据按钮尺寸自动调整，设为0使用自动值)
@export_range(0, 48, 1) var icon_size: int = 0:
	set(value):
		icon_size = value
		_update_icon()

## 图标与文字间距
@export_range(-128, 128, 1) var icon_text_gap: int = 8:
	set(value):
		icon_text_gap = value
		_update_layout()

## 图标布局模式
@export var icon_layout_mode: IconLayoutMode = IconLayoutMode.ICON_LEFT:
	set(value):
		icon_layout_mode = value
		_update_button_style()
		_update_layout()

## 是否启用涟漪效果
@export var enable_ripple: bool = true

## 涟漪颜色 (默认淡灰色)
@export var ripple_color: Color = Color(0.5, 0.5, 0.5, 0.3):
	set(value):
		ripple_color = value
		if _ripple_mixin:
			_ripple_mixin.set_ripple_color(ripple_color)

## 默认背景颜色 (当状态未指定时使用)
@export var default_background_color: Color = Color.TRANSPARENT:
	set(value):
		default_background_color = value
		_update_button_style()

## 圆角半径 (自动根据按钮高度计算，设为-1使用自动值)
@export var corner_radius: int = -1:
	set(value):
		corner_radius = value
		_update_button_style()

## 内部边距 (水平)
@export_range(8, 32, 1) var padding_horizontal: int = 16:
	set(value):
		padding_horizontal = value
		_update_layout()

## 内部边距 (垂直)
@export_range(4, 16, 1) var padding_vertical: int = 8:
	set(value):
		padding_vertical = value
		_update_layout()

## 是否在点击时自动切换状态
@export var auto_cycle: bool = true

## 状态切换动画时长 (秒，0表示无动画)
@export_range(0.0, 1.0, 0.05) var transition_duration: float = 0.15

# 内部节点
var _icon_texture_rect: TextureRect
var _ripple_mixin: MaterialRippleMixin
var _updating: bool = false
var _ping_pong_direction: int = 1  # 用于 PING_PONG 模式
var _transition_tween: Tween

# Material Design尺寸定义 (dp)
const SIZE_MAP = {
	ButtonSize.SMALL32: {"height": 32, "icon": 18, "padding_h": 12, "padding_v": 6, "corner": 4},
	ButtonSize.STANDARD36: {"height": 36, "icon": 20, "padding_h": 14, "padding_v": 7, "corner": 6},
	ButtonSize.MEDIUM40: {"height": 40, "icon": 24, "padding_h": 16, "padding_v": 8, "corner": 6},
	ButtonSize.LARGE48: {"height": 48, "icon": 24, "padding_h": 20, "padding_v": 10, "corner": 8},
	ButtonSize.EXTRA_LARGE56: {"height": 56, "icon": 24, "padding_h": 24, "padding_v": 12, "corner": 8}
}

func _ready() -> void:
	_setup_button()
	_update_button_style()
	_update_state_display()
	_update_layout()
	
	# 连接信号
	if not pressed.is_connected(_on_pressed):
		pressed.connect(_on_pressed)
	
	if enable_ripple:
		if not button_down.is_connected(_on_button_down):
			button_down.connect(_on_button_down)
		if not button_up.is_connected(_on_button_up):
			button_up.connect(_on_button_up)

func _setup_button() -> void:
	# 设置基础属性
	clip_contents = true
	focus_mode = Control.FOCUS_ALL
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	
	# 创建涟漪效果
	if enable_ripple and not _ripple_mixin:
		_ripple_mixin = MaterialRippleMixin.new()
		_ripple_mixin.ripple_color = ripple_color
		_ripple_mixin.setup(self)
	
	# 创建图标纹理 (后创建，确保在涟漪上面)
	if not _icon_texture_rect:
		_icon_texture_rect = TextureRect.new()
		_icon_texture_rect.name = "IconTexture"
		_icon_texture_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_icon_texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_icon_texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		add_child(_icon_texture_rect)

func _update_button_style() -> void:
	if not is_inside_tree() or _updating:
		return
	
	_updating = true
	
	var size_config = SIZE_MAP.get(button_size, SIZE_MAP[ButtonSize.STANDARD36])
	
	# 设置最小尺寸
	if icon_layout_mode == IconLayoutMode.ICON_TOP and _get_current_icon() and _get_current_text() != "":
		custom_minimum_size.y = 0  # 自适应高度
	else:
		custom_minimum_size.y = size_config["height"]
	
	# 设置圆角
	var radius = corner_radius if corner_radius >= 0 else size_config["corner"]
	
	# 同步更新涟漪的圆角和尺寸
	if _ripple_mixin:
		_ripple_mixin.set_corner_radius(float(radius))
		_ripple_mixin.update_size(size)
	
	# 获取当前状态的背景颜色
	var bg_color = _get_current_background_color()
	
	# 创建按钮样式
	_create_stylebox("normal", bg_color, radius)
	_create_stylebox("hover", bg_color.lightened(0.1) if bg_color.a > 0 else Color(0.4, 0.4, 0.4, 0.16), radius)
	_create_stylebox("pressed", bg_color.darkened(0.1) if bg_color.a > 0 else Color(0.35, 0.35, 0.35, 0.14), radius)
	_create_stylebox("focus", bg_color, radius)
	_create_stylebox("disabled", bg_color.darkened(0.3) if bg_color.a > 0 else Color(0.2, 0.2, 0.2, 0.08), radius)
	
	_updating = false

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

func _update_state_display() -> void:
	if not is_inside_tree():
		return
	
	# 更新文字
	text = _get_current_text()
	
	# 更新图标
	_update_icon()
	
	# 更新颜色
	_update_colors()
	
	# 更新按钮样式（因为背景颜色可能变化）
	_update_button_style()
	
	# 更新布局
	_update_layout()

func _update_icon() -> void:
	if not is_inside_tree() or not _icon_texture_rect or _updating:
		return
	
	var current_icon = _get_current_icon()
	_icon_texture_rect.texture = current_icon
	_icon_texture_rect.visible = current_icon != null
	
	# 应用图标颜色
	var icon_color = _get_current_icon_color()
	_icon_texture_rect.modulate = icon_color
	
	if current_icon:
		var size_config = SIZE_MAP.get(button_size, SIZE_MAP[ButtonSize.STANDARD36])
		var actual_icon_size = icon_size if icon_size > 0 else size_config["icon"]
		_icon_texture_rect.custom_minimum_size = Vector2(actual_icon_size, actual_icon_size)
		_icon_texture_rect.size = Vector2(actual_icon_size, actual_icon_size)
	
	_update_layout()

func _update_colors() -> void:
	if not is_inside_tree():
		return
	
	# 应用文字颜色
	var text_color = _get_current_text_color()
	if text_color.a > 0:
		add_theme_color_override("font_color", text_color)
		add_theme_color_override("font_hover_color", text_color.lightened(0.1))
		add_theme_color_override("font_pressed_color", text_color.darkened(0.1))
		add_theme_color_override("font_focus_color", text_color)
	else:
		remove_theme_color_override("font_color")
		remove_theme_color_override("font_hover_color")
		remove_theme_color_override("font_pressed_color")
		remove_theme_color_override("font_focus_color")

func _update_layout() -> void:
	if not is_inside_tree() or not _icon_texture_rect or _updating:
		return
	
	var has_text = _get_current_text() != ""
	var has_icon = _get_current_icon() != null
	
	var size_config = SIZE_MAP.get(button_size, SIZE_MAP[ButtonSize.STANDARD36])
	var actual_icon_size = icon_size if icon_size > 0 else size_config["icon"]
	var radius = corner_radius if corner_radius >= 0 else size_config["corner"]
	
	if has_icon:
		if has_text:
			if icon_layout_mode == IconLayoutMode.ICON_TOP:
				# 图标 + 文字:图标在上方，水平居中
				icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
				
				var current_width = size.x
				if current_width <= 0:
					current_width = custom_minimum_size.x
				
				_icon_texture_rect.position = Vector2(
					(current_width - actual_icon_size) / 2.0,
					padding_vertical
				)
				
				alignment = HORIZONTAL_ALIGNMENT_CENTER
				
				var min_width_for_icon = padding_horizontal * 2 + actual_icon_size
				if custom_minimum_size.x < min_width_for_icon:
					custom_minimum_size.x = min_width_for_icon
				
				# 修改样式的上边距为图标腾出空间
				for state in ["normal", "hover", "pressed", "focus", "disabled"]:
					var style = get_theme_stylebox(state)
					if style is StyleBoxFlat:
						style.content_margin_top = padding_vertical + actual_icon_size + icon_text_gap
						style.content_margin_left = padding_horizontal
						style.content_margin_right = padding_horizontal
						style.content_margin_bottom = padding_vertical
			else:
				# 图标 + 文字:图标在左侧，垂直居中
				icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
				custom_minimum_size.x = 0
				
				var button_height = custom_minimum_size.y
				if button_height == 0:
					button_height = size.y
				
				_icon_texture_rect.position = Vector2(
					padding_horizontal,
					(button_height - actual_icon_size) / 2.0
				)
				
				alignment = HORIZONTAL_ALIGNMENT_CENTER
				
				# 修改样式的左边距为图标腾出空间
				for state in ["normal", "hover", "pressed", "focus", "disabled"]:
					var style = get_theme_stylebox(state)
					if style is StyleBoxFlat:
						style.content_margin_left = padding_horizontal + actual_icon_size + icon_text_gap
						style.content_margin_top = padding_vertical
						style.content_margin_right = padding_horizontal
						style.content_margin_bottom = padding_vertical
			
			if _ripple_mixin:
				_ripple_mixin.set_corner_radius(float(radius))
		else:
			# 只有图标:设为圆形按钮
			alignment = HORIZONTAL_ALIGNMENT_CENTER
			var button_height = custom_minimum_size.y
			
			custom_minimum_size.x = button_height
			
			_icon_texture_rect.position = Vector2(
				(button_height - actual_icon_size) / 2.0,
				(button_height - actual_icon_size) / 2.0
			)
			
			var circle_radius = int(button_height / 2.0)
			if corner_radius >= 0:
				circle_radius = corner_radius
			
			for state in ["normal", "hover", "pressed", "focus", "disabled"]:
				var style = get_theme_stylebox(state)
				if style is StyleBoxFlat:
					style.content_margin_left = 0
					style.content_margin_right = 0
					style.content_margin_top = 0
					style.content_margin_bottom = 0
					style.corner_radius_top_left = circle_radius
					style.corner_radius_top_right = circle_radius
					style.corner_radius_bottom_left = circle_radius
					style.corner_radius_bottom_right = circle_radius
			
			if _ripple_mixin:
				_ripple_mixin.set_corner_radius(float(circle_radius))
	else:
		# 只有文字:恢复长方形按钮
		alignment = HORIZONTAL_ALIGNMENT_CENTER
		custom_minimum_size.x = 0
		
		for state in ["normal", "hover", "pressed", "focus", "disabled"]:
			var style = get_theme_stylebox(state)
			if style is StyleBoxFlat:
				style.content_margin_left = padding_horizontal
				style.content_margin_right = padding_horizontal
				style.content_margin_top = padding_vertical
				style.content_margin_bottom = padding_vertical
				style.corner_radius_top_left = radius
				style.corner_radius_top_right = radius
				style.corner_radius_bottom_left = radius
				style.corner_radius_bottom_right = radius
		
		if _ripple_mixin:
			_ripple_mixin.set_corner_radius(float(radius))

# ============ 状态获取辅助方法 ============

func _get_current_state() -> ToggleButtonState:
	if states.is_empty() or current_state < 0 or current_state >= states.size():
		return null
	return states[current_state]

func _get_current_icon() -> Texture2D:
	var state = _get_current_state()
	return state.icon if state else null

func _get_current_text() -> String:
	var state = _get_current_state()
	return state.label if state else ""

func _get_current_background_color() -> Color:
	var state = _get_current_state()
	if state and state.background_color.a > 0:
		return state.background_color
	return default_background_color

func _get_current_text_color() -> Color:
	var state = _get_current_state()
	return state.text_color if state else Color.WHITE

func _get_current_icon_color() -> Color:
	var state = _get_current_state()
	return state.icon_color if state else Color.WHITE

# ============ 状态切换 ============

func _on_pressed() -> void:
	if auto_cycle:
		cycle_state()

## 切换到下一个状态
func cycle_state() -> void:
	if states.is_empty():
		return
	
	var next_state = _calculate_next_state()
	
	if transition_duration > 0:
		_animate_transition(next_state)
	else:
		current_state = next_state

func _calculate_next_state() -> int:
	var count = states.size()
	if count <= 1:
		return 0
	
	match cycle_mode:
		CycleMode.FORWARD:
			return (current_state + 1) % count
		CycleMode.BACKWARD:
			return (current_state - 1 + count) % count
		CycleMode.PING_PONG:
			var next = current_state + _ping_pong_direction
			if next >= count - 1:
				_ping_pong_direction = -1
				return count - 1
			elif next <= 0:
				_ping_pong_direction = 1
				return 0
			return next
	
	return 0

func _animate_transition(next_state: int) -> void:
	if _transition_tween and _transition_tween.is_valid():
		_transition_tween.kill()
	
	_transition_tween = create_tween()
	_transition_tween.set_ease(Tween.EASE_OUT)
	_transition_tween.set_trans(Tween.TRANS_CUBIC)
	
	# 淡出效果
	_transition_tween.tween_property(_icon_texture_rect, "modulate:a", 0.0, transition_duration * 0.5)
	_transition_tween.tween_callback(func():
		current_state = next_state
	)
	# 淡入效果
	_transition_tween.tween_property(_icon_texture_rect, "modulate:a", 1.0, transition_duration * 0.5)

# ============ 涟漪效果 ============

func _on_button_down() -> void:
	if not enable_ripple or not _ripple_mixin:
		return
	
	var local_pos = get_local_mouse_position()
	
	# 更新圆角参数
	var has_text = _get_current_text() != ""
	var has_icon = _get_current_icon() != null
	var current_radius: float
	
	if has_icon and not has_text:
		if corner_radius >= 0:
			current_radius = float(corner_radius)
		else:
			current_radius = custom_minimum_size.y / 2.0
	else:
		current_radius = float(corner_radius if corner_radius >= 0 else SIZE_MAP[button_size]["corner"])
	
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

# ============ 公共方法 ============

## 添加状态
func add_state(state: ToggleButtonState) -> int:
	states.append(state)
	_update_state_display()
	return states.size() - 1

## 移除状态
func remove_state(index: int) -> void:
	if index >= 0 and index < states.size():
		states.remove_at(index)
		if current_state >= states.size():
			current_state = maxi(0, states.size() - 1)
		_update_state_display()

## 设置状态 (不触发信号)
func set_state_no_signal(index: int) -> void:
	if index >= 0 and index < states.size():
		current_state = index
		_update_state_display()

## 获取状态数量
func get_state_count() -> int:
	return states.size()

## 快速创建两个状态的切换按钮
func setup_toggle(
	state1_icon: Texture2D, state1_label: String,
	state2_icon: Texture2D, state2_label: String,
	state1_color: Color = Color.WHITE, state2_color: Color = Color.WHITE
) -> void:
	states.clear()
	
	var s1 = ToggleButtonState.new()
	s1.icon = state1_icon
	s1.label = state1_label
	s1.icon_color = state1_color
	s1.text_color = state1_color
	states.append(s1)
	
	var s2 = ToggleButtonState.new()
	s2.icon = state2_icon
	s2.label = state2_label
	s2.icon_color = state2_color
	s2.text_color = state2_color
	states.append(s2)
	
	current_state = 0
	_update_state_display()

## 快速创建多个仅图标状态的切换按钮
func setup_icon_toggle(icons: Array[Texture2D], colors: Array[Color] = []) -> void:
	states.clear()
	
	for i in icons.size():
		var state = ToggleButtonState.new()
		state.icon = icons[i]
		state.label = ""
		if colors.size() > i:
			state.icon_color = colors[i]
		states.append(state)
	
	current_state = 0
	_update_state_display()

## 设置为 filled 风格 (Material Design)
func set_filled_style(bg_color: Color = Color(0.4, 0.6, 1.0)) -> void:
	default_background_color = bg_color
	_update_button_style()

## 设置为 outlined 风格 (Material Design)
func set_outlined_style(border_color: Color = Color(0.4, 0.6, 1.0), border_width: int = 2) -> void:
	var radius = corner_radius if corner_radius >= 0 else SIZE_MAP[button_size]["corner"]
	
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

## 设置为 text 风格 (Material Design)
func set_text_style(text_color: Color = Color(0.4, 0.6, 1.0)) -> void:
	var radius = corner_radius if corner_radius >= 0 else SIZE_MAP[button_size]["corner"]
	
	_create_stylebox("normal", Color.TRANSPARENT, radius)
	_create_stylebox("hover", Color(text_color.r, text_color.g, text_color.b, 0.08), radius)
	_create_stylebox("pressed", Color(text_color.r, text_color.g, text_color.b, 0.12), radius)
	
	add_theme_color_override("font_color", text_color)
