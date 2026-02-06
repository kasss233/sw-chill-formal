class_name TaskModule
extends MarginContainer

@onready var canvas_layer: CanvasLayer = $CanvasLayer
@onready var task_module_new: MarginContainer = $CanvasLayer/TaskModuleNew
@onready var todo_button: MaterialToggleButton = $TodoButton

# UI 引用（用于层级管理）
@export var _ui: UI = null

func _ready() -> void:
	task_module_new.visible = false
	# 设置 CanvasLayer 的初始层级
	canvas_layer.layer = 10


## 请求新的顶层层级
func _request_top_layer() -> void:
	if _ui:
		canvas_layer.layer = _ui.request_top_layer()
	else:
		# 降级方案：使用固定的高层级
		canvas_layer.layer = 100

func _on_todo_button_state_changed(old_state: int, new_state: int) -> void:
	if new_state==0:
		GuiTransitions.hide("task")
	else:
		# 请求新的顶层层级
		_request_top_layer()
		GuiTransitions.show("task")


# --- Agent API（纯 UI 操作） ---
func show_module():
	if todo_button.current_state==0:
		# 请求新的顶层层级
		_request_top_layer()
		GuiTransitions.show("task")
		todo_button.set_state_no_signal(1)

func hide_module():
	if todo_button.current_state==1:
		GuiTransitions.hide("task")
		todo_button.set_state_no_signal(0)

## Agent API: 添加新任务（带打字动画，纯 UI 行为）
func agent_add_task(title: String, due_timestamp: int = 0, typing_speed: float = 0.05) -> int:
	return await task_module_new.agent_add_task(title, due_timestamp, typing_speed)

## Agent API: 修改任务名称（模拟打字效果，纯 UI 行为）
func agent_update_task_title(id: int, new_title: String, typing_speed: float = 0.05) -> bool:
	return await task_module_new.agent_update_task_title(id, new_title, typing_speed)
