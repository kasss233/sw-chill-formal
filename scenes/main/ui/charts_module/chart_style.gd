@tool
extends Resource
class_name ChartStyle

## 图表样式配置资源
## 条形图、折线图、饼图共用；未设置的项各图表使用内置默认值
## 在编辑器中修改任意属性会触发 style_changed，图表会实时重绘预览

signal style_changed

# ---------- 通用（后备变量 + setter 触发 style_changed，编辑器改属性即重绘）----------
var _padding: Vector4 = Vector4(40.0, 24.0, 24.0, 32.0)
var _background_color: Color = Color(0, 0, 0, 0)
var _empty_message_color: Color = Color(0.6, 0.6, 0.6, 1.0)
var _empty_message_font_size: int = 14
var _title_color: Color = Color(0.9, 0.9, 0.9, 1.0)
var _title_font_size: int = 16
var _label_color: Color = Color(0.7, 0.7, 0.7, 1.0)
var _label_font_size: int = 11
var _value_color: Color = Color(0.85, 0.85, 0.85, 1.0)
var _value_font_size: int = 10
var _grid_color: Color = Color(1, 1, 1, 0.08)
var _grid_line_width: float = 1.0
var _axis_color: Color = Color(1, 1, 1, 0.15)
var _axis_line_width: float = 1.0

var _bar_colors: Array[Color] = [Color(0.35, 0.65, 0.95, 0.9)]
var _bar_corner_radius: int = 0
var _bar_max_width: float = 48.0
var _bar_width_ratio: float = 0.65
var _bar_show_value_label: bool = true
var _bar_reference_line_color: Color = Color(1, 0.85, 0.3, 0.6)
var _bar_reference_line_width: float = 1.0
var _bar_reference_line_dashed: bool = true

var _line_color: Color = Color(0.35, 0.65, 0.95, 1.0)
var _line_series_colors: Array[Color] = []
var _line_width: float = 2.0
var _line_point_radius: float = 4.0
var _line_point_color: Color = Color(0.35, 0.65, 0.95, 1.0)
var _line_fill_color: Color = Color(0.35, 0.65, 0.95, 0.15)
var _line_smooth: bool = false

var _pie_colors: Array[Color] = [
	Color(0.35, 0.65, 0.95, 0.9),
	Color(0.95, 0.55, 0.35, 0.9),
	Color(0.35, 0.85, 0.55, 0.9),
	Color(0.85, 0.55, 0.95, 0.9),
	Color(0.95, 0.85, 0.35, 0.9),
]
var _pie_stroke_color: Color = Color(0.2, 0.2, 0.2, 0.5)
var _pie_stroke_width: float = 0.0
var _pie_inner_radius_ratio: float = 0.0
var _pie_show_legend: bool = true
var _pie_legend_spacing: float = 16.0
var _pie_label_mode: int = 2

# 动画时长（秒）
var _bar_animation_duration: float = 1.2
var _line_animation_duration: float = 1.2
var _pie_animation_duration: float = 1.2

@export_group("动画")
## 条形图展示动画时长（秒），含 set_chart_data(animate=true) 与 play_show_animation()
@export var bar_animation_duration: float:
	get: return _bar_animation_duration
	set(v): _bar_animation_duration = maxf(0.1, v); emit_signal("style_changed")
## 折线图展示动画时长（秒）
@export var line_animation_duration: float:
	get: return _line_animation_duration
	set(v): _line_animation_duration = maxf(0.1, v); emit_signal("style_changed")
## 饼图展示动画时长（秒）
@export var pie_animation_duration: float:
	get: return _pie_animation_duration
	set(v): _pie_animation_duration = maxf(0.1, v); emit_signal("style_changed")

@export_group("通用")
## 图表绘制区内边距：左、上、右、下（像素）
@export var padding: Vector4:
	get: return _padding
	set(v): _padding = v; emit_signal("style_changed")
## 图表背景色；透明则不绘制背景
@export var background_color: Color:
	get: return _background_color
	set(v): _background_color = v; emit_signal("style_changed")
## 无数据时居中提示文字的颜色（如「暂无数据」）
@export var empty_message_color: Color:
	get: return _empty_message_color
	set(v): _empty_message_color = v; emit_signal("style_changed")
## 无数据时提示文字的字号
@export var empty_message_font_size: int:
	get: return _empty_message_font_size
	set(v): _empty_message_font_size = v; emit_signal("style_changed")
## 标题文字颜色（若图表支持标题）
@export var title_color: Color:
	get: return _title_color
	set(v): _title_color = v; emit_signal("style_changed")
## 标题文字字号
@export var title_font_size: int:
	get: return _title_font_size
	set(v): _title_font_size = v; emit_signal("style_changed")
## 轴标签、图例等说明文字的颜色
@export var label_color: Color:
	get: return _label_color
	set(v): _label_color = v; emit_signal("style_changed")
## 轴标签、图例等说明文字的字号
@export var label_font_size: int:
	get: return _label_font_size
	set(v): _label_font_size = v; emit_signal("style_changed")
## 数值标签的颜色（如柱顶数字、扇区百分比）
@export var value_color: Color:
	get: return _value_color
	set(v): _value_color = v; emit_signal("style_changed")
## 数值标签的字号
@export var value_font_size: int:
	get: return _value_font_size
	set(v): _value_font_size = v; emit_signal("style_changed")
## 网格线颜色
@export var grid_color: Color:
	get: return _grid_color
	set(v): _grid_color = v; emit_signal("style_changed")
## 网格线宽度（像素）
@export var grid_line_width: float:
	get: return _grid_line_width
	set(v): _grid_line_width = v; emit_signal("style_changed")
