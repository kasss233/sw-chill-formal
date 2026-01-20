# MaterialDragHandle 使用说明

## 简介

`MaterialDragHandle` 是一个**透明拖拽区域组件**，可作为子组件添加到任何 Control 中，实现拖拽移动父节点的功能。非常适合与 `FrostedPanel` 毛玻璃面板结合使用，创建可拖动的浮动窗口。

## 功能特性

- **透明设计**：完全不可见，不影响 UI 视觉效果
- **即插即用**：作为子节点添加到标题栏即可启用拖拽
- **多种边界模式**：屏幕边界、自定义矩形、父容器边界或无边界限制
- **平滑拖拽**：可选的平滑移动和透明度变化效果
- **与 FrostedPanel 完美结合**：创建可拖动的毛玻璃面板

## 快速开始

### 基本用法

```gdscript
# 创建一个可拖动的面板
var panel = Panel.new()
panel.size = Vector2(300, 200)
add_child(panel)

# 创建标题栏
var header = Control.new()
header.size = Vector2(300, 40)
panel.add_child(header)

# 添加拖拽手柄（透明，覆盖整个标题栏）
var drag_handle = MaterialDragHandle.new()
drag_handle.size = Vector2(300, 40)
header.add_child(drag_handle)
```

### 与 FrostedPanel 结合

```gdscript
# 创建容器
var container = Control.new()
container.size = Vector2(300, 200)
add_child(container)

# 添加毛玻璃背景
var frosted = FrostedPanel.new()
frosted.set_anchors_preset(Control.PRESET_FULL_RECT)
container.add_child(frosted)

# 添加标题栏和拖拽手柄
var header = Control.new()
header.position = Vector2(0, 0)
header.size = Vector2(300, 40)
container.add_child(header)

# 核心代码：透明拖拽手柄
var drag_handle = MaterialDragHandle.new()
drag_handle.set_anchors_preset(Control.PRESET_FULL_RECT)
header.add_child(drag_handle)
```

## 边界模式

| 模式 | 说明 |
|------|------|
| `BoundaryMode.SCREEN` | 限制在屏幕范围内（默认） |
| `BoundaryMode.CUSTOM_RECT` | 限制在自定义矩形范围内 |
| `BoundaryMode.PARENT_CONTAINER` | 限制在父容器范围内 |
| `BoundaryMode.NONE` | 无边界限制 |

## 可配置属性

| 属性 | 类型 | 说明 |
|------|------|------|
| `draggable` | bool | 是否启用拖拽 |
| `boundary_mode` | BoundaryMode | 边界模式 |
| `boundary_rect` | Rect2 | 自定义边界矩形 |
| `hover_cursor` | CursorShape | 鼠标悬停时光标（默认：CURSOR_MOVE） |
| `drag_scale` | float | 拖拽时的缩放效果 (0.8-1.2) |
| `drag_opacity` | float | 拖拽时的透明度 (0.2-1.0) |
| `smooth_factor` | float | 平滑因子 (0-1) |
| `visual_feedback` | bool | 是否启用视觉反馈 |
| `bounce_animation` | bool | 是否启用弹跳动画 |

## 信号

| 信号 | 参数 | 说明 |
|------|------|------|
| `drag_started` | 无 | 拖拽开始时触发 |
| `drag_ended` | 无 | 拖拽结束时触发 |
| `drag_moved` | `position: Vector2` | 拖拽移动时触发 |

## 使用示例

### 1. 基础可拖动面板

```gdscript
func create_draggable_panel():
	var panel = Panel.new()
	panel.size = Vector2(300, 200)

	# 标题栏
	var header = Control.new()
	header.size = Vector2(300, 40)
	panel.add_child(header)

	# 添加拖拽手柄
	var drag_handle = MaterialDragHandle.new()
	drag_handle.size = Vector2(300, 40)
	header.add_child(drag_handle)

	return panel
```

### 2. 带透明度效果

```gdscript
# 拖拽时面板半透明
drag_handle.drag_opacity = 0.7
```

### 3. 平滑拖拽

```gdscript
# 启用平滑移动
drag_handle.smooth_factor = 0.15
```

### 4. 自定义边界

```gdscript
# 限制在特定区域
drag_handle.boundary_mode = MaterialDragHandle.BoundaryMode.CUSTOM_RECT
drag_handle.boundary_rect = Rect2(50, 50, 400, 400)
```

## 演示场景

打开 `DragHandleDemo.tscn` 可以看到：
- 4 个可拖动的 FrostedPanel 毛玻璃面板
- 不同样式的毛玻璃效果
- 展示透明拖拽手柄的实际使用效果

## 注意事项

1. **透明设计**：拖拽手柄完全透明，通过光标变化提示可拖拽
2. **父子关系**：默认拖拽父节点，可通过 `drag_target` 指定其他目标
3. **事件捕获**：手柄使用 `MOUSE_FILTER_STOP` 确保捕获鼠标事件
4. **全局鼠标位置**：使用全局坐标避免父节点移动时的坐标偏移

## 文件结构

```
scenes/main/ui/components/drag_handle/
├── MaterialDragHandle.gd    # 拖拽手柄组件脚本
├── MaterialDragHandle.tscn  # 拖拽手柄场景
├── DragHandleDemo.gd        # 演示场景脚本（含 FrostedPanel）
├── DragHandleDemo.tscn      # 演示场景
└── README.md                # 本文档
```
