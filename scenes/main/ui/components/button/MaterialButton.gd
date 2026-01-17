@tool
class_name MaterialButton
extends Button

## Material Design风格按钮
## 支持图标、文字自动布局,遵循Material Design规范

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

## 按钮尺寸
@export var button_size: ButtonSize = ButtonSize.STANDARD36:
	set(value):
		button_size = value
		_update_button_style()

## 按钮图标
@export var button_icon: Texture2D:
	set(value):
		button_icon = value
		_update_icon()

## 图标大小 (默认20dp，会根据按钮尺寸自动调整)
@export_range(12, 48, 1) var icon_size: int = 20:
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
		if _ripple_panel and _ripple_panel.material:
			_ripple_panel.material.set_shader_parameter("ripple_color", ripple_color)

## 背景颜色 (默认透明)
@export var background_color: Color = Color.TRANSPARENT:
	set(value):
		background_color = value
		_update_button_style()

## 圆角半径 (自动根据按钮高度计算,也可手动覆盖)
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

## 是否裁剪超出的文字
@export var clip_button_text: bool = false:
	set(value):
		clip_button_text = value
		clip_text = value
		_update_layout()

## 文字超出时的行为 (需要启用 clip_button_text)
@export var text_overrun: TextServer.OverrunBehavior = TextServer.OVERRUN_NO_TRIMMING:
	set(value):
		text_overrun = value
		text_overrun_behavior = value
		_update_layout()

@export_group("文字滚动")

## 是否启用文字滚动效果 (当文字超出时自动滚动)
@export var enable_text_scroll: bool = false:
	set(value):
		enable_text_scroll = value
		_setup_scroll_label()
		_update_scroll()

## 滚动速度 (像素/秒)
@export_range(0, 200, 5) var scroll_speed: float = 50.0

## 滚动前的等待时间 (秒)
@export_range(0.0, 5.0, 0.1) var scroll_delay: float = 1.0

## 滚动到末尾后的等待时间 (秒)
@export_range(0.0, 5.0, 0.1) var scroll_end_delay: float = 1.0

## 文字间隔 (用于循环滚动时的间距)
@export_range(0, 200, 5) var scroll_gap: float = 50.0

## 滚动模式
@export_enum("来回滚动", "循环滚动") var scroll_mode: int = 1:
	set(value):
		scroll_mode = value
		if is_inside_tree() and enable_text_scroll:
			_update_scroll()

## 循环滚动时重复显示的文字数量 (2-5份，数量越多循环越流畅)
@export_range(2, 5, 1) var scroll_repeat_count: int = 3:
	set(value):
		scroll_repeat_count = value
		if is_inside_tree() and enable_text_scroll and scroll_mode == 1:
			_update_scroll()

# 内部节点
var _icon_texture_rect: TextureRect
var _ripple_panel: ColorRect
var _ripple_expand_tween: Tween  # 扩散动画
var _ripple_fade_tween: Tween    # 淡出动画
var _ripple_material: ShaderMaterial
var _click_position: Vector2 = Vector2.ZERO
var _updating: bool = false  # 防止循环调用

# 文字滚动相关
var _scroll_label: Label
var _scroll_container: Control
var _scroll_tween: Tween
var _text_width: float = 0.0
var _is_scrolling: bool = false

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
	_setup_scroll_label()
	_update_button_style()
	_update_icon()
	_update_layout()
	
	# 连接信号 - 确保在 _setup_button 之后连接
	if enable_ripple:
		if not button_down.is_connected(_on_button_down):
			button_down.connect(_on_button_down)
		if not button_up.is_connected(_on_button_up):
			button_up.connect(_on_button_up)
	
	# 延迟启动滚动检测
	if enable_text_scroll:
		await get_tree().process_frame
		_update_scroll()

