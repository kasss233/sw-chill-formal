class_name Character
extends Node3D
@export var emotion_animation: AnimationPlayer
@export var action_animation: AnimationPlayer
@export var action_tree: AnimationTree
@export var emotion_tree: AnimationTree
@export var typing: bool = false
@export var happy: bool = false
@export var saying:bool=false
@export var sad:bool=true
@export var surprised:bool=true
@export var angry:bool=true
var action_playback: AnimationNodeStateMachinePlayback
func _ready() -> void:
	action_tree.active = true
	action_playback = action_tree.get("parameters/playback")
## 对话接口
func start_saying():
	saying=true
func stop_saying():
	saying=false
	
## 动作接口
func set_typing_pose(_typing: bool):
	typing = _typing
func set_watch_pose():
	action_playback.travel("pose_1")
func set_cheer_pose():
	action_playback.travel("cheer")
func set_disbelief_pose():
	action_playback.travel("disbelief")
func set_dodge_pose():
	action_playback.travel("dodge")
func set_angry_pose():
	action_playback.travel("angry")
func set_clap_pose():
	action_playback.travel("clap")
func set_laughing_pose():
	action_playback.travel("laughing")
## 表情接口
func set_happy(enable:bool):
	happy=enable
func set_sad(enable:bool):
	sad=enable
func set_surprised(enable:bool):
	surprised=enable
func set_angry(enable:bool):
	angry=enable
