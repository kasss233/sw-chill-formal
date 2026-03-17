# 🎮 Chill 项目设计与实现对照指南

**项目名称**：Chill（陪伴式治愈生产力工具）  
**设计版本**：v0.1.0-prototype  
**实现版本**：v0.5.0-beta  
**平台**：Android | **引擎**：Godot 4.6 Mobile  
**文档日期**：2024

---

## 📖 目录

1. [项目概览](#项目概览)
2. [核心功能实现状态](#核心功能实现状态)
3. [功能详解 & 实现映射](#功能详解--实现映射)
4. [待优化与扩展](#待优化与扩展)
5. [未来版本规划](#未来版本规划)

---

## 项目概览

### 设计目标

```
核心价值  = 陪伴 + 生产力 + 治愈
用户场景  = 独自学习/工作的人群
主要体验  = 和温柔的 AI 女孩一起完成任务、获得成长
差异化点  = AI 驱动的个性化陪伴 + 游戏化反馈
```

### 现状评估

| 维度 | 状态 | 说明 |
|-----|-----|------|
| **核心架构** | ✅ 完成 | 三层响应式架构（Data → UI → Component） |
| **数据系统** | ✅ 完成 | 17+ 单例、持久化、信号驱动 |
| **UI 框架** | ✅ 完成 | Material Design 系统、双布局（横竖屏） |
| **3D 角色** | ✅ 完成 | VRM 模型、双动画树（动作+表情）、实时交互 |
| **AI 对话** | ✅ 完成 | LLM 集成、流式输出、函数调用、记忆系统 |
| **生产力功能** | ⏳ 80% | 任务/计划/番茄/日历 + 需强化 Agent 部分 |
| **演出系统** | ⏳ 60% | 基础动画树 + 需扩展脚本系统 |
| **特殊玩法** | ❌ 待做 | 主线任务、特殊剧情、记忆迁移 |

**综合完成度**：约 **65%**（功能齐备，细节与创意待深化）

---

## 核心功能实现状态

### 功能矩阵

| # | 功能模块 | 设计需求 | 实现状态 | 相关代码 | 完成度 |
|---|--------|--------|--------|---------|-------|
| 1 | **代办事项** | 多级项目/任务、拖拽排序、重复设置、时间提醒 | ✅ 核心，⏳ 高级 | TaskState、TaskModule | 85% |
| 2 | **专注模式** | 番茄钟、自由专注、时间记录 | ✅ 完成 | PomodoroState、FocusRecorder | 95% |
| 3 | **日历系统** | 日记、计划显示、统计 | ✅ 核心，⏳ 统计 | CalendarModule、NoteState | 80% |
| 4 | **经验成长** | 升级、解锁内容、等级表 | ✅ 完成 | LevelState、AchievementState | 90% |
| 5 | **场景装饰** | 组件切换、动态环境 | ✅ 核心，⏳ 动态 | RoomDecorState、Main3d | 75% |
| 6 | **音乐系统** | 播放列表、音量调节、持久化 | ✅ 完成 | MusicState、AudioPlayer | 100% |
| 7 | **环境音** | 白噪音播放、音量控制 | ⏳ 部分 | AudioPlayer (SFX 系统) | 50% |
| 8 | **角色交互** | 点击演出、自由对话、触摸反应 | ✅ 核心，⏳ 演出 | Character、ChatController | 70% |
| 9 | **AI 对话** | LLM 对话、记忆、个性化 | ✅ 完成 | ChatController、ChatAgent | 95% |
| 10 | **演出系统** | 多脚本编排、解析生成 | ⏳ 基础 | Character (AnimationTree) | 40% |
| 11 | **任务生成** | 从对话解析任务 | ⏳ 部分 | PlannerAgent (Python) | 60% |
| 12 | **记忆系统** | RAG 长期记忆 | ✅ 基础，⏳ RAG | ChatState、ContextCollector | 70% |
| 13 | **主线任务** | 新手教程、故事解锁 | ❌ 未实现 | — | 0% |
| 14 | **特殊剧情** | 角色故事线（"女孩寄了"） | ❌ 未实现 | — | 0% |
| 15 | **消息提醒** | 系统通知、时间提醒 | ⏳ 部分 | EventTracker | 50% |

---

## 功能详解 & 实现映射

### 1️⃣ 代办事项系统

#### 设计需求

```
概念体系：
Project (项目)
  ├─ Project Info (项目信息)
  ├─ Task (任务)
  │   ├─ Task Info （任务信息）
  │   └─ SubTask (子任务)
  └─ ...

功能：
✓ 多级嵌套 (项目 → 任务 → 子任务)
✓ 拖拽排序
✓ 完成标记
✓ 重复设置 (周规律)
✓ 日期/时间提醒
✓ 专注记录
✓ 描述与附件
```

#### 现有实现

**位置**：[TaskState](../scenes/main/autoload/data/task_state.gd) + [TaskModule](../scenes/main/ui/task_module_new/)

```gdscript
# TaskState 数据模型
class TaskData:
    var id: int
    var title: String
    var content: String
    var status: int  # 0=待做, 1=进行中, 2=已完成
    var due_date: int  # Unix timestamp
    var priority: int  # 1-5
    var project_id: int
    var parent_task_id: int  # 子任务支持
    var repeat_type: int  # 0=不重复, 1=每日, 2=每周, 3=每月
    var repeat_days: Array[int]  # 周几 [1-7]
    var created_at: int
    var focus_time: int  # 累计专注时长 (秒)
    var work_records: Array  # 每次专注的记录
```

**已实现 API**：
- ✅ `create_task()` - 创建任务
- ✅ `update_task()` - 更新任务
- ✅ `delete_task()` - 删除任务
- ✅ `set_task_status()` - 完成/未完成
- ✅ `reorder_tasks()` - 拖拽排序
- ✅ `get_tasks_by_project()` - 按项目筛选
- ✅ `add_work_record()` - 记录专注时段

**UI 实现**：[TaskModule](../scenes/main/ui/task_module_new/task_module_new.gd)
- ✅ 任务列表渲染（ReorderableVBox）
- ✅ 拖拽排序
- ✅ 完成/删除交互
- ⏳ 高级编辑（日期选择、重复设置）

#### 待优化

| 问题 | 优先级 | 解决方案 |
|-----|--------|--------|
| 子任务显示层级不明显 | 中 | 添加缩进、虚线连接线 |
| 重复任务自动补齐逻辑 | 中 | TaskState._check_recurring_tasks() 完善 |
| 时间提醒功能不完整 | 中 | 集成 EventTracker，定时检查截止时间 |
| 任务拖拽到其他项目 | 低 | ReorderableVBox 扩展 parent_id 变更 |

---

### 2️⃣ 专注模式系统

#### 设计需求

```
核心概念：FocusSession (专注会话)
├─ PomodoroSession (番茄钟：25 min)
├─ TaskFocusSession (任务专注：自定)
└─ FreeFocusSession (自由专注：自定)

功能：
✓ 进入/退出专注
✓ 计时 & 暂停
✓ 自动专注记录
✓ 音效/提醒
✓ 结束演出 (鼓励)
```

#### 现有实现

**核心类**：[PomodoroState](../scenes/main/autoload/data/pomodoro_state.gd)

```gdscript
class_name PomodoroData extends RefCounted

var id: int
var type: int  # 0=25min, 1=5min, 2=15min, 3=自定义
var duration: int  # 时长 (秒)
var elapsed_time: int  # 已用时 (秒)
var is_running: bool
var created_at: int
var completed_at: int  # 为 0 表示未完成
var associated_task_id: int  # 关联的任务 ID
```

**已实现 API**：
- ✅ `start_pomodoro(type)` - 启动番茄钟
- ✅ `pause_pomodoro()` - 暂停
- ✅ `resume_pomodoro()` - 继续
- ✅ `stop_pomodoro()` - 停止
- ✅ `get_current_pomodoro()` - 获取当前
- ✅ `complete_pomodoro()` - 完成（自动奖励经验）

**UI 实现**：[PomodoroModule](../scenes/main/ui/pomodoro_technique_module/)
- ✅ 计时显示
- ✅ 开始/暂停/停止 按钮
- ✅ 进度条
- ✅ 音效播放
- ✅ 完成后鼓励演出

#### 状态机

```
IDLE ─>> START ─>> RUNNING ─┬─>> PAUSED ─┐
                             │             │
                             └─>> RESUME ──┘
                                    │
                                    └─>> COMPLETED (经验+1, 演出)
                                         │
                                         └─>> IDLE
```

#### 完成度

- ✅ **核心功能**：100% 完成
- ⏳ **打分系统**：50% （可添加"效率评分"）
- ⏳ **番茄报告**：60% （周报统计）

---

### 3️⃣ 日历与统计系统

#### 设计需求

```
功能：
✓ 月历视图 (日期点击)
✓ 日记 (当日编写/编辑)
✓ 当日任务显示
✓ 完成统计 (每日/周/月)
✓ 经验获取统计
✓ 专注时长统计
```

#### 现有实现

**相关类**：
- [CalendarModule](../scenes/main/ui/calendar_module/) - UI 模块
- [NoteState](../scenes/main/autoload/data/note_state.gd) - 日记数据
- [calendar_library 插件](../addons/calendar_library/) - 日历组件

**已实现**：
- ✅ 月历视图（calendar_library）
- ✅ 日期选择
- ✅ 当日日记编辑入口（在 Main UI 中有快捷按钮）
- ✅ 当日任务显示（CalendarModule 集成 TaskState）
- ⏳ 周报/月报统计（BaseData 有记录，但无可视化）

**日记数据模型**：

```gdscript
# NoteState 管理
var notes: Dictionary  # key=date_string ("2024-01-17"), value=NoteData

class NoteData:
    var text: String
    var created_at: int
    var last_modified_at: int
    var mood: int  # 1-5 心情
    var focus_time: int  # 该日专注时长
```

#### 待完善

| 功能 | 状态 | 备注 |
|-----|-----|-----|
| 日记快速输入 | ✅ 完成 | 有快捷按钮 |
| 心情/感受记录 | ⏳ 50% | UI 未集成心情选择 |
| 周报生成 | ❌ 未做 | 需要 Agent 总结能力 |
| 月报图表 | ❌ 未做 | 需要数据可视化 |
| 统计趋势图 | ❌ 未做 | 长期数据挖掘 |

---

### 4️⃣ 经验与升级系统

#### 设计需求

```
机制：
✓ 每次专注获得经验
✓ 任务完成获得经验
✓ 成就达成获得经验
✓ 经验值对数增长 (升级难度递增)
✓ 升级解锁：场景、音乐、对话、演出
```

#### 现有实现

**核心类**：[LevelState](../scenes/main/autoload/data/level_state.gd)

```gdscript
var current_level: int = 1
var current_exp: int = 0
var total_exp: int = 0

# 对数增长公式：exp_for_level = 100 * ln(level + 1)
func _calculate_exp_for_next_level(level: int) -> int:
    return int(100 * log(level + 1))
```

**已实现 API**：
- ✅ `add_exp(amount)` - 添加经验
- ✅ `get_current_level()` - 获取等级
- ✅ `get_exp_progress()` - 进度百分比
- ✅ 自动升级信号：`level_up(new_level)`

**UI 实现**：[LevelBar](../scenes/main/ui/level_bar/)
- ✅ 等级显示
- ✅ 经验条
- ✅ 升级动画

**经验来源**：
- ✅ +10 exp：完成 1 个任务
- ✅ +5 exp：完成 1 个番茄钟
- ✅ +20 exp：达成每日成就
- ✅ +50 exp：达成周成就

#### 解锁机制

> ⏳ **部分实现**：等级存储，但解锁内容的关联逻辑不完整

建议补充：

```gdscript
# LevelState 中添加解锁表
const UNLOCK_TABLE = {
    1: { "scene_decors": ["desk_wood"], "music": ["bgm_morning"] },
    5: { "scene_decors": ["window_rain"], "music": ["bgm_rain"], "dialogue": ["hello_day5"] },
    10: { "scene_decors": ["cafe_outside"], "music": ["bgm_cafe"], "performances": ["perf_celebrate"] },
    # ...
}

func get_unlocked_content_for_level(level: int) -> Dictionary:
    var unlocked = {}
    for lv in range(1, level + 1):
        if lv in UNLOCK_TABLE:
            for key in UNLOCK_TABLE[lv]:
                if key not in unlocked:
                    unlocked[key] = []
                unlocked[key].append_array(UNLOCK_TABLE[lv][key])
    return unlocked
```

---

### 5️⃣ 场景与装饰系统

#### 设计需求

```
功能：
✓ 场景由组件构成
✓ 组件可切换
✓ 通过等级解锁新组件
✓ 支持结构化文本修改
✓ 女孩有时会改变场景

结构：
Desk (场景根)
├─ Background (背景：工作台)
├─ Decor1 (装饰：窗户)
├─ Decor2 (装饰：植物)
├─ Lighting (光效：台灯)
└─ Ambient (氛围：下雨/晴天)
```

#### 现有实现

**核心类**：[RoomDecorState](../scenes/main/autoload/data/room_decor_state.gd)

```gdscript
var active_decors: Dictionary  # key=category, value=decor_name
# 示例：
# {
#   "background": "workspace_afternoon",
#   "wall": "poster_study",
#   "decor": ["plant_01", "lamp_table"],
#   "ambient": "rain_light"
# }
```

**已实现 API**：
- ✅ `set_active_decor(category, decor_name)` - 切换装饰
- ✅ `add_decor(decor)` - 添加装饰
- ✅ `remove_decor(decor)` - 移除装饰
- ✅ `get_active_decors()` - 获取当前配置

**数据源**：[RoomDecorRes](../resource/room_decor_res/)

```gdscript
# 每个装饰物品 (RoomDecorItem)
var name: String              # "desk_wood"
var category: String          # "furniture"
var required_level: int = 1   # 解锁等级
var icon: Texture2D
var model_path: String        # 3D 模型路径
```

**3D 集成**：[Main3d](../scenes/main/3d/Main3d.gd)
- ✅ 监听 RoomDecorState 信号
- ✅ 根据装饰配置加载 3D 模型
- ✅ 切换场景动画（淡入淡出）

**UI 实现**：[RoomDecorModule](../scenes/main/ui/room_decor_module/)
- ✅ 装饰选择面板
- ✅ 按等级显示可用/锁定
- ✅ 实时预览

#### 待完善

| 功能 | 状态 | 优先级 |
|-----|-----|--------|
| 女孩自动改变场景 | ⏳ 20% | 中（需 Agent 集成） |
| 结构化文本解析 | ❌ 未做 | 低 |
| 场景存档系统 | ⏳ 50% | 中（需完善 RoomDecorState 导入导出） |
| 动态环境变化（时间同步） | ⏳ 30% | 低 |

**建议优化**：

```gdscript
# 支持文本格式：
# scene: {
#   "background": "workspace_rain",
#   "decors": ["plant_big", "lamp_desk"],
#   "ambient": "rain_medium"
# }

func apply_scene_text(text: String) → bool:
    var parsed = JSON.parse_string(text)
    if not parsed or not "scene" in parsed:
        return false
    
    var scene_config = parsed["scene"]
    for category in scene_config:
        set_active_decor(category, scene_config[category])
    
    return true
```

---

### 6️⃣ 音乐与环境音系统

#### 设计需求

```
音乐系统：
✓ 播放列表管理
✓ 顺序/随机/单曲循环
✓ 音量调节
✓ 淡入淡出

环境音：
✓ 白噪音（雨声、风、鸟鸣等）
✓ 独立音量控制
```

#### 现有实现

**✅ 已完全实现**：见 [音频系统指南](audio_system_and_resources_summary.md)

- ✅ MusicState（17 个信号、完整 API）
- ✅ AudioPlayer（淡入淡出、音量管理）
- ✅ 持久化（user://music_data.json）
- ✅ UI 模块（MusicModule）

**音乐资源**：[AudioRes](../resource/audio_res/)

```gdscript
var BGM: Array[AudioItem]
var sound_effect: Array[AudioItem]
```

**环境音**：⏳ **部分实现**
- ✅ SFX 系统可播放环境音
- ⏳ 需添加"环境音管理器"（常驻、独立音量）

**建议补充**：

```gdscript
# AmbientSoundState (新增 Autoload)
var ambient_enabled: bool = true
var ambient_tracks: Array[String]  # ["rain_light", "cafe_murmur"]
var ambient_volume: float = 0.5

func set_ambient_track(track_name: String) → void:
    # 停止旧环境音
    # 播放新环境音（无限循环）

func set_ambient_volume(volume: float) → void:
    # 调节当前环境音音量
```

---

### 7️⃣ 角色与演出系统

#### 设计需求

```
角色交互：
✓ 点击角色 → 随机演出（IDLE 模式）
✓ 专注中点击 → 专注演出 (多次退出)
✓ 对话中点击 → 无响应
✓ 演出包含：动作 + 表情 + 对话

演出内容：
✓ 欢迎/问候
✓ 鼓励话语
✓ 任务提醒
✓ 专注完成贺词
✓ 自适应情绪
```

#### 现有实现

**核心类**：[Character](../scenes/main/3d/character/character.gd)

```gdscript
# 双 AnimationTree 架构
var action_tree: AnimationTree  # 姿态动作 (idle, writing, thinking...)
var emotion_tree: AnimationTree  # 表情 (happy, calm, excited...)

# 当前状态
var current_emotion: String = "calm"
var is_focusing: bool = false
var is_talking: bool = false
```

**已实现 API**：
- ✅ `play_action(action_name)` - 播放动作
- ✅ `set_emotion(emotion_name)` - 设置表情
- ✅ `play_performance(perf_name)` - 播放演出
- ✅ `interact(interact_type)` - 处理交互

**UI 实现**：[CharacterInteractor](../scenes/main/ui/character_interactor/)
- ✅ 点击检测
- ✅ 多次点击计数（触发强制退出专注）
- ✅ 演出播放

**DialogueBox**：
- ✅ 文本流式显示
- ✅ BBCode 格式支持
- ✅ 选项按钮（如有）

#### 演出系统 ⏳ **部分实现** (40%)

**现状**：
- ✅ 动作库（idle, writing, thinking）
- ✅ 表情库（happy, calm, sad）
- ✅ 动作树可播放
- ❌ **演出脚本序列系统不完整**

**待实现**：演出脚本的定义、存储、解析、播放

**建议实现**：

```gdscript
# PerformanceData - 演出脚本定义 (res://resource/performances/)
class PerformanceScript:
    var name: String           # "greet_morning"
    var mode: int              # 0=IDLE, 1=FOCUS 模式
    var duration: float        # 总时长
    var steps: Array[PerfStep]  # 脚本步骤序列

class PerfStep:
    var delay: float           # 从演出开始延迟时长
    var type: int              # 0=action, 1=emotion, 2=dialogue, 3=sound
    var content: String        # 具体内容（动作名、台词等）
    var duration: float = 0.0  # 该步保持时长

# 示例对话：
# {
#   "name": "greet_morning",
#   "mode": 0,
#   "duration": 3.5,
#   "steps": [
#     { "delay": 0.0, "type": 0, "content": "wave", "duration": 1.0 },
#     { "delay": 0.3, "type": 1, "content": "happy", "duration": 3.0 },
#     { "delay": 0.5, "type": 2, "content": "早上好！" },
#     { "delay": 2.0, "type": 3, "content": "sfx_cute_sound" }
#   ]
# }

# Character 脚本播放器
func play_performance(perf_name: String) → void:
    var perf_res = preload("res://resource/performances/") \
        .get_child_by_name(perf_name + ".tres")
    if not perf_res:
        return
    
    _current_performance = perf_res
    for step in perf_res.steps:
        await get_tree().create_timer(step.delay).timeout
        _execute_performance_step(step)
```

**待完成的工作**：
1. ✅ 定义 PerformanceScript 数据模型
2. ❌ 创建演出脚本资源文件
3. ❌ 实现脚本解析与播放器
4. ❌ 从 Agent 生成的文本解析成演出脚本

---

### 8️⃣ AI 对话系统

#### 设计需求

```
功能：
✓ 自然对话 (LLM 驱动)
✓ 长期记忆 (RAG)
✓ 角色设定一致性 (Prompt 系统)
✓ 生成配套演出
✓ 调控场景/音乐
✓ 任务规划建议
```

#### 现有实现

**✅ 已完全实现**：见 [AI Agent 系统指南](ai_agent_system_summary.md)

**核心架构**：
```
ChatModule (UI)
    ↓ 用户输入
InputBox
    ↓ 消息发送
ChatController (Godot 端)
    ↓ 上下文收集
ContextCollector
    ↓ 序列化 Prompt
Python Agent (服务器)
    ↓ LLM 处理 + 函数调用
SSE 流式返回
    ↓ 
DialogueBox (流式展示)
    ↓
Character (演出)
```

**已实现**：
- ✅ ChatController：对话流程管理
- ✅ AgentExecutor：函数调用执行
- ✅ ContextCollector：上下文数据收集
- ✅ ChatState：对话记录存储
- ✅ Python ChatAgent：LLM 集成
- ✅ Python ReflectionAgent：周报总结

**11 个已实现的函数调用**：

| 函数 | 目的 | 实现状态 |
|-----|-----|--------|
| `create_task()` | 创建任务 | ✅ |
| `update_task()` | 更新任务 | ✅ |
| `delete_task()` | 删除任务 | ✅ |
| `set_focus_mode()` | 启动专注 | ✅ |
| `get_task_list()` | 查询任务 | ✅ |
| `get_current_level()` | 查询等级 | ✅ |
| `set_scene()` | 改变场景 | ✅ |
| `set_music()` | 改变音乐 | ✅ |
| `set_ambient()` | 改变环境音 | ✅ |
| `record_mood()` | 记录心情 | ✅ |
| `generate_summary()` | 生成周报 | ✅ |

#### 待完善

| 功能 | 优先级 | 方案 |
|-----|--------|------|
| 演出生成 | 🔴 高 | Agent 输出演出脚本序列 |
| RAG 记忆 | 🔴 高 | 实现 VectorStore（Faiss/Milvus） |
| 任务优化建议 | 🟡 中 | PlannerAgent 扩展分析能力 |
| 离线模式 | 🟡 中 | 本地量化 LLM |
| 语音 I/O | 🟡 中 | STT/TTS 集成 |

---

### 9️⃣ 成就与每日任务系统

#### 设计需求

```
成就：
✓ 长期成就 (一次性)
✓ 每日任务 (24h 重置)
✓ 成就达成 → 奖励经验
✓ UI 显示进度/奖励

示例：
- "连续 7 天完成任务" → 100 exp
- "单次专注超过 1 小时" → 50 exp
- 每日："完成 5 个任务" → 20 exp
```

#### 现有实现

**核心类**：[AchievementState](../scenes/main/autoload/data/achievement_state.gd)

```gdscript
# 长期成就
var achievements: Dictionary  # key=achievement_id, value=AchievementData

class AchievementData:
    var id: int
    var name: String
    var description: String
    var progress: int  # 当前进度
    var target: int    # 目标值
    var reward_exp: int
    var unlocked: bool
    var unlocked_at: int

# 每日任务
var daily_tasks: Array[DailyTaskData]  # 每天 3-5 个任务
var refresh_time: int  # 上次刷新时间戳
```

**已实现 API**：
- ✅ `check_achievement(id)` - 检查成就条件
- ✅ `unlock_achievement(id)` - 解锁成就
- ✅ `claim_reward(id)` - 领取奖励(加经验)
- ✅ `auto_claim_reward()` - 自动领取
- ✅ `daily_tasks_refresh()` - 每日自动刷新

**UI 实现**：[AchievementModule](../scenes/main/ui/achievement_module/)
- ✅ 成就 Tab（列表、进度条、锁定状态）
- ✅ 每日任务 Tab（动态生成任务列表）
- ✅ 领取按钮 & 动画

#### 完成度

- ✅ **核心机制**：100% 完成
- ✅ **数据驱动**：100% 完成
- ⏳ **美术表现**：80% (结束演出完善)

---

### 🔟 记忆与上下文系统

#### 设计需求

```
记忆类型：
✓ 短期记忆 (当前对话上下文)
✓ 长期记忆 (历史对话、事件、偏好)
✓ 用户画像 (工作风格、学习节奏)

实现方式：
✓ 基础：JSON 结构化存储
✓ 高级：RAG 向量检索
```

#### 现有实现

**ChatState**：[chat_state.gd](../scenes/main/autoload/data/chat_state.gd)

```gdscript
# 基础记忆存储
var messages: Array[Message]  # 对话历史
var user_preferences: Dictionary  # 用户偏好（名字、风格等）
var past_events: Array[Event]  # 历史事件记录

class Message:
    var role: String  # "user" / "assistant"
    var content: String
    var timestamp: int
    var metadata: Dictionary  # 关键词、主题等

class Event:
    var date: int
    var description: String
    var impact: int  # 1-5 重要程度
```

**ContextCollector**：[context_collector.gd](../scenes/main/autoload/ai_service/)

```gdscript
# 收集上下文用于 Agent
func collect_context() → Dictionary:
    return {
        "user": _collect_user_context(),           # 用户状态
        "task": TaskState.get_all_tasks(),         # 任务列表
        "level": { "current": LevelState.current_level },
        "today_events": _collect_today_events(),   # 今日事件
        "chat_history": ChatState.messages[-20:],  # 最近 20 条消息
        "user_mood": _analyze_user_mood()          # 情绪分析
    }
```

**数据检查点**：
- ✅ 对话持久化（user://chat_data.json）
- ✅ 事件记录
- ✅ 用户偏好存储
- ⏳ RAG 向量检索（未完全实现）

#### 待完善

| 功能 | 优先级 | 实现方案 |
|-----|--------|--------|
| 向量嵌入与检索 | 🔴 高 | 集成 Sentence Transformers + Faiss/Redis |
| 自动情绪分析 | 🟡 中 | 文本情感分析 (TextBlob/LLM) |
| 用户画像构建 | 🟡 中 | 工作模式、学习风格分类 |
| 遗忘机制 | 🟢 低 | 旧记忆衰减 (可选产品特性) |

**建议优化代码**：

```gdscript
# 在 ChatState 中添加向量检索
var embedding_model: Variant  # 加载预训练模型
var memory_index: Variant  # Faiss index

func _retrieve_relevant_memories(query: String, top_k: int = 5) -> Array:
    # 1. 将 query 转换为向量
    var query_embedding = embedding_model.encode(query)
    
    # 2. 在 FAISS 索引中搜索最近邻
    var distances, indices = memory_index.search(query_embedding, top_k)
    
    # 3. 返回相关记忆
    var relevant = []
    for idx in indices[0]:
        relevant.append(messages[idx])
    return relevant

# 在 ContextCollector 中使用
func collect_context() -> Dictionary:
    var context = {
        # ... 其他字段 ...
        "relevant_memories": ChatState._retrieve_relevant_memories(
            user_input, 5
        )
    }
    return context
```

---

### 1️⃣1️⃣ 高级 AI 功能

#### 任务生成与规划

**设计需求**：
- Agent 从对话理解用户目标 → 解析为任务列表
- 自动评估任务时间 → 制定时间表
- 大任务自动分解为子任务

**现有实现**：⏳ **60%**

| 功能 | 实现 | 位置 |
|-----|-----|------|
| 任务提取 | ✅ 部分 | ChatAgent (Python) |
| 优先级排序 | ✅ 部分 | PlannerAgent |
| 任务分解 | ⏳ 30% | PlannerAgent (待完善) |
| 时间评估 | ⏳ 40% | PlannerAgent |
| 自动安排 | ❌ 未做 | — |

**改进方案**：

```python
# agent/core/planner_agent.py

class PlannerAgent:
    def generate_task_plan(self, user_goal: str, user_context: dict) -> dict:
        """
        从用户目标生成任务计划
        Returns: {
            "tasks": [
                {"title": "...", "duration": 30, "priority": 1, "subtasks": [...]}
            ],
            "schedule": {...}  # 按时间排序
        }
        """
        # 第一步：提取任务
        task_list = self._extract_tasks(user_goal)
        
        # 第二步：评估时间
        for task in task_list:
            task["duration"] = self._estimate_duration(
                task["title"], 
                user_context.get("user_experience_level")
            )
        
        # 第三步：分解大任务
        for task in task_list:
            if task["duration"] > 90:  # 大于 1.5 小时
                task["subtasks"] = self._decompose_task(task)
        
        # 第四步：优先级排序
        task_list = self._sort_by_priority(task_list, user_goal)
        
        return {"tasks": task_list}
```

#### 周报与总结

**设计需求**：
- Agent 自动生成周报（工作内容、成就、改进建议）
- 即使用户"什么都没做"也能生成温暖的总结
- 可导出为文本/图表

**现有实现**：✅ **ReflectionAgent 基础完成**

```python
# agent/core/reflection_agent.py
class ReflectionAgent:
    def generate_weekly_summary(self, weekly_data: dict) -> str:
        """生成周报"""
        # 分析工作量
        # 识别关键成就
        # 提供建议
        # 温暖鼓励
```

**优化方向**：
- ⏳ 支持图表生成（matplotlib）
- ⏳ 支持多语种
- ⏳ 支持用户自定义周报模板

---

### 1️⃣2️⃣ 主线任务与故事线（未实现）

#### 设计需求

```
分阶段解锁功能：

第 0 天：只有「对话」按钮
    └─ 女孩："我是来陪伴你的"
       → 解锁「待办事项」

第 1 天：完成第一个任务
    └─ 女孩（演出）："太棒了！"
       → 解锁「专注模式」

第 3 天：连续 3 天使用
    └─ 女孩（演出）："我逐渐了解你了..."
       → 解锁「日历」

... (更多解锁)

特殊线索：「女孩寄了」
    └─ 到一定等级或事件触发
       → 女孩："我其实是虚拟的..."
       → 她给出保存记忆的方法
       → 为下一个"她"保留回忆
```

#### 实现方案

建议创建新的 Autoload 单例：**MainlineQuestState**

```gdscript
# scenes/main/autoload/data/mainline_quest_state.gd
class_name MainlineQuestState extends Node

# 主线任务进度
var current_chapter: int = 0  # 当前章节
var chapter_completed: Array[bool] = [false] * 20  # 各章节完成状态

const CHAPTER_DEFINITIONS = [
    {
        "id": 0,
        "name": "初见",
        "trigger": "first_launch",
        "unlock": ["chat_feature"],
        "dialogue": "dialogue_intro",
        "performance": "perf_greet_first"
    },
    {
        "id": 1,
        "name": "第一个任务",
        "trigger": "task_count >= 1",
        "unlock": ["task_feature"],
        "dialogue": "dialogue_first_task",
        "performance": "perf_celebrate_first_task"
    },
    # ... 更多章节
]

signal chapter_unlocked(chapter_id: int)

func _check_chapter_progress() → void:
    # 每帧或每个重要事件检查
    for chapter in CHAPTER_DEFINITIONS:
        if not chapter_completed[chapter["id"]]:
            if _check_trigger(chapter["trigger"]):
                _unlock_chapter(chapter)

func _check_trigger(trigger: String) -> bool:
    var parts = trigger.split(" ")
    match parts[0]:
        "first_launch":
            return ChatState.messages.size() == 0
        "task_count":
            # 解析 ">=" 条件
            return TaskState.get_all_tasks().size() >= int(parts[2])
        # ... 更多触发条件
    return false

func _unlock_chapter(chapter: Dictionary) → void:
    chapter_completed[chapter["id"]] = true
    
    # 解锁功能
    for feature in chapter["unlock"]:
        _unlock_feature(feature)
    
    # 触发对话与演出
    _trigger_dialogue_and_performance(chapter)
    
    chapter_unlocked.emit(chapter["id"])
```

#### 特殊剧情：「女孩寄了」

```gdscript
# 触发条件示例：
# - 达到等级 50
# - 或 累计使用时长 100 小时
# - 或 成就解锁 90%

const SPECIAL_STORY_TRIGGER = {
    "level": 50,
    "total_usage_hours": 100,
    "achievements_percent": 90
}

func _check_special_story_trigger() → bool:
    return (
        LevelState.current_level >= SPECIAL_STORY_TRIGGER["level"] or
        _get_total_usage_hours() >= SPECIAL_STORY_TRIGGER["total_usage_hours"]
    )

func trigger_special_story() → void:
    # 一系列演出与对话
    # 女孩："其实我一开始没告诉你..."
    # → 对话展示她是 AI 的内心独白
    # → "我想保留和你的记忆..."
    # → "这是存储链接，给下一个'她'..."
    # → 导出记忆库 (encryption)
    # → 女孩消失（结局元素）
    
    var memory_export = _export_memories()
    var export_link = _generate_export_link(memory_export)
    
    # UI 显示导出链接
    DialogueBox.show_special_dialogue({
        "text": "这是我们的记忆，请保留好...",
        "action_button": "复制链接",
        "export_link": export_link
    })
```

---

## 待优化与扩展

### 🔴 高优先级

#### 1. 演出脚本系统完整化

当前状态：30% 完成（动画树存在，脚本系统不完整）

**工作量**：中等  
**收益**：对话体验 +50%

**TODO**：
- [ ] 定义 PerformanceScript 类 & 资源格式
- [ ] 实现脚本编辑器（可
视化或文本）
- [ ] Agent 集成：生成演出脚本
- [ ] 5-10 个通用演出预设（问候、鼓励、庆祝等）

#### 2. RAG 向量记忆完整化

当前状态：50% 完成（基础 JSON 存储，无向量检索）

**工作量**：中等  
**收益**：对话个性化 +40%

**TODO**：
- [ ] 集成 Sentence Transformers（Python side）
- [ ] 集成 Faiss 或 Redis 向量库
- [ ] 优化 ContextCollector 接口
- [ ] 测试长对话连贯性（100+ 条消息）

#### 3. 主线任务系统实现

当前状态：0% 完成

**工作量**：高  
**收益**：新手留存 +30%、故事体验 +50%

**TODO**：
- [ ] 创建 MainlineQuestState
- [ ] 定义 15-20 个章节
- [ ] 编写故事对白与演出
- [ ] 实现"女孩寄了"特殊结局

---

### 🟡 中优先级

#### 4. 环境音系统完善

当前状态：50% 完成（SFX 系统可用，管理器不完整）

**工作量**：低  
**收益**：沉浸感 +20%

**TODO**：
- [ ] AmbientSoundState 新增 Autoload
- [ ] 环境音音量独立控制
- [ ] 3-5 个预设环境音（雨、咖啡馆、清晨等）
- [ ] UI 环境音选择面板

#### 5. 任务推荐与智能安排

当前状态：60% 完成（Agent 基础存在，分析能力不足）

**工作量**：中等  
**收益**：生产力提升 +20%

**TODO**：
- [ ] PlannerAgent 完善时间评估模型
- [ ] 支持"我不知道要做什么" → Agent 建议流程
- [ ] 优先级动态调整（基于完成率历史）
- [ ] 任务自动分解为子任务

#### 6. 个性化周报生成

当前状态：70% 完成（ReflectionAgent 基础，可视化缺失）

**工作量**：中等  
**收益**：反馈体验 +30%

**TODO**：
- [ ] 支持 Markdown / HTML 导出
- [ ] 图表生成（matplotlib）
- [ ] 周报邮件通知（可选）
- [ ] 长期趋势图表（月度、季度）

---

### 🟢 低优先级

#### 7. 语音 I/O（STT/TTS）

当前状态：0% 完成

**工作量**：中等  
**收益**：可用性 +20%（可选产品功能）

**推荐方案**：
- STT：OpenAI Whisper API
- TTS：Edge TTS（免费）或 Piper.ai（本地）

#### 8. 离线模式支持

当前状态：0% 完成

**工作量**：高  
**收益**：用户体验 +15%（边界场景）

**方案**：本地量化 LLM（Ollama + Mistral 7B）

#### 9. 多角色 DLC

当前状态：0% 完成

**工作量**：很高  
**收益**：长期内容扩展

**计划**：v1.5+ 版本考虑

---

## 未来版本规划

### v0.6.0（下个迭代）

**主题**：故事与沉浸感

- ✅ MainlineQuestState 实现
- ✅ PerformanceScript 系统补完
- ✅ 5+ 演出预设
- ✅ 特殊结局"女孩寄了"

**预期收益**：
- 新手留存 ↑ 30%
- 故事代入感 ↑ 50%

---

### v0.7.0（后续迭代）

**主题**：智能陪伴

- ✅ RAG 向量记忆完整化
- ✅ 任务智能推荐
- ✅ 周报可视化
- ✅ 情绪识别与自适应

**预期收益**：
- 对话深度 ↑ 40%
- 生产力体感 ↑ 25%

---

### v1.0.0（正式版）

**主题**：完整体验

- ✅ 所有核心功能打磨
- ✅ 视觉美术完善
- ✅ 音乐/音效扩展
- ✅ 性能优化
- ✅ 多语言支持

**预期指标**：
- 日活留存 60%+
- 平均会话时长 30+ 分钟
- 用户满意度 4.5/5.0

---

### 后续 DLC

- **多角色扩展**（v1.5）
- **离线LLM 支持**（v1.2）
- **语音交互**（v1.1）
- **云存档同步**（v1.0 minor）

---

## 开发成本与时间估算

### 基于 4 人团队

| 角色 | 工作项 | 时间 |
|-----|--------|------|
| **程序（2 人）** | 主线任务系统、演出脚本、RAG | 2-3 周 |
| **美术（1 人）** | 演出资源、UI 优化、特效 | 2 周 |
| **音频（0.5 人）** | 演出音效、特殊音乐 | 1 周 |
| **策划（0.5 人）** | 故事编写、Prompt 调优 | 1 周 |

**总计**：**4-5 周** 完成 v0.6.0

---

## 核心指标追踪表

定期检查这些指标以评估项目进度：

| 指标 | 目标 | 当前 | 截止 |
|-----|------|------|------|
| 功能完成度 | 80% | 65% | v0.6.0 |
| 美术资源数 | 50+ | 35 | v0.6.0 |
| AI 函数调用 | 15+ | 11 | v0.7.0 |
| 故事章节 | 20 | 0 | v0.6.0 |
| 演出预设 | 30+ | 8 | v0.6.0 |
| 新手转化率 | 70% | TBD | v1.0.0 |
| DAU | 1000+ | — | v1.0.0 |

---

## 关键文档索引

| 文档 | 查阅用途 |
|-----|--------|
| [UI & Data 模块指南](ui_data_modules_summary.md) | 各模块 API 详解 |
| [3D 系统指南](3d_system_summary.md) | Character、Room、演出 |
| [AI Agent 指南](ai_agent_system_summary.md) | LLM 对话、函数调用 |
| [音频系统指南](audio_system_and_resources_summary.md) | 音乐、环境音、SFX |
| [工具脚本指南](transition_tools_and_plugins_summary.md) | 工具链、插件 |
| **[本文件]** | **设计与实现对照** |

---

## 常见问题速查

### Q: 主线任务要怎么集成到现有代码？

**A**：创建 MainlineQuestState Autoload → 在 _process() 逐帧检查条件 → 触发时调用 ChatController.request_special_dialogue() → 播放演出 → 解锁功能。

### Q: 女孩怎么自动改变场景？

**A**：设计 Agent 输出 `set_scene()` 函数调用 → AgentExecutor 执行 → RoomDecorState 更新 → 场景淡入淡出。

### Q: 演出脚本要怎么定义？

**A**：参考本文档的"演出系统"章节 → 创建 PerformanceScript 数据模型 → 编辑器存储为 .tres 资源 → Character 读取播放。

### Q: 如何测试 RAG 记忆效果？

**A**：连续对话 50+ 条消息 → 提出不在最近消息中的旧话题 → 检查 Agent 是否能用 `_retrieve_relevant_memories()` 找到相关记忆。

---

**文档完成** ✓  
**最后更新**：2024  
**下一步**：分配 v0.6.0 任务，启动主线任务系统开发
