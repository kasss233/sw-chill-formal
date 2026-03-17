# 🎨 Godot 项目完整技术文档库

**项目**：sw-chill-formal (Godot 4.6 Mobile)  
**版本**：1.0  
**最后更新**：2024

---

## 📚 文档览表 

项目的完整技术文档已组织为 **5 份专题指南**，覆盖从 UI/Data、3D、AI Agent、到音频、工具脚本的全技术栈。

| 文档 | 章数 | 行数 | 面向 | 核心内容 |
|-----|------|------|-----|--------|
| [1️⃣ UI & Data 模块指南](ui_data_modules_summary.md) | 8 | ~800 | UI/Data 开发者 | 17 个 UI 模块、17+ 数据单例、完整映射表、信号体系 |
| [2️⃣ 3D 系统指南](3d_system_summary.md) | 10 | ~700 | 3D/场景设计师 | Character、Room、Environment、特效、与 Data 集成 |
| [3️⃣ AI Agent 系统指南](ai_agent_system_summary.md) | 9 | ~900 | Agent 集成者 | Godot 端、Python Agent、函数调用 8 步流程、SSE 参考 |
| [4️⃣ 音频系统指南](audio_system_and_resources_summary.md) | 8 | ~850 | 音频/模块开发者 | MusicState、AudioPlayer、资源库、淡入淡出、算法 |
| [5️⃣ 工具脚本&插件指南](transition_tools_and_plugins_summary.md) | 8 | ~950 | 工具/运维 | 过渡动画、3 个工具脚本、8 个插件一览 |
| [🎮 游戏设计与实现对照](game_design_and_implementation.md) | 12 | ~1400 | 全员参考 | 15+ 功能实现状态、设计vs现状对照、v0.6-v1.0 路线图 |

**总计**：55 章 × ~5650 行 × 120+ 表格 × 60+ 代码示例

---

## 🗺️ 快速导航

### 📖 按用途查找

#### 🎯 新手快速上手
```
1. 先读 → 3D系统指南 (理解场景结构)
2. 再读 → UI & Data 模块指南 (掌握响应式数据流)
3. 深读 → AI Agent 系统指南 (集成高级功能)
```

#### 🛠️ 功能开发快查
```
需求 | 查阅文档
-----|--------
新增 UI 模块 | UI & Data 模块指南 § 快速参考
实现音乐播放 | 音频系统指南 § MusicState API
AI 对话集成 | AI Agent 系统指南 § 函数调用流程
3D 场景调试 | 工具脚本&插件指南 § 自由相机
模型导入处理 | 工具脚本&插件指南 § 着色器自动化
设计评估 | 游戏设计文档 § 核心功能实现状态
功能优化建议 | 游戏设计文档 § 待优化与扩展
版本计划 | 游戏设计文档 § 未来版本规划
```

#### 🐛 问题排查快查
```
症状 | 查阅位置
-----|--------
音乐不播放 | 音频系统指南 → 故障排查 → 问题：音乐不播放
UI 不响应 | UI & Data 模块指南 → 故障排查 → 问题：信号未连接
3D 角色变黑 | 3D 系统指南 → 故障排查 → 问题：Shader 加载失败
AI 返回为空 | AI Agent 系统指南 → 故障排查 → 问题：流式输出异常
```

---

## � 游戏设计特别指南

最新创建的**游戏设计与实现对照文档**涵盖：

| 内容 | 描述 |
|-----|-----|
| **功能矩阵** | 15+ 功能的实现状态（完成度 0-100%）|
| **设计vs现状** | 逐个对照设计文档与现有代码实现 |
| **待优化清单** | 高/中/低优先级任务，含工作量评估 |
| **版本规划** | v0.6.0 → v1.0.0 的发展路线图 |
| **代码示例** | MainlineQuestState、PerformanceScript 等实现方案 |

