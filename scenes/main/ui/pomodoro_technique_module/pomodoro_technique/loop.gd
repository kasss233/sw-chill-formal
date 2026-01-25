extends HBoxContainer
@export var times : int = 1;
# 左开右开区间
@export var uppper_bound : int = 100;
@export var lower_bound : int = 0;
@onready var loop_time_text = $text/loop_time_text;

func _ready() -> void:
	flush_times_text();
	pass

func flush_times_text() -> void:
	loop_time_text.text = str(times)
	pass

func _on_loop_time_minus_pressed() -> void:
	if times <= lower_bound + 1:
		return;
	times -= 1;
	times %= uppper_bound;
	flush_times_text();
	pass # Replace with function body.


func _on_loop_time_add_pressed() -> void:
	if times >= uppper_bound - 1:
		return;
	times += 1;
	times %= uppper_bound;
	flush_times_text();
	pass # Replace with function body.
