extends Control

@export var task_item:PackedScene
@onready var v_box_container: VBoxContainer = $PanelContainer/VBoxContainer/ScrollContainer/VBoxContainer

func _ready() -> void:
	add_task(TaskData.create_example())
	

func add_task(task:TaskData) -> void:
	var t = task_item.instantiate() as TaskItem
	v_box_container.add_child(t)
	t.set_task(task)
	print("["+self.name+"]"+"Added a Task("+"id:"+str(task.id)+" title:"+task.title+")")
	#傻逼godot没有fstring


#TODO
func remove_task() -> void:
	pass

func get_tasks() -> void:
	pass


func _on_add_button_pressed() -> void:
	#TODO 如何设置具体数据
	add_task(TaskData.create_example())
