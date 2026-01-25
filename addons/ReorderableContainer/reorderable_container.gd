@tool
@icon("Icon/reorderable_container_icon.svg")
class_name ReorderableContainer
extends Container
## A container that allows its child to be reorder and arranges horizontally or vertically.
##
## A container similar to [BoxContainer] but extended with drag-and-drop style reordering functionality, 
## and auto-scroll functionality when placed under [ScrollContainer].[br][br]
## [b]Note:[/b] This addon also works with SmoothScroll by SpyrexDE.
##
## @tutorial(SmoothScroll): https://github.com/SpyrexDE/SmoothScroll
## @tutorial(Using Containers): https://docs.godotengine.org/en/4.1/tutorials/ui/gui_containers.html

## Emitted when children have been reordered.
signal reordered(from: int, to: int)

## Emitted when drag starts.
signal drag_started(child: Control)

## Emitted when drag ends.
signal drag_ended(child: Control)

## Extend the drop zone length at the start and end of the container. 
## This will ensure that drop input is recognized even outside the container itself.
const DROP_ZONE_EXTEND = 2000

## The hold duration time in seconds before the holded child will start being drag.
@export 
var hold_duration := 0.5

## The overall speed of how fast children will move and arrange.
@export_range(3, 30, 0.01, "or_greater", "or_less")
var speed := 10.0

## The space between the container's elements, in pixels.
@export 
var separation := 10: set = set_separation
func set_separation(value):
	if value == separation or value < 0:
		return
	separation = value
	_on_sort_children()


## if [code]true[/code] the container will arrange its children vertically, rather than horizontally.
@export var is_vertical := false: set = set_vertical
func set_vertical(value):
	if value == is_vertical:
		return
	is_vertical = value
	if is_vertical:
		custom_minimum_size.x = 0
	else:
		custom_minimum_size.y = 0
	_on_sort_children()

## (Optional) [ScrollContainer] refference. Normally, the addon will automatically check 
## its parent node for [ScrollContainer]. If this is not the case, you can manually specify it here.
@export
var scroll_container: ScrollContainer

## The maximum speed of auto scroll.
@export 
var auto_scroll_speed := 10.0

## The pacentage of how much space auto scroll will take in [ScrollContainer][br][br]
## [b]Example:[/b] If [code]auto_scroll_range[/code] is 30% (0.3) and [ScrollContainer] height is 100 px, 
## upper part will be 0 to 30 px and lower part will be 70 to 100 px.
@export_range(0, 0.5) 
var auto_scroll_range := 0.3

## The scrolling threshold in pixel. In a nutshell, user will have hard time trying to drag a child if it too low
## and user will accidentally drag a child when scrolling if it too high.
@export 
var scroll_threshold := 30

## Uses when debugging
@export
var is_debugging := false

var _scroll_starting_point := 0
var _is_smooth_scroll := false

var _drop_zones: Array[Rect2] = []
var _drop_zone_index := -1
var _expect_child_rect: Array[Rect2] = []

var _focus_child: Control
var _is_press := false
var _is_hold := false
var _current_duration := 0.0
var _is_using_process := false

# Store original mouse_filter settings during drag
var _saved_mouse_filters: Dictionary = {}

# Store original scroll settings for SmoothScrollContainer
var _original_allow_horizontal_scroll := true
var _original_allow_vertical_scroll := true


func _ready():
	if scroll_container == null and get_parent() is ScrollContainer:
		scroll_container = get_parent()
		
	if scroll_container != null and scroll_container.has_method("handle_overdrag"):
		_is_smooth_scroll = true
		# Store original scroll settings
		if scroll_container.has_method("get"):
			_original_allow_horizontal_scroll = scroll_container.get("allow_horizontal_scroll")
			_original_allow_vertical_scroll = scroll_container.get("allow_vertical_scroll")
		# Connect signals to disable/enable scrolling during drag
		if not drag_started.is_connected(_on_drag_started_disable_scroll):
			drag_started.connect(_on_drag_started_disable_scroll)
		if not drag_ended.is_connected(_on_drag_ended_enable_scroll):
			drag_ended.connect(_on_drag_ended_enable_scroll)
	
	process_mode = Node.PROCESS_MODE_PAUSABLE
	_adjust_expected_child_rect()
	if not sort_children.is_connected(_on_sort_children):
		sort_children.connect(_on_sort_children, CONNECT_PERSIST)
	if not get_tree().node_added.is_connected(_on_node_added):
		get_tree().node_added.connect(_on_node_added, CONNECT_PERSIST)


