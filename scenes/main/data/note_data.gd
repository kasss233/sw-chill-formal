class_name NoteData
extends RefCounted

## 笔记数据模型
## 包含笔记的所有数据字段，支持序列化/反序列化

# 自增 id
var id: int = 0
# 标题（可空，为空时展示内容第一行）
var title: String = ""
# 正文内容
var content: String = ""
# 分类列表（空数组表示无分类，一个笔记可属于多个分类）
var categories: Array[String] = []
# 创建时间戳
var created_at: int = 0
# 最后修改时间戳
var updated_at: int = 0


func _init(p_id: int = 0, p_title: String = "", p_content: String = "", p_categories: Array[String] = []):
	id = p_id
	title = p_title
	content = p_content
	categories = p_categories.duplicate()
	created_at = int(Time.get_unix_time_from_system())
	updated_at = created_at


## 获取展示用标题（标题为空时取内容第一行）
func get_display_title() -> String:
	if title.strip_edges() != "":
		return title
	if content.strip_edges() != "":
		var first_line = content.split("\n")[0].strip_edges()
		if first_line.length() > 50:
			return first_line.substr(0, 50) + "..."
		return first_line
	return "无标题笔记"


## 获取内容预览（一行摘要）
func get_content_preview() -> String:
	if content.strip_edges() == "":
		return ""
	var lines = content.split("\n")
	for line in lines:
		var trimmed = line.strip_edges()
		if trimmed != "":
			if trimmed.length() > 80:
				return trimmed.substr(0, 80) + "..."
			return trimmed
	return ""


## 获取格式化的修改时间
func get_formatted_time() -> String:
	if updated_at == 0:
		return ""
	var timezone_offset = 8 * 3600
	var local_timestamp = updated_at + timezone_offset
	var dict = Time.get_datetime_dict_from_unix_time(local_timestamp)
	return "%d年%d月%d日 %d:%02d" % [dict.year, dict.month, dict.day, dict.hour, dict.minute]


## 获取字数
func get_word_count() -> int:
	return content.length()


## 序列化为字典
func to_dict() -> Dictionary:
	return {
		"id": id,
		"title": title,
		"content": content,
		"categories": categories.duplicate(),
		"created_at": created_at,
		"updated_at": updated_at
	}


## 从字典反序列化（兼容旧版单分类数据）
static func from_dict(d: Dictionary) -> NoteData:
	var cats: Array[String] = []
	if d.has("categories") and d["categories"] is Array:
		for c in d["categories"]:
			cats.append(str(c))
	elif d.has("category") and d["category"] is String and d["category"] != "":
		cats.append(d["category"])
	var note = NoteData.new(
		d.get("id", 0),
		d.get("title", ""),
		d.get("content", ""),
		cats
	)
	note.created_at = d.get("created_at", 0)
	note.updated_at = d.get("updated_at", 0)
	return note
