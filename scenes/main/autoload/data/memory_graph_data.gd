extends Node

## 记忆图数据（Autoload：`MemoryGraphData`）
## 维护可编辑记忆与只读记忆两套图数据，结构与 [method MemoryModuleBase.apply_memory_graph_from_dict] 一致，并扩展 `position`、`body_expanded`、`is_lit` 等字段。
## 本地存档：`user://memory_graph_data.json`（与 `NoteState` 等一致，防抖写盘）。

const SAVE_PATH := "user://memory_graph_data.json"
const SAVE_DEBOUNCE_SEC := 0.45
const DATA_VERSION := 1

var _editor_demo_graph: Dictionary = {
	"prompts": [
		{"id": 1, "title": "角色语气", "body": "对话时语调柔和自然；涉及隐私或原则问题时需明确边界并简短说明原因。", "weight": 0.92, "connected": true, "mutable": true},
		{"id": 2, "title": "先确认目标", "body": "在执行多步操作前，用一两句话复述或确认用户意图，避免跑偏。", "weight": 0.85, "connected": true, "mutable": true},
		{"id": 3, "title": "回复风格：简洁", "body": "优先短句与要点，避免冗长套话。", "weight": 0.64, "connected": false, "mutable": true},
		{"id": 4, "title": "架构：数据经 State", "body": "所有数据变更必须通过对应 XxxState 单例 API；UI 只响应信号刷新，禁止直接改数据字段。", "weight": 0.70, "connected": true, "mutable": true},
		{"id": 5, "title": "【系统】只读展示", "body": "此条由系统注入，仅展示；用户不可在侧栏修改或删除。", "weight": 0.55, "connected": true, "mutable": false},
		{"id": 6, "title": "【演出】流光 · 常亮", "body": "进入场景时即点亮，与未发光卡片对照。", "weight": 0.78, "connected": true, "mutable": true},
		{"id": 7, "title": "【演出】流光 · 渐亮", "body": "约 0.85s 后淡入点亮，演示 set_lit(true) 过渡。", "weight": 0.72, "connected": true, "mutable": true},
		{"id": 8, "title": "【演出】未点亮", "body": "默认不发光；可在侧栏选中后自行用代码 set_lit(true) 试验。", "weight": 0.66, "connected": false, "mutable": true}
	]
}

var _immutable_demo_graph: Dictionary = {
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

## 根结构：`version`、`editor`、`immutable`，每项为完整图字典（`prompts` + 可选 `edges`）。
var _bundle: Dictionary = {}

var _save_timer: SceneTreeTimer
var _pending_module: MemoryModuleBase


func _ready() -> void:
	_load_data()
	print("[MemoryGraphData] Initialized")


func get_editor_demo_graph() -> Dictionary:
	return _editor_demo_graph.duplicate(true)


func get_immutable_demo_graph() -> Dictionary:
	return _immutable_demo_graph.duplicate(true)


## 供 [memory.tscn] 加载：已存档数据优先，否则为内置演示数据。
func get_editor_graph() -> Dictionary:
	_ensure_bundle()
	return _bundle["editor"].duplicate(true)


## 供 [memory_immutable.tscn] 加载：已存档数据优先，否则为内置演示数据。
func get_immutable_graph() -> Dictionary:
	_ensure_bundle()
	return _bundle["immutable"].duplicate(true)


## 由 [method MemoryModuleBase.export_memory_graph_to_dict] + 场景槽位写回并防抖落盘。
func sync_from_module(module: MemoryModuleBase) -> void:
	if not is_instance_valid(module):
		return
	_pending_module = module
	_queue_save_from_module()


func export_data() -> Dictionary:
	_ensure_bundle()
	return {
		"version": DATA_VERSION,
		"editor": _bundle["editor"].duplicate(true),
		"immutable": _bundle["immutable"].duplicate(true)
	}


## 用于调试或将来扩展导入；会立即写盘。
func import_data(data: Dictionary) -> void:
	if not data.has("editor") and not data.has("immutable"):
		push_warning("[MemoryGraphData] import_data: 缺少 editor/immutable")
		return
	_ensure_bundle()
	if data.has("editor") and typeof(data["editor"]) == TYPE_DICTIONARY:
		_bundle["editor"] = data["editor"].duplicate(true)
	if data.has("immutable") and typeof(data["immutable"]) == TYPE_DICTIONARY:
		_bundle["immutable"] = data["immutable"].duplicate(true)
	_save_to_disk_immediate()


func _ensure_bundle() -> void:
	if _bundle.is_empty():
		_bundle = {
			"version": DATA_VERSION,
			"editor": _editor_demo_graph.duplicate(true),
			"immutable": _immutable_demo_graph.duplicate(true)
		}


func _load_data() -> void:
	_bundle.clear()
	if not FileAccess.file_exists(SAVE_PATH):
		_ensure_bundle()
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		push_error("[MemoryGraphData] 无法读取 %s" % SAVE_PATH)
		_ensure_bundle()
		return
	var text := f.get_as_text()
	f.close()
	var json := JSON.new()
	if json.parse(text) != OK:
		push_error("[MemoryGraphData] JSON 解析失败: %s" % json.get_error_message())
		_ensure_bundle()
		return
	var parsed: Variant = json.get_data()
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("[MemoryGraphData] 根类型须为对象")
		_ensure_bundle()
		return
	var d: Dictionary = parsed
	_bundle["version"] = int(d.get("version", DATA_VERSION))
	_ensure_bundle()
	if d.has("editor") and typeof(d["editor"]) == TYPE_DICTIONARY:
		_bundle["editor"] = d["editor"].duplicate(true)
	if d.has("immutable") and typeof(d["immutable"]) == TYPE_DICTIONARY:
		_bundle["immutable"] = d["immutable"].duplicate(true)
	print("[MemoryGraphData] 已从本地加载记忆图存档")


func _queue_save_from_module() -> void:
	if get_tree() == null:
		return
	if _save_timer != null and _save_timer.time_left > 0.0:
		return
	_save_timer = get_tree().create_timer(SAVE_DEBOUNCE_SEC)
	_save_timer.timeout.connect(_flush_save_from_module, CONNECT_ONE_SHOT)


func _flush_save_from_module() -> void:
	_save_timer = null
	if _pending_module == null or not is_instance_valid(_pending_module):
		return
	var slot: String = _pending_module._get_memory_graph_slot()
	var exported: Dictionary = _pending_module.export_memory_graph_to_dict()
	_ensure_bundle()
	_bundle[slot] = exported.duplicate(true)
	_save_to_disk_immediate()
	_pending_module = null


func _save_to_disk_immediate() -> void:
	_ensure_bundle()
	var payload := {
		"version": DATA_VERSION,
		"editor": _bundle["editor"].duplicate(true),
		"immutable": _bundle["immutable"].duplicate(true)
	}
	var json_string := JSON.stringify(payload, "\t")
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("[MemoryGraphData] 无法写入 %s" % SAVE_PATH)
		return
	file.store_string(json_string)
	file.close()