func _gui_input(event):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		for _child in get_children():
			var child := _child as Control
			if child.get_rect().has_point(get_local_mouse_position()) and event.is_pressed():
				_focus_child = child
				_is_press = true
			elif not event.is_pressed():
				# Check if focused child is still valid and is still our child
				if _focus_child != null and (not is_instance_valid(_focus_child) or _focus_child.get_parent() != self):
					_focus_child = null
				_is_press = false
				_is_hold = false


func _process(delta):
	if Engine.is_editor_hint(): return	
	
	# Check if focused child is still valid and is still a child of this container
	if _focus_child != null and (not is_instance_valid(_focus_child) or _focus_child.get_parent() != self):
		_focus_child = null
		_is_press = false
		_is_hold = false
		_current_duration = 0.0
		_drop_zone_index = -1
		_is_using_process = false
		_saved_mouse_filters.clear()
	
	_handle_input(delta)
	if _current_duration >= hold_duration != _is_hold:
		_is_hold = _current_duration >= hold_duration
		if _is_hold:
			_on_start_dragging()
	
	if _is_hold:
		_handle_dragging_child_pos(delta)
		if scroll_container != null:
			_handle_auto_scroll(delta)
	elif not _is_hold and _drop_zone_index != -1:
		_on_stop_dragging()
			
	if _is_using_process :
		_on_sort_children(delta)


func _handle_input(delta): 
	if scroll_container != null and _is_press and not _is_hold:
		var scroll_point = scroll_container.scroll_vertical if is_vertical else scroll_container.scroll_horizontal
		if _current_duration == 0:
			_scroll_starting_point = scroll_point
		else:
			# If user scroll more than scroll_threshold, press is abort.
			_is_press = true if abs(scroll_point - _scroll_starting_point) <= scroll_threshold else false
	_current_duration = _current_duration + delta if _is_press else 0.0


func _on_start_dragging():
	if _focus_child == null or not is_instance_valid(_focus_child) or _focus_child.get_parent() != self:
		_focus_child = null
		_is_press = false
		_is_hold = false
		return
	
	# Force _on_sort_children to use process update for linear interpolation
	_is_using_process = true 
	_focus_child.z_index = 1
	# Workaround for SmoothScroll addon
	if _is_smooth_scroll:
		scroll_container.process_mode = Node.PROCESS_MODE_DISABLED
	
	# Save original mouse_filter states and set to IGNORE
	_saved_mouse_filters.clear()
	for child in _get_visible_children():
		_save_and_set_mouse_filter(child, MOUSE_FILTER_IGNORE)
	
	drag_started.emit(_focus_child)


func _on_stop_dragging():
	if _focus_child == null or not is_instance_valid(_focus_child) or _focus_child.get_parent() != self:
		_focus_child = null
		_drop_zone_index = -1
		_is_using_process = false
		return
	
	_focus_child.z_index = 0
	var focus_child_index := _focus_child.get_index()
	var dragged_child = _focus_child
	move_child(_focus_child, _drop_zone_index)
	reordered.emit(focus_child_index, _drop_zone_index)
	drag_ended.emit(dragged_child)
	_focus_child = null
	_drop_zone_index = -1
	if _is_smooth_scroll:
		scroll_container.pos = -Vector2(scroll_container.scroll_horizontal, scroll_container.scroll_vertical)
		scroll_container.process_mode = Node.PROCESS_MODE_INHERIT
	
	# Restore original mouse_filter states
	for child in _get_visible_children():
		_restore_mouse_filter(child)
	_saved_mouse_filters.clear()
	
	# Note: _is_using_process will be set to false by _adjust_child_rect()
	# once animation completes	


