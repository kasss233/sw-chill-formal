@tool
class_name MaterialFAB
extends Control

## Material Design 风格浮动操作按钮 (FAB)
## 支持 Small/Standard/Large/Extended 四种尺寸

enum FABSize {
	SMALL,      ## 40dp，图标 24dp，圆角 12dp
	STANDARD,   ## 56dp，图标 24dp，圆角 16dp (默认)
	LARGE,      ## 96dp，图标 36dp，圆角 28dp
}

# FAB 尺寸规格 (Material Design 3)
const SIZE_MAP = {
	FABSize.SMALL: {"size": 40, "icon": 24, "corner": 12, "padding": 8},
	FABSize.STANDARD: {"size": 56, "icon": 24, "corner": 16, "padding": 16},
	FABSize.LARGE: {"size": 96, "icon": 36, "corner": 28, "padding": 30},
}

signal pressed

@export_group("基础")
## FAB 尺寸
@export var fab_size: FABSize = FABSize.STANDARD:
	set(value):
		fab_size = value
		_update_fab()

## FAB 图标
@export var fab_icon: Texture2D:
	set(value):
		fab_icon = value
		_update_icon()

## Extended 模式时显示的文字
@export var fab_text: String = "":
	set(value):
		fab_text = value
		_update_fab()

@export_group("颜色")
## 背景颜色
@export var background_color: Color = Color(0.35, 0.65, 0.95, 1.0):
	set(value):
		background_color = value
		_update_background()

## 图标颜色
@export var icon_color: Color = Color.WHITE:
	set(value):
		icon_color = value
		_update_icon()

## 文字颜色
@export var text_color: Color = Color.WHITE:
	set(value):
		text_color = value
		_update_label()

@export_group("阴影")
## 阴影颜色
@export var shadow_color: Color = Color(0, 0, 0, 0.3):
	set(value):
		shadow_color = value
		_update_shadow()

## 阴影大小
@export_range(0.0, 32.0) var shadow_size: float = 8.0:
	set(value):
		shadow_size = value
		_update_shadow_padding()
		_update_shadow()

## 阴影偏移
@export var shadow_offset: Vector2 = Vector2(0, 4):
	set(value):
		shadow_offset = value
		_update_shadow_padding()
		_update_shadow()

@export_group("涟漪")
## 是否启用涟漪效果
@export var enable_ripple: bool = true

## 涟漪颜色
@export var ripple_color: Color = Color(1, 1, 1, 0.3):
	set(value):
		ripple_color = value
		if _ripple_mixin:
			_ripple_mixin.set_ripple_color(ripple_color)

# 内部节点
var _shadow_panel: ColorRect
var _shadow_material: ShaderMaterial
var _background_panel: Panel
var _ripple_mixin: MaterialRippleMixin
var _content_container: HBoxContainer
var _icon_texture: TextureRect
var _label: Label

var _shadow_padding: float = 0.0
var _updating: bool = false

func _ready() -> void:
	_setup_fab()
	_update_shadow_padding()
	_update_fab()

	# 连接鼠标事件
	gui_input.connect(_on_gui_input)

func _setup_fab() -> void:
	# 设置基础属性
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	# 创建阴影层
	if not _shadow_panel:
		_shadow_panel = ColorRect.new()
		_shadow_panel.name = "ShadowPanel"
		_shadow_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_shadow_panel.color = Color(1, 1, 1, 1)

		_shadow_material = ShaderMaterial.new()
		var shader = load("res://scenes/main/ui/components/fab/fab_shadow.gdshader")
		_shadow_material.shader = shader
		_shadow_panel.material = _shadow_material
		add_child(_shadow_panel)

	# 创建背景层
	if not _background_panel:
		_background_panel = Panel.new()
		_background_panel.name = "BackgroundPanel"
		_background_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_background_panel)

	# 创建涟漪层 (使用 MaterialRippleMixin)
	if enable_ripple and not _ripple_mixin:
		_ripple_mixin = MaterialRippleMixin.new()
		_ripple_mixin.setup(_background_panel, "res://scenes/main/ui/components/button/ripple.gdshader")
		_ripple_mixin.set_ripple_color(ripple_color)

	# 创建内容容器
	if not _content_container:
		_content_container = HBoxContainer.new()
		_content_container.name = "ContentContainer"
		_content_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_content_container.alignment = BoxContainer.ALIGNMENT_CENTER
		add_child(_content_container)

	# 创建图标
	if not _icon_texture:
		_icon_texture = TextureRect.new()
		_icon_texture.name = "IconTexture"
		_icon_texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_icon_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_icon_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_content_container.add_child(_icon_texture)

	# 创建文字标签
	if not _label:
		_label = Label.new()
		_label.name = "Label"
		_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_content_container.add_child(_label)

func _update_shadow_padding() -> void:
	_shadow_padding = shadow_size + max(abs(shadow_offset.x), abs(shadow_offset.y))
	if is_inside_tree():
		_update_fab()

