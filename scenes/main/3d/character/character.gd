@tool
class_name Character
extends Node3D
@export var action_tree: AnimationTree
@export var emotion_tree: AnimationTree

## 运行时：idle 时随机做一些一次性小动作（不包含 typing）
@export var idle_variation_enabled: bool = true
@export_range(1.0, 60.0, 0.5) var idle_variation_min_delay_sec: float = 6.0
@export_range(1.0, 60.0, 0.5) var idle_variation_max_delay_sec: float = 18.0

## 运行时：随机眨眼（避免打断持续表情，默认只在 neutral 时眨眼）
@export var blinking_enabled: bool = true
@export_range(0.5, 60.0, 0.5) var blinking_min_delay_sec: float = 3.0
@export_range(0.5, 60.0, 0.5) var blinking_max_delay_sec: float = 8.0
@export var blinking_only_when_neutral: bool = true

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

var _last_action_node: StringName = &""
var _idle_variation_token: int = 0
var _idle_variation_scheduled: bool = false
var _last_idle_variation: StringName = &""

var _blinking_token: int = 0
var _blinking_scheduled: bool = false

func _ready() -> void:
	if action_tree:
		action_tree.active = true
		action_playback = action_tree.get("parameters/playback")
	if emotion_tree:
		emotion_tree.active = true
		emotion_playback = emotion_tree.get("parameters/playback")

	if Engine.is_editor_hint():
		set_process(false)
		return

	randomize()
	set_process(true)
	# 初始化一次当前动作节点，避免刚启动时误触发
	_last_action_node = _get_current_action_node()
	if _last_action_node == &"idle":
		_schedule_idle_variation()
	_schedule_blinking()


func _process(_delta: float) -> void:
	if Engine.is_editor_hint() or not idle_variation_enabled:
		return
	if not action_playback:
		return

	var current_node := _get_current_action_node()
	if current_node == _last_action_node:
		return

	_last_action_node = current_node
	if current_node == &"idle":
		_schedule_idle_variation()
	else:
		_cancel_idle_variation()


func _get_current_action_node() -> StringName:
	if not action_playback:
		return &""
	return action_playback.get_current_node()


func _get_current_emotion_node() -> StringName:
	if not emotion_playback:
		return &""
	return emotion_playback.get_current_node()


func _is_in_idle() -> bool:
	return _get_current_action_node() == &"idle"


func _cancel_idle_variation() -> void:
	_idle_variation_token += 1
	_idle_variation_scheduled = false


func _cancel_blinking() -> void:
	_blinking_token += 1
	_blinking_scheduled = false


func _schedule_blinking() -> void:
	if Engine.is_editor_hint() or not blinking_enabled:
		return
	if not emotion_playback:
		return
	if blinking_max_delay_sec < blinking_min_delay_sec:
		blinking_max_delay_sec = blinking_min_delay_sec
	if _blinking_scheduled:
		return

	_blinking_scheduled = true
	var token := _blinking_token + 1
	_blinking_token = token

	var delay_sec := randf_range(blinking_min_delay_sec, blinking_max_delay_sec)
	await get_tree().create_timer(delay_sec).timeout

	if not is_inside_tree():
		return
	if token != _blinking_token:
		return
	_blinking_scheduled = false

	if blinking_enabled and emotion_playback:
		if (not blinking_only_when_neutral) or (_get_current_emotion_node() == &"neutral"):
			set_blinking()

	# 循环调度下一次
	_schedule_blinking()


func _schedule_idle_variation() -> void:
	# 只在真正 idle 时调度；typing/其他动作时不调度
	if not _is_in_idle():
		return
	if idle_variation_max_delay_sec < idle_variation_min_delay_sec:
		# 容错：避免配置错误导致 randf_range 异常
		idle_variation_max_delay_sec = idle_variation_min_delay_sec
	if _idle_variation_scheduled:
		return

	_idle_variation_scheduled = true
	var token := _idle_variation_token + 1
	_idle_variation_token = token

	var delay_sec := randf_range(idle_variation_min_delay_sec, idle_variation_max_delay_sec)
	await get_tree().create_timer(delay_sec).timeout

	if token != _idle_variation_token:
		return
	_idle_variation_scheduled = false

	# 再次确认仍在 idle（若已切到 typing 或其它动作则放弃）
	if not _is_in_idle():
		return

	_trigger_random_idle_variation()


func _trigger_random_idle_variation() -> void:
	# 使用“重复项”做简单权重，让动作更自然
	var pool: Array[StringName] = [
		&"watch", &"watch",
		&"stretch", &"stretch",
		&"stretch2",
		&"think",
		#&"greet",
		#&"clap",
		#&"cheer",
		#&"surprised",
		#&"disbelief",
	]

	if pool.is_empty():
		return

	var picked: StringName = pool[randi() % pool.size()]
	# 避免连续重复同一个小动作
	var reroll := 0
	while picked == _last_idle_variation and reroll < 3:
		picked = pool[randi() % pool.size()]
		reroll += 1
	_last_idle_variation = picked

	match picked:
		&"watch":
			set_watch_pose()
		&"stretch":
			set_stretch_pose()
		&"stretch2":
			set_stretch2_pose()
		&"think":
			set_think_pose()
		&"greet":
			set_greet_pose()
		&"clap":
			set_clap_pose()
		&"cheer":
			set_cheer_pose()
		&"surprised":
			set_surprised_pose()
		&"disbelief":
			set_disbelief_pose()
		_:
			# 未知动作直接忽略
			pass
	
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
