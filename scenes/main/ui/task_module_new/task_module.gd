extends MarginContainer

@onready var task_module_new: MarginContainer = $CanvasLayer/TaskModuleNew

func _ready() -> void:
	task_module_new.visible = false

func _on_todo_button_state_changed(old_state: int, new_state: int) -> void:
	task_module_new.visible = !task_module_new.visible


# --- Agent API 转发方法 ---
## Agent API: 添加新任务（带动画）
func agent_add_task(title: String, due_timestamp: int = 0) -> int:
	return task_module_new.agent_add_task(title, due_timestamp)

## Agent API: 修改任务名称（模拟打字效果）
func agent_update_task_title(id: int, new_title: String, typing_speed: float = 0.05) -> bool:
	return await task_module_new.agent_update_task_title(id, new_title, typing_speed)

## Agent API: 标记任务完成状态
func agent_mark_task_completed(id: int, completed: bool) -> bool:
	return task_module_new.agent_mark_task_completed(id, completed)

## Agent API: 删除任务
func agent_remove_task(id: int) -> bool:
	return task_module_new.agent_remove_task(id)

## Agent API: 获取任务信息
func agent_get_task_info(id: int) -> Dictionary:
	return task_module_new.agent_get_task_info(id)

## Agent API: 获取所有任务信息
func agent_get_all_tasks() -> Array[Dictionary]:
	return task_module_new.agent_get_all_tasks()