func _update_fab() -> void:
	if not is_inside_tree() or _updating:
		return

	_updating = true

	var config = SIZE_MAP.get(fab_size, SIZE_MAP[FABSize.STANDARD])
	var fab_height: float = config["size"]
	var icon_sz: float = config["icon"]
	var corner: float = config["corner"]
	var padding: float = config["padding"]

	# 计算 FAB 宽度
	var fab_width: float
	if fab_text.is_empty():
		# 圆形 FAB
		fab_width = fab_height
	else:
		# Extended FAB：高度固定，宽度自适应
		var text_width = _measure_text_width(fab_text)
		fab_width = padding * 2 + icon_sz + 8 + text_width

	# 设置控件尺寸（包含阴影 padding）
	var total_width = fab_width + _shadow_padding * 2
	var total_height = fab_height + _shadow_padding * 2
	custom_minimum_size = Vector2(total_width, total_height)
	size = Vector2(total_width, total_height)

	# 更新阴影层
	if _shadow_panel:
		_shadow_panel.position = Vector2.ZERO
		_shadow_panel.size = Vector2(total_width, total_height)

	# 更新背景层
	if _background_panel:
		_background_panel.position = Vector2(_shadow_padding, _shadow_padding)
		_background_panel.size = Vector2(fab_width, fab_height)
		_update_background_style(corner)

	# 更新涟漪层圆角
	if _ripple_mixin:
		_ripple_mixin.set_corner_radius(corner)
		_ripple_mixin.update_size(Vector2(fab_width, fab_height))

	# 更新内容容器
	if _content_container:
		_content_container.position = Vector2(_shadow_padding, _shadow_padding)
		_content_container.size = Vector2(fab_width, fab_height)
		# 设置间距
		_content_container.add_theme_constant_override("separation", 8)

	# 更新图标
	if _icon_texture:
		_icon_texture.custom_minimum_size = Vector2(icon_sz, icon_sz)
		_icon_texture.size = Vector2(icon_sz, icon_sz)
		_icon_texture.texture = fab_icon
		_icon_texture.modulate = icon_color

	# 更新文字
	if _label:
		_label.visible = not fab_text.is_empty()
		_label.text = fab_text
		_label.add_theme_color_override("font_color", text_color)

	# 更新阴影 shader 参数
	_update_shadow()

	_updating = false

func _update_background() -> void:
	if not is_inside_tree():
		return

	var config = SIZE_MAP.get(fab_size, SIZE_MAP[FABSize.STANDARD])
	_update_background_style(config["corner"])

func _update_background_style(corner: float) -> void:
	if not _background_panel:
		return

	var style = StyleBoxFlat.new()
	style.bg_color = background_color
	style.corner_radius_top_left = int(corner)
	style.corner_radius_top_right = int(corner)
	style.corner_radius_bottom_left = int(corner)
	style.corner_radius_bottom_right = int(corner)
	_background_panel.add_theme_stylebox_override("panel", style)

func _update_shadow() -> void:
	if not _shadow_material:
		return

	var config = SIZE_MAP.get(fab_size, SIZE_MAP[FABSize.STANDARD])
	var corner: float = config["corner"]

	_shadow_material.set_shader_parameter("shadow_color", shadow_color)
	_shadow_material.set_shader_parameter("shadow_size", shadow_size)
	_shadow_material.set_shader_parameter("shadow_offset", shadow_offset)
	_shadow_material.set_shader_parameter("shadow_padding", _shadow_padding)
	_shadow_material.set_shader_parameter("corner_radius", corner)
	_shadow_material.set_shader_parameter("size", size)

func _update_icon() -> void:
	if not _icon_texture:
		return

	_icon_texture.texture = fab_icon
	_icon_texture.modulate = icon_color

func _update_label() -> void:
	if not _label:
		return

	_label.add_theme_color_override("font_color", text_color)

func _measure_text_width(text_str: String) -> float:
	if text_str.is_empty():
		return 0.0

	var font: Font
	if _label and _label.get_theme_font("font"):
		font = _label.get_theme_font("font")
	else:
		font = ThemeDB.fallback_font

	var font_size = 14
	if _label:
		font_size = _label.get_theme_font_size("font_size")

	return font.get_string_size(text_str, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x

func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				# 按下 - 触发涟漪
				if enable_ripple and _ripple_mixin:
					var local_pos = mb.position - Vector2(_shadow_padding, _shadow_padding)
					_ripple_mixin.trigger_ripple(local_pos)
			else:
				# 松开 - 淡出涟漪并发出信号
				if enable_ripple and _ripple_mixin:
					_ripple_mixin.fade_ripple()

				# 检查鼠标是否仍在按钮内
				var config = SIZE_MAP.get(fab_size, SIZE_MAP[FABSize.STANDARD])
				var fab_rect = Rect2(
					Vector2(_shadow_padding, _shadow_padding),
					Vector2(
						fab_text.is_empty() and config["size"] or (config["padding"] * 2 + config["icon"] + 8 + _measure_text_width(fab_text)),
						config["size"]
					)
				)
				if fab_rect.has_point(mb.position):
					pressed.emit()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_update_shadow()
