@tool
class_name MaterialDropdown
extends MaterialMenuButton

## Material Design 下拉选择框
## 继承 MaterialMenuButton，提供下拉框语义 API（value 绑定、placeholder、selection_changed 信号）

## 选中项变更时发射，携带索引和值
signal selection_changed(index: int, value: Variant)

@export_group("下拉框")

## 未选中时的占位文本
@export var placeholder: String = "":
	set(value):
		placeholder = value
		if selected_index == -1:
			_show_placeholder()

## 编辑器中配置选项列表
@export var editor_options: Array[DropdownOption] = []:
	set(value):
		editor_options = value
		if is_inside_tree():
			_rebuild_from_editor_options()

@export_group("")

# 内部选项数据
var _options: Array[DropdownOption] = []

func _ready() -> void:
	# 强制启用选中同步
	sync_selected_item = true

	super._ready()

	# 从编辑器选项初始化
	if editor_options.size() > 0:
		_rebuild_from_editor_options()

	# 显示 placeholder
	if selected_index == -1:
		_show_placeholder()

	# 监听父类的菜单项点击信号
	if not menu_item_pressed.is_connected(_on_dropdown_item_pressed):
		menu_item_pressed.connect(_on_dropdown_item_pressed)

## 添加一个选项，返回索引
func add_option(label: String, value: Variant = null, icon: Texture2D = null) -> int:
	var option := DropdownOption.new()
	option.label = label
	option.value = value if value != null else label
	option.icon = icon
	_options.append(option)

	add_menu_item(label, icon)

	return _options.size() - 1

## 移除指定索引的选项
func remove_option(index: int) -> void:
	if index < 0 or index >= _options.size():
		return

	_options.remove_at(index)

	# 重建菜单
	_rebuild_menu_items()

	# 调整选中索引
	if selected_index == index:
		selected_index = -1
		_show_placeholder()
		selection_changed.emit(-1, null)
	elif selected_index > index:
		selected_index -= 1

## 清空所有选项
func clear_options() -> void:
	_options.clear()
	clear_menu()
	selected_index = -1
	_show_placeholder()

## 获取当前选中值
func get_selected_value() -> Variant:
	if selected_index < 0 or selected_index >= _options.size():
		return null
	return _options[selected_index].value

## 获取当前选中标签
func get_selected_label() -> String:
	if selected_index < 0 or selected_index >= _options.size():
		return ""
	return _options[selected_index].label

## 按 value 选中
func set_selected_by_value(value: Variant) -> void:
	for i in range(_options.size()):
		if _options[i].value == value:
			set_selected_by_index(i)
			return

## 按 index 选中
func set_selected_by_index(index: int) -> void:
	if index < 0 or index >= _options.size():
		return
	selected_index = index
	selection_changed.emit(index, _options[index].value)

## 获取选项数量
func get_option_count() -> int:
	return _options.size()

# ============ 内部方法 ============

func _show_placeholder() -> void:
	if placeholder != "":
		text = placeholder
	elif _original_text != "":
		text = _original_text

func _on_dropdown_item_pressed(index: int, _item: MaterialMenuItem) -> void:
	if index >= 0 and index < _options.size():
		selection_changed.emit(index, _options[index].value)

func _rebuild_from_editor_options() -> void:
	_options.clear()
	clear_menu()

	for opt in editor_options:
		if opt == null:
			continue
		var option := DropdownOption.new()
		option.label = opt.label
		option.value = opt.value if opt.value != "" else opt.label
		option.icon = opt.icon
		_options.append(option)
		add_menu_item(opt.label, opt.icon)

	if selected_index == -1:
		_show_placeholder()

func _rebuild_menu_items() -> void:
	clear_menu()
	for opt in _options:
		add_menu_item(opt.label, opt.icon)

## 重写父类的选中同步显示，增加 placeholder 逻辑
func _sync_selected_item_display() -> void:
	if selected_index == -1:
		_show_placeholder()
		return
	super._sync_selected_item_display()
