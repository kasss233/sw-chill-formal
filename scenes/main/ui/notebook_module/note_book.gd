extends Control
## 选择页面的按钮
@export var page_button: PackedScene
## 页面内容
@export var page: PackedScene
@export_category("子节点")
@export var vbox: VBoxContainer
@export var inner_panel: InnerPanel
@export var panel: FrostedPanel
## 数组变量，保存pagebutton名称
var page_names: Array[String] = []
## 保存页面按钮和对应的页面内容
var pages: Dictionary = {}
var current_page_btn: PageButton = null
var is_page_opened: bool = false

func _ready() -> void:
	panel.visible = false

func _on_add_button_pressed() -> void:
	var new_page_button = page_button.instantiate() as PageButton
	vbox.add_child(new_page_button)
	
	var base_name = "新页面"
	var new_name = base_name
	var counter = 1
	while page_names.has(new_name):
		new_name = base_name + str(counter)
		counter += 1
		
	new_page_button.set_page_name(new_name)
	page_names.append(new_page_button.get_page_name())
	new_page_button.page_changed.connect(_on_page_changed.bind(new_page_button))
	new_page_button.page_removed.connect(_on_page_removed.bind(new_page_button))
func _on_page_changed(_name: String, btn: PageButton) -> void:
	if btn == current_page_btn:
		return
	if is_page_opened:
		# 保存当前页面内容
		var current_page = inner_panel.get_child(0) as Page
		pages[current_page_btn] = current_page.get_text()
		inner_panel.remove_child(current_page)
	current_page_btn = btn
	var new_page = page.instantiate() as Page
	inner_panel.add_child(new_page)
	is_page_opened = true
	# 如果之前有保存的内容，加载它
	if pages.has(btn):
		new_page.set_text(pages[btn])
	else:
		new_page.set_text("")
func _on_page_removed(_name: String, btn: PageButton) -> void:
	# 如果删除的是当前页面，清空内容区域
	if btn == current_page_btn:
		var current_page = inner_panel.get_child(0) as Page
		inner_panel.remove_child(current_page)
		is_page_opened = false
		current_page_btn = null
	# 从页面名称数组和内容字典中移除
	page_names.erase(_name)
	pages.erase(btn)
	# 从VBoxContainer中移除对应的PageButton
	vbox.remove_child(btn)
	btn.queue_free()
func _on_material_button_pressed() -> void:
	panel.visible = not panel.visible
