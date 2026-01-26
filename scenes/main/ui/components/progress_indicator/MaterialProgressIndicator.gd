@tool
class_name MaterialProgressIndicator
extends Control

## Material Design 风格进度指示器
## 支持线性（Linear）和圆形（Circular）两种样式
## 支持确定（Determinate）和不确定（Indeterminate）两种模式

## 进度改变信号
signal progress_changed(new_progress: float)

## 动画完成信号
signal animation_finished

## ==================== 枚举定义 ====================

enum IndicatorType {
	LINEAR,      ## 线性进度条
	CIRCULAR     ## 圆形进度环
}

enum ProgressMode {
	DETERMINATE,     ## 确定模式：显示具体进度
	INDETERMINATE    ## 不确定模式：循环动画
}

## ==================== 导出属性 ====================

## 指示器类型
@export var indicator_type: IndicatorType = IndicatorType.LINEAR:
	set(value):
		indicator_type = value
		_update_size()
		if is_inside_tree() and progress_mode == ProgressMode.INDETERMINATE:
			_restart_indeterminate_animation()
		queue_redraw()

## 进度模式
@export var progress_mode: ProgressMode = ProgressMode.DETERMINATE:
	set(value):
		progress_mode = value
		if is_inside_tree():
			if progress_mode == ProgressMode.INDETERMINATE:
				_start_indeterminate_animation()
			else:
				_stop_indeterminate_animation()
		queue_redraw()

## 进度值 (0.0 - 1.0)
## 注意：直接设置此属性会立即更新显示，使用 set_progress_value() 来获得动画效果
@export_range(0.0, 1.0, 0.01) var progress: float = 0.0:
	set(value):
		var old_progress = progress
		progress = clampf(value, 0.0, 1.0)
		if old_progress != progress:
			progress_changed.emit(progress)

@export_group("尺寸")

## 轨道粗细（线性：高度 / 圆形：环宽）
@export_range(2, 16, 1) var track_thickness: int = 4:
	set(value):
		track_thickness = value
		_update_size()
		queue_redraw()

## 圆形指示器直径
@export_range(24, 120, 1) var circular_size: int = 48:
	set(value):
		circular_size = value
		_update_size()
		queue_redraw()

## 线性指示器宽度
@export_range(50, 500, 10) var linear_width: int = 200:
	set(value):
		linear_width = value
		_update_size()
		queue_redraw()

@export_group("颜色")

## 进度颜色
@export var progress_color: Color = Color(0.35, 0.65, 0.95, 1):
	set(value):
		progress_color = value
		queue_redraw()

## 轨道颜色
@export var track_color: Color = Color(0.3, 0.3, 0.3, 0.5):
	set(value):
		track_color = value
		queue_redraw()

@export_group("动画")

## 进度变化动画时长
@export_range(0.1, 1.0, 0.05) var animation_duration: float = 0.3

## 不确定模式循环周期
@export_range(0.5, 3.0, 0.1) var indeterminate_duration: float = 1.8

## 是否启用进度变化动画
@export var enable_animation: bool = true

## ==================== 内部变量 ====================

var _progress_tween: Tween
var _display_progress: float = 0.0:  # 实际显示的进度（用于动画）
	set(value):
		_display_progress = value
		queue_redraw()  # 值变化时触发重绘

# 不确定模式动画参数
var _anim_time: float = 0.0  # 动画时间累计
var _anim_running: bool = false  # 动画是否运行中

# 线性：bar的头部和尾部位置
var _bar_head: float = 0.0    # bar 头部位置 (右端)
var _bar_tail: float = 0.0    # bar 尾部位置 (左端)

# 圆形：旋转角度和弧长
var _arc_rotation: float = 0.0      # 整体旋转角度
var _arc_sweep: float = 0.0         # 弧扫过的角度 (0-1 of TAU)

# 圆弧绘制参数
const ARC_POINTS: int = 128  # 圆弧绘制点数（增加以改善抗锯齿效果）

