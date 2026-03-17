# 3D 系统总体架构与实现

本文档总结 `scenes/main/3d` 下的 3D 场景、角色系统、环境管理、天气特效、房间装饰等核心模块的设计与交互。

## 1. 3D 整体概览

```
Main 3D Scene (main_3d.gd)
├── Character (VRM 模型 + 双 AnimationTree)
│   ├── ActionTree (动作状态机: idle ↔ typing ↔ talk + 一次性动作)
│   └── EmotionTree (表情状态机: neutral ↔ happy ↔ sad ↔ surprised ↔ angry ↔ saying)
│
├── TimeOfDay (时间计时器)
├── Sky3D (天空/光照)
├── Camera3D (主摄像机)
│
├── Outdoor (环境管理)
│   ├── Planet (行星: 黑洞、紫星、火星)
│   ├── WindowSide (窗边: 樱花 / 鲸)
│   │   └── CherryBlossom (物理摆动)
│   └── RainSystem / SnowSystem (粒子特效)
│
├── Room (房间装饰)
│   └── Decor (书架、灯、球体等装饰物)
│
├── SideDesk (侧柜: 鲜花 / 猫咪)
├── OnDesk (桌面: 闹钟 / 台灯)
└── Particles: Rain, Snow (全局天气粒子)
```

## 2. 场景主控 — Main3d

**脚本**: [scenes/main/3d/main_3d.gd](../scenes/main/3d/main_3d.gd)

### 2.1 职责

- 管理所有 3D 节点生命周期（角色、环境、特效）
- 协调全局环境状态（时间、天气、天尊光照）
- 响应 Godot UI 数据层信号（SettingState、PomodoroState 等）
- 驱动角色动作与表情（基于任务完成、番茄钟事件）

### 2.2 核心方法

| 方法 | 参数 | 功能 |
|---|---|---|
| `set_env_time_daytime()` | 无 | 切换到白天（带 Tween 动画） |
| `set_env_time_dusk()` | 无 | 切换到黄昏 |
| `set_env_time_evening()` | 无 | 切换到晚上 |
| `set_env_time_sync()` | 无 | 按系统时间自动同步 |
| `set_env_weather_sunny()` | 无 | 晴天 |
| `set_env_weather_rain()` | 无 | 雨天 |
| `set_env_weather_snowy()` | 无 | 下雪 |
| `set_rain_amount(amount)` | int (300~1200) | 调整雨滴密度 |
| `set_snow_amount(amount)` | int (500~2000) | 调整雪花密度 |
| `_animate_time(target_time)` | float | 用 Tween 平滑过渡天空颜色 |

### 2.3 信号连接

| 信号来源 | 信号名 | 处理方法 | 作用 |
|---|---|---|---|
| SettingState | `env_time_changed(mode)` | `_on_setting_env_time_changed()` | 时间模式切换（0=白天, 1=黄昏, 2=晚上, 3=同步） |
| SettingState | `env_weather_changed(mode)` | `_on_setting_env_weather_changed()` | 天气模式切换（0=晴天, 1=雨, 2=雪） |
| SettingState | `rain_changed(amount)` | `_on_setting_rain_changed()` | 雨量变化 |
| SettingState | `snow_changed(amount)` | `_on_setting_snow_changed()` | 雪量变化 |
| SettingState | `fog_changed(state)` | `_on_setting_fog_changed()` | 雾效开关 |
| SettingState | `camera_changed(mode)` | `_on_setting_camera_changed()` | 摄像机位置调整 |
| PomodoroState | `work_phase_started` | `_on_pomodoro_work_phase_started()` | 进入工作阶段 → 角色转向 typing_pose |
| PomodoroState | `work_phase_stopped` | `_on_pomodoro_work_phase_stopped()` | 工作停止 → 角色转向 idle_pose |
| PomodoroState | `rest_phase_completed` | `_on_pomodoro_rest_phase_completed()` | 休息完成 → 角色播放 cheer_pose |
| TaskState | `task_completed` | `_on_task_state_task_completed()` | 任务完成 → 角色播放 cheer_pose |
| CharacterInteractorState | `character_interacted` | `_on_character_interacted()` | 用户点击角色 → 角色播放 surprised_pose |
| RoomDecorState | `room_decor_selected` | `_on_room_decor_selected()` | 房间装修项选中 → 更新对应 3D 场景 |
| RoomDecorState | `room_decor_category_unselected` | `_on_room_decor_category_unselected()` | 装修项取消 → 隐藏对应 3D 物体 |

### 2.4 核心实现细节

#### 环境时间切换

```gdscript
func _animate_time(target_time: float) -> void:
    # 使用 Tween 平滑过渡 Sky3D 的光照与颜色
    # 持续时间通常 1-2 秒
    var tween = create_tween().set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
    tween.tween_property(sky3d, "sky_light:energy", target_energy, 1.5)
    # 同时调整环境光颜色、太阳光颜色等
```

