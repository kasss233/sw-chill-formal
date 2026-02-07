class_name NoteBookMobile
extends Control

## 移动端笔记模块（UI Module）
## 管理二级菜单：笔记列表 ↔ 笔记编辑页
## 支持分类筛选、搜索、防抖保存
## 监听 NoteState 信号响应式更新 UI

# --- 节点引用 ---
@onready var _frosted_panel: PanelContainer = $FrostedPanel
@onready var _header_button: Button = $FrostedPanel/MarginContainer/VBoxContainer/HBoxContainer/MaterialButton
@onready var _scroll_container: ScrollContainer = $FrostedPanel/MarginContainer/VBoxContainer/SmoothScrollContainer
@onready var _search_field: Control = $FrostedPanel/MarginContainer/VBoxContainer/SmoothScrollContainer/VBoxContainer/MaterialTextField
@onready var _chips_container: HBoxContainer = $FrostedPanel/MarginContainer/VBoxContainer/SmoothScrollContainer/VBoxContainer/HBoxContainer2
@onready var _all_chip: Control = $FrostedPanel/MarginContainer/VBoxContainer/SmoothScrollContainer/VBoxContainer/HBoxContainer2/AllChip
@onready var _items_container: VBoxContainer = $FrostedPanel/MarginContainer/VBoxContainer/SmoothScrollContainer/VBoxContainer/VBoxContainer
@onready var _list_container: VBoxContainer = $FrostedPanel/MarginContainer/VBoxContainer
@onready var _note_container: VBoxContainer = $FrostedPanel/MarginContainer/NoteVBoxContainer
@onready var _back_button: Button = $FrostedPanel/MarginContainer/NoteVBoxContainer/HBoxContainer/BackButton

# --- 场景资源 ---
var _note_item_scene: PackedScene = preload("res://scenes/main/ui/notebook_mobile_module/note_item/note_item.tscn")
var _note_page_scene: PackedScene = preload("res://scenes/main/ui/notebook_mobile_module/note_page/note_page.tscn")

# --- 内部状态 ---
var _current_page: NotePage = null
var _current_category: String = ""   # 空字符串 = "全部"
var _search_query: String = ""
var _is_page_open: bool = false
var _category_chips: Dictionary = {} # {category_name: MaterialChip}
var _save_timer: Timer = null


func _ready() -> void:
	# 移除编辑器中的占位 NoteItem
	for child in _items_container.get_children():
		child.queue_free()

	# 防抖保存定时器
	_save_timer = Timer.new()
	_save_timer.wait_time = 1.5
	_save_timer.one_shot = true
	_save_timer.timeout.connect(_save_current_page)
	add_child(_save_timer)

	# 连接 UI 信号
	_header_button.pressed.connect(_on_header_button_pressed)
	_back_button.pressed.connect(_close_page)
	_search_field.text_changed.connect(_on_search_text_changed)
	_all_chip.selected.connect(_on_all_chip_selected)

	# 连接 NoteState 信号
	NoteState.note_added.connect(_on_note_added)
	NoteState.note_removed.connect(_on_note_removed)
	NoteState.note_updated.connect(_on_note_updated)
	NoteState.data_loaded.connect(_on_data_loaded)
	NoteState.category_added.connect(_on_category_added)
	NoteState.category_removed.connect(_on_category_removed)

	# 初始加载
	_refresh_categories()
	_refresh_note_list()


# ======================== 列表视图 ========================

## 获取过滤后的笔记列表
func _get_filtered_notes() -> Array[NoteData]:
	var notes: Array[NoteData]

	# 按分类过滤
	if _current_category != "":
		notes = NoteState.get_notes_by_category(_current_category)
	else:
		notes = NoteState.get_all_notes()

	# 按搜索词过滤
	if _search_query != "":
		var q = _search_query.to_lower()
		var filtered: Array[NoteData] = []
		for note in notes:
			if note.title.to_lower().find(q) >= 0 or note.content.to_lower().find(q) >= 0:
				filtered.append(note)
		notes = filtered

	# 按更新时间倒序排列
	notes.sort_custom(func(a, b): return a.updated_at > b.updated_at)
	return notes


## 刷新笔记列表
func _refresh_note_list() -> void:
	# 清除现有列表项
	for child in _items_container.get_children():
		child.queue_free()

	var notes = _get_filtered_notes()
	var delay = 0.0
	for note in notes:
		var item = _note_item_scene.instantiate() as NoteItemMobile
		_items_container.add_child(item)
		item.update_display(note)
		item.note_pressed.connect(_on_note_item_pressed)
		item.play_entry_animation(delay)
		delay += 0.05


## 刷新分类 Chip
func _refresh_categories() -> void:
	# 清除已有的动态 Chip
	for cat_name in _category_chips:
		if is_instance_valid(_category_chips[cat_name]):
			_category_chips[cat_name].queue_free()
	_category_chips.clear()

	# 从 NoteState 加载分类
	var categories = NoteState.get_categories()
	for cat in categories:
		_add_category_chip(cat)


## 动态添加分类 Chip
func _add_category_chip(category: String) -> void:
	var chip = MaterialChip.new()
	chip.chip_type = MaterialChip.ChipType.FILTER
	chip.text = category
	chip.custom_minimum_size = Vector2(76, 32)
	_chips_container.add_child(chip)
	chip.selected.connect(_on_category_chip_selected.bind(category))
	_category_chips[category] = chip