func _setup_button() -> void:
	# 设置基础属性
	clip_contents = true
	focus_mode = Control.FOCUS_ALL
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	
	# 应用文字裁剪设置
	clip_text = clip_button_text
	text_overrun_behavior = text_overrun
	
	# 创建涟漪效果层 (先创建，确保在图标下面)
	if enable_ripple and not _ripple_panel:
		_ripple_panel = ColorRect.new()
		_ripple_panel.name = "RipplePanel"
		_ripple_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_ripple_panel.color = Color(1, 1, 1, 1)  # 白色背景，由 shader 控制显示
		
		# 创建并应用涟漪 shader
		_ripple_material = ShaderMaterial.new()
		var shader = load("res://scenes/main/ui/components/button/ripple.gdshader")
		_ripple_material.shader = shader
		_ripple_material.set_shader_parameter("ripple_color", ripple_color)
		_ripple_material.set_shader_parameter("ripple_radius", 0.0)
		_ripple_material.set_shader_parameter("ripple_alpha", 0.0)
		_ripple_material.set_shader_parameter("ripple_center", Vector2(0.5, 0.5))
		_ripple_material.set_shader_parameter("button_size", Vector2(100, 40))  # 默认尺寸
		_ripple_material.set_shader_parameter("corner_radius", 4.0)  # 默认圆角
		_ripple_panel.material = _ripple_material
		
		add_child(_ripple_panel)
		_ripple_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
		_ripple_panel.size = size
	
	# 创建图标纹理 (后创建，确保在涟漪上面)
	if not _icon_texture_rect:
		_icon_texture_rect = TextureRect.new()
		_icon_texture_rect.name = "IconTexture"
		_icon_texture_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		# 使用 EXPAND_IGNORE_SIZE 忽略原始纹理尺寸，允许任意缩放
		_icon_texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		# 使用 STRETCH_KEEP_ASPECT_CENTERED 保持比例并居中
		_icon_texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		add_child(_icon_texture_rect)

func _update_button_style() -> void:
	if not is_inside_tree() or _updating:
		return
	
	_updating = true
	
	var size_config = SIZE_MAP.get(button_size, SIZE_MAP[ButtonSize.STANDARD36])
	
	# 设置最小尺寸
	if icon_layout_mode == IconLayoutMode.ICON_TOP and button_icon and text != "":
		custom_minimum_size.y = 0 # 自适应高度
	else:
		custom_minimum_size.y = size_config["height"]
	
	# 直接设置变量，不触发 setter
	if icon_size == 20:  # 默认值,自动调整
		icon_size = size_config["icon"]
	
	# 直接设置变量，不触发 setter
	padding_horizontal = size_config["padding_h"]
	padding_vertical = size_config["padding_v"]
	
	# 设置圆角
	var radius = corner_radius if corner_radius >= 0 else size_config["corner"]
	
	# 同步更新涟漪的圆角和尺寸
	if _ripple_material:
		_ripple_material.set_shader_parameter("corner_radius", float(radius))
		_ripple_material.set_shader_parameter("button_size", size)
	
	# 创建按钮样式（使用背景颜色）
	_create_stylebox("normal", background_color, radius)
	_create_stylebox("hover", background_color.lightened(0.1) if background_color.a > 0 else Color(0.4, 0.4, 0.4, 0.16), radius)
	_create_stylebox("pressed", background_color.darkened(0.1) if background_color.a > 0 else Color(0.35, 0.35, 0.35, 0.14), radius)
	_create_stylebox("focus", background_color, radius)
	_create_stylebox("disabled", background_color.darkened(0.3) if background_color.a > 0 else Color(0.2, 0.2, 0.2, 0.08), radius)
	
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

func _update_icon() -> void:
	if not is_inside_tree() or not _icon_texture_rect or _updating:
		return
	
	_icon_texture_rect.texture = button_icon
	_icon_texture_rect.visible = button_icon != null
	
	if button_icon:
		# 直接设置图标尺寸，EXPAND_IGNORE_SIZE 模式会忽略原始纹理尺寸
		# STRETCH_KEEP_ASPECT_CENTERED 会保持比例并在区域内居中
		_icon_texture_rect.custom_minimum_size = Vector2(icon_size, icon_size)
		_icon_texture_rect.size = Vector2(icon_size, icon_size)
	
	_update_layout()

