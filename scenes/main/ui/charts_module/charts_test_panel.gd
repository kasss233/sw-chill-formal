@tool
extends Control

## 图表模块测试面板：展示条形图、折线图、饼图并注入示例数据
## 在编辑器中打开此场景即可看到三个图表的渲染效果；修改任意图表的 chart_style 或样式资源会在视图中实时更新
## 顶部三个按钮可分别触发对应图表的展示动画

var bar_chart: Control
var line_chart: Control
var pie_chart: Control


func _ready() -> void:
	bar_chart = get_node_or_null("MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/BarChartSection/BarChart")
	line_chart = get_node_or_null("MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/LineChartSection/LineChart")
	pie_chart = get_node_or_null("MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/PieChartSection/PieChart")
	var bar_btn = get_node_or_null("MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/AnimationButtons/BarAnimBtn")
	var line_btn = get_node_or_null("MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/AnimationButtons/LineAnimBtn")
	var pie_btn = get_node_or_null("MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/AnimationButtons/PieAnimBtn")
	if bar_btn and bar_btn.pressed.is_connected(_on_bar_anim_pressed) == false:
		bar_btn.pressed.connect(_on_bar_anim_pressed)
	if line_btn and line_btn.pressed.is_connected(_on_line_anim_pressed) == false:
		line_btn.pressed.connect(_on_line_anim_pressed)
	if pie_btn and pie_btn.pressed.is_connected(_on_pie_anim_pressed) == false:
		pie_btn.pressed.connect(_on_pie_anim_pressed)
	call_deferred("_apply_sample_data")


func _on_bar_anim_pressed() -> void:
	if is_instance_valid(bar_chart) and bar_chart.has_method("play_show_animation"):
		bar_chart.play_show_animation()


func _on_line_anim_pressed() -> void:
	if is_instance_valid(line_chart) and line_chart.has_method("play_show_animation"):
		line_chart.play_show_animation()


func _on_pie_anim_pressed() -> void:
	if is_instance_valid(pie_chart) and pie_chart.has_method("play_show_animation"):
		pie_chart.play_show_animation()


func _apply_sample_data() -> void:
	if is_instance_valid(bar_chart) and bar_chart.has_method("set_chart_data"):
		bar_chart.set_chart_data([
			{"label": "周一", "value": 12},
			{"label": "周二", "value": 19},
			{"label": "周三", "value": 8},
			{"label": "周四", "value": 24},
			{"label": "周五", "value": 15},
			{"label": "周六", "value": 22},
			{"label": "周日", "value": 10},
		])
		bar_chart.set_reference_line(15.7)
	if is_instance_valid(line_chart) and line_chart.has_method("set_chart_data"):
		line_chart.set_chart_data([
			{"label": "1月", "value": 20},
			{"label": "2月", "value": 35},
			{"label": "3月", "value": 28},
			{"label": "4月", "value": 45},
			{"label": "5月", "value": 38},
			{"label": "6月", "value": 52},
		])
	if is_instance_valid(pie_chart) and pie_chart.has_method("set_chart_data"):
		pie_chart.set_chart_data([
			{"label": "学习", "value": 35},
			{"label": "运动", "value": 25},
			{"label": "娱乐", "value": 20},
			{"label": "休息", "value": 15},
			{"label": "其他", "value": 5},
		])
