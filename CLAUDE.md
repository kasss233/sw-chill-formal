# CLAUDE.md

## Project Overview

Godot 4.6 项目（Mobile 渲染），3D 角色互动 + Material Design UI 系统（音乐、任务、AI 对话、番茄钟、笔记）。

## Development Commands

Godot 项目，无传统构建/测试命令，通过 Godot Editor 开发。

## Architecture

### 三层架构

```
Data Autoload (单例) → UI Module (模块) → UI Component (组件)
```

- **Data Autoload**：继承 `Node`，注册为 Autoload 单例，唯一数据源，修改后自动持久化到 `user://`，通过信号通知 UI 层。命名：`XxxState`
- **UI Module**：监听 State 信号响应式更新 UI。用户操作 → State API → State 信号 → Module 更新。禁止直接修改数据
- **UI Component**：纯展示 + 交互，不持有业务数据。信号上报传 ID 不传 self，提供 `update_display(data)`

### 架构规则

1. **数据流向**：所有数据变更必须通过 State 单例 API，UI 响应 State 信号更新，禁止在 UI 层直接修改数据属性
2. **信号通信**：Component 信号（传 ID）→ Module 监听 → Module 调 State API → State 发信号 → Module 更新 UI
3. **Agent API**：数据操作直接调用 State 单例；UI 操作（动画）调用 Module 方法。Parser (`agent/godot_paser/paser.gd`) 直接持有 Module 和 State 引用，`ui.gd` 不封装 Agent API
4. **State 单例规范**：
   - 信号命名：`xxx_added(data)`, `xxx_removed(id)`, `xxx_updated(data)`, `xxx_state_changed(data)`, `xxxs_reordered`, `data_loaded`
   - 持久化格式：`{"version": 1, "next_id": N, "items": [...]}`
   - 数据模型实现 `to_dict() -> Dictionary` 和 `static from_dict(d) -> XxxData`
5. **双布局**：横竖屏两套 `.tscn` 共享同一 Module 脚本，节点命名跨布局一致
6. **动画一致性**：Task: Tween + back easing 0.4s；Dialog: scale + alpha 0.2s；Audio: Tween fade

### Autoload 单例

| 单例 | 路径 | 职责 |
|---|---|---|
| GuiTransitions | `addons/simple-gui-transitions/singleton.gd` | UI 布局切换动画，`go_to()` / `show()` / `hide()` |
| AudioPlayer | `scenes/main/audio_player/audio_player.tscn` | BGM/SFX 引擎，音量淡入淡出，crossfade。`is_paused` 独立于当前曲目 |
| MusicState | `scenes/main/audio_player/music_state.gd` | 音乐状态数据源：曲目、播放状态、模式(SEQUENTIAL/RANDOM/SINGLE_LOOP)、播放列表 |
| TaskState | `scenes/main/data/task_state.gd` | 任务数据管理，持久化 `user://task_data.json`，60s 检查截止时间 |
| AIService | `scenes/main/ai_service/ai_service.tscn` | OpenAI 兼容 SSE 流式 API，多模态，线程化 HTTP |

### 音频数据流

```
AudioRes (resource/audio_res/) → AudioPlayer → MusicModule → MusicList → MusicItem
```

### UI Modules (`scenes/main/ui/`)

| 模块 | 脚本 | 职责 |
|---|---|---|
| Main UI Controller | `ui.gd` | UI 协调器，信号转发，不含 Agent API |
| MusicModule | `music_module/music_module.gd` | 音乐播放 UI，多播放列表 |
| TaskModule | `task_module_new/task_module_new.gd` | 任务管理，ReorderableVBox 拖拽排序 |
| NoteModule | `note_module/note_module.gd` | 便签系统（上限 20），`take_note(text)` |
| NotebookModule | `notebook_module/note_book.gd` | 多页笔记本 |
| InputBox | `input_box/input_box.gd` | AI 对话输入框，单行/多行切换，图片附件(max 2) |
| DialogueBox | `dialogue_box/dialogue_box.gd` | AI 对话展示，逐字流式动画，BBCode，3 个操作按钮 |
| Setting | `setting/setting.gd` | 环境时间/天气/抗锯齿设置，持久化到 `user://settings.cfg` |
| PomodoroModule | `pomodoro_technique_module/pomodoro_technique_module.gd` | 番茄钟，CanvasLayer UI |
| CharacterInteractor | `character_interactor/character_interactor.gd` | 角色交互触发（3 次点击） |

### 3D Components

- **Character** (`scenes/main/3d/character/character.gd`)：VRM 角色，双 AnimationTree（action_tree 姿势 + emotion_tree 表情），支持对话动画
- **Room** (`scenes/main/3d/room/`)：环境道具
- **Environment**：`outdoor/` / `rain/` / `snow/`

## UI Components 与 Skill 工具

Material Design 组件位于 `scenes/main/ui/components/`，继承 Godot 原语，`@tool` 标记，mixin 共享行为。另有 Calendar（日历）和 DatePicker（日期选择器）两个非 Material 组件。

**规则：使用或配置以下组件时，必须优先调用对应 Skill 工具获取规范，而非搜索源码。仅当 Skill 不足时才读源码补充。**

| Skill | 组件 |
|---|---|
| `material-button` | MaterialButton |
| `material-checkbox` | MaterialCheckbox |
| `material-chip` | MaterialChip |
| `material-context-menu` | MaterialContextMenu |
| `material-dialog` | MaterialDialog |
| `material-drag-handle` | MaterialDragHandle |
| `material-fab` | MaterialFAB |
| `material-menu` | MaterialMenu |
| `material-menu-button` | MaterialMenuButton |
| `material-dropdown` | MaterialDropdown |
| `material-progress-indicator` | MaterialProgressIndicator |
| `material-segmented-button` | MaterialSegmentedButton |
| `material-slider` | MaterialSlider |
| `material-snackbar` | MaterialSnackbar |
| `material-switch` | MaterialSwitch |
| `material-text-field` | MaterialTextField |
| `material-toggle-button` | MaterialToggleButton |
| `frosted-panel` | FrostedPanel |
| `inner-panel` | InnerPanel |

## Project Structure

```
scenes/main/
├── 3d/                      # Character, Room, Environment
├── ai_service/              # AIService autoload (adapters/, context, agent, tts)
├── audio_player/            # AudioPlayer + MusicState autoload
├── data/                    # Data Autoload singletons (TaskState, NoteState, etc.)
└── ui/
	├── components/          # Material Design 组件 (→ 用 Skill 工具查询)
	├── music_module/
	├── task_module_new/
	├── note_module/
	├── notebook_module/
	├── notebook_mobile_module/
	├── input_box/
	├── dialogue_box/
	├── setting/
	├── pomodoro_technique_module/
	├── character_interactor/
	└── debug/

addons/                      # vrm, Godot-MToon-Shader, sky_3d,
							 # simple-gui-transitions, SmoothScroll,
							 # ReorderableContainer, calendar_library, markdownlabel
resource/audio_res/          # AudioRes 音频资源
agent/godot_paser/paser.gd   # Agent JSON → modules/State
docs/REFACTOR_GUIDE.md       # 三层架构重构指南（权威规则）
```

## Important Notes

- **Godot 4.6**，Mobile 渲染
- **语言约定**：所有对话、文档、注释、commit message 使用中文
- **重构指南**：`docs/REFACTOR_GUIDE.md` 为三层架构权威规则文档
- **启用插件**：vrm, Godot-MToon-Shader, ReorderableContainer, SmoothScroll, markdownlabel, simple-gui-transitions, sky_3d
