# Material Menu 使用指南

## 快速开始

### 1. 运行演示场景

在 Godot 编辑器中：
1. 打开 `scenes/main/ui/components/menu/menu_demo.tscn`
2. 按 `F5` 或点击"运行场景"按钮
3. 体验三种菜单类型：
   - **下拉菜单按钮** - 点击按钮打开菜单
   - **右键菜单** - 在灰色区域右键点击
   - **弹出菜单** - 点击按钮在指定位置弹出

---

## 使用方法

### 方式一：在编辑器中手动添加

#### 添加 MaterialMenu
```
1. 在场景中添加 MaterialMenu 节点
2. 在其下的 ItemsContainer 节点中添加：
   - MaterialMenuItem (菜单项)
   - MaterialMenuSeparator (分隔线)
3. 在检查器中配置每个 MenuItem 的属性：
   - label_text: 菜单项文字
   - icon: 图标纹理
   - shortcut_text: 快捷键显示
   - item_type: 类型（NORMAL/CHECKABLE/SUBMENU）
```

**节点结构示例：**
```
MaterialMenu
└─ ItemsContainer (VBoxContainer)
   ├─ MaterialMenuItem (新建)
   ├─ MaterialMenuItem (打开)
   ├─ MaterialMenuSeparator
   ├─ MaterialMenuItem (保存)
   └─ MaterialMenuItem (退出)
```

---

### 方式二：通过代码添加

#### 1. 基础菜单

```gdscript
# 创建菜单
var menu = MaterialMenu.new()
add_child(menu)

# 添加菜单项
menu.add_item("新建", null, "Ctrl+N")
menu.add_item("打开", null, "Ctrl+O")
menu.add_separator()
menu.add_item("退出")

# 连接信号
menu.item_pressed.connect(func(index: int, item: MaterialMenuItem):
	print("选择了: ", item.label_text)
)

# 显示菜单
menu.popup_at_mouse()  # 在鼠标位置弹出
# 或
menu.show_menu(Vector2(100, 100))  # 在指定位置显示
```

#### 2. 下拉菜单按钮

```gdscript
# 创建菜单按钮
var menu_button = MaterialMenuButton.new()
menu_button.text = "文件"
add_child(menu_button)

# 创建菜单
menu_button.create_menu()
menu_button.add_menu_item("新建")
menu_button.add_menu_item("打开")
menu_button.add_menu_separator()
menu_button.add_check_menu_item("自动保存", true)

# 连接信号
menu_button.menu_item_pressed.connect(func(index: int, item: MaterialMenuItem):
	print("选择了: ", item.label_text)
)
```

#### 3. 右键菜单

```gdscript
# 创建右键菜单
var context_menu = MaterialContextMenu.new()
add_child(context_menu)

# 添加菜单项
context_menu.add_item("复制", null, "Ctrl+C")
context_menu.add_item("粘贴", null, "Ctrl+V")
context_menu.add_separator()
context_menu.add_item("删除")

# 附加到控件
var panel = Panel.new()
add_child(panel)
context_menu.attach_to(panel)  # 右键点击 panel 时弹出菜单
```

#### 4. 可选中菜单项

```gdscript
var menu = MaterialMenu.new()
add_child(menu)

# 添加可选中项
var check_item = menu.add_check_item("显示行号", false)

# 监听选中状态变化
menu.item_pressed.connect(func(index: int, item: MaterialMenuItem):
	if item.item_type == MaterialMenuItem.MenuItemType.CHECKABLE:
		print("选中状态: ", item.checked)
)
```

#### 5. 子菜单

```gdscript
# 创建主菜单
var main_menu = MaterialMenu.new()
add_child(main_menu)

# 创建子菜单
var sub_menu = MaterialMenu.new()
add_child(sub_menu)
sub_menu.add_item("子选项 1")
sub_menu.add_item("子选项 2")

# 添加子菜单到主菜单
main_menu.add_submenu("最近打开", sub_menu)

main_menu.popup_at_mouse()
```

---

## 常用配置

### MaterialMenu 属性

```gdscript
var menu = MaterialMenu.new()

# 尺寸
menu.menu_size = MaterialMenu.MenuSize.STANDARD  # COMPACT/STANDARD/COMFORTABLE
menu.min_width = 200
menu.max_width = 320

# 外观
menu.background_color = Color(0.15, 0.15, 0.15, 0.95)
menu.corner_radius = 8
menu.border_width = 1

# 行为
menu.auto_hide = true  # 点击菜单项后自动隐藏
menu.close_on_click_outside = true  # 点击外部关闭
```

