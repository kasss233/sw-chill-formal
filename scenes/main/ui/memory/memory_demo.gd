extends Node

## 记忆模块快捷键演示：与 [MemoryModule] 原版打开方式一致（[method MemoryModule.open_memory_panel]），并驱动 [FrostedPanel] 外圈 AI glow。

const _GROUP_SHELL := "memory_module_shell"

var _忙碌中: bool = false
var _记忆模块缓存: MemoryModule = null


@export_group("绑定")
## 相对 **本节点** 的路径，常用 `..` 指向父级 [MemoryModule]。若为空则通过分组 `memory_module_shell` 查找。
@export var 记忆模块节点路径: NodePath = NodePath()

@export_group("通用快捷键")
@export var 快捷键需要按住Ctrl: bool = true

@export_group("演示1_长期_标题流光")
@export var 演示1_按键: Key = KEY_0
@export var 演示1_目标标题列表: PackedStringArray = PackedStringArray(["身份锚点（林小晴）", "性格与口吻来源"])
@export var 演示1_点亮前等待秒: float = 0.35
@export var 演示1_保持发光秒: float = 2.0
@export var 演示1_弹窗后等待秒: float = 0.35
@export var 演示1_标题列表逐项间隔秒: float = 0.08
@export var 演示1_结束时关闭窗口: bool = true
@export var 演示1_面板外圈亮起秒: float = 0.4
@export var 演示1_面板外圈熄灭秒: float = 0.6

@export_group("演示2_短期_新节点动画")
@export var 演示2_按键: Key = KEY_9
@export var 演示2_新节点标题: String = "演示 · 新短期记忆"
@export var 演示2_新节点正文: String = "由 MemoryDemo 快捷键演示添加。"
@export var 演示2_权重: float = 0.72
@export var 演示2_与中心连接: bool = true
@export var 演示2_可变: bool = true
@export var 演示2_落点归一化: Vector2 = Vector2(0.15, 0.22)
@export var 演示2_缩放动画时长秒: float = 0.65
## 横轴 0~1 对应时间进度；纵轴 0~1 映射为均匀缩放系数。留空则用 BACK 缓动近似回弹。
@export var 演示2_缩放曲线: Curve
@export var 演示2_入场初始缩放: float = 0.08
@export var 演示2_结束后等待秒: float = 1.2
@export var 演示2_弹窗后等待秒: float = 0.35
@export var 演示2_新增节点写入本地存档: bool = false
@export var 演示2_结束时关闭窗口: bool = true
@export var 演示2_面板外圈亮起秒: float = 0.4
@export var 演示2_面板外圈熄灭秒: float = 0.6

@export_group("演示3_长期_新节点与连线")
@export var 演示3_按键: Key = KEY_8
@export var 演示3_新节点标题: String = "演示 · 新长期记忆"
@export var 演示3_新节点正文: String = "与中心相连，并可与指定标题节点连线。"
@export var 演示3_权重: float = 0.8
@export var 演示3_与中心连接: bool = true
@export var 演示3_可变: bool = false
@export var 演示3_额外连线目标标题: PackedStringArray = PackedStringArray(["童年 · 学会自己待着"])
@export var 演示3_落点归一化: Vector2 = Vector2(0.82, 0.35)
@export var 演示3_缩放动画时长秒: float = 0.65
@export var 演示3_缩放曲线: Curve
@export var 演示3_入场初始缩放: float = 0.08
@export var 演示3_结束后等待秒: float = 1.2
@export var 演示3_弹窗后等待秒: float = 0.35
@export var 演示3_额外连线逐项间隔秒: float = 0.08
@export var 演示3_新增节点写入本地存档: bool = false
@export var 演示3_结束时关闭窗口: bool = true
@export var 演示3_面板外圈亮起秒: float = 0.4
@export var 演示3_面板外圈熄灭秒: float = 0.6


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var ek := event as InputEventKey
	if not ek.pressed or ek.echo:
		return
	if 快捷键需要按住Ctrl and not ek.ctrl_pressed:
		return
	if ek.keycode == 演示1_按键:
		get_viewport().set_input_as_handled()
		_开始演示1()
	elif ek.keycode == 演示2_按键:
		get_viewport().set_input_as_handled()
		_开始演示2()
	elif ek.keycode == 演示3_按键:
		get_viewport().set_input_as_handled()
		_开始演示3()


