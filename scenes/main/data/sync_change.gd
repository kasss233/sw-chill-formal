class_name SyncChange
extends RefCounted

## 同步变更记录数据模型
## 记录本地数据变更，等待 push 到服务器

# 资源类型: "task" | "note" | "category"
var resource: String = ""
# 动作类型: "create" | "update" | "delete" | "reorder"
var action: String = ""
# 本地 ID（category 用 0）
var local_id: int = 0
# category 用 name 作为 key
var local_key: String = ""
# 发送到后端的 data 字段
var data: Dictionary = {}
# 变更发生时的毫秒时间戳
var timestamp: int = 0


func _init(p_resource: String = "", p_action: String = "", p_local_id: int = 0, p_local_key: String = "", p_data: Dictionary = {}, p_timestamp: int = 0):
	resource = p_resource
	action = p_action
	local_id = p_local_id
	local_key = p_local_key
	data = p_data.duplicate(true)
	timestamp = p_timestamp if p_timestamp > 0 else int(Time.get_unix_time_from_system() * 1000)


## 序列化为字典
func to_dict() -> Dictionary:
	return {
		"resource": resource,
		"action": action,
		"local_id": local_id,
		"local_key": local_key,
		"data": data.duplicate(true),
		"timestamp": timestamp
	}


## 从字典反序列化
static func from_dict(d: Dictionary) -> SyncChange:
	return SyncChange.new(
		d.get("resource", ""),
		d.get("action", ""),
		d.get("local_id", 0),
		d.get("local_key", ""),
		d.get("data", {}),
		d.get("timestamp", 0)
	)
