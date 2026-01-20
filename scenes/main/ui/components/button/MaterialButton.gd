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

enum ContentAlignment {
	ALIGN_LEFT,   ## 靠左对齐
	ALIGN_CENTER, ## 居中对齐 (默认)
	ALIGN_RIGHT   ## 靠右对齐
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

## 内容对齐方式 (图标+文字整体的位置)
@export var content_alignment: ContentAlignment = ContentAlignment.ALIGN_CENTER:
	set(value):
		content_alignment = value
		_update_layout()

## 按钮最小宽度 (0 表示自动)
@export_range(0, 500, 1) var min_width: int = 0:
	set(value):
		min_width = value
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
var _scroll_label2: Label  # 第二个标签，用于循环滚动的无缝衔接
var _scroll_container: Control
var _scroll_tween: Tween
var _text_width: float = 0.0
var _is_scrolling: bool = false
var _scroll_position: float = 0.0  # 当前滚动位置
var _total_scroll_width: float = 0.0  # 循环滚动的总宽度（文字+间隔）
var _scroll_wait_timer: float = 0.0  # 等待计时器
var _scroll_state: int = 0  # 0: 等待开始, 1: 滚动中, 2: 等待结束（来回模式）, 3: 返回中（来回模式）
var _scroll_update_queued: bool = false  # 是否已排队更新

# Material Design尺寸定义 (dp)
const SIZE_MAP = {
	ButtonSize.SMALL32: {"height": 32, "icon": 18, "padding_h": 12, "padding_v": 6, "corner": 4},
	ButtonSize.STANDARD36: {"height": 36, "icon": 20, "padding_h": 14, "padding_v": 7, "corner": 6},
	ButtonSize.MEDIUM40: {"height": 40, "icon": 24, "padding_h": 16, "padding_v": 8, "corner": 6},
	ButtonSize.LARGE48: {"height": 48, "icon": 24, "padding_h": 20, "padding_v": 10, "corner": 8},
	ButtonSize.EXTRA_LARGE56: {"height": 56, "icon": 24, "padding_h": 24, "padding_v": 12, "corner": 8}
}

func _ready() -> void:
	set_process(false)  # 默认禁用 _process，只在需要滚动时启用
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
		# 设置 anchors 填充父容器，offsets 设为 0 让 size 自动跟随
		_ripple_panel.anchor_left = 0.0
		_ripple_panel.anchor_top = 0.0
		_ripple_panel.anchor_right = 1.0
		_ripple_panel.anchor_bottom = 1.0
		_ripple_panel.offset_left = 0
		_ripple_panel.offset_top = 0
		_ripple_panel.offset_right = 0
		_ripple_panel.offset_bottom = 0
	
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
	
	# 设置最小宽度
	if min_width > 0:
		custom_minimum_size.x = min_width
	
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
				# 图标 + 文字:图标在上方
				# 确保有宽度
				var current_width = size.x
				if current_width <= 0:
					current_width = custom_minimum_size.x
				
				# 根据内容对齐方式设置图标位置
				var icon_x: float
				match content_alignment:
					ContentAlignment.ALIGN_LEFT:
						icon_x = padding_horizontal
						icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
						alignment = HORIZONTAL_ALIGNMENT_LEFT
					ContentAlignment.ALIGN_RIGHT:
						icon_x = current_width - padding_horizontal - icon_size
						icon_alignment = HORIZONTAL_ALIGNMENT_RIGHT
						alignment = HORIZONTAL_ALIGNMENT_RIGHT
					_: # ALIGN_CENTER
						icon_x = (current_width - icon_size) / 2.0
						icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
						alignment = HORIZONTAL_ALIGNMENT_CENTER
				
				_icon_texture_rect.position = Vector2(icon_x, padding_vertical)
				
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
				# 重置最小宽度 (如果没有设置min_width且没有启用clip_text)
				if min_width == 0 and not clip_button_text:
					custom_minimum_size.x = 0
				