func _取得记忆模块() -> MemoryModule:
	if is_instance_valid(_记忆模块缓存):
		return _记忆模块缓存
	if not 记忆模块节点路径.is_empty():
		var n := get_node_or_null(记忆模块节点路径)
		if n is MemoryModule:
			_记忆模块缓存 = n as MemoryModule
			return _记忆模块缓存
	var g := get_tree().get_first_node_in_group(_GROUP_SHELL)
	if g is MemoryModule:
		_记忆模块缓存 = g as MemoryModule
		return _记忆模块缓存
	return null


func _取得磨砂面板(记忆模块: MemoryModule) -> FrostedPanel:
	var p := 记忆模块.get_node_or_null("CanvasLayer/FrostedPanel")
	return p as FrostedPanel


func _等待(秒: float) -> void:
	if 秒 <= 0.0:
		return
	await get_tree().create_timer(秒).timeout


func _开始演示1() -> void:
	if _忙碌中:
		return
	var 外壳 := _取得记忆模块()
	if 外壳 == null:
		push_warning("[MemoryDemo] 未找到 MemoryModule（请绑定路径或给根节点加分组 memory_module_shell）")
		return
	_忙碌中 = true
	外壳.open_memory_panel()
	外壳.set_memory_tab(false)
	await _等待(演示1_弹窗后等待秒)
	var 磨砂 := _取得磨砂面板(外壳)
	if 磨砂:
		磨砂.start_ai_glow(演示1_面板外圈亮起秒)
	await _等待(演示1_点亮前等待秒)
	var 长期 := 外壳.memory_immutable as MemoryModuleBase
	if 长期 == null:
		_忙碌中 = false
		return
	for 节点 in 长期.get_all_prompt_nodes():
		节点.set_demo_lit_override(true, false)
	for 标题 in 演示1_目标标题列表:
		var arr := 长期.find_prompt_nodes_by_titles(PackedStringArray([标题]))
		for 节点 in arr:
			节点.set_demo_lit_override(true, true)
		await _等待(演示1_标题列表逐项间隔秒)
	await _等待(演示1_保持发光秒)
	for 节点 in 长期.get_all_prompt_nodes():
		节点.clear_demo_lit_override()
	if 磨砂:
		磨砂.stop_ai_glow(演示1_面板外圈熄灭秒)
	if 演示1_结束时关闭窗口:
		外壳.close_memory_panel()
	_忙碌中 = false


func _开始演示2() -> void:
	if _忙碌中:
		return
	var 外壳 := _取得记忆模块()
	if 外壳 == null:
		push_warning("[MemoryDemo] 未找到 MemoryModule")
		return
	_忙碌中 = true
	外壳.open_memory_panel()
	外壳.set_memory_tab(true)
	await _等待(演示2_弹窗后等待秒)
	var 磨砂 := _取得磨砂面板(外壳)
	if 磨砂:
		磨砂.start_ai_glow(演示2_面板外圈亮起秒)
	var 短期 := 外壳.memory as MemoryModuleBase
	if 短期 == null:
		_忙碌中 = false
		return
	var 区域 := 短期.get_move_bounds_rect()
	var 估计半宽 := Vector2(140.0, 90.0)
	var 左上角 := 区域.position + Vector2(区域.size.x * 演示2_落点归一化.x, 区域.size.y * 演示2_落点归一化.y) - 估计半宽
	var 演示2已存在 := 短期.has_prompt_title(演示2_新节点标题)
	var 卡片: PromptMemoryNode = null
	if not 演示2已存在:
		卡片 = 短期.add_prompt_node_for_demo(
		演示2_新节点标题,
		演示2_新节点正文,
		演示2_权重,
		演示2_与中心连接,
		演示2_可变,
		左上角,
		false
	)
		await get_tree().process_frame
		await get_tree().process_frame
		短期.clamp_prompt_node_to_bounds(卡片)
		卡片.pivot_offset = 卡片.size * 0.5
		await _播放节点入场缩放(卡片, 演示2_入场初始缩放, 演示2_缩放动画时长秒, 演示2_缩放曲线)
	await _等待(演示2_结束后等待秒)
	if is_instance_valid(卡片) and not 演示2_新增节点写入本地存档:
		短期.remove_prompt_node_by_id(卡片.prompt_id)
	if 磨砂:
		磨砂.stop_ai_glow(演示2_面板外圈熄灭秒)
	if 演示2_结束时关闭窗口:
		外壳.close_memory_panel()
	_忙碌中 = false


