# Material Segmented Button 使用指南

## 简介

`MaterialSegmentedButton` 是一个遵循 Material Design 规范的分段选择器组件，采用胶囊形状设计，支持平滑的滑动动画效果。

## 快速开始

### 1. 运行演示场景

在 Godot 编辑器中：
1. 打开 `scenes/main/ui/components/segmented_button/SegmentedButtonDemo.tscn`
2. 按 `F6` 或点击"运行当前场景"按钮
3. 体验各种分段选择器样式

---

## 使用方法

### 方式一：在编辑器中配置

```
1. 在场景中添加 MaterialSegmentedButton 节点
2. 在检查器中配置属性：
   - editor_segments: 选项文本数组
   - background_color: 背景颜色
   - selected_color: 选中项背景颜色
   - corner_radius: 圆角半径
   - button_height: 按钮高度
```

### 方式二：通过代码创建和使用

#### 1. 基础分段选择器

```gdscript
var segmented = MaterialSegmentedButton.new()
add_child(segmented)

# 添加选项
segmented.add_segment("日")
segmented.add_segment("周")
segmented.add_segment("月")

# 设置默认选中
segmented.selected_index = 0

# 连接信号
segmented.segment_selected.connect(func(index: int, text: String):
	print("选择了: ", text, " 索引: ", index)
)
```

#### 2. 自定义颜色样式

```gdscript
var segmented = MaterialSegmentedButton.new()
add_child(segmented)

# 背景颜色（深色胶囊）
segmented.background_color = Color(0.15, 0.15, 0.15, 1)

# 选中项颜色（蓝色高亮）
segmented.selected_color = Color(0.35, 0.65, 0.95, 1)

# 文字颜色
segmented.unselected_color = Color(0.7, 0.7, 0.7, 1)
segmented.selected_text_color = Color.WHITE

# 圆角和尺寸
segmented.corner_radius = 20
segmented.button_height = 36

# 添加选项
segmented.add_segment("选项1")
segmented.add_segment("选项2")
```

#### 3. 动态添加/移除选项

```gdscript
# 添加新选项
segmented.add_segment("新选项")

# 移除指定索引的选项
segmented.remove_segment(0)

# 清空所有选项
segmented.clear_segments()

# 获取选项数量
var count = segmented.get_segment_count()
```

---

## API 参考

### 信号

| 信号 | 说明 |
|------|------|
| `segment_selected(index: int, text: String)` | 选中项改变时触发 |

### 主要属性

| 属性 | 类型 | 说明 |
|------|------|------|
| `editor_segments` | Array[String] | 编辑器配置的选项 |
| `selected_index` | int | 当前选中索引 (-1 表示未选中) |
| `background_color` | Color | 背景颜色 |
| `selected_color` | Color | 选中项背景颜色 |
| `unselected_color` | Color | 未选中文字颜色 |
| `selected_text_color` | Color | 选中文字颜色 |
| `corner_radius` | int | 圆角半径 |
| `button_height` | int | 按钮高度 |
| `min_button_width` | int | 按钮最小宽度 |
| `button_gap` | int | 按钮间距 |
| `enable_slide_animation` | bool | 是否启用滑块动画 |
| `animation_duration` | float | 动画时长 |

### 主要方法

#### `add_segment(text: String) -> int`
添加选项，返回添加的索引

#### `remove_segment(index: int) -> void`
移除指定索引的选项

#### `clear_segments() -> void`
清空所有选项

#### `get_segment_count() -> int`
获取选项数量

#### `get_segment_text(index: int) -> String`
获取指定索引的选项文本

#### `set_segment_text(index: int, text: String) -> void`
设置指定索引的选项文本

#### `get_selected_index() -> int`
获取当前选中的索引

#### `get_selected_text() -> String`
获取当前选中的文本

#### `set_selected_no_signal(index: int) -> void`
设置选中项但不发送信号

---

## 样式定制

### 自定义颜色主题

```gdscript
# 绿色主题
segmented.background_color = Color(0.1, 0.2, 0.1, 1)
segmented.selected_color = Color(0.3, 0.8, 0.4, 1)

# 橙色主题
segmented.background_color = Color(0.2, 0.15, 0.1, 1)
segmented.selected_color = Color(0.95, 0.5, 0.3, 1)

# 紫色主题
segmented.background_color = Color(0.15, 0.1, 0.2, 1)
segmented.selected_color = Color(0.7, 0.3, 0.9, 1)
```

### 调整尺寸

```gdscript
# 更大的按钮
segmented.button_height = 48
segmented.min_button_width = 120
segmented.corner_radius = 24

# 紧凑按钮
segmented.button_height = 28
segmented.min_button_width = 60
segmented.corner_radius = 14
```

### 动画设置

```gdscript
# 禁用动画（快速响应）
segmented.enable_slide_animation = false

# 自定义动画时长
segmented.animation_duration = 0.15  # 更快
segmented.animation_duration = 0.4   # 更慢
```

---

## 使用场景

- **视图切换**: 日/周/月视图切换
- **过滤选项**: 全部/未完成/已完成
- **单位选择**: 小/中/大
- **模式切换**: 编辑/预览/代码
- **时间范围**: 1小时/24小时/7天

---

## 注意事项

1. 组件继承自 `HBoxContainer`，可以像普通容器一样布局
2. 滑块动画使用 Tween，确保在场景树中才能正常工作
3. 至少需要两个选项才能体现分段选择器的作用
4. 编辑器模式下可以直接在 `editor_segments` 数组中配置选项

---

## 文件结构

```
scenes/main/ui/components/segmented_button/
├── MaterialSegmentedButton.gd    # 主组件脚本
├── SegmentedButtonDemo.gd        # 演示脚本
├── SegmentedButtonDemo.tscn      # 演示场景
└── README.md                      # 使用说明
```

---

## 示例代码

完整示例请参考 `SegmentedButtonDemo.gd` 和 `SegmentedButtonDemo.tscn`。
