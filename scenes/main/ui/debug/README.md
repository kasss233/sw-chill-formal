# UI模块测试面板使用说明

## 概述

测试面板已集成到主UI场景中，可以直接测试所有UI模块的Agent API功能。采用可拓展的架构设计，方便添加新模块的测试。

## 文件结构

```
scenes/main/ui/debug/
├── test_panel.tscn              # 主测试面板场景
├── test_panel.gd                # 主测试面板脚本
├── task_module_test_panel.tscn  # TaskModule测试页场景
├── task_module_test_panel.gd    # TaskModule测试页脚本
└── README.md                    # 本文档
```

## 快速开始

### 打开测试面板

测试面板已集成到主UI场景(`scenes/main/ui/ui.tscn`)中，有以下几种方式打开:

1. **按F12键** - 在运行时按F12切换测试面板显示/隐藏
2. **通过代码调用**:
   ```gdscript
   # 在任何可以访问UI实例的地方
   ui.toggle_test_panel()  # 切换显示/隐藏
   ui.show_test_panel()    # 显示
   ui.hide_test_panel()    # 隐藏
   ```

### 关闭测试面板

- 按**ESC键**
- 点击测试面板右上角的**"关闭 [ESC]"**按钮
- 再次按**F12键**

## TaskModule Agent API 测试功能

### 1. 添加任务 (agent_add_task)
- 在"任务标题"输入框中输入标题(可选,留空则自动生成)
- 点击"添加任务"按钮
- 返回新任务的ID,自动填充到"任务ID"输入框

### 2. 更新任务标题 (agent_update_task_title)
- 在"任务ID"输入框中输入要更新的任务ID
- 在"任务标题"输入框中输入新标题
- 点击"更新标题"按钮
- 将看到打字效果动画

### 3. 标记任务完成状态 (agent_mark_task_completed)
- 在"任务ID"输入框中输入任务ID
- 点击"标记为完成"或"标记为未完成"按钮
- 任务将在UI中移动到相应区域

### 4. 删除任务 (agent_remove_task)
- 在"任务ID"输入框中输入任务ID
- 点击"删除任务"按钮

### 5. 获取任务信息 (agent_get_task_info)
- 在"任务ID"输入框中输入任务ID
- 点击"获取任务信息"按钮
- 在日志区域查看任务详细信息(JSON格式)

### 6. 获取所有任务 (agent_get_all_tasks)
- 点击"获取所有任务"按钮
- 在日志区域查看所有任务列表

## 架构设计

### 集成方式

测试面板直接集成在主UI场景中:
- **自动初始化**: TestPanel在`_ready()`时自动查找父级UI节点
- **模块引用传递**: 自动将UI中的各个模块引用传递给对应的测试页
- **零配置**: 无需手动设置，开箱即用

### 可拓展性

测试面板使用`TabContainer`组织不同模块的测试页,添加新模块测试非常简单:

1. **创建新的测试页脚本** (例如 `music_module_test_panel.gd`)
   ```gdscript
   extends Control

   var music_module: MusicModule = null

   func set_music_module(module: MusicModule) -> void:
       music_module = module
       _log_info("已连接到MusicModule: %s" % module.name)

   # 添加测试方法...
   ```

2. **创建新的测试页场景** (例如 `music_module_test_panel.tscn`)
   - 添加测试按钮和输入控件
   - 添加日志显示区域

3. **添加到TestPanel的TabContainer**
   - 在`test_panel.tscn`中,将新测试页作为TabContainer的子节点
   - Tab标题会自动显示为节点名称

4. **更新TestPanel初始化逻辑**
   - 在`test_panel.gd`的`_initialize_test_panels()`方法中添加初始化代码:
   ```gdscript
   if child.has_method("set_music_module") and ui.music_module:
       child.set_music_module(ui.music_module)
   ```

### 设计模式

- **松耦合**: 测试页通过`set_xxx_module()`方法接收模块引用,不依赖场景树结构
- **独立性**: 每个测试页是独立的脚本,互不干扰
- **统一风格**: 使用相同的日志输出方法(`_log_info`, `_log_success`, `_log_error`, `_log_data`)

## 日志系统

测试页提供彩色日志输出:
- **白色**: 普通信息 (`_log_info`)
- **绿色**: 成功信息 (`_log_success`)
- **红色**: 错误信息 (`_log_error`)
- **青色**: 数据信息 (`_log_data`)

日志同时输出到:
1. 测试面板的RichTextLabel (带颜色)
2. Godot控制台 (纯文本)

## 注意事项

1. **异步操作**: `agent_update_task_title`是异步方法,需要使用`await`
2. **模块锁定**: Agent操作期间,TaskModule会自动锁定用户交互
3. **ID管理**: 添加任务后会自动将新ID填充到输入框,方便后续测试

## 未来拓展

可以添加的测试页:
- MusicModule测试页 (测试音乐播放、播放列表管理)
- NoteModule测试页 (测试便签创建、删除)
- NotebookModule测试页 (测试笔记本页面管理)
- InputBox测试页 (测试输入框功能)

每个测试页遵循相同的模式,保持代码一致性和可维护性。
