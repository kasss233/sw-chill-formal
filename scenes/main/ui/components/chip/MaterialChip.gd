@tool
class_name MaterialChip
extends Control

## Material Design 风格 Chip（标签/筛选器）组件
## 支持四种变体：Assist、Filter、Input、Suggestion

# ============ 信号 ============

## 点击时触发（Assist/Suggestion 类型）
signal pressed
## 选中状态改变（Filter 类型）
signal selected(is_selected: bool)
## 删除按钮点击（Input 类型）
signal deleted

# ============ 枚举 ============

enum ChipType {
	ASSIST,      ## 辅助 - 带图标，点击触发操作
	FILTER,      ## 筛选 - 可选中，显示勾选图标
	INPUT,       ## 输入 - 可删除，显示关闭按钮
	SUGGESTION   ## 建议 - 纯文字
}

enum ChipSize {
	SMALL,       ## 28dp 高度
	STANDARD,    ## 32dp 高度（默认）
	LARGE        ## 36dp 高度
}

enum ChipStyle {
	FILLED,      ## 填充背景
	OUTLINED     ## 边框样式
}

# ============ 常量 ============

const SIZE_MAP = {
	ChipSize.SMALL: {"height": 28, "icon": 16, "padding_h": 10, "corner": 14, "font_size": 12, "gap": 4},
	ChipSize.STANDARD: {"height": 32, "icon": 18, "padding_h": 12, "corner": 16, "font_size": 14, "gap": 6},
	ChipSize.LARGE: {"height": 36, "icon": 20, "padding_h": 14, "corner": 18, "font_size": 16, "gap": 8}
}

# Outlined 样式默认颜色
const DEFAULT_OUTLINED = {
	"bg_color": Color(0.0, 0.0, 0.0, 0.0),
	"bg_color_selected": Color(0.35, 0.65, 0.95, 0.15),
	"border_color": Color(0.5, 0.5, 0.5, 0.5),
	"border_color_selected": Color(0.35, 0.65, 0.95, 1.0),
	"text_color": Color(0.8, 0.8, 0.8, 1.0),
	"text_color_selected": Color(0.35, 0.65, 0.95, 1.0),
	"icon_color": Color(0.7, 0.7, 0.7, 1.0),
	"icon_color_selected": Color(0.35, 0.65, 0.95, 1.0)
}

# Filled 样式默认颜色
const DEFAULT_FILLED = {
	"bg_color": Color(0.25, 0.25, 0.25, 1.0),
	"bg_color_selected": Color(0.35, 0.65, 0.95, 1.0),
	"border_color": Color.TRANSPARENT,
	"border_color_selected": Color.TRANSPARENT,
	"text_color": Color(0.9, 0.9, 0.9, 1.0),
	"text_color_selected": Color.WHITE,
	"icon_color": Color(0.8, 0.8, 0.8, 1.0),
	"icon_color_selected": Color.WHITE
}

# ============ 导出属性 ============

@export_group("基础")

## Chip 类型
@export var chip_type: ChipType = ChipType.SUGGESTION:
	set(value):
		chip_type = value
		_update_icons()
		_update_style()

## Chip 尺寸
@export var chip_size: ChipSize = ChipSize.STANDARD:
	set(value):
		chip_size = value
		_update_style()
		_update_layout()

## Chip 样式
@export var chip_style: ChipStyle = ChipStyle.OUTLINED:
	set(value):
		chip_style = value
		_update_style()

## 文字内容
@export var text: String = "Chip":
	set(value):
		text = value
		if _label:
			_label.text = value
		_update_layout()

## 左侧图标
@export var chip_icon: Texture2D:
	set(value):
		chip_icon = value
		_update_icons()

@export_group("状态")

## 是否选中（Filter 类型使用）
@export var is_selected: bool = false:
	set(value):
		if is_selected != value:
			is_selected = value
			_update_selection()
			selected.emit(is_selected)

## 是否可删除（Input 类型使用）
@export var is_deletable: bool = true:
	set(value):
		is_deletable = value
		_update_icons()

@export_group("颜色")

## 背景色（留空使用默认）
@export var background_color: Color = Color.TRANSPARENT:
	set(value):
		background_color = value
		_update_style()

## 选中背景色（留空使用默认）
@export var selected_background_color: Color = Color.TRANSPARENT:
	set(value):
		selected_background_color = value
		_update_style()

