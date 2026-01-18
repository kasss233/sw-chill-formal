class_name MusicItem
extends Control

## 音乐列表项，显示单首音乐并处理相关交互

# --- 信号 ---
## 当点击播放按钮时发出，传递音乐名称
signal music_changed(p_name: String)
## 当点击选项按钮时发出，传递音乐名称
signal music_options_requested(p_name: String)
## 当点击删除按钮时发出，传递音乐名称
signal music_removed(p_name: String)
## 当音乐分类改变时发出，传递音乐名称和分类名
signal music_category_changed(p_name: String, category: String, checked: bool)

# --- 导出变量/节点引用 ---
## 音乐名称
@export var music_name: String
## 播放按钮引用
@onready var button: MaterialButton = $InnerPanel/HBoxContainer/Button


@onready var material_menu: MaterialMenu = $MaterialMenu


# --- 私有变量 ---
var _options_menu: MaterialMenu
var _category_items: Dictionary = {} # 存储分类名称和菜单项索引的映射

# --- 内置函数 ---
func _ready() -> void:
	set_music_name(music_name)
	_create_options_menu()

# --- 私有方法 ---
## 创建选项菜单
func _create_options_menu() -> void:
	_options_menu = material_menu
	
	# 添加分类选项（checkbutton）
	# 注意：只添加"收藏"分类，其他分类在创建后动态添加
	var categories = ["收藏"]
	for category in categories:
		var current_index = _options_menu.get_item_count()
		_options_menu.add_check_item(category, false)
		_category_items[category] = current_index
	
	# 添加分割线
	_options_menu.add_separator()
	
	# 添加删除选项
	var delete_index = _options_menu.get_item_count()
	var delete_icon = preload("res://assets/ui/icons/delete_forever_24dp_FFFFFF_FILL0_wght400_GRAD0_opsz24.svg")
	_options_menu.add_item("删除", delete_icon, "")
	
	# 连接菜单项点击信号
	_options_menu.item_pressed.connect(_on_menu_item_pressed)

# --- 公有 API ---
## 设置显示的音乐名称
func set_music_name(p_name: String) -> void:
	music_name = p_name
	if button:
		button.text = music_name

## 获取当前项的音乐名称
func get_music_name() -> String:
	return music_name

## 触发播放逻辑
func play_music() -> void:
	music_changed.emit(music_name)

func remove_music() -> void:
	music_removed.emit(music_name)

## 设置分类的勾选状态
func set_category_checked(category: String, checked: bool) -> void:
	if category in _category_items and _options_menu:
		var item_index = _category_items[category] as int
		_options_menu.set_item_checked(item_index, checked)

## 获取分类的勾选状态
func get_category_checked(category: String) -> bool:
	if category in _category_items and _options_menu:
		var item_index = _category_items[category] as int
		return _options_menu.is_item_checked(item_index)
	return false
# --- 信号回调 ---
func _on_button_pressed() -> void:
	play_music()
'''
func _on_option_button_pressed() -> void:
	# 获取 option button 的引用并在其下方弹出菜单
	var option_button = get_node_or_null("HBoxContainer/OptionButton")
	if option_button and _options_menu:
		_options_menu.popup_below(option_button)
	else:
		music_options_requested.emit(music_name)
'''
func _on_remove_button_pressed() -> void:
	remove_music()

func _on_menu_item_pressed(index: int, item: MaterialMenuItem) -> void:
	# 检查是否是分类选项
	for category in _category_items:
		if _category_items[category] == index:
			var checked = _options_menu.is_item_checked(index)
			music_category_changed.emit(music_name, category, checked)
			return
	
	# 检查是否是删除选项（分隔符占一个索引，删除选项在分类之后）
	var delete_index = _category_items.size() + 1  # +1 是因为分隔符
	if index == delete_index:
		remove_music()