func _update_layout() -> void:
	if not is_inside_tree() or not _icon_texture_rect or _updating:
		return
	
	var has_text = text != null and text.length() > 0
	var has_icon = button_icon != null
	
	if has_icon:
		if has_text:
			if icon_layout_mode == IconLayoutMode.ICON_TOP:
				# 图标 + 文字:图标在上方，水平居中
				icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
				
				# 确保有宽度
				var current_width = size.x
				if current_width <= 0:
					current_width = custom_minimum_size.x
				
				_icon_texture_rect.position = Vector2(
					(current_width - icon_size) / 2.0,
					padding_vertical
				)
				
				# 调整文字对齐
				alignment = HORIZONTAL_ALIGNMENT_CENTER
				
				# 确保有宽度以容纳图标
				var min_width_for_icon = padding_horizontal * 2 + icon_size
				if custom_minimum_size.x < min_width_for_icon:
					custom_minimum_size.x = min_width_for_icon

				
				# 通过修改样式的上边距来为图标腾出空间
				for state in ["normal", "hover", "pressed", "focus", "disabled"]:
					var style = get_theme_stylebox(state)
					if style is StyleBoxFlat:
						style.content_margin_top = padding_vertical + icon_size + icon_text_gap
						style.content_margin_left = padding_horizontal
						style.content_margin_right = padding_horizontal
						style.content_margin_bottom = padding_vertical
			else:
				# 图标 + 文字:图标在左侧，垂直居中
				icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
				
				# 重置最小宽度 (如果有必要，但启用clip_text时保留宽度)
				if custom_minimum_size.x > 0 and not clip_button_text:
					custom_minimum_size.x = 0
				
				var button_height = custom_minimum_size.y
				if button_height == 0: button_height = size.y
				
				_icon_texture_rect.position = Vector2(
					padding_horizontal, 
					(button_height - icon_size) / 2.0  # 垂直居中
				)
				
				# 调整文字对齐
				alignment = HORIZONTAL_ALIGNMENT_CENTER
				
				# 通过修改样式的左边距来为图标腾出空间
				for state in ["normal", "hover", "pressed", "focus", "disabled"]:
					var style = get_theme_stylebox(state)
					if style is StyleBoxFlat:
						style.content_margin_left = padding_horizontal + icon_size + icon_text_gap
						style.content_margin_top = padding_vertical
						style.content_margin_right = padding_horizontal
						style.content_margin_bottom = padding_vertical
			
			# 同步更新涟漪效果的圆角（图标+文字时使用正常圆角）
			if _ripple_material:
				var size_config = SIZE_MAP.get(button_size, SIZE_MAP[ButtonSize.STANDARD36])
				var radius = corner_radius if corner_radius >= 0 else size_config["corner"]
				_ripple_material.set_shader_parameter("corner_radius", float(radius))
		else:
			# 只有图标:设为圆形按钮
			alignment = HORIZONTAL_ALIGNMENT_CENTER
			var button_height = custom_minimum_size.y
			
			# 设置按钮为正方形（圆形按钮）
			custom_minimum_size.x = button_height
			
			# 图标居中
			_icon_texture_rect.position = Vector2(
				(button_height - icon_size) / 2.0,  # 水平居中
				(button_height - icon_size) / 2.0   # 垂直居中
			)
			
			# 设置圆角 (如果未自定义，则默认为圆形)
			var radius = int(button_height / 2.0)
			if corner_radius >= 0:
				radius = corner_radius
				
			for state in ["normal", "hover", "pressed", "focus", "disabled"]:
				var style = get_theme_stylebox(state)
				if style is StyleBoxFlat:
					style.content_margin_left = 0
					style.content_margin_right = 0
					style.content_margin_top = 0
					style.content_margin_bottom = 0
					# 设置圆角
					style.corner_radius_top_left = radius
					style.corner_radius_top_right = radius
					style.corner_radius_bottom_left = radius
					style.corner_radius_bottom_right = radius
			
			# 同步更新涟漪效果的圆角
			if _ripple_material:
				_ripple_material.set_shader_parameter("corner_radius", float(radius))
	else:
		# 只有文字:恢复长方形按钮
		alignment = HORIZONTAL_ALIGNMENT_CENTER
		# 启用clip_text时保留宽度，否则重置
		if not clip_button_text:
			custom_minimum_size.x = 0
		
		# 重置边距和圆角
		var size_config = SIZE_MAP.get(button_size, SIZE_MAP[ButtonSize.STANDARD36])
		var radius = corner_radius if corner_radius >= 0 else size_config["corner"]
		
		for state in ["normal", "hover", "pressed", "focus", "disabled"]:
			var style = get_theme_stylebox(state)
			if style is StyleBoxFlat:
				style.content_margin_left = padding_horizontal
				style.content_margin_right = padding_horizontal
				style.content_margin_top = padding_vertical
				style.content_margin_bottom = padding_vertical
				# 恢复正常圆角
				style.corner_radius_top_left = radius
				style.corner_radius_top_right = radius
				style.corner_radius_bottom_left = radius
				style.corner_radius_bottom_right = radius
		
		# 同步更新涟漪效果的圆角
		if _ripple_material:
			_ripple_material.set_shader_parameter("corner_radius", float(radius))

