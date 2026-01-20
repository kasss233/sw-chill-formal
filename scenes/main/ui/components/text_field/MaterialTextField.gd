@tool
class_name MaterialTextField
extends Control

## Material Design 风格输入框 (TextField)
## 完全圆角（Pill-shaped），带图标、阴影和交互效果
## 支持多种背景样式：纯色、半透明、磨砂效果

## 文本改变信号
signal text_changed(new_text: String)

## 文本提交信号（按 Enter 键）
signal text_submitted(text: String)

## 获得焦点信号
signal focus_gained

## 失去焦点信号
signal focus_lost

## ==================== 背景样式枚举 ====================

enum BackgroundStyle {
	SOLID,           ## 纯色背景
	TRANSPARENT,     ## 半透明背景
	FROSTED          ## 磨砂玻璃效果
}

## ==================== 导出属性 ====================

## 背景样式
@export var background_style: BackgroundStyle = BackgroundStyle.SOLID:
	set(value):
		background_style = value
		_update_background()

## 提示文本（Placeholder）
@export var placeholder_text: String = "":
	set(value):
		placeholder_text = value
		if _line_edit:
			_line_edit.placeholder_text = value

## 输入框文本
@export var text: String = "":
	set(value):
		text = value
		if _line_edit:
			_line_edit.text = value

## 是否为密码框
@export var is_password: bool = false:
	set(value):
		is_password = value
		if _line_edit:
			_line_edit.secret = is_password
			_update_icon()

## 最大字符长度（0 表示无限制）
@export_range(0, 1000, 1) var max_length: int = 0:
	set(value):
		max_length = value
		if _line_edit:
			_line_edit.max_length = max_length

## ==================== 颜色属性 ====================

## 背景颜色（正常状态）
@export var bg_color: Color = Color.WHITE:
	set(value):
		bg_color = value
		_update_colors()

## 悬停背景颜色
@export var bg_color_hover: Color = Color(0.95, 0.95, 0.95, 1):
	set(value):
		bg_color_hover = value
		_update_colors()

## 焦点背景颜色
@export var bg_color_focus: Color = Color.WHITE:
	set(value):
		bg_color_focus = value
		_update_colors()

## 背景透明度（用于 TRANSPARENT 样式）
@export_range(0, 1, 0.05) var bg_opacity: float = 0.6:
	set(value):
		bg_opacity = value
		_update_colors()

## 边框颜色（正常状态）
@export var border_color: Color = Color(0.7, 0.7, 0.7, 1):
	set(value):
		border_color = value
		_update_colors()

## 焦点边框颜色
@export var border_color_focus: Color = Color(0.35, 0.65, 0.95, 1):
	set(value):
		border_color_focus = value
		_update_colors()

## 文字颜色
@export var text_color: Color = Color(0.15, 0.15, 0.15, 1):
	set(value):
		text_color = value
		_update_colors()

## 占位符文字颜色
@export var placeholder_color: Color = Color(0.5, 0.5, 0.5, 1):
	set(value):
		placeholder_color = value
		_update_colors()

## 正常状态图标颜色
@export var icon_color: Color = Color(0.6, 0.6, 0.6, 1):
	set(value):
		icon_color = value
		_update_colors()

## 悬停状态图标颜色
@export var icon_color_hover: Color = Color(0.35, 0.65, 0.95, 1):
	set(value):
		icon_color_hover = value
		_update_colors()

## 焦点状态图标颜色
@export var icon_color_focus: Color = Color(0.35, 0.65, 0.95, 1):
	set(value):
		icon_color_focus = value
		_update_colors()

## 阴影颜色
@export var shadow_color: Color = Color(0, 0, 0, 0.1):
	set(value):
		shadow_color = value
		_update_style()

## 阴影大小
@export_range(0, 20, 1) var shadow_size: int = 4:
	set(value):
		shadow_size = value
		_update_style()

## 阴影偏移
@export var shadow_offset: Vector2 = Vector2(0, 2):
	set(value):
		shadow_offset = value
		_update_style()

## ==================== 尺寸属性 ====================

## 输入框高度
@export_range(32, 80, 1) var text_field_height: int = 48:
	set(value):
		text_field_height = value
		_update_style()

## 圆角半径（-1 表示自动计算为高度的一半）
@export_range(-1, 48, 1) var corner_radius: int = -1:
	set(value):
		corner_radius = value
		_update_style()