## 边框色（留空使用默认）
@export var border_color: Color = Color.TRANSPARENT:
	set(value):
		border_color = value
		_update_style()

## 文字色（留空使用默认）
@export var text_color: Color = Color.TRANSPARENT:
	set(value):
		text_color = value
		_update_style()

## 图标色（留空使用默认）
@export var icon_color: Color = Color.TRANSPARENT:
	set(value):
		icon_color = value
		_update_icons()

@export_group("涟漪效果")

## 是否启用涟漪效果
@export var enable_ripple: bool = true

## 涟漪颜色
@export var ripple_color: Color = Color(0.5, 0.5, 0.5, 0.3)

# ============ 内部节点 ============

var _background_panel: Panel
var _content_container: HBoxContainer
var _leading_icon: TextureRect
var _label: Label
var _trailing_icon: TextureRect
var _ripple_mixin: MaterialRippleMixin

# 内置图标路径（使用项目现有的 Material Design 图标）
const CHECK_ICON_PATH = "res://assets/ui/icons/check_24dp_FFFFFF_FILL0_wght400_GRAD0_opsz24.svg"
const CLOSE_ICON_PATH = "res://assets/ui/icons/close_24dp_FFFFFF_FILL0_wght400_GRAD0_opsz24.svg"

# 内置图标（勾选和关闭）
var _check_icon_texture: Texture2D
var _close_icon_texture: Texture2D

# 状态标记
var _is_pressing: bool = false
var _is_hovering: bool = false

# ============ 生命周期 ============

func _ready() -> void:
	_create_builtin_icons()
	_setup_component()
	_update_style()
	_update_icons()
	_update_layout()

func _create_builtin_icons() -> void:
	# 尝试加载项目中的 Material Design 图标
	if ResourceLoader.exists(CHECK_ICON_PATH):
		_check_icon_texture = load(CHECK_ICON_PATH)
	else:
		# 备用：程序化创建勾选图标
		_check_icon_texture = _create_check_icon()

	if ResourceLoader.exists(CLOSE_ICON_PATH):
		_close_icon_texture = load(CLOSE_ICON_PATH)
	else:
		# 备用：程序化创建关闭图标
		_close_icon_texture = _create_close_icon()

## 程序化创建勾选图标（备用）
func _create_check_icon() -> ImageTexture:
	var img = Image.create(24, 24, false, Image.FORMAT_RGBA8)
	img.fill(Color.TRANSPARENT)
	# 绘制勾选标记 ✓
	var points = [
		Vector2i(4, 12), Vector2i(5, 12),
		Vector2i(5, 13), Vector2i(6, 13),
		Vector2i(6, 14), Vector2i(7, 14),
		Vector2i(7, 15), Vector2i(8, 15),
		Vector2i(8, 16), Vector2i(9, 16),
		Vector2i(9, 15), Vector2i(10, 15),
		Vector2i(10, 14), Vector2i(11, 14),
		Vector2i(11, 13), Vector2i(12, 13),
		Vector2i(12, 12), Vector2i(13, 12),
		Vector2i(13, 11), Vector2i(14, 11),
		Vector2i(14, 10), Vector2i(15, 10),
		Vector2i(15, 9), Vector2i(16, 9),
		Vector2i(16, 8), Vector2i(17, 8),
		Vector2i(17, 7), Vector2i(18, 7),
		Vector2i(18, 6), Vector2i(19, 6),
	]
	for p in points:
		if p.x >= 0 and p.x < 24 and p.y >= 0 and p.y < 24:
			img.set_pixel(p.x, p.y, Color.WHITE)
			# 加粗
			if p.x + 1 < 24:
				img.set_pixel(p.x + 1, p.y, Color.WHITE)
			if p.y + 1 < 24:
				img.set_pixel(p.x, p.y + 1, Color.WHITE)
	return ImageTexture.create_from_image(img)

## 程序化创建关闭图标（备用）
func _create_close_icon() -> ImageTexture:
	var img = Image.create(24, 24, false, Image.FORMAT_RGBA8)
	img.fill(Color.TRANSPARENT)
	# 绘制 X 标记
	for i in range(12):
		var x1 = 6 + i
		var y1 = 6 + i
		var y2 = 17 - i
		if x1 < 24 and y1 < 24:
			img.set_pixel(x1, y1, Color.WHITE)
			img.set_pixel(x1 + 1, y1, Color.WHITE)
		if x1 < 24 and y2 >= 0 and y2 < 24:
			img.set_pixel(x1, y2, Color.WHITE)
			img.set_pixel(x1 + 1, y2, Color.WHITE)
	return ImageTexture.create_from_image(img)

