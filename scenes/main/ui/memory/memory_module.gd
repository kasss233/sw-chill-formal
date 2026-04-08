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
func show_module() -> void:
	if not panel.visible:
		LayerManager.bring_to_front(canvas_layer)
		GuiTransitions.show("memory")
		memory_button.set_state_no_signal(1)

func hide_module() -> void:
	if panel.visible:
		GuiTransitions.hide("memory")
		memory_button.set_state_no_signal(0)