**推荐阅读顺序**：
1. 新成员 → [游戏设计文档](#game_design_and_implementation.md) 了解全貌
2. 功能开发 → [具体模块指南](#ui_data_modules_summary.md) 查 API
3. 问题排查 → 对应模块的故障排查部分

---

## �🏗️ 架构全览

### 三层核心架构

```
┌─────────────────────────────────────────────────────────┐
│              UI Module (响应式组件)                      │
│  • MusicModule • TaskModule • NoteModule • ChatModule   │
│  • DialogueBox • InputBox • AchievementModule • ...      │
└────────┬────────────────────────────────────────────────┘
         │ 监听信号 & 调用 API
         ↓
┌─────────────────────────────────────────────────────────┐
│              Data Autoload (数据单例)                    │
│  • MusicState • TaskState • ChatState • LevelState • .. │
│  ✓ 持久化 ✓ 信号驱动 ✓ 唯一数据源                      │
└────────┬────────────────────────────────────────────────┘
         │ 发出信号 (state_changed / items_added / ...)
         ↓
┌─────────────────────────────────────────────────────────┐
│              UI Component (纯展示组件)                   │
│  • MaterialButton • MaterialCard • MaterialCheckbox • .. │
│  • Calendar • DatePicker • MusicVisualizer • ...        │
└─────────────────────────────────────────────────────────┘
```

**参考**：
- 详细版 → [UI & Data 模块指南 § 整体架构](ui_data_modules_summary.md#整体架构)

### 音频数据流

```
AudioRes (资源库)
    ↓ 初始化加载
AudioPlayer (音频引擎)
    ↓ 监听信号
MusicState (数据源)
    ↓ 发出信号 (track_changed / playback_state_changed)
MusicModule (UI)
    ↓ 用户交互
界面更新 + 音乐播放
```

**参考**：
- 详细版 → [音频系统指南 § 整体架构](audio_system_and_resources_summary.md#整体架构)

### AI Agent 完整流程

```
用户输入 (input_box)
    ↓ 上报 InputBox.message_submitted(text)
MusicModule 或 Chat 相关模块
    ↓ 调用 ChatController API
ChatController (Godot 端)
    ↓ 收集上下文 (Character、Task、Level 等)
ContextCollector
    ↓ 序列化为 Agent Prompt
Python ChatAgent (服务器)
    ↓ LLM 处理 + 函数调用
Reflection Agent (生成摘要)
    ↓ SSE 流式返回
Godot 端 SSE 解析
    ↓ 逐字动画显示
DialogueBox (对话框)
    ↓ 用户看到 AI 回复
```

**参考**：
- 详细版 → [AI Agent 系统指南 § 函数调用详解](ai_agent_system_summary.md#函数调用详解)

---

## 🎯 15 分钟快速聚焦

### 任务：新增任务（Task）模块功能

**步骤 1**：检查数据模型  
→ [UI & Data 模块指南 § TaskState](ui_data_modules_summary.md) 查看 `TaskState` API

**步骤 2**：设计 UI 模块  
→ 参考 [UI & Data 模块指南 § TaskModule](ui_data_modules_summary.md) 的信号连接模式

**步骤 3**：实现拖拽排序  
→ [工具脚本&插件指南 § ReorderableContainer](transition_tools_and_plugins_summary.md)

**步骤 4**：测试音频反馈  
→ [音频系统指南 § 快速参考](audio_system_and_resources_summary.md#快速参考) - 播放音效

### 任务：集成 AI 聊天功能

**步骤 1**：理解数据流  
→ [AI Agent 系统指南 § 架构概览](ai_agent_system_summary.md#架构概览)

**步骤 2**：配置 LLM 参数  
→ [AI Agent 系统指南 § 快速参考](ai_agent_system_summary.md#快速参考)

**步骤 3**：监听流式输出  
→ [AI Agent 系统指南 § SSE 事件参考](ai_agent_system_summary.md#sse-事件参考)

**步骤 4**：处理函数调用  
→ [AI Agent 系统指南 § 函数调用详解](ai_agent_system_summary.md#函数调用详解)

### 任务：导入 VRM 角色模型

**步骤 1**：准备模型  
→ 下载 VRM 格式模型到 `res://assets/3d/character/`

**步骤 2**：了解自动处理  
→ [工具脚本&插件指南 § 着色器自动化应用](transition_tools_and_plugins_summary.md#3-toon_fix_transparentgd---着色器自动化应用)

**步骤 3**：集成到 Character  
→ [3D 系统指南 § Character 角色系统](3d_system_summary.md)

**步骤 4**：调试视效  
→ [工具脚本&插件指南 § 自由视角调试相机](transition_tools_and_plugins_summary.md#2-free_cameragd---自由视角调试相机)

---

## 📋 文档间交叉引用

### 关键概念跨文档导航

| 概念 | 提及文档 | 位置 |
|-----|--------|------|
| **MusicState** | Data、Audio、UI | Data指南 § UI/Data映射表 + Audio指南全章 |
| **Character** | 3D指南、AI指南、Data指南、**游戏设计** | 3D指南 § Character角色系统 |
| **信号体系** | UI&Data、3D、AI、Audio | Data指南 § 信号体系 |
| **Tween 动画** | 3D指南、Audio指南 | 各自的 § 快速参考 |
| **Resources** | Output指南、3D指南 | Resource指南全章 |
| **GuiTransitions** | 工具&插件指南 | 工具&插件指南 § simple-gui-transitions |
| **@tool 脚本** | 工具&插件指南 | 工具&插件指南 § EditorScenePostImport |
| **演出系统** | 3D指南、**游戏设计** | 游戏设计 § 演出系统详解 |
| **主线任务** | **游戏设计** | 游戏设计 § 主线任务与故事线 |
| **RAG 记忆** | AI指南、**游戏设计** | 游戏设计 § 记忆与上下文系统 |

### 常见组合查询

```
我是           查询流程
────────────────────────────────────
UI 开发者  →  UI & Data 指南 (全)
           →  音频系统指南 (快速参考)

3D 开发者  →  3D 系统指南 (全)
           →  工具脚本&插件 (工具脚本部分)

Agent/AI   →  AI Agent 系统指南 (全)
           →  Data指南 (上下文收集相关单例)

后端/架构  →  AI Agent 指南 (Python Agent)
           →  工具脚本 (sync_change.gd)
```

---

## 🔍 按文件路径快查

### Data Autoload 单例位置

```
scenes/main/autoload/data/
├── auth_state.gd                  📄 Data指南 § AuthState
├── task_state.gd                  📄 Data指南 § TaskState
├── achievement_state.gd           📄 Data指南 § AchievementState
├── level_state.gd                 📄 Data指南 § LevelState
├── habit_state.gd                 📄 Data指南 § HabitState
├── note_state.gd                  📄 Data指南 § NoteState
├── sticky_note_state.gd           📄 Data指南 § StickyNoteState
├── chat_state.gd                  📄 Data指南 § ChatState
├── setting_state.gd               📄 Data指南 § SettingState
├── pomodoro_state.gd              📄 Data指南 § PomodoroState
├── character_interactor_state.gd  📄 Data指南 § CharacterInteractorState
├── room_decor_state.gd            📄 Data指南 § RoomDecorState
├── layer_manager.gd               📄 Data指南 § LayerManager
├── event_tracker.gd               📄 Data指南 § EventTracker
└── sync_state.gd                  📄 Data指南 § SyncState
```

### Audio Autoload

```
scenes/main/autoload/audio_player/
├── audio_player.gd                📄 Audio指南 § AudioPlayer
├── audio_player.tscn
├── music_state.gd                 📄 Audio指南 § MusicState
└── music_state.tscn
```

### 工具脚本

```
scripts/
├── sync_change.gd                 📄 工具指南 § sync_change.gd
├── free_camera.gd                 📄 工具指南 § free_camera.gd
└── toon_fix_transparent.gd        📄 工具指南 § toon_fix_transparent.gd
```

### 资源系统

```
resource/
├── audio_res/                      📄 Audio指南 § AudioRes
│   └── audio_res.gd
├── room_decor_res/                 📄 Audio指南 § RoomDecorRes
│   └── room_decor_res.gd
```

### 插件

```
addons/
├── Godot-MToon-Shader/             📄 工具指南 § Godot-MToon-Shader
├── ReorderableContainer/           📄 工具指南 § ReorderableContainer
├── SmoothScroll/                   📄 工具指南 § SmoothScroll
├── markdownlabel/                  📄 工具指南 § markdownlabel
├── simple-gui-transitions/         📄 工具指南 § simple-gui-transitions
├── sky_3d/                         📄 工具指南 § sky_3d
├── vrm/                            📄 工具指南 § vrm
└── calendar_library/               📄 工具指南 § calendar_library
```

---

## 🚀 开发工作流最佳实践

### 1️⃣ 开发新 UI 功能

```
1. 分析需求
   ↓
2. 查阅 [Data指南 § UI/Data 映射表]
   → 找出需要的 Data 单例与信号
   ↓
3. 从 [Data指南 § [单例名]]
   → 获取 API 与信号列表
   ↓
4. 参考 [Data指南 § 快速参考 - 监听关键信号]
   → 实现 UI 监听与更新
   ↓
5. 如需音效，查 [Audio指南 § 快速参考]
   → AudioPlayer.play_sound_effect()
```

### 2️⃣ 集成 AI Agent 功能

```
1. 查阅 [AI指南 § 架构概览]
   → 理解 Godot 端与 Python Agent 交互
   ↓
2. 参考 [AI指南 § 上下文收集]
   → 定义需要传给 LLM 的数据
   ↓
3. 实现函数调用处理
   → [AI指南 § 函数调用详解 - 8 步流程]
   ↓
4. 测试 SSE 流式解析
   → [AI指南 § SSE 事件参考]
   ↓
5. 处理错误与重试
   → [AI指南 § 错误处理与重试]
```

### 3️⃣ 场景调试与优化

```
1. 启用自由相机
   → [工具指南 § free_camera.gd]
   → WASD + 右键拖动调整视角
   ↓
2. 检查模型材质
   → [工具指南 § toon_fix_transparent.gd]
   → 确保自动着色器应用正确
   ↓
3. 验证动画流程
   → [3D指南 § Character 角色系统]
   → ActionTree + EmotionTree 协调
   ↓
4. 优化 UI 渲染
   → [工具指南 § SmoothScroll]
   → 长列表使用虚拟化滚动
```

---

## 📊 文档统计

| 指标 | 值 |
|-----|-----|
| 总文档数 | 6 份 |
| 总章节数 | 55 章 |
| 总行数 | ~5650 行 |
| 表格数 | 120+ |
| 代码示例 | 60+ |
| 流程图/时序图 | 25+ |
| 快速参考部分 | 6 份 |
| 故障排查条目 | 35+ |

---

## 🎓 学习路径建议

### 初级（新手）
```
Day 1: 阅读 3D系统指南 (理解场景概览)
Day 2: 阅读 UI&Data指南 § 整体架构 + 快速参考
Day 3: 跟随一个完整示例（如新增 Task）
```

### 中级（开发者）
```
Week 1: 精读 UI&Data指南 (掌握响应式流程)
Week 2: 精读 AI Agent指南 (集成 LLM 功能)
Week 3: 实践项目任务（日历、习惯、成就等）
```

### 高级（架构师）
```
Phase 1: 审视 Audio 和 Tools 脚本设计（同步机制、Editor工具）
Phase 2: 研究 Godot 与 Python Agent 的 SSE 通信
Phase 3: 性能优化与可扩展性改进
```

---

## ❓ FAQ

### Q: 如何快速从 X 功能找到代码位置？
**A**: 使用 § 文件路径快查 → 找对应 .gd 文件 → 对应文档→ Ctrl+F 搜索。

### Q: 某个 UI 模块不工作，如何诊断？
**A**: 
1. [Data指南 § 快速参考 - 监听关键信号]
2. [Data指南 § 故障排查 - 问题：UI不响应]

### Q: 音乐播放有问题怎么办？
**A**: 
1. [Audio指南 § 快速参考]
2. [Audio指南 § 故障排查]

### Q: 如何添加新的 AI 函数？
**A**: 
1. [AI指南 § 已实现函数清单]
2. [AI指南 § 函数调用详解]
3. 参考现有函数的实现流程

### Q: 3D 模型导入后显示错误怎么办？
**A**: 
1. [工具指南 § toon_fix_transparent.gd]
2. [工具指南 § 故障排查]

### Q: 项目现在完成度多少？应该优先做什么？
**A**:
1. [游戏设计文档 § 核心功能实现状态] 查看 15+ 功能的完成度
2. [游戏设计文档 § 待优化与扩展] 查看优先级清单
3. 建议按 🔴 高优先级先做

### Q: 主线任务怎么实现？
**A**: 
1. [游戏设计文档 § 主线任务与故事线] 查看设计方案
2. 创建 MainlineQuestState Autoload
3. 参考文档中的代码示例实现

### Q: 怎么让女孩自动改变场景或播放音乐？
**A**:
1. [游戏设计文档 § 高级 AI 功能 - 任务生成与规划]
2. 需要 Agent 生成 `set_scene()` / `set_music()` 函数调用
3. 参考 [AI指南 § 函数调用详解] 理解执行流程

---

## 📞 文档维护

- **更新频率**：功能迭代时同步更新
- **责任人**：Architecture & AI 团队
- **版本控制**：docs/ 路径下的 Markdown 文件纳入 Git
- **讨论**：[项目 Wiki / Issues]

---

## 🎉 总结

这套完整文档库涵盖：
- ✅ **数据架构**（响应式 Data 单例）
- ✅ **UI 系统**（17 个模块 + 组件库）
- ✅ **3D 渲染**（Character、环境、特效）
- ✅ **AI 集成**（LLM + 函数调用流程）
- ✅ **音频系统**（MusicState + AudioPlayer）
- ✅ **工具链**（脚本、插件、资源系统）

**目标**：让每个开发者能在 **5 分钟内** 找到需要的详细文档。

---

**文档编制完成** ✓  
**最后检查**：2024-01-XX  
**下一步**：定期维护与更新
