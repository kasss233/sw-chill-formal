# 数据可视化图表模块

Godot 4.6 下基于 `Control._draw()` 的条形图、折线图、饼图组件，支持样式配置。**支持 @tool 编辑器实时预览**：修改任意图表的 `chart_style` 或 ChartStyle 资源中的属性后，视图会立即重绘。

## 文件说明

| 文件 | 说明 |
|------|------|
| `chart_style.gd` | 样式资源类 `ChartStyle`，可配置颜色、边距、字体、线宽等；属性变更会发出 `style_changed` 供图表重绘 |
| `default_chart_style.tres` | 默认样式资源，可复制后按需修改 |
| `bar_chart.gd` / `bar_chart.tscn` | 条形图 |
| `line_chart.gd` / `line_chart.tscn` | 折线图 |
| `pie_chart.gd` / `pie_chart.tscn` | 饼图 |
| `charts_test_panel.tscn` / `charts_test_panel.gd` | **测试场景**：打开即可看到三个图表示例，便于调试样式与数据 |

## 使用方式

1. **场景中挂载**：将 `bar_chart.tscn` / `line_chart.tscn` / `pie_chart.tscn` 实例化到场景中。
2. **样式配置**：在 Inspector 中为节点的 `chart_style` 指定一个 `ChartStyle` 资源（可新建 Resource → 选择 ChartStyle，或使用/复制 `default_chart_style.tres`）。
3. **设置数据与展示动画**：
   - **条形图**：`set_chart_data(data)` 或 `set_chart_data(data, true)` 立即播动画；若先 `set_chart_data(data, false)` 再在需要时调用 `play_show_animation(duration)`，可重复触发「逐条伸出」动画而不重建图表。
   - **折线图**：同上，`play_show_animation(duration)` 为「逐点连接」动画。
   - **饼图**：同上，`play_show_animation(duration)` 为「扇区转出」动画。
   - 三者均支持 `update_display(data)`，默认不自动播动画。

## 样式接口（ChartStyle）

- **通用**：`padding`、`background_color`、`label_color`、`value_color`、`grid_color`、`empty_message_color`、`title_color`、字体字号等。
- **条形图**：`bar_colors`、`bar_corner_radius`、`bar_max_width`、`bar_width_ratio`、`bar_show_value_label`、参考线相关。
- **折线图**：`line_color`、`line_series_colors`、`line_width`、`line_point_radius`、`line_fill_color`、`line_smooth`。
- **饼图**：`pie_colors`、`pie_stroke_color`、`pie_inner_radius_ratio`、`pie_show_legend`、`pie_label_mode`。
- **动画**：`bar_animation_duration`、`line_animation_duration`、`pie_animation_duration`（秒），用于 set_chart_data(animate=true) 与 play_show_animation()；传参 play_show_animation(duration > 0) 时可覆盖当次时长。

未设置 `chart_style` 时，各图表使用脚本内默认样式。

## 测试场景与编辑器预览

1. **打开测试场景**：在 Godot 中打开 `charts_test_panel.tscn`，运行或仅编辑时即可看到条形图、折线图、饼图的示例数据渲染。
2. **实时看样式效果**：
   - 在场景树中选中某个图表节点（如 BarChart），在 Inspector 中为其指定或新建一个 `ChartStyle` 资源。
   - 在 Inspector 中展开该 ChartStyle 资源，修改任意属性（如 `padding`、`bar_colors`、`label_color` 等），保存后图表会**立即重绘**，无需运行游戏。
   - 图表脚本均为 `@tool`，在编辑器中修改图表的 export 属性（如更换 chart_style）也会触发重绘。

## 架构约定

- 图表为**纯展示组件**，不持有业务数据；通过 `update_display(data)` 或 `set_chart_data(data)` 由外部传入数据。
- 数据来源应由 State 单例或 Module 提供，符合项目三层架构。