### MaterialMenuItem 属性

```gdscript
var item = MaterialMenuItem.new()

# 基础设置
item.label_text = "菜单项"
item.icon = preload("res://icon.png")
item.shortcut_text = "Ctrl+S"

# 类型
item.item_type = MaterialMenuItem.MenuItemType.NORMAL  # NORMAL/CHECKABLE/SUBMENU
item.checked = true  # 仅 CHECKABLE 类型有效

# 外观
item.item_height = 40
item.hover_color = Color(0.4, 0.4, 0.4, 0.12)
item.disabled = false
```

---

## API 参考

### MaterialMenu 方法

```gdscript
# 添加菜单项
add_item(text: String, icon: Texture2D = null, shortcut: String = "") -> MaterialMenuItem
add_check_item(text: String, is_checked: bool = false, icon: Texture2D = null) -> MaterialMenuItem
add_submenu(text: String, sub_menu: MaterialMenu, icon: Texture2D = null) -> MaterialMenuItem
add_separator() -> MaterialMenuSeparator

# 操作菜单项
clear_items() -> void
get_item_count() -> int
get_item(index: int) -> Control
set_item_text(index: int, text: String) -> void
set_item_disabled(index: int, disabled: bool) -> void
set_item_checked(index: int, checked: bool) -> void
is_item_checked(index: int) -> bool

# 显示/隐藏
show_menu(at_position: Vector2 = Vector2.ZERO) -> void
hide_menu() -> void
popup_below(control: Control, offset: Vector2 = Vector2.ZERO) -> void
popup_beside(control: Control, offset: Vector2 = Vector2.ZERO) -> void
popup_at_mouse() -> void
```

### MaterialMenu 信号

```gdscript
signal item_pressed(index: int, item: MaterialMenuItem)  # 菜单项被点击
signal menu_closed()  # 菜单关闭
signal menu_opened()  # 菜单打开
```

### MaterialMenuItem 信号

```gdscript
signal pressed()   # 菜单项被点击
signal hovered()   # 鼠标悬停
```

---

## 高级用法

### 动态更新菜单

```gdscript
# 根据条件启用/禁用菜单项
func update_menu_state(has_selection: bool):
	menu.set_item_disabled(0, not has_selection)  # 复制
	menu.set_item_disabled(2, not has_selection)  # 剪切

# 动态修改菜单项文字
func set_language(lang: String):
	if lang == "zh":
		menu.set_item_text(0, "复制")
		menu.set_item_text(1, "粘贴")
	else:
		menu.set_item_text(0, "Copy")
		menu.set_item_text(1, "Paste")
```

### 自定义样式

```gdscript
# 深色主题
menu.background_color = Color(0.15, 0.15, 0.15, 0.95)
menu.hover_color = Color(0.3, 0.3, 0.3, 0.2)
menu.ripple_color = Color(1, 1, 1, 0.3)

# 浅色主题
menu.background_color = Color(0.95, 0.95, 0.95, 0.98)
menu.hover_color = Color(0.8, 0.8, 0.8, 0.2)
menu.ripple_color = Color(0, 0, 0, 0.1)
```

### 在特定控件下方弹出

```gdscript
# 在按钮下方弹出菜单（类似下拉框）
var button = Button.new()
button.pressed.connect(func():
	menu.popup_below(button, Vector2(0, 4))  # 下方偏移4像素
)
```

---

## 注意事项

1. **菜单层级** - 确保菜单节点添加到场景树的顶层，避免被父节点裁剪
2. **涟漪效果** - 涟漪效果仅在运行时生效，编辑器中不会显示
3. **子菜单** - 子菜单会自动管理显示/隐藏，无需手动处理
4. **信号连接** - 在编辑器中手动添加的菜单项会自动连接信号
5. **屏幕边界** - 菜单会自动检测屏幕边界并调整位置

---

## 完整示例

参考 `menu_demo.gd` 获取完整的使用示例，包括：
- 下拉菜单按钮的完整实现
- 右键菜单的配置和使用
- 动态创建和销毁菜单
- 子菜单的实现
