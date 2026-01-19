# Material Dialog 使用指南

## 简介

`MaterialDialog` 是一个遵循 Material Design 规范的对话框组件，支持多种对话框类型、自定义按钮、背景遮罩、动画效果等功能。

## 快速开始

### 1. 运行演示场景

在 Godot 编辑器中：
1. 打开 `scenes/main/ui/components/dialog/dialog_demo.tscn`
2. 按 `F5` 或点击"运行场景"按钮
3. 体验各种对话框类型：
   - **信息对话框** - 显示一般信息
   - **确认对话框** - 带"确定"和"取消"按钮
   - **警告对话框** - 显示警告信息
   - **错误对话框** - 显示错误信息
   - **自定义对话框** - 完全自定义的对话框
   - **多按钮对话框** - 包含多个自定义按钮
   - **不同尺寸对话框** - 小、中、大三种尺寸
   - **自定义内容组件** - 带输入框、数字输入、复选框等自定义 UI 组件

---

## 使用方法

### 方式一：在编辑器中配置（推荐）

#### 添加 MaterialDialog 并配置按钮

```
1. 在场景中添加 MaterialDialog 节点
2. 在检查器中配置基础属性：
   - dialog_title: 对话框标题
   - dialog_text: 对话框内容文字
   - dialog_icon: 对话框图标（可选）
   - dialog_type: 对话框类型
   - dialog_size: 对话框尺寸

3. 在检查器的 Buttons 分组中配置按钮：
   - 点击 buttons 数组，添加新的 DialogButton 资源
   - 配置每个按钮：
	 * text: 按钮文字
	 * icon: 按钮图标（可选）
	 * action_type: 按钮类型（CUSTOM/CONFIRM/CANCEL）
	 * close_on_click: 点击后是否关闭对话框
	 * background_color: 按钮背景色（可选）
	 * button_size: 按钮尺寸

4. 在代码中调用 show_dialog() 显示对话框
```

**示例：创建确认对话框**
```
1. 添加 MaterialDialog 节点
2. 设置 dialog_title = "确认操作"
3. 设置 dialog_text = "确定要执行此操作吗？"
4. 在 buttons 数组中添加两个 DialogButton：
   - 按钮1: text="确定", action_type=CONFIRM, close_on_click=true
   - 按钮2: text="取消", action_type=CANCEL, close_on_click=true
5. 在脚本中连接信号：
   dialog.dialog_confirmed.connect(_on_confirmed)
   dialog.dialog_cancelled.connect(_on_cancelled)
```

**节点结构：**
```
MaterialDialog
├─ ContentContainer (VBoxContainer)
│  ├─ IconRect (TextureRect) - 图标
│  ├─ TitleLabel (Label) - 标题
│  ├─ TextLabel (RichTextLabel) - 内容文字
│  ├─ [自定义内容] - 使用 set_custom_content() 添加的组件
│  └─ ButtonContainer (HBoxContainer) - 按钮容器
└─ CustomContent (Control) - 可选：在编辑器中添加的自定义内容节点
```

#### 编辑器中配置自定义内容

```
1. 在 MaterialDialog 下添加自定义内容节点（如 VBoxContainer、LineEdit 等）
2. 在检查器中找到 custom_content_path 属性
3. 点击下拉菜单，选择你添加的自定义内容节点
4. 运行时，该节点将替代默认的 TextLabel 显示
```

**示例：创建带输入框的对话框**

```
1. 添加 MaterialDialog 节点
2. 在 MaterialDialog 下添加 VBoxContainer 节点，命名为 "CustomInput"
3. 在 VBoxContainer 下添加：
   - Label: text = "请输入名称："
   - LineEdit: placeholder_text = "在此输入..."
4. 在检查器中设置：
   - dialog_title = "输入名称"
   - custom_content_path = NodePath("CustomInput")
5. 配置按钮数组，添加"确定"和"取消"按钮
```

---

### 方式二：通过代码创建和使用

#### 1. 基础对话框

```gdscript
# 创建对话框
var dialog = MaterialDialog.new()
add_child(dialog)

# 设置标题和内容
dialog.dialog_title = "提示"
dialog.dialog_text = "这是一个简单的对话框示例。"

# 添加按钮
dialog.add_button("确定")

# 显示对话框
dialog.show_dialog()
```

#### 2. 信息对话框

```gdscript
var dialog = MaterialDialog.new()
add_child(dialog)

# 使用便捷方法
dialog.show_info_dialog(
	"信息",
    "操作已成功完成。"
)

# 连接信号
dialog.dialog_confirmed.connect(func():
	print("用户点击了确定")
)
```