# ======================== 页面视图 ========================

## 打开笔记编辑页
func _open_page(note_id: int) -> void:
	var note = NoteState.get_note_by_id(note_id)
	if note == null:
		return

	_is_page_open = true

	# 切换容器：隐藏列表，显示编辑页容器
	_list_container.visible = false
	_note_container.visible = true

	# 实例化编辑页
	_current_page = _note_page_scene.instantiate() as NotePage
	_note_container.add_child(_current_page)
	_current_page.load_note(note)

	# 连接编辑信号
	_current_page.title_changed.connect(_on_page_title_changed)
	_current_page.content_changed.connect(_on_page_content_changed)

	# 入场动画
	_current_page.modulate.a = 0
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(_current_page, "modulate:a", 1.0, 0.3)


## 关闭编辑页，返回列表
func _close_page() -> void:
	if _current_page == null:
		return

	var note_id = _current_page.get_note_id()
	var title = _current_page.get_title()
	var content = _current_page.get_content()

	# 自动删除空笔记
	if title.strip_edges() == "" and content.strip_edges() == "":
		NoteState.remove_note(note_id)
	else:
		NoteState.update_note(note_id, title, content)

	# 停止防抖定时器
	_save_timer.stop()

	# 移除页面
	_current_page.queue_free()
	_current_page = null

	# 切换容器：隐藏编辑页，显示列表
	_is_page_open = false
	_note_container.visible = false
	_list_container.visible = true

	_refresh_note_list()


## 防抖保存当前页面
func _save_current_page() -> void:
	if _current_page == null:
		return
	var note_id = _current_page.get_note_id()
	var title = _current_page.get_title()
	var content = _current_page.get_content()
	NoteState.update_note(note_id, title, content)


# ======================== UI 信号回调 ========================

func _on_header_button_pressed() -> void:
	_create_new_note()


func _create_new_note() -> void:
	var note = NoteState.add_note("", "", _current_category)
	_open_page(note.id)


func _on_note_item_pressed(note_id: int) -> void:
	_open_page(note_id)


func _on_search_text_changed(new_text: String) -> void:
	_search_query = new_text.strip_edges()
	_refresh_note_list()


func _on_all_chip_selected(is_selected: bool) -> void:
	if is_selected:
		_current_category = ""
		for cat_name in _category_chips:
			_category_chips[cat_name].set_selected_no_signal(false)
		_refresh_note_list()
	else:
		# 不允许取消选中"全部"（至少一个选中）
		_all_chip.set_selected_no_signal(true)


func _on_category_chip_selected(is_selected: bool, category: String) -> void:
	if is_selected:
		_current_category = category
		_all_chip.set_selected_no_signal(false)
		for cat_name in _category_chips:
			if cat_name != category:
				_category_chips[cat_name].set_selected_no_signal(false)
		_refresh_note_list()
	else:
		# 没有选中的分类时回到"全部"
		_current_category = ""
		_all_chip.set_selected_no_signal(true)
		_refresh_note_list()


func _on_page_title_changed(_new_title: String) -> void:
	_save_timer.start()


func _on_page_content_changed(_new_content: String) -> void:
	_save_timer.start()


# ======================== NoteState 信号回调 ========================

func _on_note_added(_note: NoteData) -> void:
	if not _is_page_open:
		_refresh_note_list()


func _on_note_removed(_note_id: int) -> void:
	if not _is_page_open:
		_refresh_note_list()


func _on_note_updated(_note: NoteData) -> void:
	if not _is_page_open:
		_refresh_note_list()


func _on_data_loaded() -> void:
	_refresh_categories()
	_refresh_note_list()


func _on_category_added(_category: String) -> void:
	_refresh_categories()


func _on_category_removed(_category: String) -> void:
	if _current_category == _category:
		_current_category = ""
		_all_chip.set_selected_no_signal(true)
	_refresh_categories()
	_refresh_note_list()


# ======================== Agent API（UI 操作）========================

## 打开指定笔记的编辑页
func agent_open_note(note_id: int) -> void:
	if _is_page_open:
		_close_page()
	_open_page(note_id)


## 关闭编辑页回到列表
func agent_close_note() -> void:
	if _is_page_open:
		_close_page()


## 创建新笔记并打开编辑页
func agent_create_and_open(title: String = "", content: String = "", category: String = "") -> int:
	var note = NoteState.add_note(title, content, category)
	_open_page(note.id)
	return note.id


## 获取当前打开的笔记 id（未打开返回 -1）
func agent_get_current_note_id() -> int:
	if _current_page:
		return _current_page.get_note_id()
	return -1


## 编辑页是否打开
func agent_is_page_open() -> bool:
	return _is_page_open


## 设置搜索关键词
func agent_search(query: String) -> void:
	_search_query = query
	_search_field.set_text(query)
	_refresh_note_list()


## 设置当前分类筛选
func agent_set_category_filter(category: String) -> void:
	if category == "":
		_current_category = ""
		_all_chip.set_selected_no_signal(true)
		for cat_name in _category_chips:
			_category_chips[cat_name].set_selected_no_signal(false)
	elif category in _category_chips:
		_current_category = category
		_all_chip.set_selected_no_signal(false)
		for cat_name in _category_chips:
			_category_chips[cat_name].set_selected_no_signal(cat_name == category)
	_refresh_note_list()
