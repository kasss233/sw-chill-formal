extends Node3D

@onready var label=$Label3D

func _process(_delta):
	var t = Time.get_datetime_dict_from_system()
	label.text = "%02d:%02d" % [
		t.hour,
		t.minute
	]
