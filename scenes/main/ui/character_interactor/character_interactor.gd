extends Control
var cnt:int=0;
func _on_button_pressed() -> void:
	cnt+=1;
	if cnt==3:
		CharacterInteractorState.notify_interacted()
		cnt=0;
