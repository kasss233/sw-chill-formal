class_name NotePage
extends MarginContainer

## 笔记编辑页组件
## 支持编辑标题和内容，实时显示字数和修改时间
## 信号上报编辑事件，不直接操作数据

signal title_changed(text: String)
signal content_changed(text: String)

var _note_id: int = -1

@onready var _title_edit: LineEdit = $VBoxContainer/TitleEdit
@onready var _info_label: Label = $VBoxContainer/Label
@onready var _text_edit: TextEdit = $VBoxContainer/TextEdit


func _ready() -> void:
	# 确保填满父容器
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	$VBoxContainer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_text_edit.size_flags_vertical = Control.SIZE_EXPAND_FILL

	_title_edit.text_changed.connect(_on_title_changed)
	_text_edit.text_changed.connect(_on_content_changed)


## 加载笔记数据到编辑器
func load_note(data: NoteData) -> void:
	_note_id = data.id
	_title_edit.text = data.title
	_text_edit.text = data.content
	_update_info_from_data(data)


## 获取当前笔记 id
func get_note_id() -> int:
	return _note_id


## 获取当前标题
func get_title() -> String:
	return _title_edit.text


## 获取当前内容
func get_content() -> String:
	return _text_edit.text


## 根据 NoteData 更新信息栏
func _update_info_from_data(data: NoteData) -> void:
	_info_label.text = "%s | %d字" % [data.get_formatted_time(), data.get_word_count()]


## 实时更新信息栏（不依赖 NoteState）
func _update_info_label() -> void:
	var word_count = _text_edit.text.length()
	var timezone_offset = 8 * 3600
	var now = int(Time.get_unix_time_from_system()) + timezone_offset
	var dict = Time.get_datetime_dict_from_unix_time(now)
	_info_label.text = "%d年%d月%d日 %d:%02d | %d字" % [
		dict.year, dict.month, dict.day, dict.hour, dict.minute, word_count
	]


func _on_title_changed(new_text: String) -> void:
	_update_info_label()
	title_changed.emit(new_text)


func _on_content_changed() -> void:
	_update_info_label()
	content_changed.emit(_text_edit.text)
