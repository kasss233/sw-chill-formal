# Material TextField 使用指南

## 简介

`MaterialTextField` 是一个遵循 Material Design 规范的输入框组件，具有完全圆角（Pill-shaped）设计、柔和阴影、图标支持和丰富的交互效果。

## 快速开始

### 1. 运行演示场景

在 Godot 编辑器中：
1. 打开 `scenes/main/ui/components/text_field/TextFieldDemo.tscn`
2. 按 `F6` 或点击"运行当前场景"按钮
3. 体验各种输入框样式

---

## 使用方法

### 方式一：在编辑器中配置

```
1. 在场景中添加 MaterialTextField 节点
2. 在检查器中配置属性：
   - placeholder_text: 占位符文本
   - text: 默认文本
   - is_password: 是否为密码框
   - bg_color, border_color: 颜色设置
   - icon: 右侧图标
   - text_field_height: 输入框高度
```

### 方式二：通过代码创建和使用

#### 1. 基础输入框

```gdscript
var text_field = MaterialTextField.new()
add_child(text_field)

# 设置占位符
text_field.placeholder_text = "请输入内容..."

# 连接信号
text_field.text_changed.connect(func(new_text: String):
	print("输入内容: ", new_text)
)

text_field.text_submitted.connect(func(submitted_text: String):
	print("提交内容: ", submitted_text)
)
```

#### 2. 密码输入框

```gdscript
var password_field = MaterialTextField.new()
add_child(password_field)

password_field.placeholder_text = "请输入密码..."
password_field.is_password = true
```

#### 3. 自定义颜色

```gdscript
var custom_field = MaterialTextField.new()
add_child(custom_field)

# 背景颜色
custom_field.bg_color = Color.WHITE
custom_field.bg_color_hover = Color(0.95, 0.95, 0.95, 1)

# 边框颜色
custom_field.border_color = Color(0.7, 0.7, 0.7, 1)
custom_field.border_color_focus = Color(0.35, 0.65, 0.95, 1)

# 图标颜色
custom_field.icon_color = Color(0.6, 0.6, 0.6, 1)
custom_field.icon_color_hover = Color(0.35, 0.65, 0.95, 1)
```

#### 4. 带图标的输入框

```gdscript
var search_field = MaterialTextField.new()
add_child(search_field)

search_field.placeholder_text = "搜索..."
search_field.icon = preload("res://icons/search.svg")
search_field.icon_size = 24
```

---

## API 参考

### 信号

| 信号 | 说明 |
|------|------|
| `text_changed(new_text: String)` | 文本内容改变时触发 |
| `text_submitted(text: String)` | 按 Enter 键提交时触发 |
| `focus_gained()` | 获得焦点时触发 |
| `focus_lost()` | 失去焦点时触发 |

### 主要属性

| 属性 | 类型 | 说明 | 默认值 |
|------|------|------|--------|
| `placeholder_text` | String | 占位符文本 | "" |
| `text` | String | 输入框文本 | "" |
| `is_password` | bool | 是否为密码框 | false |
| `max_length` | int | 最大字符长度 | 0 (无限制) |
| `bg_color` | Color | 正常背景色 | WHITE |
| `bg_color_hover` | Color | 悬停背景色 | 浅灰色 |
| `bg_color_focus` | Color | 焦点背景色 | WHITE |
| `border_color` | Color | 正常边框色 | 灰色 |
| `border_color_focus` | Color | 焦点边框色 | 蓝色 |
| `text_color` | Color | 文字颜色 | 深灰色 |
| `placeholder_color` | Color | 占位符颜色 | 灰色 |
| `icon_color` | Color | 正常图标颜色 | 灰色 |
| `icon_color_hover` | Color | 悬停图标颜色 | 蓝色 |
| `icon_color_focus` | Color | 焦点图标颜色 | 蓝色 |
| `shadow_color` | Color | 阴影颜色 | 半透明黑 |
| `shadow_size` | int | 阴影大小 | 4 |
| `shadow_offset` | Vector2 | 阴影偏移 | (0, 2) |
| `text_field_height` | int | 输入框高度 | 48 |
| `corner_radius` | int | 圆角半径 (-1 自动) | -1 |
| `border_width` | int | 边框宽度 | 1 |
| `padding_left` | int | 左内边距 | 20 |
| `padding_right` | int | 右内边距 | 48 |
| `icon` | Texture2D | 右侧图标 | null |
| `icon_size` | int | 图标大小 | 24 |

### 主要方法

#### `set_text(value: String)` / `get_text() -> String`
设置/获取输入框文本

#### `clear()`
清空输入框

#### `set_editable(value: bool)` / `is_editable() -> bool`
设置/获取是否可编辑

#### `set_placeholder(value: String)`
设置占位符文本

#### `grab_focus()` / `release_focus()`
聚焦/释放焦点

#### `set_secret(value: bool)`
设置是否为密码框

#### `has_focus() -> bool`
获取是否有焦点

#### `select_all()` / `deselect()`
全选/取消选择文本

---

## 交互效果

| 状态 | 背景色 | 边框色 | 图标色 |
|------|--------|--------|--------|
| 正常 | 白色 | 灰色 | 灰色 |
| 悬停 | 浅灰色 | 灰色 | 蓝色 |
| 焦点 | 白色 | 蓝色 | 蓝色 |

---

## 使用场景

- 搜索框
- 表单输入
- 密码输入
- 用户名输入
- 过滤器输入

---

## 注意事项

1. 组件继承自 `Control`，内部使用 `LineEdit` 进行实际输入
2. 圆角半径默认为高度的一半，形成完全圆角效果
3. 图标显示在右侧，不影响输入区域
4. 密码模式会自动使用密码图标（如果设置了图标）

---

## 文件结构

```
scenes/main/ui/components/text_field/
├── MaterialTextField.gd    # 主组件脚本
├── TextFieldDemo.gd        # 演示脚本
├── TextFieldDemo.tscn      # 演示场景
└── README.md                # 使用说明
```

---

## 示例代码

完整示例请参考 `TextFieldDemo.gd` 和 `TextFieldDemo.tscn`。
