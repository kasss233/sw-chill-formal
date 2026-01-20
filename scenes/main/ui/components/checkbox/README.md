# MaterialCheckbox 使用说明

## 简介

`MaterialCheckbox` 是一个遵循 Material Design 规范的复选框组件，支持自定义图标、涟漪效果和多种尺寸。

## 基本使用

### 1. 在场景中添加节点

可以通过以下方式添加 MaterialCheckbox：
- 在场景编辑器中创建一个新的 CheckBox 节点
- 将脚本 `MaterialCheckbox.gd` 附加到节点上

### 2. 设置图标

**必须手动设置未选中和选中状态的图标：**

```gdscript
# 在检查器中设置，或通过代码：
$MaterialCheckbox.unchecked_icon = preload("res://path/to/unchecked_icon.svg")
$MaterialCheckbox.checked_icon = preload("res://path/to/checked_icon.svg")
```

推荐使用 Material Design 图标：
- 未选中：`check_box_outline_blank` 或 `radio_button_unchecked`
- 选中：`check_box` 或 `radio_button_checked`

### 3. 配置属性

| 属性 | 类型 | 说明 |
|------|------|------|
| `checkbox_size` | CheckboxSize | 复选框尺寸 (SMALL32/STANDARD36/MEDIUM40/LARGE48/EXTRA_LARGE56) |
| `unchecked_icon` | Texture2D | 未选中状态图标 |
| `checked_icon` | Texture2D | 选中状态图标 |
| `icon_size` | int | 图标大小，0 表示自动 |
| `icon_text_gap` | int | 图标与文字间距 |
| `enable_ripple` | bool | 是否启用涟漪效果 |
| `ripple_color` | Color | 涟漪颜色 |
| `background_color` | Color | 背景颜色 |
| `corner_radius` | int | 圆角半径，-1 表示自动 |
| `padding_horizontal` | int | 水平内边距 |
| `padding_vertical` | int | 垂直内边距 |
| `checked_color` | Color | 选中状态图标颜色 |
| `unchecked_color` | Color | 未选中状态图标颜色 |

## 代码示例

### 基本用法

```gdscript
extends Control

@onready var checkbox = $MaterialCheckbox

func _ready():
	# 设置图标
	checkbox.unchecked_icon = preload("res://assets/ui/checkbox_unchecked.svg")
	checkbox.checked_icon = preload("res://assets/ui/checkbox_checked.svg")
	
	# 设置文本
	checkbox.text = "启用功能"
	
	# 监听状态变化
	checkbox.toggled.connect(_on_checkbox_toggled)

func _on_checkbox_toggled(pressed: bool):
	print("复选框状态: ", pressed)
```

### 自定义样式

```gdscript
# 设置 filled 风格
checkbox.set_filled_style(Color(0.2, 0.4, 0.8))

# 设置 outlined 风格
checkbox.set_outlined_style(Color(0.4, 0.6, 1.0), 2)

# 设置 text 风格
checkbox.set_text_style(Color(0.4, 0.6, 1.0))

# 设置选中/未选中颜色
checkbox.set_state_colors(Color.GREEN, Color.GRAY)
```

### 快速设置

```gdscript
checkbox.set_material_style(
	MaterialCheckbox.CheckboxSize.MEDIUM40,
	preload("res://assets/ui/checked.svg"),
	preload("res://assets/ui/unchecked.svg"),
    "同意条款"
)
```

## 尺寸参考

| 尺寸 | 高度 | 默认图标大小 | 适用场景 |
|------|------|--------------|----------|
| SMALL32 | 32dp | 18dp | 紧凑列表 |
| STANDARD36 | 36dp | 20dp | 默认，表单项 |
| MEDIUM40 | 40dp | 24dp | 设置页面 |
| LARGE48 | 48dp | 24dp | 突出显示 |
| EXTRA_LARGE56 | 56dp | 28dp | 主要操作 |

## 与 MaterialButton 共享的功能

MaterialCheckbox 与 MaterialButton 共享以下特性：
- 涟漪效果 (通过 `MaterialRippleMixin` 实现)
- Material Design 尺寸规范
- 样式配置方法 (filled/outlined/text)
- 圆角和内边距配置

## 文件结构

```
scenes/main/ui/components/
├── shared/
│   ├── MaterialRippleMixin.gd    # 涟漪效果混入类
│   └── MaterialSizeConfig.gd     # 尺寸配置工具类
├── button/
│   ├── MaterialButton.gd
│   └── ripple.gdshader
└── checkbox/
	├── MaterialCheckbox.gd
	└── README.md
```
