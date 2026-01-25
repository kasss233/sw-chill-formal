extends VBoxContainer
@export var times : int = 1;
# 左开右开区间
@export var uppper_bound : int = 100;
@export var lower_bound : int = 0;
# 步长
@export var step : int = 1;
@onready var rest_times_text = $times/VBoxContainer/rest_times_text;

func _ready() -> void:
	flush_times_text();
	pass

func flush_times_text() -> void:
	rest_times_text.text = str(times)
	pass

func _on_rest_times_add_pressed() -> void:
	if times >= uppper_bound:
		return;
	if times == lower_bound + 1:
		times = step;
	else:
		times += step;
	if times >= uppper_bound:
		times = uppper_bound - 1;
	times %= uppper_bound;
	flush_times_text();
	pass # Replace with function body.


func _on_rest_times_minus_pressed() -> void:
	if times <= lower_bound:
		return;
	times -= step;
	if times <= lower_bound:
		times = lower_bound + 1;
	times %= uppper_bound;
	flush_times_text();
	pass # Replace with function body.
