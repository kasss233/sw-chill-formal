extends "res://scenes/test/memory/memory.gd"

## 只读记忆结构展示：布局与 [Memory] 相同，但禁用一切编辑；卡片可走 **节点间边**（`edges`）展示 Agent 实际记忆关联。[br]
## 数据请通过 [method apply_memory_graph_from_export_json] / [method apply_memory_graph_from_dict] 注入（与可编辑版相同 JSON，可加 `edges`）。

func _build_ui() -> void:
	super._build_ui()
	_title_label.text = "Agent 记忆（只读 · 结构展示）"
	_add_button.visible = false
	_export_button.visible = false
	_delete_button.visible = false
	_apply_json_button.visible = false
	_json_import_edit.visible = false
	var v := $SidePanel/MarginContainer/VBoxContainer
	v.get_node("ImportHint").visible = false
	v.get_node("PanelTitle").text = "记忆快照（只读）"
	v.get_node("TitleHint").visible = false
	v.get_node("BodyHint").visible = false
	_prompt_edit.editable = false
	_prompt_edit.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_prompt_body_edit.editable = false
	_prompt_body_edit.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_weight_slider.editable = false
	_weight_slider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_connected_button.disabled = true
	_connected_button.mouse_filter = Control.MOUSE_FILTER_IGNORE


func apply_memory_graph_from_parsed(parsed: Variant) -> Dictionary:
	_batch_node_display_only = true
	var r := super.apply_memory_graph_from_parsed(parsed)
	_batch_node_display_only = false
	return r


func _create_demo_nodes() -> void:
	var r := apply_memory_graph_from_dict(_immutable_demo_dict())
	if not r.get("ok", false):
		push_warning("[MemoryImmutable] 演示数据加载失败：%s" % str(r.get("error", "")))
		return
	_apply_random_lit_demo_effects()


func _immutable_demo_dict() -> Dictionary:
	return {
		"prompts": [
			{"id": 1, "title": "RAG 检索片段", "body": "从向量库召回的与用户问题最相关的摘要，用于事实 grounding。", "weight": 0.88, "connected": true, "mutable": false},
			{"id": 2, "title": "会话摘要", "body": "截至上一轮的对话摘要，压缩在长窗口之外。", "weight": 0.82, "connected": true, "mutable": false},
			{"id": 3, "title": "用户画像片段", "body": "偏好语言、常用模块、最近关心的主题标签。", "weight": 0.74, "connected": true, "mutable": false},
			{"id": 4, "title": "工具结果缓存", "body": "最近一次 calendar / task 查询的结构化结果引用。", "weight": 0.71, "connected": false, "mutable": false},
			{"id": 5, "title": "策略与安全约束", "body": "当前会话启用的输出格式与安全边界（系统级）。", "weight": 0.95, "connected": true, "mutable": false}
		],
		"edges": [
			{"from": 1, "to": 5},
			{"from": 2, "to": 5},
			{"from": 2, "to": 1},
			{"from": 3, "to": 2},
			{"from": 4, "to": 1}
		]
	}
