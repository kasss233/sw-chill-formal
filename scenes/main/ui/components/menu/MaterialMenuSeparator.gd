@tool
class_name MaterialMenuSeparator
extends Control

## Material Design 风格菜单分隔线
## 用于在菜单项之间添加视觉分隔

## 分隔线颜色
@export var line_color: Color = Color(0.3, 0.3, 0.3, 0.5):
	set(value):
		line_color = value
		queue_redraw()

## 分隔线厚度
@export_range(1, 4, 1) var line_thickness: int = 1:
	set(value):
		line_thickness = value
		custom_minimum_size.y = line_thickness + padding_vertical * 2
		queue_redraw()

## 垂直内边距
@export_range(2, 16, 1) var padding_vertical: int = 8:
	set(value):
		padding_vertical = value
		custom_minimum_size.y = line_thickness + padding_vertical * 2
		queue_redraw()

## 水平内边距
@export_range(0, 32, 1) var padding_horizontal: int = 16:
	set(value):
		padding_horizontal = value
		queue_redraw()

func _ready() -> void:
	custom_minimum_size.y = line_thickness + padding_vertical * 2
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
	var y_pos = size.y / 2.0
	var start_x = padding_horizontal
	var end_x = size.x - padding_horizontal
	
	draw_line(
		Vector2(start_x, y_pos),
		Vector2(end_x, y_pos),
		line_color,
		line_thickness
	)