				var button_height = custom_minimum_size.y
				if button_height == 0: button_height = size.y
				
				var current_width = size.x
				if current_width <= 0:
					current_width = custom_minimum_size.x
				
				# 计算内容总宽度 (图标 + 间隔 + 预估文字宽度)
				var content_width = icon_size + icon_text_gap
				
				# 根据内容对齐方式设置位置
				var icon_x: float
				var margin_left: float
				var margin_right: float
				
				match content_alignment:
					ContentAlignment.ALIGN_LEFT:
						icon_x = padding_horizontal
						margin_left = padding_horizontal + icon_size + icon_text_gap
						margin_right = padding_horizontal
						icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
						alignment = HORIZONTAL_ALIGNMENT_LEFT
					ContentAlignment.ALIGN_RIGHT:
						# 图标在文字左边，整体靠右
						icon_x = current_width - padding_horizontal - icon_size
						margin_left = padding_horizontal
						margin_right = padding_horizontal + icon_size + icon_text_gap
						icon_alignment = HORIZONTAL_ALIGNMENT_RIGHT
						alignment = HORIZONTAL_ALIGNMENT_RIGHT
					_: # ALIGN_CENTER
						icon_x = padding_horizontal
						margin_left = padding_horizontal + icon_size + icon_text_gap
						margin_right = padding_horizontal
						icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
						alignment = HORIZONTAL_ALIGNMENT_CENTER
				
				_icon_texture_rect.position = Vector2(
					icon_x, 
					(button_height - icon_size) / 2.0  # 垂直居中
				)
				
				# 通过修改样式的边距来调整文字位置
				for state in ["normal", "hover", "pressed", "focus", "disabled"]:
					var style = get_theme_stylebox(state)
					if style is StyleBoxFlat:
						style.content_margin_left = margin_left
						style.content_margin_top = padding_vertical
						style.content_margin_right = margin_right
						style.content_margin_bottom = padding_vertical
			
			# 同步更新涟漪效果的圆角（图标+文字时使用正常圆角）
			if _ripple_material:
				var size_config = SIZE_MAP.get(button_size, SIZE_MAP[ButtonSize.STANDARD36])
				var radius = corner_radius if corner_radius >= 0 else size_config["corner"]
				_ripple_material.set_shader_parameter("corner_radius", float(radius))
		else:
			# 只有图标
			var button_height = custom_minimum_size.y
			var button_width = button_height
			
			# 如果设置了最小宽度，使用最小宽度
			if min_width > 0:
				button_width = max(min_width, button_height)
				custom_minimum_size.x = button_width
			else:
				# 设置按钮为正方形（圆形按钮）
				custom_minimum_size.x = button_height
				button_width = button_height
			
			var current_width = size.x if size.x > 0 else button_width
			
			# 根据内容对齐方式设置图标位置
			var icon_x: float
			match content_alignment:
				ContentAlignment.ALIGN_LEFT:
					icon_x = padding_horizontal
					alignment = HORIZONTAL_ALIGNMENT_LEFT
				ContentAlignment.ALIGN_RIGHT:
					icon_x = current_width - padding_horizontal - icon_size
					alignment = HORIZONTAL_ALIGNMENT_RIGHT
				_: # ALIGN_CENTER
					icon_x = (current_width - icon_size) / 2.0
					alignment = HORIZONTAL_ALIGNMENT_CENTER
			
