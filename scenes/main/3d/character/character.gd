extends Node3D
@export var emotion_animation: AnimationPlayer
@export var action_animation: AnimationPlayer
@export var face: MeshInstance3D
@export var action_tree: AnimationTree
@export var emotion_tree: AnimationTree
@export var typing: bool = false
@export var happy: bool = false
@export var saying:bool=false
@export var sad:bool=true
@export var surprised:bool=true
var action_playback: AnimationNodeStateMachinePlayback
func _ready() -> void:
	action_tree.active = true
	action_playback = action_tree.get("parameters/playback")
	set_dodge()
func start_saying():
	saying=true
func stop_saying():
	saying=false
func set_typing(_typing: bool):
	typing = _typing
func set_pose_watch():
	action_playback.travel("pose_1")
func set_cheer():
	action_playback.travel("cheer")
func set_disbelief():
	action_playback.travel("disbelief")
func set_dodge():
	action_playback.travel("dodge")
func set_happy(enable:bool):
	happy=enable
func set_sad(enable:bool):
	sad=enable
func set_surprised(enable:bool):
	surprised=enable