func _on_button_down() -> void:
	if not enable_ripple:
		return
	
	# 确保涟漪面板存在
	if not _ripple_panel:
		_setup_button()
	
	if not _ripple_panel or not _ripple_material:
		return
	
	# 停止之前的动画
	if _ripple_expand_tween and _ripple_expand_tween.is_valid():
		_ripple_expand_tween.kill()
	if _ripple_fade_tween and _ripple_fade_tween.is_valid():
		_ripple_fade_tween.kill()
	
	# 获取点击位置并转换为 UV 坐标
	var local_pos = get_local_mouse_position()
	var uv_center = local_pos / size
	uv_center = uv_center.clamp(Vector2.ZERO, Vector2.ONE)
	
	# 设置宽高比以保持圆形
	var aspect = size.x / size.y if size.y > 0 else 1.0
	_ripple_material.set_shader_parameter("aspect_ratio", Vector2(1.0, aspect))
	_ripple_material.set_shader_parameter("ripple_center", uv_center)
	
	# 更新按钮尺寸和圆角参数到shader
	_ripple_material.set_shader_parameter("button_size", size)
	
	# 计算正确的圆角：如果是圆形按钮（只有图标），使用按钮高度的一半
	var has_text = text != null and text.length() > 0
	var has_icon = button_icon != null
	var current_radius: float
	if has_icon and not has_text:
		# 圆形按钮 (如果没有自定义圆角)
		if corner_radius >= 0:
			current_radius = float(corner_radius)
		else:
			current_radius = custom_minimum_size.y / 2.0
	else:
		# 普通按钮
		current_radius = float(corner_radius if corner_radius >= 0 else SIZE_MAP[button_size]["corner"])
	_ripple_material.set_shader_parameter("corner_radius", current_radius)
	
	# 计算需要的最大半径（从点击位置到最远角落的距离）
	var corners = [Vector2.ZERO, Vector2(1, 0), Vector2(0, 1), Vector2.ONE]
	var max_dist = 0.0
	for corner in corners:
		var dist = ((corner - uv_center) * Vector2(1.0, aspect)).length()
		max_dist = max(max_dist, dist)
	
	# 确保涟漪面板可见，但保持在图标下方
	_ripple_panel.show()
	# 把涟漪移到第一个子节点位置（在图标下方）
	move_child(_ripple_panel, 0)
	
	# 重置涟漪状态
	_ripple_material.set_shader_parameter("ripple_radius", 0.0)
	_ripple_material.set_shader_parameter("ripple_alpha", 1.0)
	
	# 创建扩散动画 - 加快速度
	_ripple_expand_tween = create_tween()
	_ripple_expand_tween.set_ease(Tween.EASE_OUT)
	_ripple_expand_tween.set_trans(Tween.TRANS_CUBIC)
	
	# 涟漪从中心向外扩散 - 从 0.4 秒减少到 0.25 秒
	_ripple_expand_tween.tween_method(_set_ripple_radius, 0.0, max_dist * 1.1, 0.25)

func _on_button_up() -> void:
	if not enable_ripple:
		return
	
	if not _ripple_panel or not _ripple_material:
		return
	
	# 只停止淡出动画，让扩散继续进行
	if _ripple_fade_tween and _ripple_fade_tween.is_valid():
		_ripple_fade_tween.kill()
	
	# 创建淡出动画 - 加快速度
	_ripple_fade_tween = create_tween()
	_ripple_fade_tween.set_ease(Tween.EASE_OUT)
	_ripple_fade_tween.set_trans(Tween.TRANS_CUBIC)
	
	# 淡出涟漪效果 - 从 0.3 秒减少到 0.2 秒
	_ripple_fade_tween.tween_method(_set_ripple_alpha, 1.0, 0.0, 0.2)

# Shader 参数设置辅助函数
func _set_ripple_radius(value: float) -> void:
	if _ripple_material:
		_ripple_material.set_shader_parameter("ripple_radius", value)