func _on_node_added(node):
	if node is Control and not Engine.is_editor_hint():
		node.mouse_filter = Control.MOUSE_FILTER_PASS


func _handle_dragging_child_pos(delta):
	if _focus_child == null or not is_instance_valid(_focus_child) or _focus_child.get_parent() != self:
		_focus_child = null
		_is_hold = false
		return
	
	if is_vertical:
		var target_pos = get_local_mouse_position().y - (_focus_child.size.y / 2.0)
		_focus_child.position.y = lerp(_focus_child.position.y, target_pos, delta * speed)
	else:
		var target_pos = get_local_mouse_position().x - (_focus_child.size.x / 2.0)
		_focus_child.position.x = lerp(_focus_child.position.x, target_pos, delta * speed)	
		
	# Update drop zone index
	var child_center_pos: Vector2 = _focus_child.get_rect().get_center()
	for i in range(_drop_zones.size()):
		var drop_zone = _drop_zones[i]
		if drop_zone.has_point(child_center_pos):
			_drop_zone_index = i
			break
		elif i == _drop_zones.size() - 1:
			_drop_zone_index = -1	


func _handle_auto_scroll(delta):
	var mouse_g_pos = get_global_mouse_position()
	var scroll_g_rect = scroll_container.get_global_rect()
	if is_vertical:
		var upper = scroll_g_rect.position.y + (scroll_g_rect.size.y * auto_scroll_range)
		var lower = scroll_g_rect.position.y + (scroll_g_rect.size.y * (1.0 - auto_scroll_range))
		
		if upper > mouse_g_pos.y:
			var factor = (upper - mouse_g_pos.y) / (upper - scroll_g_rect.position.y)
			scroll_container.scroll_vertical -= delta * float(auto_scroll_speed) * 150.0 * factor
		elif lower < mouse_g_pos.y:
			var factor = (mouse_g_pos.y - lower) / (scroll_g_rect.end.y - lower)
			scroll_container.scroll_vertical += delta * float(auto_scroll_speed) * 150.0 * factor
		else:
			scroll_container.scroll_vertical = scroll_container.scroll_vertical
	else:
		var left = scroll_g_rect.position.x + (scroll_g_rect.size.x * auto_scroll_range)
		var right = scroll_g_rect.position.x + (scroll_g_rect.size.x * (1.0 - auto_scroll_range))
		
		if left > mouse_g_pos.x:
			var factor = (left - mouse_g_pos.x) / (left - scroll_g_rect.position.x)
			scroll_container.scroll_horizontal -= delta * float(auto_scroll_speed) * 150.0 * factor
		elif right < mouse_g_pos.x:
			var factor = (mouse_g_pos.x - right) / (scroll_g_rect.end.x - right)
			scroll_container.scroll_horizontal += delta * float(auto_scroll_speed) * 150.0 * factor
		else:
			scroll_container.scroll_horizontal = scroll_container.scroll_horizontal		


func _on_sort_children(delta := -1.0):
	# When using process mode for animation (during drag):
	# - Signal-triggered calls (delta == -1.0) update target positions but don't apply them
	# - The animation is handled by _process() calling this with a valid delta
	# This allows animated response to: size changes, child additions, window resize, etc.
	if _is_using_process and delta == -1.0:
		_adjust_expected_child_rect()
		_adjust_drop_zone_rect()
		return
	
	_adjust_expected_child_rect()
	_adjust_child_rect(delta)
	_adjust_drop_zone_rect()