func _setup_component() -> void:
	# 设置鼠标过滤
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	# 创建背景面板
	_background_panel = Panel.new()
	_background_panel.name = "BackgroundPanel"
	_background_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_background_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_background_panel)

	# 创建内容容器
	_content_container = HBoxContainer.new()
	_content_container.name = "ContentContainer"
	_content_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content_container.alignment = BoxContainer.ALIGNMENT_CENTER
	_content_container.set_anchors_preset(Control.PRESET_CENTER)
	add_child(_content_container)

	# 创建左侧图标
	_leading_icon = TextureRect.new()
	_leading_icon.name = "LeadingIcon"
	_leading_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_leading_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_leading_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_content_container.add_child(_leading_icon)

	# 创建文字标签
	_label = Label.new()
	_label.name = "Label"
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.text = text
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_content_container.add_child(_label)

	# 创建右侧图标（删除按钮）
	_trailing_icon = TextureRect.new()
	_trailing_icon.name = "TrailingIcon"
	_trailing_icon.mouse_filter = Control.MOUSE_FILTER_STOP  # 需要接收点击
	_trailing_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_trailing_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_trailing_icon.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_content_container.add_child(_trailing_icon)

	# 连接右侧图标点击事件
	_trailing_icon.gui_input.connect(_on_trailing_icon_gui_input)

	# 设置涟漪效果
	if enable_ripple:
		_ripple_mixin = MaterialRippleMixin.new()
		_ripple_mixin.ripple_color = ripple_color
		var size_config = SIZE_MAP[chip_size]
		_ripple_mixin.corner_radius = size_config["corner"]
		_ripple_mixin.setup(self)

func _update_style() -> void:
	if not is_inside_tree() or not _background_panel:
		return

	var size_config = SIZE_MAP[chip_size]
	var defaults = DEFAULT_FILLED if chip_style == ChipStyle.FILLED else DEFAULT_OUTLINED

	# 确定当前使用的颜色
	var current_bg: Color
	var current_border: Color
	var current_text: Color

	if is_selected and chip_type == ChipType.FILTER:
		current_bg = selected_background_color if selected_background_color.a > 0 else defaults["bg_color_selected"]
		current_border = defaults["border_color_selected"]
		current_text = defaults["text_color_selected"]
	else:
		current_bg = background_color if background_color.a > 0 else defaults["bg_color"]
		current_border = border_color if border_color.a > 0 else defaults["border_color"]
		current_text = text_color if text_color.a > 0 else defaults["text_color"]

	# 创建背景样式
	var bg_style = StyleBoxFlat.new()
	bg_style.bg_color = current_bg
	bg_style.corner_radius_top_left = size_config["corner"]
	bg_style.corner_radius_top_right = size_config["corner"]
	bg_style.corner_radius_bottom_left = size_config["corner"]
	bg_style.corner_radius_bottom_right = size_config["corner"]

	# 边框
	if chip_style == ChipStyle.OUTLINED:
		bg_style.border_width_left = 1
		bg_style.border_width_right = 1
		bg_style.border_width_top = 1
		bg_style.border_width_bottom = 1
		bg_style.border_color = current_border

	_background_panel.add_theme_stylebox_override("panel", bg_style)

	# 更新文字颜色和字体大小
	if _label:
		_label.add_theme_color_override("font_color", current_text)
		_label.add_theme_font_size_override("font_size", size_config["font_size"])

	# 更新涟漪圆角
	if _ripple_mixin:
		_ripple_mixin.set_corner_radius(size_config["corner"])

func _update_selection() -> void:
	_update_style()
	_update_icons()

