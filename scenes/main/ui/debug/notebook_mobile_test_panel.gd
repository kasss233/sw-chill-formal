extends Control

## NoteBookMobile 测试页 - 测试 NoteState 单例（含 Agent API）

# UI 节点引用
@onready var info_label: RichTextLabel = $MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/InfoLabel
@onready var note_title_input: LineEdit = $MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/InputSection/NoteTitleInput
@onready var note_content_input: LineEdit = $MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/InputSection/NoteContentInput
@onready var note_id_input: LineEdit = $MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/InputSection/NoteIdInput
@onready var category_input: LineEdit = $MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/InputSection/CategoryInput

# 数据操作按钮
@onready var add_note_btn: Button = $MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/DataSection/AddNoteBtn
@onready var update_note_btn: Button = $MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/DataSection/UpdateNoteBtn
@onready var remove_note_btn: Button = $MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/DataSection/RemoveNoteBtn
@onready var get_note_btn: Button = $MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/DataSection/GetNoteBtn
@onready var get_all_notes_btn: Button = $MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/DataSection/GetAllNotesBtn
@onready var search_notes_btn: Button = $MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/DataSection/SearchNotesBtn

# 分类管理按钮
@onready var add_category_btn: Button = $MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/CategorySection/AddCategoryBtn
@onready var remove_category_btn: Button = $MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/CategorySection/RemoveCategoryBtn
@onready var toggle_note_category_btn: Button = $MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/CategorySection/ToggleNoteCategoryBtn
@onready var get_all_categories_btn: Button = $MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/CategorySection/GetAllCategoriesBtn

# Agent 操作按钮
@onready var agent_create_note_btn: Button = $MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/AgentSection/AgentCreateNoteBtn
@onready var agent_write_content_btn: Button = $MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/AgentSection/AgentWriteContentBtn
@onready var agent_open_note_btn: Button = $MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/AgentSection/AgentOpenNoteBtn
@onready var agent_close_note_btn: Button = $MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/AgentSection/AgentCloseNoteBtn

var last_added_note_id: int = -1


func _ready() -> void:
	# 数据操作
	add_note_btn.pressed.connect(_on_add_note_pressed)
	update_note_btn.pressed.connect(_on_update_note_pressed)
	remove_note_btn.pressed.connect(_on_remove_note_pressed)
	get_note_btn.pressed.connect(_on_get_note_pressed)
	get_all_notes_btn.pressed.connect(_on_get_all_notes_pressed)
	search_notes_btn.pressed.connect(_on_search_notes_pressed)

	# 分类管理
	add_category_btn.pressed.connect(_on_add_category_pressed)
	remove_category_btn.pressed.connect(_on_remove_category_pressed)
	toggle_note_category_btn.pressed.connect(_on_toggle_note_category_pressed)
	get_all_categories_btn.pressed.connect(_on_get_all_categories_pressed)

	# Agent 操作
	agent_create_note_btn.pressed.connect(_on_agent_create_note_pressed)
	agent_write_content_btn.pressed.connect(_on_agent_write_content_pressed)
	agent_open_note_btn.pressed.connect(_on_agent_open_note_pressed)
	agent_close_note_btn.pressed.connect(_on_agent_close_note_pressed)

	_log_info("NoteBookMobile 测试面板已就绪")
	_log_info("所有数据操作通过 NoteState 单例执行")


# ======================== 数据操作 ========================

func _on_add_note_pressed() -> void:
	var title = note_title_input.text
	var content = note_content_input.text
	var category = category_input.text

	_log_info("调用 NoteState.add_note(title='%s', content='%s', category='%s')" % [title, content, category])
	var note = NoteState.add_note(title, content, category)
	last_added_note_id = note.id
	_log_success("笔记已添加，ID: %d" % note.id)
	note_id_input.text = str(note.id)


func _on_update_note_pressed() -> void:
	var id = note_id_input.text.to_int()
	var title = note_title_input.text
	var content = note_content_input.text

	if title.is_empty() and content.is_empty():
		_log_error("请输入标题或内容")
		return

	_log_info("调用 NoteState.update_note(id=%d, title='%s', content='%s')" % [id, title, content])
	var success = NoteState.update_note(id, title, content)
	if success:
		_log_success("笔记已更新")
	else:
		_log_error("更新失败，笔记ID不存在")


func _on_remove_note_pressed() -> void:
	var id = note_id_input.text.to_int()
	_log_info("调用 NoteState.remove_note(id=%d)" % id)
	var success = NoteState.remove_note(id)
	if success:
		_log_success("笔记已删除")
	else:
		_log_error("删除失败，笔记ID不存在")


func _on_get_note_pressed() -> void:
	var id = note_id_input.text.to_int()
	_log_info("调用 NoteState.get_note_by_id(id=%d)" % id)
	var note = NoteState.get_note_by_id(id)
	if note == null:
		_log_error("笔记不存在")
	else:
		_log_success("笔记信息:")
		_log_data(JSON.stringify(note.to_dict(), "  "))