## ==================== 生命周期 ====================

func _ready() -> void:
	_display_progress = progress
	_update_size()

	# 如果是不确定模式，启动动画
	if progress_mode == ProgressMode.INDETERMINATE:
		_start_indeterminate_animation()

func _process(delta: float) -> void:
	# 不确定模式需要持续更新动画
	if progress_mode == ProgressMode.INDETERMINATE and _anim_running:
		_anim_time += delta
		_update_indeterminate_animation()
		queue_redraw()

func _draw() -> void:
	match indicator_type:
		IndicatorType.LINEAR:
			_draw_linear()
		IndicatorType.CIRCULAR:
			_draw_circular()

## ==================== 尺寸更新 ====================

func _update_size() -> void:
	match indicator_type:
		IndicatorType.LINEAR:
			custom_minimum_size = Vector2(linear_width, track_thickness)
			size = custom_minimum_size
		IndicatorType.CIRCULAR:
			custom_minimum_size = Vector2(circular_size, circular_size)
			size = custom_minimum_size

## ==================== 线性绘制 ====================

func _draw_linear() -> void:
	var rect_size = size
	var radius = track_thickness / 2.0

	# 绘制轨道背景
	_draw_rounded_rect(Vector2.ZERO, rect_size, track_color, radius)

	if progress_mode == ProgressMode.DETERMINATE:
		# 确定模式：绘制进度条
		if _display_progress > 0:
			var progress_width = rect_size.x * _display_progress
			# 确保进度条宽度至少为高度（保持圆角效果）
			progress_width = maxf(progress_width, track_thickness)
			_draw_rounded_rect(Vector2.ZERO, Vector2(progress_width, rect_size.y), progress_color, radius)
	else:
		# 不确定模式：绘制动态bar
		_draw_indeterminate_bar(_bar_tail, _bar_head, rect_size, radius)

## 绘制不确定模式的进度条
func _draw_indeterminate_bar(bar_start: float, bar_end: float, rect_size: Vector2, radius: float) -> void:
	if bar_end <= bar_start:
		return

	var start_x = rect_size.x * bar_start
	var end_x = rect_size.x * bar_end
	var width = end_x - start_x

	if width < 1:
		return

	# 裁剪到轨道范围
	start_x = maxf(start_x, 0)
	end_x = minf(end_x, rect_size.x)
	width = end_x - start_x

	if width > 0:
		_draw_rounded_rect(Vector2(start_x, 0), Vector2(width, rect_size.y), progress_color, radius)

## 绘制圆角矩形
func _draw_rounded_rect(pos: Vector2, rect_size: Vector2, color: Color, radius: float) -> void:
	# 确保半径不超过高度的一半
	radius = minf(radius, rect_size.y / 2.0)
	radius = minf(radius, rect_size.x / 2.0)

	if radius <= 0:
		draw_rect(Rect2(pos, rect_size), color)
		return

	# 使用多边形绘制圆角矩形
	var points: PackedVector2Array = []
	var segments = 8  # 每个圆角的分段数

	# 左上角
	for i in range(segments + 1):
		var angle = PI + (PI / 2.0) * (float(i) / segments)
		points.append(pos + Vector2(radius, radius) + Vector2(cos(angle), sin(angle)) * radius)

	# 右上角
	for i in range(segments + 1):
		var angle = -PI / 2.0 + (PI / 2.0) * (float(i) / segments)
		points.append(pos + Vector2(rect_size.x - radius, radius) + Vector2(cos(angle), sin(angle)) * radius)

	# 右下角
	for i in range(segments + 1):
		var angle = 0 + (PI / 2.0) * (float(i) / segments)
		points.append(pos + Vector2(rect_size.x - radius, rect_size.y - radius) + Vector2(cos(angle), sin(angle)) * radius)

	# 左下角
	for i in range(segments + 1):
		var angle = PI / 2.0 + (PI / 2.0) * (float(i) / segments)
		points.append(pos + Vector2(radius, rect_size.y - radius) + Vector2(cos(angle), sin(angle)) * radius)

	draw_colored_polygon(points, color)

