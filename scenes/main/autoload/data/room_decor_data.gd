class_name RoomDecorData
extends RefCounted

var id: int = 0
var name: String = ""
var category: String = "default"
var icon_path: String = ""
var required_level: int = 1
var created_at: int = 0
var updated_at: int = 0


func _init(
	p_id: int = 0,
	p_name: String = "",
	p_category: String = "default",
	p_required_level: int = 1,
	p_icon_path: String = ""
) -> void:
	id = p_id
	name = p_name
	category = p_category.strip_edges()
	if category.is_empty():
		category = "default"
	required_level = max(1, p_required_level)
	icon_path = p_icon_path
	created_at = int(Time.get_unix_time_from_system())
	updated_at = created_at


func to_dict() -> Dictionary:
	return {
		"id": id,
		"name": name,
		"category": category,
		"icon_path": icon_path,
		"required_level": required_level,
		"created_at": created_at,
		"updated_at": updated_at
	}


static func from_dict(d: Dictionary) -> RoomDecorData:
	var item := RoomDecorData.new(
		int(d.get("id", 0)),
		str(d.get("name", "")),
		str(d.get("category", "default")),
		int(d.get("required_level", 1)),
		str(d.get("icon_path", ""))
	)
	item.created_at = int(d.get("created_at", item.created_at))
	item.updated_at = int(d.get("updated_at", item.updated_at))
	return item