## 边框宽度
@export_range(0, 8, 0.5) var border_width: float = 2.0:
	set(value):
		border_width = value
		_update_style()

## 是否启用边框颜色渐变动画
@export var enable_border_animation: bool = true

## 边框颜色渐变动画时长（秒）
@export_range(0.05, 0.5, 0.05) var border_animation_duration: float = 0.2

## 左内边距
@export_range(0, 32, 1) var padding_left: int = 20:
	set(value):
		padding_left = value
		_update_layout()

## 右内边距（图标区域）
@export_range(0, 32, 1) var padding_right: int = 48:
	set(value):
		padding_right = value
		_update_layout()

## ==================== 磨砂效果属性 ====================

## 磨砂模糊程度
@export_range(0, 5, 0.1) var blur_amount: float = 2.0:
	set(value):
		blur_amount = value
		_update_frosted_params()

## 磨砂色调颜色
@export var tint_color: Color = Color(0, 0, 0, 0.3):
	set(value):
		tint_color = value
		_update_frosted_params()

## ==================== 图标属性 ====================

## 右侧图标
@export var icon: Texture2D = null:
	set(value):
		icon = value
		_update_icon()

## 图标大小
@export_range(16, 48, 1) var icon_size: int = 24:
	set(value):
		icon_size = value
		_update_icon()

## ==================== 内部节点 ====================

var _background_panel: Panel
var _line_edit: LineEdit
var _icon_texture: TextureRect

var _is_hovered: bool = false
var _is_focused: bool = false
var _border_tween: Tween

## 当前显示的边框颜色（用于动画）
var _current_border_color: Color

## ==================== 生命周期 ====================

func _ready() -> void:
	_setup_components()
	# 初始化当前边框颜色
	_current_border_color = border_color
	_update_background()
	_update_colors()
	_update_icon()
	_update_layout()
	_connect_signals()

func _setup_components() -> void:
	# 创建背景面板
	if not _background_panel:
		_background_panel = Panel.new()
		_background_panel.name = "BackgroundPanel"
		_background_panel.mouse_filter = Control.MOUSE_FILTER_PASS
		add_child(_background_panel)

	# 创建输入框
	if not _line_edit:
		_line_edit = LineEdit.new()
		_line_edit.name = "LineEdit"
		_line_edit.mouse_filter = Control.MOUSE_FILTER_STOP
		_line_edit.flat = true
		add_child(_line_edit)

	# 创建图标
	if not _icon_texture:
		_icon_texture = TextureRect.new()
		_icon_texture.name = "IconTexture"
		_icon_texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_icon_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_icon_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		add_child(_icon_texture)

func _connect_signals() -> void:
	# 连接 LineEdit 信号
	if not _line_edit.text_changed.is_connected(_on_text_changed):
		_line_edit.text_changed.connect(_on_text_changed)
	if not _line_edit.text_submitted.is_connected(_on_text_submitted):
		_line_edit.text_submitted.connect(_on_text_submitted)
	if not _line_edit.focus_entered.is_connected(_on_focus_entered):
		_line_edit.focus_entered.connect(_on_focus_entered)
	if not _line_edit.focus_exited.is_connected(_on_focus_exited):
		_line_edit.focus_exited.connect(_on_focus_exited)

	# 连接鼠标信号到根节点
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)

func _update_background() -> void:
	if not _background_panel or not is_inside_tree():
		return

	match background_style:
		BackgroundStyle.SOLID:
			# 移除 shader 材质
			_background_panel.material = null
		BackgroundStyle.TRANSPARENT:
			# 移除 shader 材质，使用透明背景色
			_background_panel.material = null
		BackgroundStyle.FROSTED:
			# 添加磨砂玻璃 shader
			if not _background_panel.material:
				_background_panel.material = ShaderMaterial.new()
				_background_panel.material.shader = preload("res://scenes/main/ui/components/frosted_panel/frosted_panel.gdshader")
			_update_frosted_params()

	if _background_panel:
		_update_style()

func _update_frosted_params() -> void:
	if not _background_panel or not _background_panel.material:
		return

	var mat = _background_panel.material
	mat.set_shader_parameter("blur_amount", blur_amount)
	mat.set_shader_parameter("tint_color", tint_color)
	mat.set_shader_parameter("border_width", border_width)
	mat.set_shader_parameter("border_color", _current_border_color)
	mat.set_shader_parameter("corner_radius", get_corner_radius_value())
	mat.set_shader_parameter("shadow_color", shadow_color)
	mat.set_shader_parameter("shadow_size", shadow_size)
	mat.set_shader_parameter("shadow_offset", shadow_offset)
	mat.set_shader_parameter("size", size)
	mat.set_shader_parameter("noise_amount", 0.0)  # 不使用噪点

