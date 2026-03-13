class_name NoteBookMobile
extends Control

## 移动端笔记模块（UI Module）
## 管理二级菜单：笔记列表 ↔ 笔记编辑页
## 支持分类筛选、搜索、防抖保存
## 监听 NoteState 信号响应式更新 UI

# --- 节点引用 ---
@onready var _frosted_panel: PanelContainer = %FrostedPanel
@onready var _header_button: Button = %MaterialButton
@onready var _scroll_container: ScrollContainer = %SmoothScrollContainer
@onready var _search_field: Control = %MaterialTextField
@onready var _chips_container: HBoxContainer = %HBoxContainer2
@onready var _all_chip: Control = %AllChip
@onready var _items_container: VBoxContainer = %NoteItemsContainer
@onready var _list_container: VBoxContainer = %VBoxContainer
@onready var _note_container: VBoxContainer = %NoteVBoxContainer
@onready var _back_button: Button = %BackButton
@onready var _note_menu: MaterialMenu = %MaterialMenu
@onready var _list_menu: MaterialMenu = %MaterialMenu2

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
var _category_submenu: MaterialMenu = null
var _delete_category_submenu: MaterialMenu = null
var _delete_category_dialog: MaterialDialog = null
var _pending_delete_category: String = ""
var _delete_dialog: MaterialDialog = null
var _add_category_dialog: MaterialDialog = null
var _add_category_input: LineEdit = null
var _updating_chips: bool = false


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
	NoteState.agent_note_created.connect(_on_agent_note_created)
	NoteState.agent_content_written.connect(_on_agent_content_written)
	NoteState.agent_open_note_requested.connect(_on_agent_open_note_requested)
	NoteState.agent_close_note_requested.connect(_on_agent_close_note_requested)

	# 连接菜单信号
	_note_menu.item_pressed.connect(_on_note_menu_item_pressed)
	_list_menu.item_pressed.connect(_on_list_menu_item_pressed)
	_note_menu.menu_opened.connect(_on_note_menu_opened)
	_note_menu.menu_closed.connect(_on_note_menu_closed)
	_list_menu.menu_closed.connect(_on_list_menu_closed)

	# 初始化子菜单和对话框
	_setup_category_submenu()
	_setup_delete_category_submenu()
	_setup_dialogs()

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

	# 清理已有页面（防止资源泄漏）
	if _current_page:
		_save_current_page()
		_save_timer.stop()
		_current_page.stop_typing()
		_current_page.queue_free()
		_current_page = null

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
func _close_page(skip_save: bool = false) -> void:
	if _current_page == null:
		return

	if not skip_save:
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


# ======================== 菜单与对话框 ========================

## 初始化笔记页"分类"子菜单（悬停显示）
func _setup_category_submenu() -> void:
	_category_submenu = MaterialMenu.new()
	_category_submenu.min_width = 160
	add_child(_category_submenu)
	_category_submenu.item_pressed.connect(_on_category_submenu_item_pressed)
	_rebuild_category_submenu()

	# 将编辑器中的"分类"项（index 3）设置为子菜单类型
	var category_item = _note_menu.get_item(3) as MaterialMenuItem
	if category_item:
		category_item.set_submenu(_category_submenu, _note_menu.default_submenu_arrow)
		_category_submenu._parent_menu = _note_menu
		_category_submenu.visible = false


## 初始化列表"删除分类"子菜单（悬停显示）
func _setup_delete_category_submenu() -> void:
	_delete_category_submenu = MaterialMenu.new()
	_delete_category_submenu.min_width = 160
	add_child(_delete_category_submenu)
	_delete_category_submenu.item_pressed.connect(_on_delete_category_submenu_item_pressed)
	_rebuild_delete_category_submenu()

	# 将编辑器中的"删除分类"项（index 1）设置为子菜单类型
	var delete_cat_item = _list_menu.get_item(1) as MaterialMenuItem
	if delete_cat_item:
		delete_cat_item.set_submenu(_delete_category_submenu, _list_menu.default_submenu_arrow)
		_delete_category_submenu._parent_menu = _list_menu
		_delete_category_submenu.visible = false


## 初始化对话框
func _setup_dialogs() -> void:
	# 删除笔记确认对话框
	_delete_dialog = MaterialDialog.new()
	add_child(_delete_dialog)
	_delete_dialog.dialog_confirmed.connect(_on_delete_note_confirmed)

	# 删除分类确认对话框
	_delete_category_dialog = MaterialDialog.new()
	add_child(_delete_category_dialog)
	_delete_category_dialog.dialog_confirmed.connect(_on_delete_category_confirmed)

	# 添加分类对话框
	_add_category_dialog = MaterialDialog.new()
	add_child(_add_category_dialog)

	_add_category_input = LineEdit.new()
	_add_category_input.placeholder_text = "输入分类名称"
	_add_category_input.custom_minimum_size = Vector2(0, 36)
	_add_category_dialog.set_custom_content(_add_category_input)
	_add_category_dialog.dialog_confirmed.connect(_on_add_category_confirmed)


## 重建分类子菜单项（使用 check item）
func _rebuild_category_submenu() -> void:
	if not _category_submenu:
		return
	_category_submenu.clear_items()
	for cat in NoteState.get_categories():
		_category_submenu.add_check_item(cat, false)


## 重建删除分类子菜单项
func _rebuild_delete_category_submenu() -> void:
	if not _delete_category_submenu:
		return
	_delete_category_submenu.clear_items()
	for cat in NoteState.get_categories():
		_delete_category_submenu.add_item(cat)


## 笔记页菜单点击回调
func _on_note_menu_item_pressed(index: int, _item: MaterialMenuItem) -> void:
	match index:
		1:  # 删除
			_delete_dialog.show_confirm_dialog("删除笔记", "确定要删除这篇笔记吗？")