func _set_ripple_alpha(value: float) -> void:
	if _ripple_material:
		_ripple_material.set_shader_parameter("ripple_alpha", value)

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_update_layout()
		# 尺寸改变时更新shader参数
		if _ripple_material:
			_ripple_material.set_shader_parameter("button_size", size)
			# corner_radius 在 _update_layout 中已经处理
		# 尺寸改变时更新滚动
		if enable_text_scroll:
			_update_scroll_container_rect()
			_update_scroll()

# 公共方法:方便的设置方法
func set_material_style(size: ButtonSize, icon_tex: Texture2D = null, label: String = "") -> void:
	button_size = size
	button_icon = icon_tex
	text = label
	text = label

## 设置为filled按钮 (Material Design)
func set_filled_style(bg_color: Color = Color(0.4, 0.6, 1.0)) -> void:
	_create_stylebox("normal", bg_color, corner_radius if corner_radius >= 0 else SIZE_MAP[button_size]["corner"])
	_create_stylebox("hover", bg_color.lightened(0.1), corner_radius if corner_radius >= 0 else SIZE_MAP[button_size]["corner"])
	_create_stylebox("pressed", bg_color.darkened(0.1), corner_radius if corner_radius >= 0 else SIZE_MAP[button_size]["corner"])

## 设置为outlined按钮 (Material Design)
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

## 设置为text按钮 (Material Design)
func set_text_style(text_color: Color = Color(0.4, 0.6, 1.0)) -> void:
	var radius = corner_radius if corner_radius >= 0 else SIZE_MAP[button_size]["corner"]
	
	_create_stylebox("normal", Color.TRANSPARENT, radius)
	_create_stylebox("hover", Color(text_color.r, text_color.g, text_color.b, 0.08), radius)
	_create_stylebox("pressed", Color(text_color.r, text_color.g, text_color.b, 0.12), radius)
	
	add_theme_color_override("font_color", text_color)

# ==================== 文字滚动相关 ====================

func _setup_scroll_label() -> void:
	if not is_inside_tree():
		return
	
	if enable_text_scroll:
		# 隐藏按钮自带的文字
		add_theme_color_override("font_color", Color.TRANSPARENT)
		
		# 创建裁剪容器
		if not _scroll_container:
			_scroll_container = Control.new()
			_scroll_container.name = "ScrollContainer"
			_scroll_container.clip_contents = true
			_scroll_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
			add_child(_scroll_container)
		
		# 创建滚动文字标签
		if not _scroll_label:
			_scroll_label = Label.new()
			_scroll_label.name = "ScrollLabel"
			_scroll_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_scroll_container.add_child(_scroll_label)
		
		# 同步字体设置
		_sync_label_theme()
		_scroll_label.text = text
		
		# 更新容器位置
		_update_scroll_container_rect()
	else:
		# 恢复按钮文字颜色
		remove_theme_color_override("font_color")
		
		# 停止滚动
		_stop_scroll()
		
		# 移除滚动标签
		if _scroll_label:
			_scroll_label.queue_free()
			_scroll_label = null
		if _scroll_container:
			_scroll_container.queue_free()
			_scroll_container = null

func _sync_label_theme() -> void:
	if not _scroll_label:
		return
	
	# 从按钮复制字体设置
	var font = get_theme_font("font")
	var font_size = get_theme_font_size("font_size")
	var font_color = get_theme_color("font_color")
	
	if font:
		_scroll_label.add_theme_font_override("font", font)
	if font_size > 0:
		_scroll_label.add_theme_font_size_override("font_size", font_size)
	
	# 使用原本的字体颜色（不是透明的）
	_scroll_label.add_theme_color_override("font_color", font_color if font_color.a > 0 else Color.WHITE)

func _update_scroll_container_rect() -> void:
	if not _scroll_container:
		return
	
	var has_icon = button_icon != null
	var content_left = padding_horizontal
	var content_right = padding_horizontal
	
	# 如果有图标在左侧，调整左边距
	if has_icon and icon_layout_mode == IconLayoutMode.ICON_LEFT:
		content_left = padding_horizontal + icon_size + icon_text_gap
	
	# 计算容器区域
	var container_x = content_left
	var container_width = size.x - content_left - content_right
	var container_height = size.y - padding_vertical * 2
	
	_scroll_container.position = Vector2(container_x, padding_vertical)
	_scroll_container.size = Vector2(container_width, container_height)
	
	# 更新标签位置（垂直居中）
	if _scroll_label:
		_scroll_label.position.y = (container_height - _scroll_label.size.y) / 2.0

