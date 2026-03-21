class_name StatsRecord
extends RefCounted

## 统一统计聚合记录模型

var id: int = 0
var record_type: String = ""
var date_key: String = ""  # "YYYY-MM-DD"
var value: float = 0.0
var data: Dictionary = {}
var created_at: int = 0


func to_dict() -> Dictionary:
	return {
		"id": id,
		"record_type": record_type,
		"date_key": date_key,
		"value": value,
		"data": data,
		"created_at": created_at,
	}


static func from_dict(d: Dictionary) -> StatsRecord:
	var record = StatsRecord.new()
	record.id = d.get("id", 0)
	record.record_type = d.get("record_type", "")
	record.date_key = d.get("date_key", "")
	record.value = float(d.get("value", 0.0))
	record.data = d.get("data", {})
	record.created_at = d.get("created_at", 0)
	return record
