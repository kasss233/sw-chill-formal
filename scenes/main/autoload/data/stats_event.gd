class_name StatsEvent
extends RefCounted

## 统一统计事件模型

var id: int = 0
var event_type: String = ""
var occurred_at: int = 0
var session_id: String = ""
var source: String = ""
var payload: Dictionary = {}


func to_dict() -> Dictionary:
	return {
		"id": id,
		"event_type": event_type,
		"occurred_at": occurred_at,
		"session_id": session_id,
		"source": source,
		"payload": payload,
	}


static func from_dict(d: Dictionary) -> StatsEvent:
	var event = StatsEvent.new()
	event.id = d.get("id", 0)
	event.event_type = d.get("event_type", "")
	event.occurred_at = int(d.get("occurred_at", 0))
	event.session_id = d.get("session_id", "")
	event.source = d.get("source", "")
	event.payload = d.get("payload", {})
	return event
