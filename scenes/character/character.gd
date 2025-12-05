extends Node3D
@export var emotion_animation:AnimationPlayer
@export var action_animation:AnimationPlayer
@export var face:MeshInstance3D
func saying():
	emotion_animation.play("saying")
func typing():
	action_animation.play("Sitting/typing")
func reset_emotion():
	emotion_animation.play("RESET")
func stop_action():
	action_animation.stop()
	