func _adjust_expected_child_rect():
	_expect_child_rect.clear()
	var children := _get_visible_children()
	var end_point = 0.0
	for i in range(children.size()):
		var child := children[i]
		var min_size := child.get_combined_minimum_size()
		if is_vertical:
			if i == _drop_zone_index and _focus_child != null and is_instance_valid(_focus_child):
				end_point += _focus_child.size.y + separation
			
			_expect_child_rect.append(Rect2(Vector2(0, end_point), Vector2(size.x, min_size.y)))
			end_point += min_size.y + separation
		else:
			if i == _drop_zone_index and _focus_child != null and is_instance_valid(_focus_child):
				end_point += _focus_child.size.x + separation
			
			_expect_child_rect.append(Rect2(Vector2(end_point, 0), Vector2(min_size.x, size.y)))
			end_point += min_size.x + separation
			

func _adjust_child_rect(delta: float = -1.0):
	var children := _get_visible_children()
	if children.is_empty():
		return
	
	var is_animating := false
	var end_point := 0.0
	for i in range(children.size()):
		var child := children[i]
		if child.position == _expect_child_rect[i].position and child.size == _expect_child_rect[i].size:
			continue
		
		if _is_using_process:
			var distance = (child.position - _expect_child_rect[i].position).length()
			if distance > 0.5:  # More lenient threshold for animation completion
				is_animating = true
				child.position = lerp(child.position, _expect_child_rect[i].position, delta * speed)
			else:
				# Close enough, snap to final position
				child.position = _expect_child_rect[i].position
			child.size = _expect_child_rect[i].size
		else:
			child.position = _expect_child_rect[i].position
			child.size = _expect_child_rect[i].size
	
	var last_child := children[-1]
	if is_vertical:
		if _is_using_process and _drop_zone_index == children.size() and _focus_child != null and is_instance_valid(_focus_child):
			# 拖拽到末尾时，需要额外空间给被拖拽的子节点
			custom_minimum_size.y = _expect_child_rect[-1].end.y + _focus_child.size.y + separation
		else:
			# 程序化重排序或非动画模式时，使用最后一个子节点的实际位置
			custom_minimum_size.y = last_child.get_rect().end.y
	else:
		if _is_using_process and _drop_zone_index == children.size() and _focus_child != null and is_instance_valid(_focus_child):
			custom_minimum_size.x = _expect_child_rect[-1].end.x + _focus_child.size.x + separation
		else:
			custom_minimum_size.x = last_child.get_rect().end.x

	# Adjust rect every process frame until child is dropped and finished lerping 
	# ( return to adjust when sort_children signal is emitted)
	if not is_animating and _focus_child == null:
		_is_using_process = false


func _adjust_drop_zone_rect():
	_drop_zones.clear()
	var children = _get_visible_children()
	for i in range(children.size()):
		var drop_zone_rect: Rect2
		var child := children[i] as Control
		if is_vertical:
			if i == 0:
				# First child
				drop_zone_rect.position = Vector2(child.position.x, child.position.y - DROP_ZONE_EXTEND)
				drop_zone_rect.end = Vector2(child.size.x, child.get_rect().get_center().y)
				_drop_zones.append(drop_zone_rect)
			else:
				# In between
				var prev_child := children[i - 1] as Control
				drop_zone_rect.position = Vector2(prev_child.position.x, prev_child.get_rect().get_center().y)
				drop_zone_rect.end = Vector2(child.size.x, child.get_rect().get_center().y)
				_drop_zones.append(drop_zone_rect)
			if i == children.size() - 1:
				# Is also last child
				drop_zone_rect.position = Vector2(child.position.x, child.get_rect().get_center().y)
				drop_zone_rect.end = Vector2(child.size.x, child.get_rect().end.y + DROP_ZONE_EXTEND)
				_drop_zones.append(drop_zone_rect)
		else:
			if i == 0:
				# First child
				drop_zone_rect.position = Vector2(child.position.x - DROP_ZONE_EXTEND, child.position.y)
				drop_zone_rect.end = Vector2(child.get_rect().get_center().x, child.size.y)
				_drop_zones.append(drop_zone_rect)
			else:
				# In between
				var prev_child := children[i - 1] as Control
				drop_zone_rect.position = Vector2(prev_child.get_rect().get_center().x, prev_child.position.y)
				drop_zone_rect.end = Vector2(child.get_rect().get_center().x, child.size.y)
				_drop_zones.append(drop_zone_rect)
			if i == children.size() - 1:
				# Is also last child
				drop_zone_rect.position = Vector2(child.get_rect().get_center().x, child.position.y)
				drop_zone_rect.end = Vector2(child.get_rect().end.x + DROP_ZONE_EXTEND, child.size.y)
				_drop_zones.append(drop_zone_rect)