## 坐标轴线颜色
@export var axis_color: Color:
	get: return _axis_color
	set(v): _axis_color = v; emit_signal("style_changed")
## 坐标轴线宽度（像素）
@export var axis_line_width: float:
	get: return _axis_line_width
	set(v): _axis_line_width = v; emit_signal("style_changed")

@export_group("条形图")
## 柱体颜色列表；单色则所有柱同色，多色则按索引循环使用
@export var bar_colors: Array[Color]:
	get: return _bar_colors
	set(v): _bar_colors = v; emit_signal("style_changed")
## 柱体圆角半径（像素）；0 为直角
@export var bar_corner_radius: int:
	get: return _bar_corner_radius
	set(v): _bar_corner_radius = v; emit_signal("style_changed")
## 单根柱体的最大宽度（像素）
@export var bar_max_width: float:
	get: return _bar_max_width
	set(v): _bar_max_width = v; emit_signal("style_changed")
## 柱体占其槽位宽度的比例（0～1），与柱间距相关
@export var bar_width_ratio: float:
	get: return _bar_width_ratio
	set(v): _bar_width_ratio = v; emit_signal("style_changed")
## 是否在柱顶绘制数值标签
@export var bar_show_value_label: bool:
	get: return _bar_show_value_label
	set(v): _bar_show_value_label = v; emit_signal("style_changed")
## 参考线（如平均值线）的颜色
@export var bar_reference_line_color: Color:
	get: return _bar_reference_line_color
	set(v): _bar_reference_line_color = v; emit_signal("style_changed")
## 参考线宽度（像素）
@export var bar_reference_line_width: float:
	get: return _bar_reference_line_width
	set(v): _bar_reference_line_width = v; emit_signal("style_changed")
## 参考线是否以虚线绘制
@export var bar_reference_line_dashed: bool:
	get: return _bar_reference_line_dashed
	set(v): _bar_reference_line_dashed = v; emit_signal("style_changed")

@export_group("折线图")
## 折线颜色（单系列时使用；多系列时可用 line_series_colors 覆盖）
@export var line_color: Color:
	get: return _line_color
	set(v): _line_color = v; emit_signal("style_changed")
## 多条折线时各系列颜色，按系列索引取；未设置则用 line_color
@export var line_series_colors: Array[Color]:
	get: return _line_series_colors
	set(v): _line_series_colors = v; emit_signal("style_changed")
## 折线线宽（像素）
@export var line_width: float:
	get: return _line_width
	set(v): _line_width = v; emit_signal("style_changed")
## 数据点圆点半径（像素）；0 则不绘制数据点
@export var line_point_radius: float:
	get: return _line_point_radius
	set(v): _line_point_radius = v; emit_signal("style_changed")
## 数据点填充颜色
@export var line_point_color: Color:
	get: return _line_point_color
	set(v): _line_point_color = v; emit_signal("style_changed")
## 折线与 X 轴之间区域的填充色；透明则不填充
@export var line_fill_color: Color:
	get: return _line_fill_color
	set(v): _line_fill_color = v; emit_signal("style_changed")
## 是否使用平滑曲线（Catmull-Rom）连接数据点
@export var line_smooth: bool:
	get: return _line_smooth
	set(v): _line_smooth = v; emit_signal("style_changed")

@export_group("饼图")
## 扇区颜色列表，按扇区索引循环使用
@export var pie_colors: Array[Color]:
	get: return _pie_colors
	set(v): _pie_colors = v; emit_signal("style_changed")
## 扇区描边颜色
@export var pie_stroke_color: Color:
	get: return _pie_stroke_color
	set(v): _pie_stroke_color = v; emit_signal("style_changed")
## 扇区描边宽度（像素）
@export var pie_stroke_width: float:
	get: return _pie_stroke_width
	set(v): _pie_stroke_width = v; emit_signal("style_changed")
## 内半径与总半径之比（0～1）；大于 0 时为环形图，0 为实心圆
@export var pie_inner_radius_ratio: float:
	get: return _pie_inner_radius_ratio
	set(v): _pie_inner_radius_ratio = v; emit_signal("style_changed")
## 是否在侧边显示图例（颜色块 + 标签）
@export var pie_show_legend: bool:
	get: return _pie_show_legend
	set(v): _pie_show_legend = v; emit_signal("style_changed")
## 图例与饼图之间的间距（像素）
@export var pie_legend_spacing: float:
	get: return _pie_legend_spacing
	set(v): _pie_legend_spacing = v; emit_signal("style_changed")
## 扇区内标签：0=不显示，1=仅百分比，2=标签+百分比
@export var pie_label_mode: int:
	get: return _pie_label_mode
	set(v): _pie_label_mode = v; emit_signal("style_changed")


func get_padding_rect(control_size: Vector2) -> Rect2:
	var pl = _padding.x
	var pt = _padding.y
	var pr = _padding.z
	var pb = _padding.w
	return Rect2(pl, pt, control_size.x - pl - pr, control_size.y - pt - pb)


func get_bar_color(index: int) -> Color:
	if _bar_colors.is_empty():
		return Color(0.35, 0.65, 0.95, 0.9)
	return _bar_colors[index % _bar_colors.size()]


func get_line_series_color(series_index: int) -> Color:
	if series_index < _line_series_colors.size():
		return _line_series_colors[series_index]
	return _line_color


func get_pie_color(index: int) -> Color:
	if _pie_colors.is_empty():
		return Color(0.5, 0.6, 0.8, 0.9)
	return _pie_colors[index % _pie_colors.size()]
