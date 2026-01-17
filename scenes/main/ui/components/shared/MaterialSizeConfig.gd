class_name MaterialSizeConfig
extends RefCounted

## Material Design 尺寸配置
## 提供统一的尺寸常量和工具方法

enum ComponentSize {
	SMALL32,      ## 32dp 高度
	STANDARD36,   ## 36dp 高度 (默认)
	MEDIUM40,     ## 40dp 高度
	LARGE48,      ## 48dp 高度
	EXTRA_LARGE56 ## 56dp 高度
}

# Material Design 尺寸定义 (dp)
const SIZE_MAP = {
	ComponentSize.SMALL32: {"height": 32, "icon": 18, "padding_h": 12, "padding_v": 6, "corner": 4},
	ComponentSize.STANDARD36: {"height": 36, "icon": 20, "padding_h": 14, "padding_v": 7, "corner": 6},
	ComponentSize.MEDIUM40: {"height": 40, "icon": 24, "padding_h": 16, "padding_v": 8, "corner": 6},
	ComponentSize.LARGE48: {"height": 48, "icon": 24, "padding_h": 20, "padding_v": 10, "corner": 8},
	ComponentSize.EXTRA_LARGE56: {"height": 56, "icon": 24, "padding_h": 24, "padding_v": 12, "corner": 8}
}

## 获取尺寸配置
static func get_size_config(size: ComponentSize) -> Dictionary:
	return SIZE_MAP.get(size, SIZE_MAP[ComponentSize.STANDARD36])

## 获取高度
static func get_height(size: ComponentSize) -> int:
	return get_size_config(size)["height"]

## 获取图标尺寸
static func get_icon_size(size: ComponentSize) -> int:
	return get_size_config(size)["icon"]

## 获取水平内边距
static func get_padding_horizontal(size: ComponentSize) -> int:
	return get_size_config(size)["padding_h"]

## 获取垂直内边距
static func get_padding_vertical(size: ComponentSize) -> int:
	return get_size_config(size)["padding_v"]

## 获取圆角半径
static func get_corner_radius(size: ComponentSize) -> int:
	return get_size_config(size)["corner"]

## 创建圆角样式盒
static func create_stylebox(bg_color: Color, radius: int, padding_h: int = 0, padding_v: int = 0) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = bg_color
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	style.content_margin_left = padding_h
	style.content_margin_right = padding_h
	style.content_margin_top = padding_v
	style.content_margin_bottom = padding_v
	return style

## 创建带边框的样式盒
static func create_outlined_stylebox(bg_color: Color, border_color: Color, border_width: int, radius: int, padding_h: int = 0, padding_v: int = 0) -> StyleBoxFlat:
	var style = create_stylebox(bg_color, radius, padding_h, padding_v)
	style.border_color = border_color
	style.border_width_left = border_width
	style.border_width_right = border_width
	style.border_width_top = border_width
	style.border_width_bottom = border_width
	return style