func get_corner_radius_value() -> float:
	return corner_radius if corner_radius >= 0 else text_field_height / 2.0

func _update_style() -> void:
	if not is_inside_tree() or not _background_panel:
		return

	# 设置组件尺寸
	custom_minimum_size = Vector2(200, text_field_height)

	# 更新背景面板位置
	_background_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_background_panel.offset_left = 0
	_background_panel.offset_top = 0
	_background_panel.offset_right = 0
	_background_panel.offset_bottom = 0

	if background_style == BackgroundStyle.FROSTED:
		# 磨砂效果使用 shader，不需要 StyleBox
		_update_frosted_params()
	else:
		# 纯色或半透明背景使用 StyleBox
		_update_solid_style()

func _update_solid_style() -> void:
	if not _background_panel:
		return

	var bg_style = StyleBoxFlat.new()

	# 计算圆角
	var radius = get_corner_radius_value()
	bg_style.corner_radius_top_left = radius
	bg_style.corner_radius_top_right = radius
	bg_style.corner_radius_bottom_left = radius
	bg_style.corner_radius_bottom_right = radius

	# 设置阴影
	bg_style.shadow_color = shadow_color
	bg_style.shadow_size = shadow_size
	bg_style.shadow_offset = shadow_offset

	# 设置边框
	bg_style.border_width_left = border_width
	bg_style.border_width_top = border_width
	bg_style.border_width_right = border_width
	bg_style.border_width_bottom = border_width

	# 设置背景色（考虑透明度）
	var current_bg_color = bg_color
	if background_style == BackgroundStyle.TRANSPARENT:
		current_bg_color = Color(bg_color.r, bg_color.g, bg_color.b, bg_opacity)

	bg_style.bg_color = current_bg_color
	bg_style.border_color = _current_border_color

	_background_panel.add_theme_stylebox_override("panel", bg_style)

func _update_colors() -> void:
	if not is_inside_tree():
		return

	# 更新 LineEdit 样式
	if _line_edit:
		# 清除默认样式
		var empty_style = StyleBoxEmpty.new()
		_line_edit.add_theme_stylebox_override("normal", empty_style)
		_line_edit.add_theme_stylebox_override("focus", empty_style)
		_line_edit.add_theme_stylebox_override("read_only", empty_style)

		# 设置文字颜色
		_line_edit.add_theme_color_override("font_color", text_color)
		_line_edit.add_theme_color_override("font_placeholder_color", placeholder_color)
		_line_edit.add_theme_color_override("caret_color", border_color_focus)

		# 设置提示文本
		_line_edit.placeholder_text = placeholder_text

	# 更新图标颜色
	if _icon_texture:
		_update_icon_color()

	# 更新边框和背景
	if _background_panel:
		_update_visual_state()

func _update_icon_color() -> void:
	if not _icon_texture or not icon:
		return

	var target_color = icon_color
	if _is_focused:
		target_color = icon_color_focus
	elif _is_hovered:
		target_color = icon_color_hover

	_icon_texture.modulate = target_color

func _update_visual_state() -> void:
	if not is_inside_tree() or not _background_panel:
		return

	# 计算目标边框颜色
	var target_color = get_target_border_color()

	# 使用动画过渡边框颜色
	if enable_border_animation and is_inside_tree():
		_animate_border_color(target_color)
	else:
		_set_border_color(target_color)

	if background_style == BackgroundStyle.FROSTED:
		# 磨砂效果更新 shader 参数
		_update_frosted_params()
	else:
		# 纯色或半透明更新 StyleBox
		_update_solid_style()

	# 更新光标颜色
	if _line_edit:
		_line_edit.add_theme_color_override("caret_color", border_color_focus)

func get_target_border_color() -> Color:
	if _is_focused:
		return border_color_focus
	elif _is_hovered and background_style == BackgroundStyle.FROSTED:
		return border_color.lerp(border_color_focus, 0.5)
	return border_color