func _update_scroll() -> void:
	if not is_inside_tree() or not enable_text_scroll or not _scroll_label:
		return
	
	# 更新容器位置
	_update_scroll_container_rect()
	
	# 设置文字内容（循环模式下需要重复显示）
	var is_loop_mode = (scroll_mode == 1)
	if is_loop_mode:
		# 循环滚动：显示文字的多份拷贝，用空格隔开
		var gap_count = int(scroll_gap / 4)  # 粗略估算空格数
		var gap_text = ""
		for i in gap_count:
			gap_text += " "
		
		# 根据 scroll_repeat_count 重复文字
		var repeated_text = ""
		for i in scroll_repeat_count:
			repeated_text += text
			if i < scroll_repeat_count - 1:
				repeated_text += gap_text
		_scroll_label.text = repeated_text
	else:
		_scroll_label.text = text
	
	await get_tree().process_frame  # 等待一帧让Label更新尺寸
	
	if not _scroll_label:
		return
	
	# 计算单个文字的宽度
	if is_loop_mode:
		# 临时设置单个文字来测量宽度
		var original_text = _scroll_label.text
		_scroll_label.text = text
		await get_tree().process_frame
		_text_width = _scroll_label.size.x
		_scroll_label.text = original_text
		await get_tree().process_frame
	else:
		_text_width = _scroll_label.size.x
	
	var container_width = _scroll_container.size.x if _scroll_container else 0.0
	
	# 重置位置
	_scroll_label.position.x = 0
	
	# 如果文字超出容器，开始滚动
	if _text_width > container_width and container_width > 0:
		_start_scroll()
	else:
		_stop_scroll()

func _start_scroll() -> void:
	if _is_scrolling:
		return
	
	_is_scrolling = true
	_do_scroll_animation()

func _stop_scroll() -> void:
	_is_scrolling = false
	if _scroll_tween and _scroll_tween.is_valid():
		_scroll_tween.kill()
		_scroll_tween = null
	
	if _scroll_label:
		_scroll_label.position.x = 0

func _do_scroll_animation() -> void:
	if not _is_scrolling or not _scroll_label or not _scroll_container:
		return
	
	var container_width = _scroll_container.size.x
	var scroll_distance = _text_width - container_width
	
	if scroll_distance <= 0:
		_stop_scroll()
		return
	
	# 停止之前的动画
	if _scroll_tween and _scroll_tween.is_valid():
		_scroll_tween.kill()
	
	_scroll_tween = create_tween()
	_scroll_tween.set_loops()  # 无限循环
	
	var is_loop_mode = (scroll_mode == 1)
	if is_loop_mode:
		# 循环滚动模式：无缝循环
		# 文字已经重复显示，只需要滚动到第一份文字完全消失的位置，然后瞬间重置
		var total_distance = _text_width + scroll_gap
		var duration = total_distance / scroll_speed
		
		# 等待 -> 从0滚动到-(文字宽度+间隔) -> 瞬间重置到0
		_scroll_tween.tween_interval(scroll_delay)
		_scroll_tween.tween_property(_scroll_label, "position:x", -total_distance, duration).set_trans(Tween.TRANS_LINEAR)
		_scroll_tween.tween_callback(func(): 
			if _scroll_label:
				_scroll_label.position.x = 0
		)
	else:
		# 来回滚动模式
		var duration = scroll_distance / scroll_speed
		
		# 等待 -> 滚动到末尾 -> 等待 -> 滚动回开头
		_scroll_tween.tween_interval(scroll_delay)
		_scroll_tween.tween_property(_scroll_label, "position:x", -scroll_distance, duration).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
		_scroll_tween.tween_interval(scroll_end_delay)
		_scroll_tween.tween_property(_scroll_label, "position:x", 0.0, duration).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)

# 重写 text 属性的 setter 以支持滚动更新
func _set(property: StringName, value: Variant) -> bool:
	if property == "text":
		# 调用父类设置
		text = value
		# 更新滚动
		if enable_text_scroll and _scroll_label and is_inside_tree():
			call_deferred("_update_scroll")
		return false  # 返回 false 让父类也处理
	return false
