@tool
class_name MaterialDragHandle
extends Control

## Material Design 风格拖拽手柄
## 按住拖拽可移动父节点位置，支持多种边界限制模式

## 边界模式枚举
enum BoundaryMode {
	SCREEN,			## 限制在屏幕范围内
	CUSTOM_RECT,	## 限制在自定义矩形范围内
	PARENT_CONTAINER, ## 限制在父容器范围内
	NONE			## 无边界限制
}

## 拖拽目标（null = 使用 get_parent()）
@export var drag_target: Control = null:
	set(value):
		drag_target = value
		_update_target()

## 视觉效果目标（null = 使用 drag_target）
## 分离拖拽目标和视觉效果目标，避免缩放动画导致拖拽位置偏移
@export var visual_target: Control = null:
	set(value):
		visual_target = value
		_update_target()

## 目标节点别名（与 drag_target 相同）
@export var target_node: Control = null:
	set(value):
		target_node = value
		drag_target = value

## 是否启用拖拽
@export var draggable: bool = true:
	set(value):
		draggable = value
		if not draggable:
			_dragging = false

## 边界模式
@export var boundary_mode: BoundaryMode = BoundaryMode.SCREEN

## 自定义边界矩形（当 boundary_mode = CUSTOM_RECT 时使用）
@export var boundary_rect: Rect2 = Rect2(0, 0, 500, 500)

## 鼠标悬停时光标形状
@export var hover_cursor: Control.CursorShape = Control.CURSOR_MOVE

## 是否在拖拽时应用视觉反馈
@export var visual_feedback: bool = true

## 拖拽时的缩放效果
@export_range(0.8, 1.2, 0.01) var drag_scale: float = 1.05

## 拖拽时的透明度（1.0 = 不变，0.5 = 半透明）
@export_range(0.2, 1.0, 0.05) var drag_opacity: float = 1.0

## 拖拽完成后的弹跳动画
@export var bounce_animation: bool = true

## 平滑因子（0 = 无平滑，1 = 非常平滑）
@export_range(0.0, 1.0, 0.05) var smooth_factor: float = 0.0

## 拖拽开始信号
signal drag_started

## 拖拽结束信号
signal drag_ended

## 拖拽移动信号（传递当前位置）
signal drag_moved(position: Vector2)

var _dragging: bool = false
var _drag_start_global_pos: Vector2
var _target_start_pos: Vector2
var _handle_start_pos: Vector2  # 拖拽开始时手柄自身的全局位置
var _target: Control = null
var _visual_node: Control = null
var _tween: Tween
var _visual_start_modulate: Color = Color.WHITE
var _visual_start_scale: Vector2 = Vector2.ONE
var _canvas_layer: CanvasLayer = null


func _ready() -> void:
	_setup_handle()
	_update_target()

	# 连接信号
	gui_input.connect(_on_gui_input)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)


func _setup_handle() -> void:
	# 作为透明拖拽区域
	focus_mode = Control.FOCUS_NONE
	mouse_filter = Control.MOUSE_FILTER_STOP

	# 清除所有默认样式
	var empty_style = StyleBoxEmpty.new()
	add_theme_stylebox_override("normal", empty_style)
	add_theme_stylebox_override("hover", empty_style)
	add_theme_stylebox_override("pressed", empty_style)
	add_theme_stylebox_override("focus", empty_style)


func _update_target() -> void:
	if drag_target != null:
		_target = drag_target
	else:
		_target = get_parent() as Control
	_visual_node = visual_target if visual_target else _target
	_canvas_layer = _find_canvas_layer()


func _find_canvas_layer() -> CanvasLayer:
	var current = get_parent()
	while current:
		if current is CanvasLayer:
			return current
		current = current.get_parent()
	return null


func _on_gui_input(event: InputEvent) -> void:
	if not draggable or not _target:
		return

	if event is InputEventMouseButton:
		var mouse_event = event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT:
			if mouse_event.pressed:
				_start_dragging()
			else:
				_stop_dragging()


func _input(event: InputEvent) -> void:
	# 使用全局输入来持续跟踪拖拽
	if _dragging and event is InputEventMouseMotion:
		_handle_drag()


func _start_dragging() -> void:
	_dragging = true
	# 使用全局鼠标位置，避免父节点移动时坐标系变化
	_drag_start_global_pos = get_global_mouse_position()
	_target_start_pos = _target.global_position
	_handle_start_pos = global_position  # 记录手柄自身的初始全局位置

	# 如果有正在进行的视觉动画（如上次退出动画未结束），先恢复到干净状态
	# 避免在 scale != 1 时改变 pivot_offset 导致视觉跳变
	if _tween and _tween.is_valid():
		_tween.kill()
		_reset_visual_effect()

	_visual_start_modulate = _visual_node.modulate
	_visual_start_scale = _visual_node.scale

	# 视觉反馈
	if visual_feedback:
		_apply_drag_enter_effect()

	# 拖拽开始时将所在 CanvasLayer 置顶
	if _canvas_layer and not Engine.is_editor_hint():
		var lm = get_node_or_null("/root/LayerManager")
		if lm:
			lm.bring_to_front(_canvas_layer)

	drag_started.emit()


func _stop_dragging() -> void:
	if not _dragging:
		return

	_dragging = false

	# 弹跳动画
	if visual_feedback and bounce_animation:
		_apply_drag_exit_effect()
	else:
		_reset_visual_effect()

	drag_ended.emit()


