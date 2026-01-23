# UI模块 Agent API 文档

> 最后更新: 2026-01-23
> 版本: 1.0.0

## 📋 概述

本文档描述了所有UI模块的Agent API接口，用于程序化控制UI组件。这些API设计用于AI Agent、自动化脚本或其他需要控制UI的场景。

### 设计原则

- **同步优先**: 大多数API是同步的，立即返回结果
- **动画友好**: 支持可选的动画效果，提升用户体验
- **错误安全**: 操作失败时返回明确的错误信息
- **状态一致**: 确保数据和UI状态始终同步

### 模块列表

- ✅ [TaskModule](#taskmodule-agent-api) - 任务管理模块
- 🔲 [MusicModule](#musicmodule-agent-api) - 音乐播放模块 (待补充)
- 🔲 [NoteModule](#notemodule-agent-api) - 便签模块 (待补充)
- 🔲 [NotebookModule](#notebookmodule-agent-api) - 笔记本模块 (待补充)
- 🔲 [InputBox](#inputbox-agent-api) - 输入框模块 (待补充)

---

## TaskModule Agent API

> 路径: `res://scenes/main/ui/task_module_new/task_module_new.gd`
> 类名: `TaskModule`

### 功能概述

TaskModule提供完整的任务管理功能，包括添加、更新、删除、标记完成、调整顺序等操作。所有操作都支持动画效果，并确保UI和数据的一致性。

### API方法列表

#### 1. 添加任务

```gdscript
func agent_add_task(title: String, due_timestamp: int = 0, typing_speed: float = 0.05) -> int
```

**描述**: 添加新任务，先显示空标题，然后通过打字动画逐字显示标题。

**参数**:
- `title: String` - 任务标题
- `due_timestamp: int` - 截止时间戳（Unix时间戳，可选，默认0表示无截止时间）
- `typing_speed: float` - 打字速度（秒/字符，默认0.05）

**返回值**: `int` - 新任务的唯一ID

**动画效果**:
1. 淡入 + 缩放动画 (0.4秒)
2. 打字动画显示标题（后台异步执行）

**示例**:
```gdscript
# 基本用法
var task_id = task_module.agent_add_task("完成项目文档")

# 带截止时间
var due_time = Time.get_unix_time_from_system() + 86400  # 明天
var task_id = task_module.agent_add_task("提交报告", due_time)

# 自定义打字速度
var task_id = task_module.agent_add_task("快速任务", 0, 0.02)  # 更快的打字速度
```

**注意事项**:
- 函数立即返回，打字动画在后台执行
- 不需要使用`await`
- 空标题会跳过打字动画

---

#### 2. 更新任务标题

```gdscript
func agent_update_task_title(id: int, new_title: String, typing_speed: float = 0.05) -> bool
```

**描述**: 更新任务标题，使用打字动画逐字显示新标题。

**参数**:
- `id: int` - 任务ID
- `new_title: String` - 新标题
- `typing_speed: float` - 打字速度（秒/字符，默认0.05）

**返回值**: `bool` - 成功返回true，任务不存在返回false

**动画效果**: 打字动画逐字显示新标题

**示例**:
```gdscript
# 需要使用await，因为这是协程
var success = await task_module.agent_update_task_title(1, "更新后的标题")
if success:
	print("标题更新成功")
else:
	print("任务不存在")
```

**注意事项**:
- **必须使用`await`**，这是一个协程函数
- 更新期间模块会被锁定，防止用户交互

---

#### 3. 标记任务完成状态

```gdscript
func agent_mark_task_completed(id: int, completed: bool) -> bool
```

**描述**: 标记任务为已完成或未完成状态。

**参数**:
- `id: int` - 任务ID
- `completed: bool` - true=已完成，false=未完成

**返回值**: `bool` - 成功返回true

**效果**:
- 任务移动到相应区域（已完成/未完成）
- 更新checkbox状态
- 更新line_edit样式（删除线效果）
- 设置/清除完成时间戳

**示例**:
```gdscript
# 标记为已完成
task_module.agent_mark_task_completed(1, true)

# 标记为未完成
task_module.agent_mark_task_completed(1, false)
```

**注意事项**:
- 不会触发其他任务的状态变化
- 信号已正确处理，避免递归调用

---

#### 4. 删除任务

```gdscript
func agent_remove_task(id: int) -> bool
```

**描述**: 删除指定任务。

**参数**:
- `id: int` - 任务ID

**返回值**: `bool` - 成功返回true

**示例**:
```gdscript
task_module.agent_remove_task(1)
```

---

#### 5. 获取任务信息

```gdscript
func agent_get_task_info(id: int) -> Dictionary
```

**描述**: 获取指定任务的详细信息。

**参数**:
- `id: int` - 任务ID

**返回值**: `Dictionary` - 任务信息字典，如果任务不存在返回空字典

**字典结构**:
```gdscript
{
	"id": int,                    # 任务ID
	"title": String,              # 任务标题
	"is_completed": bool,         # 是否已完成
	"due_timestamp": int,         # 截止时间戳
	"finish_timestamp": int       # 完成时间戳
}
```

**示例**:
```gdscript
var info = task_module.agent_get_task_info(1)
if not info.is_empty():
	print("任务标题: ", info.title)
	print("是否完成: ", info.is_completed)
else:
	print("任务不存在")
```

---

#### 6. 获取所有任务

```gdscript
func agent_get_all_tasks() -> Array[Dictionary]
```

**描述**: 获取所有任务的信息列表。

**返回值**: `Array[Dictionary]` - 任务信息字典数组

**示例**:
```gdscript
var all_tasks = task_module.agent_get_all_tasks()
print("共有 %d 个任务" % all_tasks.size())

for task in all_tasks:
	print("- [%d] %s (完成: %s)" % [task.id, task.title, task.is_completed])
```

---

#### 7. 调整任务顺序

```gdscript
func agent_reorder_task(id: int, new_position: int) -> bool
```

**描述**: 调整任务在其类别（已完成/未完成）中的顺序位置。

**参数**:
- `id: int` - 任务ID
- `new_position: int` - 新位置索引（在同类别任务中的位置，0-based）

**返回值**: `bool` - 成功返回true，失败返回false

**行为说明**:
- 任务只能在同类别内调整顺序（已完成任务不能移动到未完成区域，反之亦然）
- `new_position` 是相对于任务类别的索引：
  - 未完成任务：0 表示第一个未完成任务的位置
  - 已完成任务：0 表示第一个已完成任务的位置
- 如果位置无效（超出范围），操作失败并返回false
- 如果任务已在目标位置，直接返回true

**示例**:
```gdscript
# 将未完成任务移动到未完成列表的第一个位置
task_module.agent_reorder_task(1, 0)

# 将未完成任务移动到未完成列表的第三个位置
task_module.agent_reorder_task(2, 2)

# 将已完成任务移动到已完成列表的最后
var completed_tasks = task_module.get_finished_task_list()
task_module.agent_reorder_task(5, completed_tasks.size() - 1)
```

**注意事项**:
- 操作期间模块会被锁定，防止用户交互
- 不能跨类别移动任务（使用 `agent_mark_task_completed` 来改变任务状态）
- 位置索引从0开始

**错误处理**:
```gdscript
var success = task_module.agent_reorder_task(999, 0)
if not success:
	print("调整失败：任务不存在或位置无效")
```

---

### 完整使用示例

#### 示例1: 创建任务流程

```gdscript
# 1. 添加任务
var task_id = task_module.agent_add_task("学习Godot", 0, 0.05)
print("创建任务，ID: ", task_id)

# 2. 等待一段时间后更新标题
await get_tree().create_timer(2.0).timeout
await task_module.agent_update_task_title(task_id, "深入学习Godot引擎")

# 3. 标记为完成
await get_tree().create_timer(1.0).timeout
task_module.agent_mark_task_completed(task_id, true)

# 4. 获取任务信息
var info = task_module.agent_get_task_info(task_id)
print("任务完成时间: ", info.finish_timestamp)
```

#### 示例2: 批量操作

```gdscript
# 批量添加任务
var task_ids = []
var tasks = ["任务1", "任务2", "任务3", "任务4", "任务5"]

for task_title in tasks:
	var id = task_module.agent_add_task(task_title)
	task_ids.append(id)

# 等待所有任务添加完成（包括动画）
await get_tree().create_timer(2.0).timeout

# 标记偶数任务为完成
for i in range(task_ids.size()):
	if i % 2 == 0:
		task_module.agent_mark_task_completed(task_ids[i], true)

# 获取所有任务状态
var all_tasks = task_module.agent_get_all_tasks()
var completed_count = 0
for task in all_tasks:
	if task.is_completed:
		completed_count += 1

print("已完成: %d/%d" % [completed_count, all_tasks.size()])
```

#### 示例3: 任务顺序调整

```gdscript
# 添加多个任务
var task_ids = []
for i in range(5):
	var id = task_module.agent_add_task("任务 %d" % (i + 1))
	task_ids.append(id)

# 等待任务添加完成
await get_tree().create_timer(2.0).timeout

# 将第一个任务移动到最后
task_module.agent_reorder_task(task_ids[0], 4)

# 将最后一个任务移动到第一个位置
task_module.agent_reorder_task(task_ids[4], 0)

# 验证顺序
var all_tasks = task_module.agent_get_all_tasks()
print("当前任务顺序:")
for i in range(all_tasks.size()):
	if not all_tasks[i].is_completed:
		print("  %d. [%d] %s" % [i, all_tasks[i].id, all_tasks[i].title])
```

#### 示例4: 错误处理

```gdscript
# 尝试更新不存在的任务
var success = await task_module.agent_update_task_title(999, "新标题")
if not success:
	print("错误: 任务不存在")

# 检查任务是否存在
var info = task_module.agent_get_task_info(999)
if info.is_empty():
	print("任务不存在")
```

---

### 性能考虑

- **打字动画**: 长标题可能需要较长时间完成动画，建议标题长度控制在50字符以内
- **批量操作**: 连续添加多个任务时，动画会并行执行，不会阻塞
- **ID管理**: ID自动递增，删除任务后ID不会被重用

---

### 常见问题

**Q: 为什么`agent_add_task()`不需要await，但`agent_update_task_title()`需要？**

A: `agent_add_task()`立即返回任务ID，打字动画在后台异步执行。而`agent_update_task_title()`需要等待打字动画完成才返回，因此是协程。

**Q: 如何禁用打字动画？**

A: 将`typing_speed`设置为极小值（如0.001）或传入空字符串作为标题。

**Q: 标记任务完成后，其他任务会受影响吗？**

A: 不会。已修复信号处理逻辑，确保只更新指定任务。

---

## MusicModule Agent API

> 路径: `res://scenes/main/ui/music_module/music_module.gd`
> 类名: `MusicModule`

### 🔲 待补充

此模块的Agent API文档待补充。

**预期功能**:
- 播放/暂停音乐
- 切换曲目
- 管理播放列表
- 设置播放模式（顺序/随机/单曲循环）
- 音量控制

**参考现有API**:
- `play_bgm()`
- `change_music()`
- `add_music_list()`
- `switch_to_list_by_name()`

---

## NoteModule Agent API

> 路径: `res://scenes/main/ui/note_module/note_module.gd`
> 类名: `NoteModule`

### 🔲 待补充

此模块的Agent API文档待补充。

**预期功能**:
- 创建便签
- 删除便签
- 更新便签内容
- 移动便签位置
- 获取所有便签

**参考现有API**:
- `take_note(text: String)`

---

## NotebookModule Agent API

> 路径: `res://scenes/main/ui/notebook_module/note_book.gd`
> 类名: `NoteBook`

### 🔲 待补充

此模块的Agent API文档待补充。

**预期功能**:
- 添加笔记本页面
- 删除页面
- 切换页面
- 更新页面内容
- 获取所有页面

**参考现有API**:
- `add_page_and_open(name: String, content: String)`

---

## InputBox Agent API

> 路径: `res://scenes/main/ui/input_box/input_box.gd`
> 类名: `InputBox`

### 🔲 待补充

此模块的Agent API文档待补充。

**预期功能**:
- 设置输入文本
- 获取输入文本
- 添加附件
- 清空输入
- 提交输入

---

## 附录

### A. 通用约定

#### 命名规范
- Agent API方法以`agent_`前缀开头
- 使用snake_case命名风格
- 方法名清晰描述功能

#### 返回值约定
- 成功操作返回`true`或有效数据
- 失败操作返回`false`或空数据（空字典、空数组）
- 新建资源返回唯一ID

#### 错误处理
- 不抛出异常，通过返回值表示成功/失败
- 在控制台输出错误日志
- 提供详细的错误信息

### B. 测试工具

使用测试面板测试Agent API:
```gdscript
# 打开测试面板
ui.show_test_panel()  # 或按F12键
```

测试面板位置: `res://scenes/main/ui/debug/test_panel.tscn`

### C. 贡献指南

为新模块添加Agent API文档时，请遵循以下格式：

1. **模块标题**: 包含路径、类名
2. **功能概述**: 简要描述模块功能
3. **API方法列表**: 每个方法包含：
   - 方法签名
   - 描述
   - 参数说明
   - 返回值说明
   - 示例代码
   - 注意事项
4. **完整使用示例**: 展示实际使用场景
5. **性能考虑**: 说明性能相关注意事项
6. **常见问题**: 回答常见疑问

---

## 更新日志

### v1.0.0 (2026-01-23)
- ✅ 添加TaskModule完整API文档
- ✅ 预留其他模块文档位置
- ✅ 添加使用示例和最佳实践
- ✅ 添加测试工具说明

---

**文档维护**: 请在添加或修改Agent API时及时更新本文档。