func _update_icons() -> void:
	if not is_inside_tree():
		return

	var size_config = SIZE_MAP[chip_size]
	var icon_size = size_config["icon"]
	var defaults = DEFAULT_FILLED if chip_style == ChipStyle.FILLED else DEFAULT_OUTLINED

	# 确定图标颜色
	var current_icon_color: Color
	if is_selected and chip_type == ChipType.FILTER:
		current_icon_color = icon_color if icon_color.a > 0 else defaults["icon_color_selected"]
	else:
		current_icon_color = icon_color if icon_color.a > 0 else defaults["icon_color"]

	# 更新左侧图标
	if _leading_icon:
		_leading_icon.custom_minimum_size = Vector2(icon_size, icon_size)

		match chip_type:
			ChipType.FILTER:
				if is_selected:
					_leading_icon.texture = _check_icon_texture
					_leading_icon.visible = true
				elif chip_icon:
					_leading_icon.texture = chip_icon
					_leading_icon.visible = true
				else:
					_leading_icon.visible = false
			ChipType.ASSIST:
				if chip_icon:
					_leading_icon.texture = chip_icon
					_leading_icon.visible = true
				else:
					_leading_icon.visible = false
			_:
				if chip_icon:
					_leading_icon.texture = chip_icon
					_leading_icon.visible = true
				else:
					_leading_icon.visible = false

		_leading_icon.modulate = current_icon_color

	# 更新右侧图标（删除按钮）
	if _trailing_icon:
		_trailing_icon.custom_minimum_size = Vector2(icon_size, icon_size)

		if chip_type == ChipType.INPUT and is_deletable:
			_trailing_icon.texture = _close_icon_texture
			_trailing_icon.visible = true
			_trailing_icon.modulate = current_icon_color
		else:
			_trailing_icon.visible = false

	_update_layout()

func _update_layout() -> void:
	if not is_inside_tree() or not _content_container:
		return

	var size_config = SIZE_MAP[chip_size]

	# 设置容器间距
	_content_container.add_theme_constant_override("separation", size_config["gap"])

	# 计算内容宽度
	var content_width = size_config["padding_h"] * 2

	if _leading_icon and _leading_icon.visible:
		content_width += size_config["icon"] + size_config["gap"]

	if _label:
		# 使用字体测量文字宽度
		var font = _label.get_theme_font("font")
		var font_size = size_config["font_size"]
		if font:
			content_width += font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		else:
			content_width += text.length() * font_size * 0.6  # 估算

	if _trailing_icon and _trailing_icon.visible:
		content_width += size_config["icon"] + size_config["gap"]

	# 设置组件尺寸
	custom_minimum_size = Vector2(content_width, size_config["height"])

	# 更新内容容器位置
	call_deferred("_deferred_update_content_position")

func _deferred_update_content_position() -> void:
	if not is_inside_tree() or not _content_container:
		return

	# 居中内容容器
	_content_container.position = (size - _content_container.size) / 2

# ============ 交互处理 ============

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_is_pressing = true
				if enable_ripple and _ripple_mixin:
					_ripple_mixin.trigger_ripple(mb.position)
			else:
				if _is_pressing:
					_is_pressing = false
					if enable_ripple and _ripple_mixin:
						_ripple_mixin.fade_ripple()
					_on_pressed()

	elif event is InputEventMouseMotion:
		if not get_global_rect().has_point(event.global_position):
			if _is_pressing:
				_is_pressing = false
				if enable_ripple and _ripple_mixin:
					_ripple_mixin.fade_ripple()

func _on_pressed() -> void:
	match chip_type:
		ChipType.FILTER:
			is_selected = not is_selected
		ChipType.ASSIST, ChipType.SUGGESTION:
			pressed.emit()
		ChipType.INPUT:
			pressed.emit()

func _on_trailing_icon_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			# 阻止事件传播到 Chip 本身
			accept_event()
			deleted.emit()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_update_layout()
		if _ripple_mixin:
			_ripple_mixin.update_size(size)
	elif what == NOTIFICATION_MOUSE_ENTER:
		_is_hovering = true
	elif what == NOTIFICATION_MOUSE_EXIT:
		_is_hovering = false
		if _is_pressing:
			_is_pressing = false
			if enable_ripple and _ripple_mixin:
				_ripple_mixin.fade_ripple()

# ============ 公共 API ============

## 设置选中状态（不触发信号）
func set_selected_no_signal(value: bool) -> void:
	if is_selected != value:
		is_selected = value
		_update_selection()

## 切换选中状态
func toggle_selected() -> void:
	is_selected = not is_selected

## 获取当前尺寸配置
func get_size_config() -> Dictionary:
	return SIZE_MAP[chip_size]

## 清理资源
func cleanup() -> void:
	if _ripple_mixin:
		_ripple_mixin.cleanup()
