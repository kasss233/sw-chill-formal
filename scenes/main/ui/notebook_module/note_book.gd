class_name NoteBook
extends Control
## 选择页面的按钮
@export var page_button: PackedScene
## 页面内容
@export var page: PackedScene
@export_category("子节点")
@export var vbox: VBoxContainer
@export var inner_panel: InnerPanel
@export var panel: FrostedPanel
@export var button: MaterialToggleButton
## 数组变量，保存pagebutton名称
var page_names: Array[String] = []
## 保存页面按钮和对应的页面内容
var pages: Dictionary = {}
var current_page_btn: PageButton = null
var is_page_opened: bool = false

func _ready() -> void:
	panel.visible = false
	inner_panel.visible = false
	#add_page_and_open("123","dsadasdawdwa")
	#panel.visible = true
	#add_page_and_open("欢迎页", "欢迎使用笔记本模块！\n\n点击“+”按钮添加新页面。")


func add_page_and_open(_name: String, _content: String) -> void:
	if button.current_state == 0:
		button.set_state(1)
	var new_page_button = add_page(_name)
	# 设置页面内容
	pages[new_page_button] = _content
	# 自动打开新添加的页面
	change_page(_name, new_page_button, true)

func add_page(_name: String) -> PageButton:
	var new_page_button = page_button.instantiate() as PageButton
	vbox.add_child(new_page_button)
	new_page_button.set_page_name(_name)
	page_names.append(new_page_button.get_page_name())
	new_page_button.page_changed.connect(_on_page_changed.bind(new_page_button))
	new_page_button.page_removed.connect(_on_page_removed.bind(new_page_button))
	return new_page_button
func change_page(_name: String, btn: PageButton, animate: bool = false) -> void:
	inner_panel.visible = true
	btn.select_button(false)
	if btn == current_page_btn:
		return
	if is_page_opened:
		# 保存当前页面内容
		if inner_panel.get_child_count() > 0:
			var current_page = inner_panel.get_child(0) as Page
			if current_page:
				pages[current_page_btn] = current_page.get_text()
				inner_panel.remove_child(current_page)
				current_page.queue_free() # 记得释放内存
	current_page_btn = btn
	var new_page = page.instantiate() as Page
	inner_panel.add_child(new_page)
	is_page_opened = true
	# 如果之前有保存的内容，加载它
	if pages.has(btn):
		new_page.set_text(pages[btn], animate)
	else:
		new_page.set_text("", animate)

func _on_add_button_pressed() -> void:
	var base_name = "新页面"
	var new_name = base_name
	var counter = 1
	while page_names.has(new_name):
		new_name = base_name + str(counter)
		counter += 1
	var new_page_button = add_page(new_name)
	change_page(new_name, new_page_button)
func _on_page_changed(_name: String, btn: PageButton) -> void:
	change_page(_name, btn)
func _on_page_removed(_name: String, btn: PageButton) -> void:
	# 如果删除的是当前页面，清空内容区域
	print("Removing page: ", _name)
	if btn == current_page_btn:
		if inner_panel.get_child_count() > 0:
			var current_page = inner_panel.get_child(0)
			inner_panel.remove_child(current_page)
			if current_page:
				current_page.queue_free()
		is_page_opened = false
		current_page_btn = null
		inner_panel.visible = false
	
	# 从页面名称数组和内容字典中移除
	# 由于名称可能已被用户修改，这里通过find来删除更稳妥
	var actual_name = _name
	if btn.has_method("get_page_name"):
		actual_name = btn.get_page_name()
	
	var idx = page_names.find(actual_name)
	if idx != -1:
		page_names.remove_at(idx)
	else:
		page_names.erase(_name)
		
	pages.erase(btn)
	
	# 从VBoxContainer中移除对应的PageButton
	if btn.get_parent():
		btn.get_parent().remove_child(btn)
	btn.queue_free()


func _on_material_button_state_changed(_old_state: int, new_state: int) -> void:
	match new_state:
		0: GuiTransitions.hide("notebook")
		1: GuiTransitions.show("notebook")