			_icon_texture_rect.position = Vector2(
				icon_x,
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
		# 根据内容对齐方式设置文字对齐
		match content_alignment:
			ContentAlignment.ALIGN_LEFT:
				alignment = HORIZONTAL_ALIGNMENT_LEFT
			ContentAlignment.ALIGN_RIGHT:
				alignment = HORIZONTAL_ALIGNMENT_RIGHT
			_: # ALIGN_CENTER
				alignment = HORIZONTAL_ALIGNMENT_CENTER
		
		# 如果没有设置min_width且没有启用clip_text，重置宽度
		if min_width == 0 and not clip_button_text:
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
	# 需要按照实际像素距离计算，所以直接使用 size 而不是比例
	var aspect = size.x / size.y if size.y > 0 else 1.0
	_ripple_material.set_shader_parameter("aspect_ratio", Vector2(aspect, 1.0))
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
		var dist = ((corner - uv_center) * Vector2(aspect, 1.0)).length()
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
		# 尺寸改变时更新滚动（使用 deferred 避免与 text 改变时的更新冲突）
		if enable_text_scroll:
			_update_scroll_container_rect()
			_request_scroll_update()

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

# 保存原始字体颜色（用于滚动标签）
var _original_font_color: Color = Color.WHITE

func _setup_scroll_label() -> void:
	if not is_inside_tree():
		return
	
	if enable_text_scroll:
		# 先获取原始字体颜色（在设置透明之前）
		if not has_theme_color_override("font_color"):
			_original_font_color = get_theme_color("font_color")
			if _original_font_color.a <= 0:
				_original_font_color = Color.WHITE
		
		# 创建裁剪容器
		if not _scroll_container:
			_scroll_container = Control.new()
			_scroll_container.name = "ScrollContainer"
			_scroll_container.clip_contents = true
			_scroll_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
			add_child(_scroll_container)
		
		# 创建第一个滚动文字标签
		if not _scroll_label:
			_scroll_label = Label.new()
			_scroll_label.name = "ScrollLabel"
			_scroll_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_scroll_label.autowrap_mode = TextServer.AUTOWRAP_OFF
			_scroll_container.add_child(_scroll_label)
		
		# 创建第二个滚动文字标签（用于循环滚动的无缝衔接）
		if not _scroll_label2:
			_scroll_label2 = Label.new()
			_scroll_label2.name = "ScrollLabel2"
			_scroll_label2.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_scroll_label2.autowrap_mode = TextServer.AUTOWRAP_OFF
			_scroll_container.add_child(_scroll_label2)
		
		# 同步字体设置
		_sync_label_theme()
		_scroll_label.text = text
		_scroll_label2.text = text
		
		# 隐藏按钮自带的文字（所有状态）
		add_theme_color_override("font_color", Color.TRANSPARENT)
		add_theme_color_override("font_hover_color", Color.TRANSPARENT)
		add_theme_color_override("font_pressed_color", Color.TRANSPARENT)
		add_theme_color_override("font_focus_color", Color.TRANSPARENT)
		add_theme_color_override("font_disabled_color", Color.TRANSPARENT)
		add_theme_color_override("font_outline_color", Color.TRANSPARENT)
		
		# 更新容器位置
		_update_scroll_container_rect()
	else:
		# 恢复按钮文字颜色（移除所有覆盖）
		remove_theme_color_override("font_color")
		remove_theme_color_override("font_hover_color")
		remove_theme_color_override("font_pressed_color")
		remove_theme_color_override("font_focus_color")
		remove_theme_color_override("font_disabled_color")
		remove_theme_color_override("font_outline_color")
		
		# 停止滚动
		_stop_scroll()
		
		# 移除滚动标签
		if _scroll_label:
			_scroll_label.queue_free()
			_scroll_label = null
		if _scroll_label2:
			_scroll_label2.queue_free()
			_scroll_label2 = null
		if _scroll_container:
			_scroll_container.queue_free()
			_scroll_container = null

func _sync_label_theme() -> void:
	# 从按钮复制字体设置
	var font = get_theme_font("font")
	var font_size = get_theme_font_size("font_size")
	
	for label in [_scroll_label, _scroll_label2]:
		if label:
			if font:
				label.add_theme_font_override("font", font)
			if font_size > 0:
				label.add_theme_font_size_override("font_size", font_size)
			label.add_theme_color_override("font_color", _original_font_color)

func _update_scroll_container_rect() -> void:
	if not _scroll_container:
		return
	
	var has_icon = button_icon != null
	var has_text = text != null and text.length() > 0
	var content_left = padding_horizontal
	var content_right = padding_horizontal
	
	# 如果有图标在左侧，调整左边距
	if has_icon and has_text and icon_layout_mode == IconLayoutMode.ICON_LEFT:
		content_left = padding_horizontal + icon_size + icon_text_gap
	
	# 如果是图标在上的布局，不需要调整水平边距
	if has_icon and has_text and icon_layout_mode == IconLayoutMode.ICON_TOP:
		content_left = padding_horizontal
		content_right = padding_horizontal
	
	# 计算容器区域（确保尺寸至少为0）
	var container_x = content_left
	var actual_width = size.x if size.x > 0 else custom_minimum_size.x
	var actual_height = size.y if size.y > 0 else custom_minimum_size.y
	
	# 如果尺寸仍然为0，使用默认值
	if actual_width <= 0:
		actual_width = 100.0
	if actual_height <= 0:
		actual_height = SIZE_MAP.get(button_size, SIZE_MAP[ButtonSize.STANDARD36])["height"]
	
	var container_width = maxf(0.0, actual_width - content_left - content_right)
	var container_height = maxf(0.0, actual_height - padding_vertical * 2)
	
	# 如果是图标在上的布局，需要为图标腾出顶部空间
	if has_icon and has_text and icon_layout_mode == IconLayoutMode.ICON_TOP:
		var top_offset = padding_vertical + icon_size + icon_text_gap
		_scroll_container.position = Vector2(container_x, top_offset)
		container_height = maxf(0.0, actual_height - top_offset - padding_vertical)
	else:
		_scroll_container.position = Vector2(container_x, padding_vertical)
	
	_scroll_container.size = Vector2(container_width, container_height)
	
	# 更新标签位置（垂直居中）
	if _scroll_label:
		var label_height = _scroll_label.size.y
		if label_height <= 0:
			# 如果标签还没有尺寸，使用字体高度估算
			var font = _scroll_label.get_theme_font("font")
			var font_size_val = _scroll_label.get_theme_font_size("font_size")
			if font:
				label_height = font.get_height(font_size_val)
		_scroll_label.position.y = (container_height - label_height) / 2.0
		if _scroll_label2:
			_scroll_label2.position.y = _scroll_label.position.y

## 请求滚动更新（使用 deferred 确保不会并发）
func _request_scroll_update() -> void:
	if _scroll_update_queued:
		return
	_scroll_update_queued = true
	call_deferred("_do_update_scroll")

## 实际执行滚动更新
func _do_update_scroll() -> void:
	_scroll_update_queued = false
	_update_scroll()

func _update_scroll() -> void:
	if not is_inside_tree() or not enable_text_scroll or not _scroll_label or not _scroll_container:
		return
	
	# 先停止当前滚动
	_stop_scroll()
	
	# 更新容器位置
	_update_scroll_container_rect()
	
	var container_width = _scroll_container.size.x
	if container_width <= 0:
		return
	
	# 设置文字并测量宽度
	var current_text = text if text else ""
	_scroll_label.text = current_text
	if _scroll_label2:
		_scroll_label2.text = current_text
	
	# 强制更新尺寸
	_scroll_label.reset_size()
	if _scroll_label2:
		_scroll_label2.reset_size()
	
	_text_width = _scroll_label.size.x
	
	# 如果文字为空或没有超出容器，不需要滚动
	if _text_width <= 0 or _text_width <= container_width:
		_scroll_label.position.x = 0
		if _scroll_label2:
			_scroll_label2.visible = false
		return
	
	# 文字超出容器，需要滚动
	var is_loop_mode = (scroll_mode == 1)
	
	if is_loop_mode:
		# 循环滚动模式：使用双标签实现无缝循环
		var gap_width: float = scroll_gap if scroll_gap > 0 else 50.0
		_total_scroll_width = _text_width + gap_width
		
		# 设置第二个标签可见并定位
		if _scroll_label2:
			_scroll_label2.visible = true
			_scroll_label2.position.x = _total_scroll_width
	else:
		# 来回滚动模式：隐藏第二个标签
		if _scroll_label2:
			_scroll_label2.visible = false
		_total_scroll_width = _text_width - container_width
	
	# 重置位置并开始滚动
	_scroll_label.position.x = 0
	_scroll_position = 0.0
	_scroll_wait_timer = scroll_delay
	_scroll_state = 0
	_is_scrolling = true
	set_process(true)

func _start_scroll() -> void:
	if _is_scrolling:
		return
	_is_scrolling = true
	set_process(true)

func _stop_scroll() -> void:
	_is_scrolling = false
	set_process(false)
	_scroll_position = 0.0
	_scroll_state = 0
	_total_scroll_width = 0.0

	if _scroll_tween and _scroll_tween.is_valid():
		_scroll_tween.kill()
		_scroll_tween = null

	if _scroll_label and is_instance_valid(_scroll_label):
		_scroll_label.position.x = 0
		_scroll_label.text = text if text else ""
	
	if _scroll_label2 and is_instance_valid(_scroll_label2):
		_scroll_label2.visible = false

func _process(delta: float) -> void:
	if not _is_scrolling or not _scroll_label or not is_instance_valid(_scroll_label):
		set_process(false)
		return
	
	if scroll_mode == 1:
		_process_loop_scroll(delta)
	else:
		_process_bounce_scroll(delta)

## 处理循环滚动（双标签无缝滚动）
func _process_loop_scroll(delta: float) -> void:
	if _scroll_state == 0:
		# 等待开始
		_scroll_wait_timer -= delta
		if _scroll_wait_timer <= 0:
			_scroll_state = 1
		return
	
	# 持续滚动
	_scroll_position += scroll_speed * delta
	
	# 当第一个标签完全滚出时，重置位置
	if _total_scroll_width > 0 and _scroll_position >= _total_scroll_width:
		_scroll_position = fmod(_scroll_position, _total_scroll_width)
	
	# 更新两个标签的位置
	if _scroll_label and is_instance_valid(_scroll_label):
		_scroll_label.position.x = -_scroll_position
	
	if _scroll_label2 and is_instance_valid(_scroll_label2):
		# 第二个标签始终在第一个标签后面 _total_scroll_width 的位置
		_scroll_label2.position.x = _total_scroll_width - _scroll_position

## 处理来回滚动
func _process_bounce_scroll(delta: float) -> void:
	match _scroll_state:
		0:  # 等待开始
			_scroll_wait_timer -= delta
			if _scroll_wait_timer <= 0:
				_scroll_state = 1
		1:  # 向前滚动（向左）
			_scroll_position += scroll_speed * delta
			if _scroll_position >= _total_scroll_width:
				_scroll_position = _total_scroll_width
				_scroll_wait_timer = scroll_end_delay
				_scroll_state = 2
			_update_scroll_label_position()
		2:  # 等待结束
			_scroll_wait_timer -= delta
			if _scroll_wait_timer <= 0:
				_scroll_state = 3
		3:  # 返回滚动（向右）
			_scroll_position -= scroll_speed * delta
			if _scroll_position <= 0:
				_scroll_position = 0
				_scroll_wait_timer = scroll_delay
				_scroll_state = 0
			_update_scroll_label_position()

func _update_scroll_label_position() -> void:
	if _scroll_label and is_instance_valid(_scroll_label):
		_scroll_label.position.x = -_scroll_position

# 重写 text 属性的 setter 以支持滚动更新
func _set(property: StringName, value: Variant) -> bool:
	if property == "text":
		if enable_text_scroll and _scroll_label and is_inside_tree():
			# 使用请求更新，确保不会并发
			_request_scroll_update()
		return false  # 返回 false 让父类处理
	return false

## 延迟更新滚动文字（在 text 属性设置完成后调用）
func _deferred_update_scroll_text() -> void:
	if enable_text_scroll and _scroll_label and is_inside_tree():
		_update_scroll()