## 列表菜单点击回调
func _on_list_menu_item_pressed(index: int, _item: MaterialMenuItem) -> void:
	match index:
		0:  # 添加分类
			_add_category_input.text = ""
			_add_category_dialog.show_confirm_dialog("添加分类", "")


## 分类子菜单点击回调（切换笔记分类）
func _on_category_submenu_item_pressed(_index: int, item: MaterialMenuItem) -> void:
	if _current_page == null:
		return
	var note_id = _current_page.get_note_id()
	NoteState.toggle_note_category(note_id, item.label_text)


## 删除分类子菜单点击回调
func _on_delete_category_submenu_item_pressed(_index: int, item: MaterialMenuItem) -> void:
	_pending_delete_category = item.label_text
	_delete_category_dialog.show_confirm_dialog("删除分类", "确定要删除分类「%s」吗？\n该分类下的笔记不会被删除。" % item.label_text)


## 删除分类确认回调
func _on_delete_category_confirmed() -> void:
	if _pending_delete_category != "":
		NoteState.remove_category(_pending_delete_category)
		_pending_delete_category = ""


## 删除笔记确认回调
func _on_delete_note_confirmed() -> void:
	if _current_page == null:
		return
	var note_id = _current_page.get_note_id()
	NoteState.remove_note(note_id)
	_close_page(true)


## 添加分类确认回调
func _on_add_category_confirmed() -> void:
	var cat_name = _add_category_input.text.strip_edges()
	if cat_name != "":
		NoteState.add_category(cat_name)


## 笔记页菜单打开时，同步分类子菜单的勾选状态
func _on_note_menu_opened() -> void:
	_update_category_submenu_checks()


## 更新分类子菜单的 check 状态
func _update_category_submenu_checks() -> void:
	if _current_page == null or not _category_submenu:
		return
	var note = NoteState.get_note_by_id(_current_page.get_note_id())
	if note == null:
		return
	var categories = NoteState.get_categories()
	for i in range(categories.size()):
		_category_submenu.set_item_checked(i, categories[i] in note.categories)


## 笔记页菜单关闭后，将子菜单从 MenuCanvasLayer 救回
func _on_note_menu_closed() -> void:
	_rescue_submenu(_category_submenu)


## 列表菜单关闭后，将子菜单从 MenuCanvasLayer 救回
func _on_list_menu_closed() -> void:
	_rescue_submenu(_delete_category_submenu)


## 将子菜单从即将销毁的 MenuCanvasLayer 移回 self
func _rescue_submenu(submenu: MaterialMenu) -> void:
	if submenu and is_instance_valid(submenu) and submenu.get_parent() != self:
		if submenu.get_parent():
			submenu.get_parent().remove_child(submenu)
		add_child(submenu)
		submenu.visible = false


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
	if _updating_chips:
		return
	_updating_chips = true
	if is_selected:
		_current_category = ""
		for cat_name in _category_chips:
			_category_chips[cat_name].set_selected_no_signal(false)
		_refresh_note_list()
	else:
		# 不允许取消选中"全部"（至少一个选中）
		_all_chip.set_selected_no_signal(true)
	_updating_chips = false


func _on_category_chip_selected(is_selected: bool, category: String) -> void:
	if _updating_chips:
		return
	_updating_chips = true
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
	_updating_chips = false


func _on_page_title_changed(_new_title: String) -> void:
	_save_timer.start()


func _on_page_content_changed(_new_content: String) -> void:
	# 打字动画期间不启动保存（避免保存部分内容）
	if _current_page and _current_page.is_typing():
		return
	_save_timer.start()


# ======================== NoteState 信号回调 ========================

func _on_note_added(_note: NoteData) -> void:
	if not _is_page_open:
		_refresh_note_list()


func _on_note_removed(_note_id: int) -> void:
	if not _is_page_open:
		_refresh_note_list()


func _on_note_updated(note: NoteData) -> void:
	if _is_page_open and _current_page and _current_page.get_note_id() == note.id:
		# 页面打开时，仅在内容确实不同时才刷新（避免 save_timer 保存后的循环）
		if _current_page.get_title() != note.title or _current_page.get_content() != note.content:
			_current_page.stop_typing()
			_current_page.load_note(note)
		return
	if not _is_page_open:
		_refresh_note_list()


func _on_data_loaded() -> void:
	_refresh_categories()
	_refresh_note_list()


func _on_category_added(_category: String) -> void:
	_refresh_categories()
	_rebuild_category_submenu()
	_rebuild_delete_category_submenu()


func _on_category_removed(_category: String) -> void:
	if _current_category == _category:
		_current_category = ""
		_all_chip.set_selected_no_signal(true)
	_refresh_categories()
	_refresh_note_list()
	_rebuild_category_submenu()
	_rebuild_delete_category_submenu()


func _on_agent_note_created(note: NoteData) -> void:
	_open_page(note.id)
	# 等一帧让 NotePage @onready 初始化
	await get_tree().process_frame
	if _current_page and note.content != "":
		_current_page.set_content(note.content, true)


func _on_agent_content_written(note_id: int, content: String) -> void:
	# 如果当前正在编辑这个笔记，直接播放打字动画
	if _is_page_open and _current_page and _current_page.get_note_id() == note_id:
		_current_page.set_content(content, true)
		return
	# 否则先打开笔记再播放
	_open_page(note_id)
	await get_tree().process_frame
	if _current_page:
		_current_page.set_content(content, true)


func _on_agent_open_note_requested(note_id: int) -> void:
	_open_page(note_id)


func _on_agent_close_note_requested() -> void:
	if _is_page_open:
		_close_page()
