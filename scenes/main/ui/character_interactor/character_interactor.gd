extends Control
var cnt:int=0;
signal character_interacted
func _on_button_pressed() -> void:
	cnt+=1;
	if cnt==3:
		emit_signal("character_interacted")
		cnt=0;