func _animate_border_color(target_color: Color) -> void:
	if not is_inside_tree():
		return

	# 如果已经在动画中，先停止之前的动画
	if _border_tween and _border_tween.is_valid():
		_border_tween.kill()

	_border_tween = create_tween()
	_border_tween.set_ease(Tween.EASE_OUT)
	_border_tween.set_trans(Tween.TRANS_CUBIC)

	# 从当前颜色渐变到目标颜色
	_border_tween.parallel()
	_border_tween.tween_method(_set_border_color, _current_border_color, target_color, border_animation_duration)

func _set_border_color(color: Color) -> void:
	_current_border_color = color

	if background_style == BackgroundStyle.FROSTED:
		# 更新 shader 参数
		if _background_panel and _background_panel.material:
			_background_panel.material.set_shader_parameter("border_color", color)
	else:
		# 更新 StyleBox 边框颜色
		if _background_panel:
			var bg_style = _background_panel.get_theme_stylebox("panel")
			if bg_style is StyleBoxFlat:
				bg_style.border_color = color
				# 需要重新应用样式以触发更新
				_background_panel.add_theme_stylebox_override("panel", bg_style)

func _update_icon() -> void:
	if not _icon_texture:
		return

	_icon_texture.texture = icon
	if icon:
		_icon_texture.custom_minimum_size = Vector2(icon_size, icon_size)
		_icon_texture.visible = true
	else:
		_icon_texture.visible = false

	if is_inside_tree():
		_update_icon_color()
		_update_layout()

func _update_layout() -> void:
	if not is_inside_tree():
		return

	# 设置 LineEdit 位置和尺寸
	if _line_edit:
		_line_edit.set_anchors_preset(Control.PRESET_FULL_RECT)
		_line_edit.offset_left = padding_left
		_line_edit.offset_top = 0
		_line_edit.offset_right = -padding_right
		_line_edit.offset_bottom = 0

	# 设置图标位置（右侧居中）
	if _icon_texture and icon:
		var icon_x = size.x - padding_right + (padding_right - icon_size) / 2
		var icon_y = (size.y - icon_size) / 2.0
		_icon_texture.position = Vector2(icon_x, icon_y)
		_icon_texture.size = Vector2(icon_size, icon_size)

## ==================== 信号回调 ====================

func _on_text_changed(new_text: String) -> void:
	text_changed.emit(new_text)

func _on_text_submitted(submitted_text: String) -> void:
	text_submitted.emit(submitted_text)

func _on_focus_entered() -> void:
	_is_focused = true
	focus_gained.emit()
	_update_visual_state()
	_update_icon_color()

func _on_focus_exited() -> void:
	_is_focused = false
	focus_lost.emit()
	_update_visual_state()
	_update_icon_color()

func _on_mouse_entered() -> void:
	if not _is_hovered:
		_is_hovered = true
		_update_visual_state()
		_update_icon_color()

func _on_mouse_exited() -> void:
	if _is_hovered:
		_is_hovered = false
		_update_visual_state()
		_update_icon_color()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_update_layout()
		_update_style()
		if background_style == BackgroundStyle.FROSTED:
			_update_frosted_params()

## ==================== 公共 API ====================

## 设置输入框文本
func set_text(value: String) -> void:
	text = value
	if _line_edit:
		_line_edit.text = value

## 获取输入框文本
func get_text() -> String:
	if _line_edit:
		return _line_edit.text
	return text

## 清空输入框
func clear() -> void:
	set_text("")

## 设置是否可编辑
func set_editable(value: bool) -> void:
	if _line_edit:
		_line_edit.editable = value

## 获取是否可编辑
func is_editable() -> bool:
	if _line_edit:
		return _line_edit.editable
	return true

## 设置占位符文本
func set_placeholder(value: String) -> void:
	placeholder_text = value
	if _line_edit:
		_line_edit.placeholder_text = value

## 聚焦输入框
func focus_text_field() -> void:
	if _line_edit:
		_line_edit.grab_focus()

## 释放焦点
func blur_text_field() -> void:
	if _line_edit:
		_line_edit.release_focus()

## 设置是否为密码框
func set_secret(value: bool) -> void:
	is_password = value
	if _line_edit:
		_line_edit.secret = value
		_update_icon()

## 获取是否有焦点
func is_text_field_focused() -> bool:
	if _line_edit:
		return _line_edit.has_focus()
	return false

## 选择所有文本
func select_all() -> void:
	if _line_edit:
		_line_edit.select_all()

## 取消选择
func deselect() -> void:
	if _line_edit:
		_line_edit.deselect()
