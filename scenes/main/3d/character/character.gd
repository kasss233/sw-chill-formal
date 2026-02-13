@tool
class_name Character
extends Node3D
@export var action_tree: AnimationTree
@export var emotion_tree: AnimationTree

## 编辑器测试工具
enum ActionTest {
	IDLE,
	TYPING,
	NOT_TYPING,
	CLAP,
	THINK,
	CHEER,
	WATCH,
	GREET,
	SURPRISED,
	DISBELIEF,
	STRETCH,
	STRETCH2
}

enum EmotionTest {
	NEUTRAL,
	HAPPY,
	SAD,
	SURPRISED,
	ANGRY,
	SAYING,
	BLINKING
}

@export var test_action: ActionTest = ActionTest.IDLE:
	set(value):
		test_action = value
		if Engine.is_editor_hint():
			_test_action(value)

@export var test_emotion: EmotionTest = EmotionTest.NEUTRAL:
	set(value):
		test_emotion = value
		if Engine.is_editor_hint():
			_test_emotion(value)
var action_playback: AnimationNodeStateMachinePlayback
var emotion_playback: AnimationNodeStateMachinePlayback
func _ready() -> void:
	if action_tree:
		action_tree.active = true
		action_playback = action_tree.get("parameters/playback")
	if emotion_tree:
		emotion_tree.active = true
		emotion_playback = emotion_tree.get("parameters/playback")
	
## 动作接口
func set_idle_pose():
	if action_playback:
		action_playback.travel("idle")
	set_neutral()
## typing一直循环，需要手动跳转到idle
func set_typing_pose():
	if action_playback:
		action_playback.travel("typing")
## 以下动作都是一次性动作，播放完会自动回到idle
func set_clap_pose():
	if action_playback:
		action_playback.travel("clap")
	set_happy()
func set_think_pose():
	if action_playback:
		action_playback.travel("think")
	set_angry()
func set_cheer_pose():
	if action_playback:
		action_playback.travel("cheer")
	set_happy()
func set_watch_pose():
	if action_playback:
		action_playback.travel("watch")
	set_neutral()
func set_greet_pose():
	if action_playback:
		action_playback.travel("greet")
	set_happy()
func set_surprised_pose():
	if action_playback:
		action_playback.travel("surprised")
	set_surprised()
func set_disbelief_pose():
	if action_playback:
		action_playback.travel("disbelief")
	set_sad()
func set_stretch_pose():
	if action_playback:
		action_playback.travel("stretch")
func set_stretch2_pose():
	if action_playback:
		action_playback.travel("stretch2")

## 表情接口
## blinking为一次性动作，播放完会自动回到neutral
func set_blinking():
	if emotion_playback:
		emotion_playback.travel("blinking")
## 以下表情都是持续表情，需要手动跳转到neutral
func set_neutral():
	if emotion_playback:
		emotion_playback.travel("neutral")
func set_happy():
	if emotion_playback:
		emotion_playback.travel("happy")
func set_sad():
	if emotion_playback:
		emotion_playback.travel("sad")
func set_surprised():
	if emotion_playback:
		emotion_playback.travel("surprised")
func set_angry():
	if emotion_playback:
		emotion_playback.travel("angry")
func set_saying():
	if emotion_playback:
		emotion_playback.travel("saying")

## 编辑器测试辅助函数
func _test_action(action: ActionTest):
	if not action_playback:
		_ready()
	if not action_playback:
		return
	
	match action:
		ActionTest.IDLE:
			set_idle_pose()
		ActionTest.TYPING:
			set_typing_pose()
		ActionTest.CLAP:
			set_clap_pose()
		ActionTest.THINK:
			set_think_pose()
		ActionTest.CHEER:
			set_cheer_pose()
		ActionTest.WATCH:
			set_watch_pose()
		ActionTest.GREET:
			set_greet_pose()
		ActionTest.SURPRISED:
			set_surprised_pose()
		ActionTest.DISBELIEF:
			set_disbelief_pose()
		ActionTest.STRETCH:
			set_stretch_pose()
		ActionTest.STRETCH2:
			set_stretch2_pose()

func _test_emotion(emotion: EmotionTest):
	if not emotion_playback:
		_ready()
	if not emotion_playback:
		return
	
	match emotion:
		EmotionTest.NEUTRAL:
			set_neutral()
		EmotionTest.HAPPY:
			set_happy()
		EmotionTest.SAD:
			set_sad()
		EmotionTest.SURPRISED:
			set_surprised()
		EmotionTest.ANGRY:
			set_angry()
		EmotionTest.SAYING:
			set_saying()
		EmotionTest.BLINKING:
			set_blinking()


func _on_action_animation_tree_animation_finished(anim_name: StringName) -> void:
	print("Action animation finished: ", anim_name)
	set_neutral()
