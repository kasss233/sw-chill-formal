extends Node

## 便签状态管理单例（Data Autoload）
## 管理便签计数和 Agent API，便签 UI 由 NoteModule 负责

# --- 信号 ---
signal sticky_note_requested(text: String)
signal count_changed(count: int)

# --- 状态 ---
var _count: int = 0
const MAX_COUNT: int = 20


func _ready() -> void:
	print("[StickyNoteState] 初始化完成")


# ======================== 查询 API ========================

func get_count() -> int:
	return _count


func can_create() -> bool:
	return _count < MAX_COUNT


# ======================== 通知（NoteModule 调用）========================

func notify_created() -> void:
	_count += 1
	count_changed.emit(_count)


func notify_closed() -> void:
	_count = max(0, _count - 1)
	count_changed.emit(_count)


# ======================== Agent API ========================

func agent_take_note(text: String) -> bool:
	if text.strip_edges() == "":
		print("[StickyNoteState] 内容为空，忽略")
		return false
	if _count >= MAX_COUNT:
		print("[StickyNoteState] 便签数量已达上限 %d" % MAX_COUNT)
		return false
	sticky_note_requested.emit(text)
	return true