#### 3. 确认对话框

```gdscript
var dialog = MaterialDialog.new()
add_child(dialog)

dialog.show_confirm_dialog(
	"确认操作",
    "确定要删除此项目吗？此操作不可撤销。"
)

# 连接信号
dialog.dialog_confirmed.connect(func():
	print("用户确认了操作")
	# 执行删除操作
)

dialog.dialog_cancelled.connect(func():
	print("用户取消了操作")
)
```

#### 4. 自定义对话框

```gdscript
var dialog = MaterialDialog.new()
add_child(dialog)

# 设置对话框属性
dialog.dialog_title = "自定义对话框"
dialog.dialog_text = "这是一个完全自定义的对话框。"
dialog.dialog_type = MaterialDialog.DialogType.CUSTOM
dialog.dialog_size = MaterialDialog.DialogSize.MEDIUM

# 清空默认按钮
dialog.clear_buttons()

# 添加自定义按钮
var save_btn = dialog.add_button("保存", null, func():
	print("保存操作")
	dialog.hide_dialog()
)

var cancel_btn = dialog.add_button("取消", null, func():
	dialog.hide_dialog()
)

# 可以自定义按钮样式
save_btn.background_color = Color(0.2, 0.6, 0.9, 0.3)

# 显示对话框
dialog.show_dialog()
```

#### 5. 多按钮对话框

```gdscript
var dialog = MaterialDialog.new()
add_child(dialog)

dialog.dialog_title = "选择操作"
dialog.dialog_text = "请选择要执行的操作："

dialog.clear_buttons()

# 添加多个按钮，每个都有独立的回调
dialog.add_button("选项 1", null, func():
	print("选择了选项 1")
	dialog.hide_dialog()
)

dialog.add_button("选项 2", null, func():
	print("选择了选项 2")
	dialog.hide_dialog()
)

dialog.add_button("选项 3", null, func():
	print("选择了选项 3")
	dialog.hide_dialog()
)

dialog.add_button("取消", null, func():
	dialog.hide_dialog()
)

# 连接按钮按下信号（可选）
dialog.button_pressed.connect(func(index: int, text: String):
	print("按钮 %d (%s) 被按下" % [index, text])
)

dialog.show_dialog()
```

#### 6. 带自定义内容组件的对话框

使用 `set_custom_content()` 方法可以在对话框中显示自定义 UI 组件，而不是默认的文本标签。

```gdscript
var dialog = MaterialDialog.new()
add_child(dialog)
dialog.dialog_title = "输入名称"

# 创建包含标签和输入框的容器
var vbox = VBoxContainer.new()
vbox.name = "InputContent"

# 添加说明标签
var hint_label = Label.new()
hint_label.text = "请输入您的名称："
hint_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
vbox.add_child(hint_label)

# 添加输入框
var line_edit = LineEdit.new()
line_edit.placeholder_text = "在此输入..."
line_edit.custom_minimum_size = Vector2(200, 36)
vbox.add_child(line_edit)

# 设置为自定义内容
dialog.set_custom_content(vbox)

# 添加按钮
dialog.add_button("取消")
var confirm_btn = dialog.add_button("确定")
confirm_btn.pressed.connect(func():
	print("用户输入的名称: ", line_edit.text)
)

dialog.show_dialog()
```

**支持的自定义组件示例：**

- **输入框 (LineEdit)** - 单行文本输入
- **数字输入框 (SpinBox)** - 数值选择
- **复选框 (CheckBox)** - 选项开关
- **下拉菜单 (OptionMenu)** - 选项选择
- **任何 Control 子类** - 完全自定义

**布局顺序：** 标题 → 自定义内容 → 按钮

#### 7. 带图标的对话框

```gdscript
var dialog = MaterialDialog.new()
add_child(dialog)

# 设置图标
dialog.dialog_icon = preload("res://assets/ui/icons/info_48dp.svg")

dialog.show_info_dialog(
	"提示",
    "这是一个带图标的对话框。"
)
```

---

## API 参考

### 信号

| 信号 | 说明 |
|------|------|
| `dialog_confirmed()` | 对话框确认时触发（点击确定按钮） |
| `dialog_cancelled()` | 对话框取消时触发（点击取消按钮或点击背景） |
| `dialog_closed()` | 对话框关闭时触发 |
| `button_pressed(button_index: int, button_text: String)` | 任何按钮被按下时触发 |

### 主要属性

