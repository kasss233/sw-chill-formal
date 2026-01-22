extends Control
## 选择页面的按钮
@export var page_button: PackedScene
## 页面内容
@export var page: PackedScene
@onready var vbox = $VBoxContainer
@onready var inner_panel = $InnerPanel
## 数组变量，保存pagebutton名称
var page_names: Array[String] = []
## 保存页面名称和对应的页面内容
var pages: Dictionary = {}
var current_page_name: String = ""
var is_page_opened: bool = false
func _on_add_button_pressed() -> void:
	var new_page_button = page_button.instantiate() as PageButton
	vbox.add_child(new_page_button)
	new_page_button.set_page_name("新页面" + str(page_names.size() + 1))
	page_names.append(new_page_button.get_page_name())
	new_page_button.page_changed.connect(_on_page_changed)
	
func _on_page_changed(_name: String) -> void:
	if _name == current_page_name:
		return
	if is_page_opened:
		# 保存当前页面内容
		var current_page = inner_panel.get_child(0) as Page
		pages[current_page_name] = current_page.get_text()
		inner_panel.remove_child(current_page)
	current_page_name = _name
	var new_page = page.instantiate() as Page
	inner_panel.add_child(new_page)
	is_page_opened = true
	# 如果之前有保存的内容，加载它
	if pages.has(_name):
		new_page.set_text(pages[_name])
	else:
		new_page.set_text("")