func _handle_drag() -> void:
	if not _target or not _dragging:
		return

	# 使用全局鼠标位置
	var current_global_mouse = get_global_mouse_position()
	var delta = current_global_mouse - _drag_start_global_pos
	var new_pos = _target_start_pos + delta

	# 应用边界限制
	var clamped_pos = _apply_boundary(new_pos)

	# 计算目标节点实际移动的距离（考虑边界限制）
	var actual_delta = clamped_pos - _target_start_pos

	if smooth_factor > 0:
		# 平滑移动
		_target.global_position = _target.global_position.lerp(clamped_pos, smooth_factor)
	else:
		_target.global_position = clamped_pos

	# 如果 DragHandle 不是 target 的子孙节点，需要同步移动自身
	# 这样可以确保手柄始终跟随目标节点移动
	if not _is_descendant_of_target():
		var handle_new_pos = _handle_start_pos + actual_delta
		if smooth_factor > 0:
			global_position = global_position.lerp(handle_new_pos, smooth_factor)
		else:
			global_position = handle_new_pos

	drag_moved.emit(_target.global_position)


## 应用边界限制并返回限制后的位置
func _apply_boundary(pos: Vector2) -> Vector2:
	match boundary_mode:
		BoundaryMode.SCREEN:
			var viewport_rect = get_viewport_rect()
			return pos.clamp(Vector2.ZERO, viewport_rect.size - _target.size)

		BoundaryMode.CUSTOM_RECT:
			var min_pos = boundary_rect.position
			var max_pos = boundary_rect.end - _target.size
			return pos.clamp(min_pos, max_pos)

		BoundaryMode.PARENT_CONTAINER:
			var parent = _target.get_parent()
			if parent and parent is Control:
				return pos.clamp(Vector2.ZERO, parent.size - _target.size)
			return pos

		BoundaryMode.NONE:
			return pos

		_:
			return pos


func _on_mouse_entered() -> void:
	if draggable:
		mouse_default_cursor_shape = hover_cursor


func _on_mouse_exited() -> void:
	if not _dragging:
		mouse_default_cursor_shape = Control.CURSOR_ARROW


## 应用拖拽进入效果
func _apply_drag_enter_effect() -> void:
	if not is_inside_tree() or not _visual_node:
		return

	if _tween and _tween.is_valid():
		_tween.kill()

	# 先确保 scale 为起始值，再设置 pivot_offset
	# 避免 scale != 1 时改变 pivot 导致位置跳变
	_visual_node.scale = _visual_start_scale
	_visual_node.pivot_offset = _visual_node.size / 2.0

	_tween = create_tween()
	_tween.set_parallel(true)

	# 缩放效果
	_tween.tween_property(_visual_node, "scale", Vector2(drag_scale, drag_scale), 0.15)

	# 透明度效果
	if drag_opacity < 1.0:
		_visual_node.modulate = _visual_start_modulate
		_tween.tween_property(_visual_node, "modulate:a", drag_opacity, 0.15)


## 应用拖拽退出效果（弹跳动画）
func _apply_drag_exit_effect() -> void:
	if not is_inside_tree() or not _visual_node:
		return

	if _tween and _tween.is_valid():
		_tween.kill()

	_visual_node.pivot_offset = _visual_node.size / 2.0
	_tween = create_tween()
	_tween.set_parallel(false)

	# 缩放回原始大小（bounce easing）
	_tween.tween_property(_visual_node, "scale", _visual_start_scale, 0.25)
	_tween.set_ease(Tween.EASE_OUT)
	_tween.set_trans(Tween.TRANS_BACK)

	# 恢复透明度
	if drag_opacity < 1.0:
		_tween.parallel()
		_tween.tween_property(_visual_node, "modulate:a", _visual_start_modulate.a, 0.15)

	_tween.tween_callback(_reset_visual_effect)


## 重置视觉效果
func _reset_visual_effect() -> void:
	if not is_inside_tree():
		return

	if _visual_node:
		_visual_node.scale = _visual_start_scale
		_visual_node.pivot_offset = Vector2.ZERO
		_visual_node.modulate = _visual_start_modulate


## 设置拖拽目标
func set_drag_target(target: Control) -> void:
	drag_target = target
	_update_target()


## 设置手柄颜色（用于可视化调试）
func set_handle_color(color: Color, alpha: float = 0.5) -> void:
	pass  # 透明设计，无可见手柄


## 设置手柄图标
func set_handle_icon(texture: Texture2D) -> void:
	pass  # 透明设计，无可见图标


## 设置手柄尺寸
func set_handle_size(size_value: Vector2) -> void:
	custom_minimum_size = size_value
	size = size_value


## 检查是否正在拖拽
func is_dragging() -> bool:
	return _dragging


## 设置边界矩形
func set_boundary_rect(rect: Rect2) -> void:
	boundary_rect = rect
	boundary_mode = BoundaryMode.CUSTOM_RECT


## 设置边界模式
func set_boundary_mode(mode: BoundaryMode) -> void:
	boundary_mode = mode


## 检查 DragHandle 是否是 target 的子孙节点
## 如果是，则 DragHandle 会自动跟随 target 移动（由于父子关系）
## 如果不是，则需要手动同步 DragHandle 的位置
func _is_descendant_of_target() -> bool:
	if not _target:
		return false

	var current = get_parent()
	while current:
		if current == _target:
			return true
		# CanvasLayer 会打断变换继承链，视为非子孙关系
		if current is CanvasLayer:
			return false
		current = current.get_parent()
	return false