| 属性 | 类型 | 说明 |
|------|------|------|
| `dialog_type` | DialogType | 对话框类型 (INFO/WARNING/ERROR/QUESTION/CUSTOM) |
| `dialog_size` | DialogSize | 对话框尺寸 (SMALL/MEDIUM/LARGE/CUSTOM) |
| `dialog_title` | String | 对话框标题 |
| `dialog_text` | String | 对话框内容文字（支持多行） |
| `custom_content_path` | NodePath | 自定义内容节点路径（在编辑器中配置，优先于 dialog_text 显示） |
| `dialog_icon` | Texture2D | 对话框图标 |
| `buttons` | Array[DialogButton] | 在检查器中配置的按钮列表 |
| `modal` | bool | 是否模态（模态时阻止背景交互，默认 true） |
| `close_on_background_click` | bool | 是否点击背景关闭（默认 true） |
| `show_background_overlay` | bool | 是否显示背景遮罩（默认 true） |
| `overlay_fade_duration` | float | 背景遮罩渐变动画时长（默认 0.2） |
| `show_animation_duration` | float | 对话框显示动画时长（默认 0.2） |
| `hide_animation_duration` | float | 对话框隐藏动画时长（默认 0.15） |
| `background_overlay_color` | Color | 背景遮罩颜色 |
| `background_overlay_alpha` | float | 背景遮罩透明度（默认 0.5） |
| `padding` | int | 内边距 |
| `title_content_gap` | int | 标题与内容间距 |
| `content_button_gap` | int | 内容与按钮间距 |
| `button_gap` | int | 按钮间距 |

### 主要方法

#### `show_dialog()`
显示对话框（带动画效果）

#### `hide_dialog()`
隐藏对话框（带动画效果）

#### `add_button(text: String, icon: Texture2D = null, callback: Callable = Callable()) -> MaterialButton`
添加按钮到对话框
- `text`: 按钮文字
- `icon`: 按钮图标（可选）
- `callback`: 按钮点击回调（可选）
- 返回创建的 `MaterialButton` 实例

#### `set_custom_content(content_node: Control) -> bool`
设置自定义内容节点，替代默认的文本标签
- `content_node`: 要显示的自定义内容节点
- 返回设置成功返回 true

#### `clear_buttons()`
清空所有按钮

#### `show_info_dialog(title: String, text: String, icon: Texture2D = null)`
显示信息对话框（带"确定"按钮）

#### `show_confirm_dialog(title: String, text: String, icon: Texture2D = null)`
显示确认对话框（带"确定"和"取消"按钮）

#### `show_warning_dialog(title: String, text: String, icon: Texture2D = null)`
显示警告对话框（带"确定"按钮）

#### `show_error_dialog(title: String, text: String, icon: Texture2D = null)`
显示错误对话框（带"确定"按钮）

---

## 对话框类型

| 类型 | 说明 | 默认按钮 |
|------|------|----------|
| `INFO` | 信息对话框 | 确定 |
| `WARNING` | 警告对话框 | 确定 |
| `ERROR` | 错误对话框 | 确定 |
| `QUESTION` | 询问对话框 | 确定、取消 |
| `CUSTOM` | 自定义对话框 | 无（需手动添加） |

## 对话框尺寸

| 尺寸 | 宽度 | 最小高度 | 适用场景 |
|------|------|----------|----------|
| `SMALL` | 280dp | 120dp | 简单提示 |
| `MEDIUM` | 400dp | 160dp | 默认，一般对话框 |
| `LARGE` | 560dp | 200dp | 复杂内容 |
| `CUSTOM` | 自定义 | 自定义 | 特殊需求 |

## DialogButton 资源

DialogButton 是用于在检查器中配置按钮的资源类。

### DialogButton 属性

| 属性 | 类型 | 说明 |
|------|------|------|
| `text` | String | 按钮文字 |
| `icon` | Texture2D | 按钮图标（可选） |
| `action_type` | ActionType | 按钮操作类型（CUSTOM/CONFIRM/CANCEL） |
| `close_on_click` | bool | 点击后是否关闭对话框（默认 true） |
| `background_color` | Color | 按钮背景颜色（可选） |
| `button_size` | int | 按钮尺寸（SMALL32/STANDARD36/MEDIUM40/LARGE48/EXTRA_LARGE56） |

### DialogButton 操作类型

| 类型 | 说明 | 触发信号 |
|------|------|----------|
| `CUSTOM` | 自定义按钮 | `button_pressed` |
| `CONFIRM` | 确认按钮 | `dialog_confirmed` |
| `CANCEL` | 取消按钮 | `dialog_cancelled` |

---

## 样式定制

### 自定义颜色和样式

