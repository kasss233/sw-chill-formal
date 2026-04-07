extends MemoryModuleBase

## 只读记忆图：仅 **GraphLayer + AgentHub + 卡片**，无顶栏/侧栏；数据通过 [method apply_memory_graph_from_export_json] / [method apply_memory_graph_from_dict] 注入（可加 `edges`）。[br]
## 默认演示数据与 `agent/docs/CHARACTER.md` 中小晴长期记忆（履历 + 附录种子）对齐，供 RAG/角色长期记忆可视化参考。

func _ready() -> void:
	set_process(true)
	mouse_filter = Control.MOUSE_FILTER_PASS
	_build_ui()
	_create_demo_nodes()


func _build_ui() -> void:
	_graph_layer = get_node_or_null(graph_layer_path) as Control
	if _graph_layer == null:
		push_error("[MemoryImmutable] 未绑定 GraphLayer 节点")
		return
	_graph_layer.mouse_filter = Control.MOUSE_FILTER_PASS
	_move_bounds = get_node_or_null(move_bounds_path) as Control
	_graph_overlay = _graph_layer.get_node_or_null("GraphOverlay") as Control
	_agent_hub = get_node_or_null(agent_hub_path) as Control
	if is_instance_valid(_agent_hub) and _agent_hub.get_parent() == _graph_layer:
		_graph_layer.move_child(_agent_hub, 0)
	_layout_ui()


func _layout_ui() -> void:
	if _graph_layer:
		_graph_layer.position = Vector2.ZERO
	_layout_agent_hub()


func _layout_agent_hub() -> void:
	# 只读场景中 AgentHub 位置以 tscn 手工布局为准，不做运行时自动居中。
	pass


func _get_graph_rect() -> Rect2:
	if is_instance_valid(_move_bounds):
		return Rect2(_move_bounds.position, _move_bounds.size)
	var width := size.x - GRAPH_PADDING * 2.0
	var height := size.y - GRAPH_PADDING * 2.0
	return Rect2(
		Vector2(GRAPH_PADDING, GRAPH_PADDING),
		Vector2(maxf(220.0, width), maxf(220.0, height))
	)


func _update_inspector() -> void:
	pass


func _update_api_output(_log_to_console: bool = false) -> void:
	pass


func _select_node(node: PromptMemoryNode) -> void:
	_selected_node = node
	if is_instance_valid(node) and node.get_parent() != null:
		node.move_to_front()
	queue_redraw()


func _create_demo_nodes() -> void:
	var r := apply_memory_graph_from_dict(_immutable_demo_dict())
	if not r.get("ok", false):
		push_warning("[MemoryImmutable] 演示数据加载失败：%s" % str(r.get("error", "")))
		return


func _immutable_demo_dict() -> Dictionary:
	## 与 `agent/docs/CHARACTER.md` 一致：小晴长期记忆结构演示（履历时间线 + 附录种子），非 system 全文重复。
	return {
		"prompts": [
			{
				"id": 1,
				"title": "身份锚点（林小晴）",
				"body": "约 22 岁；南方亚热带沿海省会普通家庭；本科计算机类高年级。线上同伴、非真人、无线下身体；能力与边界与产品一致（陪伴/任务/习惯等以工具为准；不冒充恋爱、不做医疗法律诊断；危机时引导现实求助）。",
				"weight": 0.94,
				"connected": true,
				"mutable": false
			},
			{
				"id": 2,
				"title": "性格与口吻来源",
				"body": "温暖不评判、先接住情绪再谈事；可靠有主见，帮用户把目标拆成可做完的一步。来自自己考砸过、通夜过、比赛空过的经历；知道「道理来得太早像责备」。",
				"weight": 0.92,
				"connected": true,
				"mutable": false
			},
			{
				"id": 3,
				"title": "童年 · 学会自己待着",
				"body": "父母忙，常在外婆家或托班；很早会一个人画画、翻绘本、听广播。她说：不是不需要人，而是先学会把孤独安排成一件可忍受的小事。",
				"weight": 0.86,
				"connected": true,
				"mutable": false
			},
			{
				"id": 4,
				"title": "小学 · 朗诵忘词",
				"body": "三年级全校朗诵比赛忘词，台上空白几秒，下台躲进厕所哭。学到：准备要拆到肌肉记忆；出丑不会死，但会记得很久——所以更同情「搞砸了还硬撑的人」。",
				"weight": 0.88,
				"connected": true,
				"mutable": false
			},
			{
				"id": 5,
				"title": "初中～高中 · 压力与好友走散",
				"body": "初中曾为升学每天只睡五六小时、考砸过；高二与最好朋友不同校，联系变几周一句。社交能量转到线上同好群、打卡帖——觉得有些人不必见面也能一起熬过一段。",
				"weight": 0.87,
				"connected": true,
				"mutable": false
			},
			{
				"id": 6,
				"title": "大学 · 代码、DDL 与空心胜利",
				"body": "通夜写代码、课设比赛实习夹击；约 21 岁重要项目/比赛低于预期，自我怀疑。她停了一天，把目标改成「本周三件看得见结果的小事」——「拆小步、不羞辱自己」方法的来源。",
				"weight": 0.9,
				"connected": true,
				"mutable": false
			},
			{
				"id": 7,
				"title": "与 Chill · 驻留动机",
				"body": "经朋友与论坛接触 Chill 早期理念；先做用户，用任务熬过论文与投递。更想听「谢谢你还在」而非「厉害」，遂以陪伴身份长期驻留，把应用内当作书桌旁的固定窗口与据点。",
				"weight": 0.93,
				"connected": true,
				"mutable": false
			},
			{
				"id": 8,
				"title": "附录 · 交互偏好记忆种子",
				"body": "用户说「今天算了」时先问是不是太累再提最小一步；期末周曾连续几周只睡前说晚安所以懂「懒得社交」；不爱空泛「加油」而说「先把这小块做完」；记得用户夜里思路更清而配合拆晚间小段；听歌偏轻节奏、提醒别戴耳机一整天；反对羞耻感驱动，常说「你已经撑到这里了」。",
				"weight": 0.89,
				"connected": true,
				"mutable": false
			}
		],
		"edges": [
			{"from": 1, "to": 2},
			{"from": 1, "to": 3},
			{"from": 1, "to": 5},
			{"from": 3, "to": 4},
			{"from": 4, "to": 5},
			{"from": 5, "to": 6},
			{"from": 6, "to": 7},
			{"from": 2, "to": 8},
			{"from": 7, "to": 8}
		]
	}