#### 天气粒子控制

```gdscript
func set_rain_amount(amount: int) -> void:
    amount = clampi(amount, RAIN_MIN_AMOUNT, RAIN_MAX_AMOUNT)
    rain.set_amount(amount)  # 传给 Rain 组件控制粒子数
```

---

## 3. 角色系统 — Character

**脚本**: [scenes/main/3d/character/character.gd](../scenes/main/3d/character/character.gd)

### 3.1 双 AnimationTree 架构

角色同时拥有两套独立的动画树：

| 动画树 | 用途 | 状态示例 |
|---|---|---|
| **action_tree** | 身体姿态 | idle, typing, talk; 一次性: clap, think, cheer, watch, greet, surprised, disbelief, stretch, stretch2 |
| **emotion_tree** | 面部表情 | neutral, happy, sad, surprised, angry, saying; 一次性: blinking |

### 3.2 动作系统

#### 持续动作（需手动返回 idle）

```gdscript
set_idle_pose()      # 站立空闲
set_typing_pose()    # 打字姿态（手指动作）
set_talk_pose()      # 对话姿态（身体微动）
```

调用者需负责在适当时机调用 `set_idle_pose()` 返回。

#### 一次性动作（自动返回 idle）

```gdscript
set_cheer_pose()        # 欢呼（手臂抬起）— 用于任务完成
set_clap_pose()         # 鼓掌
set_think_pose()        # 思考（表情同时设为 angry）
set_watch_pose()        # 观看（表情 neutral）
set_greet_pose()        # 打招呼（表情 happy）
set_surprised_pose()    # 惊讶（表情 surprised）
set_disbelief_pose()    # 怀疑（表情 sad）
set_stretch_pose()      # 伸展（表情 neutral）
set_stretch2_pose()     # 伸展变体（表情 neutral）
```

这些动作播放完成后自动调用 `_return_to_idle()`，不需要外部干预。

**约束**：一次性动作仅在 `action_state == "idle"` 时才能触发，其他状态会被忽略。

### 3.3 表情系统

#### 持续表情

```gdscript
set_neutral()       # 无表情（默认）
set_happy()         # 开心
set_sad()           # 难过
set_surprised()     # 惊讶
set_angry()         # 生气
set_saying()        # 说话（口形）
```

可与任何动作组合，不受 action_state 影响。

#### 一次性表情

```gdscript
set_blinking()  # 眨眼（自动返回到当前持续表情）
```

### 3.4 自动行为

#### Idle Variation（定时随机小动作）

```gdscript
@export var idle_variation_enabled: bool = true
@export var idle_variation_min_delay_sec: float = 6.0
@export var idle_variation_max_delay_sec: float = 18.0
@export var idle_variation_weights: Dictionary = {
    "watch": 0.25,
    "stretch": 0.25,
    "stretch2": 0.25,
    "think": 0.25
}
```

在 idle 状态下，每 6-18 秒随机选一个权重，触发对应小动作。

#### 自动眨眼

```gdscript
@export var blinking_enabled: bool = true
@export var blinking_min_delay_sec: float = 3.0
@export var blinking_max_delay_sec: float = 8.0
```

独立定时器，每 3-8 秒眨眼一次。仅在表情为 `neutral` 时分发。

**防重复**：已调度的眨眼若被新的眨眼打断，自动取消旧定时器。

---

## 4. 环境子系统

### 4.1 行星系统 — Planet

**脚本**: [scenes/main/3d/outdoor/planet/planet.gd](../scenes/main/3d/outdoor/planet/planet.gd)

管理三个可见行星对象：黑洞、紫星、火星（通常最多在视野内显示一个）。

```gdscript
show_black_hole()       # 显示黑洞
show_purple_planet()    # 显示紫星
show_fire_planet()      # 显示火星
hide_all()              # 隐藏所有
```

### 4.2 窗边环境 — WindowSide

**脚本**: [scenes/main/3d/outdoor/window_side/window_side.gd](../scenes/main/3d/outdoor/window_side/window_side.gd)

管理两套窗边装饰：樱花 vs 鲸。

```gdscript
show_cherry()   # 显示樱花
show_whale()    # 显示鲸
hide_all()      # 隐藏所有
```

### 4.3 樱花摆动 — CherryBlossom

**脚本**: [scenes/main/3d/outdoor/window_side/cherry_blossom.gd](../scenes/main/3d/outdoor/window_side/cherry_blossom.gd)

给樱花 MeshInstance3D 添加物理摆动效果。

```gdscript
@export var sway_strength: float = 0.3    # 摆幅（弧度）
@export var sway_speed: float = 1.5       # 摆动速度（rad/s）

func _process(delta: float) -> void:
    var angle = sin(time * sway_speed) * sway_strength
    node.rotation = Vector3(angle, 0, 0)  # 每帧更新旋转
```