func _on_get_all_notes_pressed() -> void:
	_log_info("调用 NoteState.get_all_notes()")
	var all_notes = NoteState.get_all_notes()
	_log_success("共有 %d 条笔记:" % all_notes.size())
	for note in all_notes:
		_log_data("  - [%d] %s (%d字)" % [note.id, note.get_display_title(), note.get_word_count()])


func _on_search_notes_pressed() -> void:
	var query = note_title_input.text
	if query.is_empty():
		_log_error("请在标题输入框输入搜索关键词")
		return
	_log_info("调用 NoteState.search_notes(query='%s')" % query)
	var results = NoteState.search_notes(query)
	_log_success("搜索到 %d 条结果:" % results.size())
	for note in results:
		_log_data("  - [%d] %s" % [note.id, note.get_display_title()])


# ======================== 分类管理 ========================

func _on_add_category_pressed() -> void:
	var cat = category_input.text.strip_edges()
	if cat.is_empty():
		_log_error("请输入分类名称")
		return
	_log_info("调用 NoteState.add_category('%s')" % cat)
	var success = NoteState.add_category(cat)
	if success:
		_log_success("分类已添加: %s" % cat)
	else:
		_log_error("添加失败（分类已存在或名称为空）")


func _on_remove_category_pressed() -> void:
	var cat = category_input.text.strip_edges()
	if cat.is_empty():
		_log_error("请输入分类名称")
		return
	_log_info("调用 NoteState.remove_category('%s')" % cat)
	var success = NoteState.remove_category(cat)
	if success:
		_log_success("分类已删除: %s" % cat)
	else:
		_log_error("删除失败（分类不存在）")


func _on_toggle_note_category_pressed() -> void:
	var id = note_id_input.text.to_int()
	var cat = category_input.text.strip_edges()
	if cat.is_empty():
		_log_error("请输入分类名称")
		return
	_log_info("调用 NoteState.toggle_note_category(id=%d, category='%s')" % [id, cat])
	var success = NoteState.toggle_note_category(id, cat)
	if success:
		_log_success("笔记分类已切换")
	else:
		_log_error("操作失败，笔记ID不存在")


func _on_get_all_categories_pressed() -> void:
	_log_info("调用 NoteState.get_categories()")
	var categories = NoteState.get_categories()
	_log_success("共有 %d 个分类:" % categories.size())
	for cat in categories:
		_log_data("  - %s" % cat)


# ======================== Agent 操作 ========================

func _on_agent_create_note_pressed() -> void:
	var title = note_title_input.text
	var content = note_content_input.text
	var category = category_input.text
	if title.is_empty():
		title = "Agent笔记 " + str(Time.get_ticks_msec())
	if content.is_empty():
		content = "这是一条由 Agent 创建的测试笔记内容，用于验证打字动画效果是否正常工作。"

	_log_info("调用 NoteState.agent_create_note(title='%s', content='%s', category='%s')" % [title, content, category])
	var note = NoteState.agent_create_note(title, content, category)
	last_added_note_id = note.id
	_log_success("Agent 笔记已创建，ID: %d（NoteBookMobile 应自动打开并播放打字动画）" % note.id)
	note_id_input.text = str(note.id)


func _on_agent_write_content_pressed() -> void:
	var id = note_id_input.text.to_int()
	var content = note_content_input.text
	if content.is_empty():
		content = "Agent 写入的新内容，验证打字动画是否正常播放。当前时间: " + str(Time.get_ticks_msec())

	_log_info("调用 NoteState.agent_write_content(id=%d, content='%s')" % [id, content])
	var success = NoteState.agent_write_content(id, content)
	if success:
		_log_success("Agent 内容已写入（应播放打字动画）")
	else:
		_log_error("写入失败，笔记ID不存在")


func _on_agent_open_note_pressed() -> void:
	var id = note_id_input.text.to_int()
	_log_info("调用 NoteState.agent_open_note(id=%d)" % id)
	var success = NoteState.agent_open_note(id)
	if success:
		_log_success("Agent 打开笔记请求已发送（NoteBookMobile 应自动打开笔记页）")
	else:
		_log_error("打开失败，笔记ID不存在")


func _on_agent_close_note_pressed() -> void:
	_log_info("调用 NoteState.agent_close_note()")
	NoteState.agent_close_note()
	_log_success("Agent 关闭笔记页请求已发送（NoteBookMobile 应返回列表视图）")


# ======================== 日志输出 ========================

func _log_info(message: String) -> void:
	info_label.append_text("[color=white]%s[/color]\n" % message)
	print("[NoteBookMobileTest] %s" % message)


func _log_success(message: String) -> void:
	info_label.append_text("[color=green]%s[/color]\n" % message)
	print("[NoteBookMobileTest] %s" % message)


func _log_error(message: String) -> void:
	info_label.append_text("[color=red]%s[/color]\n" % message)
	print("[NoteBookMobileTest] ERROR: %s" % message)


func _log_data(message: String) -> void:
	info_label.append_text("[color=cyan]%s[/color]\n" % message)
	print("[NoteBookMobileTest] %s" % message)