func _开始演示3() -> void:
	if _忙碌中:
		return
	var 外壳 := _取得记忆模块()
	if 外壳 == null:
		push_warning("[MemoryDemo] 未找到 MemoryModule")
		return
	_忙碌中 = true
	外壳.open_memory_panel()
	外壳.set_memory_tab(false)
	await _等待(演示3_弹窗后等待秒)
	var 磨砂 := _取得磨砂面板(外壳)
	if 磨砂:
		磨砂.start_ai_glow(演示3_面板外圈亮起秒)
	var 长期 := 外壳.memory_immutable as MemoryModuleBase
	if 长期 == null:
		_忙碌中 = false
		return
	var 区域 := 长期.get_move_bounds_rect()
	var 估计半宽 := Vector2(140.0, 90.0)
	var 左上角 := 区域.position + Vector2(区域.size.x * 演示3_落点归一化.x, 区域.size.y * 演示3_落点归一化.y) - 估计半宽
	var 演示3已存在 := 长期.has_prompt_title(演示3_新节点标题)
	var 卡片: PromptMemoryNode = null
	if not 演示3已存在:
		卡片 = 长期.add_prompt_node_for_demo(
		演示3_新节点标题,
		演示3_新节点正文,
		演示3_权重,
		演示3_与中心连接,
		演示3_可变,
		左上角,
		false
	)
		var 新id := 卡片.prompt_id
		for 标题 in 演示3_额外连线目标标题:
			长期.add_inter_edges_from_new_node_by_titles(新id, PackedStringArray([标题]))
			await _等待(演示3_额外连线逐项间隔秒)
		await get_tree().process_frame
		await get_tree().process_frame
		长期.clamp_prompt_node_to_bounds(卡片)
		卡片.pivot_offset = 卡片.size * 0.5
		await _播放节点入场缩放(卡片, 演示3_入场初始缩放, 演示3_缩放动画时长秒, 演示3_缩放曲线)
	await _等待(演示3_结束后等待秒)
	if is_instance_valid(卡片) and not 演示3_新增节点写入本地存档:
		长期.remove_prompt_node_by_id(卡片.prompt_id)
	if 磨砂:
		磨砂.stop_ai_glow(演示3_面板外圈熄灭秒)
	if 演示3_结束时关闭窗口:
		外壳.close_memory_panel()
	_忙碌中 = false


func _播放节点入场缩放(卡片: PromptMemoryNode, 初始: float, 时长: float, 曲线: Curve) -> void:
	if not is_instance_valid(卡片):
		return
	var 起点 := maxf(0.02, 初始)
	卡片.scale = Vector2(起点, 起点)
	var tw := create_tween()
	if 曲线 != null:
		var c: Curve = 曲线
		var 缩放步 := func(t: float) -> void:
			if is_instance_valid(卡片):
				var s: float = c.sample_baked(clampf(t, 0.0, 1.0))
				卡片.scale = Vector2(s, s)
		tw.tween_method(缩放步, 0.0, 1.0, 时长)
	else:
		tw.tween_property(卡片, "scale", Vector2.ONE, 时长).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await tw.finished