---

## 5. 天气特效

### 5.1 下雨系统 — Rain

**脚本**: [scenes/main/3d/rain/rain.gd](../scenes/main/3d/rain/rain.gd)

```gdscript
@export var min_amount: int = 300
@export var max_amount: int = 1200

func set_amount(amount: int) -> void:
    particles.amount = clampi(amount, min_amount, max_amount)
```

通过调整 `GPUParticles3D.amount` 属性改变雨滴密度。

### 5.2 下雪系统 — Snow

**脚本**: [scenes/main/3d/snow/snow.gd](../scenes/main/3d/snow/snow.gd)

```gdscript
@export var min_amount: int = 500
@export var max_amount: int = 2000

func set_amount(amount: int) -> void:
    particles.amount = clampi(amount, min_amount, max_amount)
```

与下雨系统类似，但雪花范围与密度配置不同。

---

## 6. 房间装饰

### 6.1 侧柜 — SideDesk

**脚本**: [scenes/main/3d/side_desk/side_desk.gd](../scenes/main/3d/side_desk/side_desk.gd)

管理两种侧柜显示方案。

```gdscript
show_flowers()  # 显示鲜花
show_cat()      # 显示猫咪
hide_all()      # 隐藏所有
```

### 6.2 桌面 — OnDesk

**脚本**: [scenes/main/3d/on_desk/on_desk.gd](../scenes/main/3d/on_desk/on_desk.gd)

管理两种桌面装饰。

```gdscript
show_alarm_clock()  # 显示闹钟
show_night_light()  # 显示台灯
hide_all()          # 隐藏所有
```

### 6.3 房间静态装饰

`room/decor/` 下存放各种静态装饰模型（书架、灯、球体、壁纸、娃娃等），通过 RoomDecorState 的选择进行显示/隐藏。

---

## 7. 与 Data 层的集成

| Data 单例 | 对应 Main3d 的处理 | 3D 反馈 |
|---|---|---|
| **SettingState** | 监听时间/天气/光照/摄像机信号 | 环境动画平滑切换 |
| **PomodoroState** | 监听工作/休息相位 | 角色 typing → idle, 完成时 cheer |
| **TaskState** | 监听任务完成 | 角色播放 cheer_pose |
| **CharacterInteractorState** | 监听交互事件 | 角色播放 surprised_pose |
| **RoomDecorState** | 监听装饰选中/取消 | 显示/隐藏对应 3D 物体与 SideDesk/OnDesk 模式 |

---

## 8. 快速参考 — 常见操作

### 8.1 切换环境时间

```gdscript
# 从 UI 设置中触发
Main3d.set_env_time_daytime()  # 白天
Main3d.set_env_time_dusk()      # 黄昏
Main3d.set_env_time_evening()   # 晚上
```

### 8.2 触发任务完成动作

```gdscript
# Main3d._on_task_state_task_completed() 自动处理
# 角色自动播放欢呼动作
```

### 8.3 驱动角色对话

```gdscript
character.set_talk_pose()      # 开始对话
character.set_saying()         # 设置口形表情
# ... 对话进行中 ...
character.set_idle_pose()      # 对话结束，返回空闲
character.set_neutral()        # 表情恢复
```

### 8.4 手动触发小动作

```gdscript
character.set_think_pose()      # 思考（自动返回 idle）
character.set_surprised_pose()  # 惊讶（自动返回 idle）
```

---

## 9. 设计亮点

1. **Tween 平滑过渡**：环境参数（时间、光照）使用 Tween 而非瞬间切换，提升视觉连贯性。
2. **双动画树解耦**：动作与表情独立，允许灵活组合，无需复杂的动画融合。
3. **自动行为系统**：Idle Variation 和 Blinking 减轻主程打理角色，使其更显生动。
4. **条件约束**：一次性动作仅在 idle 时生效，防止不自然的肢体冲突。
5. **信号驱动**：所有环境变化来自上层 Data 单例，保持 3D 层的被动性，避免业务逻辑泄漏。

---

## 10. 故障排查

| 问题 | 症状 | 排查步骤 |
|---|---|---|
| 角色动作不播放 | 按钮点击无响应 | 检查是否在 idle 状态；检查 action_tree 是否有效 |
| 表情不更新 | 一直是默认表情 | 检查 emotion_tree 连接；检查 set_neutral() 是否被调用 |
| 环境光照突变 | 没有 Tween 过渡 | 检查 `set_env_time_*()` 是否调用了 `_animate_time()` |
| 下雨/下雪无效 | 粒子不显示或固定数量 | 检查 Rain/Snow 中 `particles` 引用是否有效 |
| 房间装饰没变 | RoomDecorState 信号发出但无效果 | 检查 SideDesk/OnDesk 的可见性与 Node3D 引用 |