```gdscript
var dialog = MaterialDialog.new()
add_child(dialog)

# 自定义背景颜色
dialog.background_color = Color(0.2, 0.2, 0.2, 0.98)

# 自定义边框
dialog.border_color = Color(0.4, 0.4, 0.4, 0.8)
dialog.border_width = 2

# 自定义圆角
dialog.corner_radius = 16

# 自定义阴影
dialog.shadow_color = Color(0, 0, 0, 0.5)
dialog.shadow_size = 20
dialog.shadow_offset = Vector2(0, 10)

# 自定义内边距
dialog.padding = 32

# 自定义背景遮罩
dialog.background_overlay_color = Color(0, 0, 0, 0.6)
dialog.background_overlay_alpha = 0.6
```

### 自定义动画时长

```gdscript
dialog.show_animation_duration = 0.3  # 显示动画时长
dialog.hide_animation_duration = 0.2   # 隐藏动画时长
```

---

## 高级用法

### 1. 复用对话框实例

```gdscript
# 在 _ready 中创建一次，后续复用
var dialog: MaterialDialog

func _ready():
	dialog = MaterialDialog.new()
	add_child(dialog)
	dialog.dialog_confirmed.connect(_on_dialog_confirmed)

func show_some_dialog():
	dialog.dialog_title = "新标题"
	dialog.dialog_text = "新内容"
	dialog.clear_buttons()
	dialog.add_button("确定")
	dialog.show_dialog()
```

### 2. 动态内容

```gdscript
var dialog = MaterialDialog.new()
add_child(dialog)

# 使用 RichTextLabel 支持富文本
dialog.dialog_text = "[b]粗体[/b] [i]斜体[/i] [color=red]红色文字[/color]"

# 支持换行
dialog.dialog_text = "第一行\n第二行\n第三行"
```

### 3. 模态与非模态

```gdscript
# 模态对话框（默认）- 阻止背景交互
dialog.modal = true

# 非模态对话框 - 允许背景交互
dialog.modal = false
```

### 4. 背景遮罩配置

```gdscript
# 禁用背景遮罩
dialog.show_background_overlay = false

# 自定义遮罩颜色和透明度
dialog.background_overlay_color = Color(0, 0, 0, 1)  # 纯黑色
dialog.background_overlay_alpha = 0.7  # 70% 不透明度

# 调整遮罩渐变动画时长
dialog.overlay_fade_duration = 0.3
```

### 5. 禁用背景点击关闭

```gdscript
dialog.close_on_background_click = false
```

---

## 注意事项

1. **对话框会自动居中显示**，无需手动设置位置
2. **背景遮罩可配置**，通过 `show_background_overlay` 控制是否显示
3. **背景遮罩支持渐变动画**，可通过 `overlay_fade_duration` 调整动画时长
4. **按钮会自动右对齐**，遵循 Material Design 规范
5. **支持多行文字**，使用 `\n` 换行
6. **支持富文本**（通过 RichTextLabel 的 BBCode）
7. **对话框会自动管理层级**，确保显示在最上层

---

## 文件结构

```
scenes/main/ui/components/dialog/
├── MaterialDialog.gd          # 主组件脚本
├── DialogButton.gd            # 按钮配置资源类
├── DialogDemo.gd              # 演示脚本
├── DialogDemo.tscn            # 演示场景
└── README.md                  # 使用说明
```

---

## 示例代码

完整示例请参考 `dialog_demo.gd` 和 `dialog_demo.tscn`。

---

## 与 MaterialButton 的集成

MaterialDialog 使用 `MaterialButton` 作为按钮组件，因此支持所有 MaterialButton 的功能：
- 图标支持
- 涟漪效果
- 多种尺寸
- 自定义样式

```gdscript
var button = dialog.add_button("确定")
button.button_size = MaterialButton.ButtonSize.LARGE48
button.background_color = Color(0.2, 0.6, 0.9, 0.3)
button.button_icon = preload("res://assets/ui/icons/check.svg")
```

---

## 常见问题

**Q: 如何让对话框不自动居中？**  
A: 目前对话框固定居中显示，如需自定义位置，可以修改 `_center_dialog()` 方法。

**Q: 如何添加更多按钮？**  
A: 多次调用 `add_button()` 方法即可，按钮会自动排列。

**Q: 如何自定义按钮样式？**  
A: `add_button()` 返回 `MaterialButton` 实例，可以直接设置其属性。

**Q: 对话框关闭后会自动删除吗？**  
A: 不会，对话框节点会保留在场景中。如需删除，可以手动调用 `queue_free()`。