func _get_visible_children() -> Array[Control]:
	var visible_control: Array[Control]
	for _child in get_children():
		var child := _child as Control
		if not child.visible:
			continue
		if child == _focus_child and _is_hold and is_instance_valid(_focus_child):
			continue
		
		visible_control.append(child)
	return visible_control


func _print_debug(val):
	if is_debugging:
		print(val)


## Recursively save mouse_filter state and set to new value
func _save_and_set_mouse_filter(node: Node, new_filter: int) -> void:
	if node is Control:
		var control = node as Control
		_saved_mouse_filters[control] = control.mouse_filter
		control.mouse_filter = new_filter
	
	for child in node.get_children():
		_save_and_set_mouse_filter(child, new_filter)


## Recursively restore mouse_filter state
func _restore_mouse_filter(node: Node) -> void:
	if node is Control:
		var control = node as Control
		if _saved_mouse_filters.has(control):
			control.mouse_filter = _saved_mouse_filters[control]
	
	for child in node.get_children():
		_restore_mouse_filter(child)


## Called when drag starts to disable SmoothScrollContainer scrolling
func _on_drag_started_disable_scroll(child: Control):
	if _is_smooth_scroll and scroll_container != null:
		scroll_container.set("allow_horizontal_scroll", false)
		scroll_container.set("allow_vertical_scroll", false)


## Called when drag ends to restore SmoothScrollContainer scrolling
func _on_drag_ended_enable_scroll(child: Control):
	if _is_smooth_scroll and scroll_container != null:
		scroll_container.set("allow_horizontal_scroll", _original_allow_horizontal_scroll)
		scroll_container.set("allow_vertical_scroll", _original_allow_vertical_scroll)


## 同步 SmoothScrollContainer 的 pos 状态
## 用于程序化重排序后保持滑动功能正常
func _sync_smooth_scroll_pos() -> void:
	if _is_smooth_scroll and scroll_container != null:
		# 延迟同步，确保布局已经更新
		call_deferred("_do_sync_smooth_scroll_pos")


## 实际执行 SmoothScrollContainer 的 pos 同步
func _do_sync_smooth_scroll_pos() -> void:
	if scroll_container != null and is_instance_valid(scroll_container):
		scroll_container.pos = -Vector2(scroll_container.scroll_horizontal, scroll_container.scroll_vertical)


## Programmatically reorder a child from one index to another.
## This achieves the same result as manual drag-and-drop but through code.
## [br][br]
## [param from_index]: The current index of the child to move (0-based, among visible children).
## [param to_index]: The target index to move the child to (0-based).
## [param animate]: If [code]true[/code], the reordering will be animated. Default is [code]true[/code].
## [br][br]
## Returns [code]true[/code] if the reorder was successful, [code]false[/code] otherwise.
func reorder_child_by_index(from_index: int, to_index: int, animate: bool = true) -> bool:
	# Get children without excluding any (since we're not dragging)
	var children: Array[Control] = []
	for _child in get_children():
		var c := _child as Control
		if c != null and c.visible:
			children.append(c)

	# Validate indices
	if from_index < 0 or from_index >= children.size():
		push_warning("ReorderableContainer: from_index %d is out of range (0-%d)" % [from_index, children.size() - 1])
		return false
	if to_index < 0 or to_index > children.size():
		push_warning("ReorderableContainer: to_index %d is out of range (0-%d)" % [to_index, children.size()])
		return false
	if from_index == to_index:
		return true  # No change needed

	var child := children[from_index]

	if animate:
		# Enable process mode for animation
		_is_using_process = true

	# Use the Node's move_child method (not Container's)
	(self as Node).move_child(child, to_index)
	reordered.emit(from_index, to_index)

	if not animate:
		_on_sort_children()

	# 同步 SmoothScrollContainer 的 pos 状态，防止滑动失效
	_sync_smooth_scroll_pos()

	return true


