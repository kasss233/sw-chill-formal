extends Node3D
@export var emotion_animation:AnimationPlayer
@export var action_animation:AnimationPlayer
@export var face:MeshInstance3D
@export var animation_tree:AnimationTree
@export var  typing:bool=false
func start_saying():
	emotion_animation.play("saying")
func stop_saying():
	emotion_animation.play("RESET")
func set_typing(_typing:bool):
	typing=_typing
	