## ==================== 圆形绘制 ====================

func _draw_circular() -> void:
	var center = size / 2.0
	var outer_radius = minf(size.x, size.y) / 2.0
	var inner_radius = outer_radius - track_thickness
	var cap_radius = track_thickness / 2.0  # 端点圆角半径

	# 绘制轨道背景（完整圆环）
	_draw_ring(center, inner_radius, outer_radius, 0, TAU, track_color)

	if progress_mode == ProgressMode.DETERMINATE:
		# 确定模式：绘制进度弧
		if _display_progress > 0.001:
			var sweep_angle = TAU * _display_progress
			# 从顶部开始（-PI/2），顺时针方向
			var start_angle = -PI / 2.0
			var end_angle = start_angle + sweep_angle
			_draw_ring_with_caps(center, inner_radius, outer_radius, start_angle, end_angle, progress_color, cap_radius)
	else:
		# 不确定模式：绘制旋转的弧（带圆角端点）
		var start_angle = _arc_rotation - PI / 2.0
		var sweep_angle = TAU * _arc_sweep
		var end_angle = start_angle + sweep_angle
		_draw_ring_with_caps(center, inner_radius, outer_radius, start_angle, end_angle, progress_color, cap_radius)

## 绘制带圆角端点的圆环扇形
func _draw_ring_with_caps(center: Vector2, inner_r: float, outer_r: float, start_angle: float, end_angle: float, color: Color, cap_radius: float) -> void:
	# 先绘制主体圆弧
	_draw_ring(center, inner_r, outer_r, start_angle, end_angle, color)

	# 计算中心半径（圆环中心线）
	var mid_r = (inner_r + outer_r) / 2.0

	# 绘制起始端点圆角
	var start_cap_center = center + Vector2(cos(start_angle), sin(start_angle)) * mid_r
	_draw_circle(start_cap_center, cap_radius, color)

	# 绘制结束端点圆角
	var end_cap_center = center + Vector2(cos(end_angle), sin(end_angle)) * mid_r
	_draw_circle(end_cap_center, cap_radius, color)

## 绘制圆形（使用抗锯齿）
func _draw_circle(center: Vector2, radius: float, color: Color) -> void:
	# 使用Godot内置的draw_circle方法，自带抗锯齿
	draw_circle(center, radius, color)

## 绘制圆环扇形（优化抗锯齿）
func _draw_ring(center: Vector2, inner_r: float, outer_r: float, start_angle: float, end_angle: float, color: Color) -> void:
	if inner_r <= 0 or outer_r <= inner_r:
		return

	var angle_range = end_angle - start_angle
	var steps = maxi(int(abs(angle_range) / TAU * ARC_POINTS), 16)

	# 计算圆环的中心半径和宽度
	var mid_radius = (inner_r + outer_r) / 2.0
	var ring_width = outer_r - inner_r

	# 使用draw_arc绘制圆环中心线，宽度为圆环宽度，自带抗锯齿
	draw_arc(center, mid_radius, start_angle, end_angle, steps, color, ring_width, true)

## ==================== 动画控制 ====================

## 设置进度（可选动画）
func set_progress_value(new_value: float, animate: bool = true) -> void:
	new_value = clampf(new_value, 0.0, 1.0)

	# 停止之前的动画
	if _progress_tween and _progress_tween.is_valid():
		_progress_tween.kill()
		_progress_tween = null

	# 更新目标进度值
	progress = new_value

	# 无动画：直接设置显示进度
	if not enable_animation or not animate or not is_inside_tree():
		_display_progress = new_value
		queue_redraw()
		return

	# 有动画：创建 tween 从当前显示进度过渡到目标进度
	var from_value = _display_progress
	_progress_tween = create_tween()
	_progress_tween.tween_method(
		func(v: float):
			_display_progress = v,
		from_value,
		new_value,
		animation_duration
	).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	_progress_tween.tween_callback(animation_finished.emit)

