extends Control
@export var task:PackedScene
@onready var task_container=$TaskBar/TaskContainer
@onready var add_button=$AddButton
@onready var task_bar=$TaskBar

func _ready() -> void:
	add_task("1233321")
	
func add_task(_name:String):
	var t=task.instantiate() as SingleTask
	task_container.add_child(t)
	t.set_task_name(_name)
	print("add task:",_name)
	
func remove_task(_name:String):
	for c in task_container.get_children():
		c= c as SingleTask
		if c.get_task_name()==_name:
			c.remove()

func _on_add_button_pressed() -> void:
	add_task("请输入代办事项")
	task_bar.folded=false
	
