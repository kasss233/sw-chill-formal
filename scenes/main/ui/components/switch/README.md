# Material Switch 使用指南

## 简介

`MaterialSwitch` 是一个遵循 Material Design 规范的开关组件，支持平滑滑块动画、颜色渐变效果。

## 快速开始

### 1. 运行演示场景

在 Godot 编辑器中：
1. 打开 `scenes/main/ui/components/switch/SwitchDemo.tscn`
2. 按 `F6` 或点击"运行当前场景"按钮
3. 体验各种开关类型

---

## 使用方法

### 方式一：在编辑器中配置

```
1. 在场景中添加 MaterialSwitch 节点（继承自 CheckBox）
2. 在检查器中配置属性：
   - switch_size: 开关尺寸
   - label_text: 标签文字
   - active_color: 开启状态颜色
   - inactive_color: 关闭状态颜色
   - animation_duration: 动画时长
```

### 方式二：通过代码创建和使用

#### 1. 基础开关

```gdscript
var switch = MaterialSwitch.new()
add_child(switch)

# 连接信号
switch.toggled.connect(func(pressed: bool):
	print("开关状态: ", pressed)
)
```

#### 2. 带标签的开关

```gdscript
var switch = MaterialSwitch.new()
add_child(switch)
switch.label_text = "Wi-Fi"
switch.position = Vector2(20, 20)
```

#### 3. 自定义颜色

```gdscript
var switch = MaterialSwitch.new()
add_child(switch)

# 设置颜色
switch.active_color = Color(0.3, 0.8, 0.3)    # 绿色（开启）
switch.inactive_color = Color(0.5, 0.5, 0.5)   # 灰色（关闭）
switch.thumb_color_on = Color.WHITE
switch.thumb_color_off = Color.WHITE
```

#### 4. 不同尺寸

```gdscript
var small_switch = MaterialSwitch.new()
small_switch.switch_size = MaterialSwitch.SwitchSize.SMALL32

var large_switch = MaterialSwitch.new()
large_switch.switch_size = MaterialSwitch.SwitchSize.LARGE56
```

#### 5. 带图标的开关

```gdscript
var switch = MaterialSwitch.new()
add_child(switch)
switch.label_text = "通知"
switch.show_icon = true
switch.active_icon = preload("res://icons/check.svg")
```

---

## API 参考

### 信号

| 信号 | 说明 |
|------|------|
| `toggled(pressed: bool)` | 开关状态改变时触发 |

### 主要属性

| 属性 | 类型 | 说明 |
|------|------|------|
| `switch_size` | SwitchSize | 开关尺寸 (SMALL32/STANDARD40/MEDIUM48/LARGE56) |
| `label_text` | String | 标签文字（显示在开关右侧） |
| `active_color` | Color | 开启状态颜色 |
| `inactive_color` | Color | 关闭状态颜色 |
| `thumb_color_on` | Color | 滑块开启状态颜色 |
| `thumb_color_off` | Color | 滑块关闭状态颜色 |
| `track_width` | int | 轨道宽度（像素） |
| `track_height` | int | 轨道高度（像素） |
| `thumb_size` | int | 滑块大小（像素） |
| `label_gap` | int | 标签与开关间距 |
| `show_icon` | bool | 是否显示开启状态图标 |
| `active_icon` | Texture2D | 开启状态图标 |
| `animation_duration` | float | 动画时长（秒） |
| `enable_ripple` | bool | 是否启用涟漪效果 |
| `ripple_color` | Color | 涟漪颜色 |

### 主要方法

#### `set_checked_no_signal(pressed: bool)`
设置开关状态但不发送信号

#### `toggle_switch()`
切换开关状态

#### `set_colors(on: Color, off: Color, thumb_on: Color, thumb_off: Color)`
设置开关颜色

#### `set_switch_style(sw_size: SwitchSize, label: String = "")`
设置开关样式

#### `is_switch_on() -> bool`
获取当前开关状态

---

## 开关尺寸

| 尺寸 | 宽度 | 轨道高度 | 滑块大小 | 适用场景 |
|------|------|----------|----------|----------|
| `SMALL32` | 32dp | 12dp | 16dp | 紧凑布局 |
| `STANDARD40` | 40dp | 14dp | 20dp | 默认，一般场景 |
| `MEDIUM48` | 48dp | 16dp | 24dp | 较大触摸区域 |
| `LARGE56` | 56dp | 18dp | 28dp | 大触摸区域 |

---

## 样式定制

### 自定义颜色

```gdscript
# 绿色主题
switch.active_color = Color(0.3, 0.7, 0.3)
switch.inactive_color = Color(0.6, 0.6, 0.6)

# 橙色主题
switch.active_color = Color(0.95, 0.5, 0.3)
switch.inactive_color = Color(0.5, 0.5, 0.5)

# 自定义滑块颜色
switch.thumb_color_on = Color(1, 1, 1)
switch.thumb_color_off = Color(0.9, 0.9, 0.9)
```

### 调整动画时长

```gdscript
# 快速动画
switch.animation_duration = 0.1

# 慢速动画
switch.animation_duration = 0.3
```

### 自定义尺寸

```gdscript
# 轨道宽度
switch.track_width = 50

# 轨道高度
switch.track_height = 16

# 滑块大小
switch.thumb_size = 24
```

---

## 注意事项

1. **开关继承自 CheckBox**，可以像普通 CheckBox 一样使用
2. **滑块动画使用 Tween**，确保在场景树中才能正常工作
3. **标签显示在开关右侧**，通过 `label_text` 属性设置
4. **支持涟漪效果**，可通过 `enable_ripple` 控制是否启用

---

## 文件结构

```
scenes/main/ui/components/switch/
├── MaterialSwitch.gd    # 主组件脚本
├── SwitchDemo.gd        # 演示脚本
├── SwitchDemo.tscn      # 演示场景
└── README.md            # 使用说明
```

---

## 示例代码

完整示例请参考 `SwitchDemo.gd` 和 `SwitchDemo.tscn`。