## Programmatically reorder a specific child control to a new index.
## [br][br]
## [param child]: The child control to move.
## [param to_index]: The target index to move the child to (0-based).
## [param animate]: If [code]true[/code], the reordering will be animated. Default is [code]true[/code].
## [br][br]
## Returns [code]true[/code] if the reorder was successful, [code]false[/code] otherwise.
func reorder_child_to(child: Control, to_index: int, animate: bool = true) -> bool:
	if child == null or not is_instance_valid(child) or child.get_parent() != self:
		push_warning("ReorderableContainer: Invalid child control")
		return false
	
	# Get children without excluding any
	var children: Array[Control] = []
	for _child in get_children():
		var c := _child as Control
		if c != null and c.visible:
			children.append(c)
	
	var from_index := children.find(child)
	
	if from_index == -1:
		push_warning("ReorderableContainer: Child not found among visible children")
		return false
	
	return reorder_child_by_index(from_index, to_index, animate)


## Swap two children at the given indices.
## [br][br]
## [param index_a]: The index of the first child (0-based, among visible children).
## [param index_b]: The index of the second child (0-based, among visible children).
## [param animate]: If [code]true[/code], the swap will be animated. Default is [code]true[/code].
## [br][br]
## Returns [code]true[/code] if the swap was successful, [code]false[/code] otherwise.
func swap_children_at(index_a: int, index_b: int, animate: bool = true) -> bool:
	# Get children without excluding any
	var children: Array[Control] = []
	for _child in get_children():
		var c := _child as Control
		if c != null and c.visible:
			children.append(c)

	# Validate indices
	if index_a < 0 or index_a >= children.size():
		push_warning("ReorderableContainer: index_a %d is out of range (0-%d)" % [index_a, children.size() - 1])
		return false
	if index_b < 0 or index_b >= children.size():
		push_warning("ReorderableContainer: index_b %d is out of range (0-%d)" % [index_b, children.size() - 1])
		return false
	if index_a == index_b:
		return true  # No change needed

	# Ensure index_a < index_b for consistent behavior
	if index_a > index_b:
		var temp := index_a
		index_a = index_b
		index_b = temp

	var child_a := children[index_a]
	var child_b := children[index_b]

	if animate:
		_is_using_process = true

	# Move child_b to index_a first, then child_a to index_b
	(self as Node).move_child(child_b, index_a)
	(self as Node).move_child(child_a, index_b)

	reordered.emit(index_a, index_b)

	if not animate:
		_on_sort_children()

	# 同步 SmoothScrollContainer 的 pos 状态，防止滑动失效
	_sync_smooth_scroll_pos()

	return true


## Move a child to the first position (index 0).
## [br][br]
## [param child]: The child control to move to the beginning.
## [param animate]: If [code]true[/code], the movement will be animated. Default is [code]true[/code].
## [br][br]
## Returns [code]true[/code] if successful, [code]false[/code] otherwise.
func move_child_to_front(child: Control, animate: bool = true) -> bool:
	return reorder_child_to(child, 0, animate)


## Move a child to the last position.
## [br][br]
## [param child]: The child control to move to the end.
## [param animate]: If [code]true[/code], the movement will be animated. Default is [code]true[/code].
## [br][br]
## Returns [code]true[/code] if successful, [code]false[/code] otherwise.
func move_child_to_back(child: Control, animate: bool = true) -> bool:
	# Get children without excluding any
	var children: Array[Control] = []
	for _child in get_children():
		var c := _child as Control
		if c != null and c.visible:
			children.append(c)
	return reorder_child_to(child, children.size(), animate)
