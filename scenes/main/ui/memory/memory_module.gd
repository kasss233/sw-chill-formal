class_name MemoryModule
extends MarginContainer

const GROUP_MEMORY_MODULE_SHELL := "memory_module_shell"

@export var memory: Control
@export var memory_immutable: Control
@export var canvas_layer: CanvasLayer
## 与 [method set_memory_tab] 同步选中态；可为空则仅切换 [member memory] / [member memory_immutable] 可见性。
@export var segmented_button: Control
## 供脚本侧开关面板时同步按钮态；建议绑定到 MemoryButton（MaterialToggleButton）。
@export var memory_button: MaterialToggleButton
@export var panel: FrostedPanel
var _模块已显示: bool = false
## 面板占渲染窗口比例（跨平台：手机/电脑都按视口尺寸自适配）。
@export var panel_size_ratio: Vector2 = Vector2(0.8, 0.8)

func _enter_tree() -> void:
	add_to_group(GROUP_MEMORY_MODULE_SHELL)


## [param short_term] 为 true 时显示短期记忆（index 0），否则长期记忆（index 1）。
func set_memory_tab(short_term: bool) -> void:
	if short_term:
		if is_instance_valid(memory):
			memory.visible = true
		if is_instance_valid(memory_immutable):
			memory_immutable.visible = false
		if is_instance_valid(segmented_button):
			segmented_button.set("selected_index", 0)
	else:
		if is_instance_valid(memory):
			memory.visible = false
		if is_instance_valid(memory_immutable):
			memory_immutable.visible = true
		if is_instance_valid(segmented_button):
			segmented_button.set("selected_index", 1)


func _on_material_segmented_button_segment_selected(index: int, _text: String) -> void:
	match index:
		0:
			memory.visible = true
			memory_immutable.visible = false
		1:
			memory.visible = false
			memory_immutable.visible = true


func _on_memory_button_state_changed(_old_state: int, new_state: int) -> void:
	if new_state == 0:
		hide_module()
	else:
		show_module()


func _ready() -> void:
	_layout_panel_to_viewport()
	# 启动阶段 panel.visible 可能受过渡/加载时序影响，先以按钮状态作为单一真实来源，避免“早期无效”。
	if is_instance_valid(memory_button):
		_模块已显示 = memory_button.current_state != 0
	else:
		_模块已显示 = false
	if _模块已显示:
		show_module()
	else:
		hide_module()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_layout_panel_to_viewport()


func _layout_panel_to_viewport() -> void:
	if not is_instance_valid(panel):
		return
	var viewport_size := get_viewport_rect().size
	var ratio := Vector2(
		clampf(panel_size_ratio.x, 0.1, 1.0),
		clampf(panel_size_ratio.y, 0.1, 1.0)
	)
	var target_size := viewport_size * ratio
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	panel.offset_left = -target_size.x * 0.5
	panel.offset_top = -target_size.y * 0.5
	panel.offset_right = target_size.x * 0.5
	panel.offset_bottom = target_size.y * 0.5
func show_module() -> void:
	if _模块已显示:
		return
	_模块已显示 = true
	if is_instance_valid(canvas_layer):
		LayerManager.bring_to_front(canvas_layer)
	GuiTransitions.show("memory")
	if is_instance_valid(memory_button):
		memory_button.set_state_no_signal(1)

func hide_module() -> void:
	if not _模块已显示:
		return
	_模块已显示 = false
	GuiTransitions.hide("memory")
	if is_instance_valid(memory_button):
		memory_button.set_state_no_signal(0)