## 立即设置进度（无动画）
func set_progress_immediate(value: float) -> void:
	set_progress_value(value, false)

## 重置进度
func reset() -> void:
	set_progress_immediate(0.0)

## ==================== 不确定模式动画 ====================

func _restart_indeterminate_animation() -> void:
	_stop_indeterminate_animation()
	_start_indeterminate_animation()

func _start_indeterminate_animation() -> void:
	if not is_inside_tree():
		return

	_anim_time = 0.0
	_anim_running = true
	set_process(true)

	# 初始化动画参数
	match indicator_type:
		IndicatorType.LINEAR:
			_bar_head = -0.1
			_bar_tail = -0.2
		IndicatorType.CIRCULAR:
			_arc_rotation = 0.0
			_arc_sweep = 0.1

## 更新不确定模式动画状态
func _update_indeterminate_animation() -> void:
	match indicator_type:
		IndicatorType.LINEAR:
			_update_linear_indeterminate()
		IndicatorType.CIRCULAR:
			_update_circular_indeterminate()

## 线性不确定动画 - 头部持续前进，尾部追赶产生伸缩效果
func _update_linear_indeterminate() -> void:
	var duration = indeterminate_duration
	var t = fmod(_anim_time, duration) / duration  # 归一化周期时间 0-1

	# 头部持续向前移动（基于累计时间，永不回退）
	var head_speed = 1.6 / duration  # 每周期移动 1.6 个单位长度
	var head_pos = fmod(_anim_time * head_speed, 1.6) - 0.3  # 从 -0.3 到 1.3

	# bar 长度变化：先伸展后收缩（使用正弦波）
	var breath = (sin(t * TAU - PI / 2.0) + 1.0) / 2.0  # 0->1->0
	var bar_len = lerp(0.1, 0.5, breath)

	# 尾部位置 = 头部位置 - bar长度（尾部追赶头部）
	_bar_head = head_pos
	_bar_tail = head_pos - bar_len

## 圆形不确定动画 - 头部持续前进，尾部追赶产生弧长变化
func _update_circular_indeterminate() -> void:
	var duration = indeterminate_duration
	var t = fmod(_anim_time, duration) / duration  # 归一化周期时间 0-1

	# 头部持续向前旋转（基于累计时间，永不回退）
	var head_speed = TAU * 1.0 / duration  # 每周期转 1 圈
	var head_angle = _anim_time * head_speed

	# 弧长变化：先伸展后收缩（使用正弦波）
	var breath = (sin(t * TAU - PI / 2.0) + 1.0) / 2.0  # 0->1->0
	var arc_len = lerp(0.08, 0.65, breath)

	# 尾部位置 = 头部位置 - 弧长（尾部追赶头部）
	# _arc_rotation 存储的是弧的起始角度（尾部）
	_arc_rotation = head_angle - TAU * arc_len
	_arc_sweep = arc_len

func _stop_indeterminate_animation() -> void:
	_anim_running = false
	set_process(false)

	# 重置动画参数
	_anim_time = 0.0
	_bar_head = 0.0
	_bar_tail = 0.0
	_arc_rotation = 0.0
	_arc_sweep = 0.0

## 开始不确定模式
func start_indeterminate() -> void:
	progress_mode = ProgressMode.INDETERMINATE

## 停止不确定模式
func stop_indeterminate() -> void:
	progress_mode = ProgressMode.DETERMINATE

## ==================== 通知处理 ====================

func _notification(what: int) -> void:
	match what:
		NOTIFICATION_ENTER_TREE:
			_display_progress = progress
			if progress_mode == ProgressMode.INDETERMINATE:
				_start_indeterminate_animation()
		NOTIFICATION_EXIT_TREE:
			_stop_indeterminate_animation()
		NOTIFICATION_RESIZED:
			queue_redraw()
