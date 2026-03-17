# 过渡动画、工具脚本与插件集成指南

**版本**：1.0 | **作者**：AI Agent | **最后更新**：2024

---

## 📖 目录

1. [整体架构](#整体架构)
2. [TransitionAnimation 过渡动画](#transitionanimation-过渡动画)
3. [工具脚本详解](#工具脚本详解)
4. [插件集成清单](#插件集成清单)
5. [快速参考](#快速参考)
6. [故障排查](#故障排查)

---

## 整体架构

### 系统分层

```
┌────────────────────────────────────────────────────────────────┐
│                    UI 层 + 3D 系统                               │
│                   (gameplay & scenes)                           │
└────────┬──────────────────────────────────────────────────────┘
         │ 调用或使用以下系统
         ├─────────────────────────────────────────────────┐
         │                                                 │
         ↓                                                 ↓
┌────────────────────────────┐      ┌────────────────────────────┐
│  GuiTransitions            │      │  TransitionAnimation       │
│  (UI 场景切换动画 Addon)     │      │  (启动过渡效果 Autoload)    │
│   - go_to() / show() / hide()      │   - play_startup_transition()
└────────────────────────────┘      └────────────────────────────┘
         │                                      │
         ↓                                      ↓
  ┌──────────────────┐            ┌────────────────────────────┐
  │ 布局切换动画      │            │  启动画面焦点框、扫描线     │
  │ (CanvasLayer)   │            │  (5 层视觉效果编排)        │
  └──────────────────┘            └────────────────────────────┘
```

### 工具脚本与资源系统

```
┌──────────────────────────────────────────────────────────────┐
│                     工具脚本 (scripts/)                        │
├──────────────────────────────────────────────────────────────┤
│ ┌──────────────────────┐  ┌──────────┐  ┌──────────────────┐ │
│ │  sync_change.gd      │  │ free_    │  │ toon_fix_trans.  │ │
│ │  (数据同步记录)       │  │ camera.  │  │ gd (着色器自动   │ │
│ │                      │  │ gd (调   │  │ 化)              │ │
│ │  - 记录本地变更      │  │ 试相机)  │  │                  │ │
│ │  - 版本/时间戳      │  │          │  │ - 后处理导入      │ │
│ │  - 序列化到服务器    │  │ - WASD   │  │ - 着色器应用      │ │
│ └──────────────────────┘  │ 控制     │  │ - 透明/实心识别   │ │
│                           │ - 鼠标   │  └──────────────────┘ │
│                           │ 环顾     │                        │
│                           │ - 速度   │                        │
│                           │ 调节     │                        │
│                           └──────────┘                        │
└──────────────────────────────────────────────────────────────┘
```

---

## TransitionAnimation 过渡动画

**位置**：`scenes/main/autoload/transition_animation/transition_animation.tscn` + `transition_animation.gd`  
**集成方式**：Autoload（全局 `TransitionAnimation` 单例）  
**用途**：启动画面过渡动画，包含炫彩视觉效果（快门、扫描线、焦点框）

### 设计目的

为应用启动时创建专业化的视觉过渡效果：
- **沉浸感**：多层次动画效果营造科技感
- **专业性**：类似现代软件启动画面
- **品牌识别**：可自定义参数调整风格

### 核心组件与时序

#### 5 层视觉效果分层结构

```
时间轴 (总长 ~1.02 秒)

阶段 1: 快门 (0 → 0.28s)
┌─────┬─────┬─────────────────────────────────────────────┐
│上黑条│     │                                             │
│ ↓↓↓ │ Y↑  │ ┌─────────────────────────────────────────┐ │
│     │ 0→-400 px                                        │ │
│     │     │ │            屏幕内容                       │ │
│     │     │ │ (淡暗 α: 1.0 → 0.12)                    │ │
│     │     │ │                                         │ │
│下黑条│     │ │ └─────────────────────────────────────┘ │
│ ↑↑↑ │ Y↓  │                                             │
│     │ 0→+400 px                                        │
└─────┴─────┴─────────────────────────────────────────────┘

结果：屏幕从上下两端被黑条挤压，内容暗淡

阶段 2: 淡黑消逝 (0.28s → 0.42s)
┌──────────────────────────────────┐
│ ColorRect "_fade"                │
│ α: 0.12 → 0.0                   │
│ (黑色逐渐透明)                   │
└──────────────────────────────────┘

结果：屏幕逐渐恢复亮度

阶段 3: 扫描线下扫 (0.42s → 0.76s)
┌───────────────────────────────────┐
│ 🔦 (扫描线)                        │
│ Y: -8 → 屏幕高 + 8               │
│ α: 0.55 → 0.0                    │
│                                   │
│ (模拟 CRT 显示器扫描效果)        │
└───────────────────────────────────┘

结果：科技感十足的扫描线从上到下移动并消逝

阶段 4: 焦点框脉冲 (0.76s → 1.02s)
┌───────────────────────────────────┐
│ ┌─────────────────────────────┐  │
│ │ ╔════════════════════════╗  │  │
│ │ ║   焦点边框脉冲         ║  │  │
│ │ ║ scale: 1.18 → 1.0     ║  │  │
│ │ ║ α: 0 → 0.85 → 0       ║  │  │
│ │ ╚════════════════════════╝  │  │
│ │                             │  │
│ └─────────────────────────────┘  │
└───────────────────────────────────┘

结果：从外向内收缩的焦点框最后出现又消逝，标志过渡结束
```

### 节点结构与层级

```
TransitionAnimation (Node2D, @tool 标记)
│
├── CanvasLayer (layer=120, 确保前景)
│   │
│   └── Control "TransitionOverlay"
│       │
│       ├── ColorRect "_fade"
│       │   ├── color: Color.BLACK
│       │   ├── anchor_right: 1.0
│       │   ├── anchor_bottom: 1.0
│       │   └── modulate.a: 1.0 (初始不透明)
│       │
│       ├── ColorRect "_shutter_top" (上快门)
│       │   ├── color: Color.BLACK
│       │   ├── size.y: 屏幕高 * 0.5
│       │   └── position.y: 0 → -屏幕高 * 0.5 (向上收缩)
│       │
│       ├── ColorRect "_shutter_bottom" (下快门)
│       │   ├── color: Color.BLACK
│       │   ├── size.y: 屏幕高 * 0.5
│       │   └── position.y: 屏幕高 → 屏幕高 * 1.5 (向下收缩)
│       │
│       ├── ColorRect "_scanline" (扫描线)
│       │   ├── color: Color(0.8, 0.9, 1.0, 0.55) (淡蓝绿)
│       │   ├── size: [屏幕宽, 8px] (水平线)
│       │   ├── position.y: -8 → 屏幕高 + 8 (纵向移动)
│       │   └── modulate.a: 0.55 → 0.0 (淡出)
│       │
│       └── Panel "_focus_frame" (焦点边框)
│           ├── theme: 自定义边框样式
│           ├── scale: 1.18 → 1.0 (收缩)
│           ├── modulate.a: 0 → 0.85 → 0 (闪现-消逝)
│           └── centered: true
```

### 关键配置参数

```gdscript
@export var shutter_duration: float = 0.28      # 快门收缩时长
@export var scanline_duration: float = 0.34     # 扫描线横扫时长
@export var focus_pulse_duration: float = 0.2   # 焦点框脉冲时长
@export var block_input_during_transition: bool = true  # 过渡期间阻挡输入
@export var auto_play_on_ready: bool = true     # 是否在 _ready 时自动启动

# 内部参数
var _fade_color: Color = Color.BLACK
var _has_played: bool = false                   # 防止重复播放
```

### 公开 API

#### 核心方法

```gdscript
# 播放启动过渡动画（主要公开 API）
# 注意：使用 call_deferred 以确保场景树已完全初始化
func play_startup_transition() → void:
    call_deferred("_play_animation")

# 实际播放逻辑（内部）
func _play_animation() → void:
    if _has_played:
        return  # 防止重复播放
    _has_played = true
    
    # 依次执行各阶段
    await _play_shutter_phase()
    await _play_fade_phase()
    await _play_scanline_phase()
    await _play_focus_phase()
    
    startup_transition_finished.emit()
```

### 信号

```gdscript
# 过渡动画完全播放完毕时发出
signal startup_transition_finished
```

### 与 UI 的集成方式

#### 使用场景：应用启动时

```gdscript
# 在主 UI 场景的 _ready 中
func _ready() → void:
    # 场景树初始化完毕后执行过渡
    TransitionAnimation.play_startup_transition()
    
    # 监听过渡完成信号
    await TransitionAnimation.startup_transition_finished
    
    # 过渡完毕后开始 UI 初始化
    _initialize_ui()
    _load_game_data()
```

#### 时序控制

```
应用启动
    ↓
UI 场景加载到场景树
    ↓
_ready() 被调用
    ↓
call_deferred("TransitionAnimation.play_startup_transition()")
    ↓ (下一帧执行)
TransitionAnimation 开始 1.02s 动画
    ├─ 0.00s - 0.28s: 快门收缩 + 淡暗
    ├─ 0.28s - 0.42s: 淡黑消逝
    ├─ 0.42s - 0.76s: 扫描线下扫
    └─ 0.76s - 1.02s: 焦点框脉冲
    ↓
signal startup_transition_finished 发出
    ↓
UI 模块继续初始化（期间被冻结）
```

#### 输入阻挡

```gdscript
# 过渡期间自动阻挡用户输入
func _play_animation() → void:
    if block_input_during_transition:
        get_tree().paused = true  # OR mouse_filter = MOUSE_FILTER_STOP
    
    # 执行过渡...
    await ...
    
    if block_input_during_transition:
        get_tree().paused = false
```

---

## 工具脚本详解

### 1. sync_change.gd - 数据同步记录

**位置**：`scripts/sync_change.gd`  
**继承自**：`RefCounted`  
**用途**：记录本地数据的每次变更，等待推送到服务器同步

#### 数据模型

```gdscript
class_name SyncChange extends RefCounted

# 必填字段
var resource: String        # 资源类型 ("task" / "note" / "category")
var action: String          # 动作类型 ("create" / "update" / "delete" / "reorder")
var local_id: int           # 本地对象 ID；category 用 0
var local_key: String       # category 的唯一标识（name）；其他资源用 ""
var data: Dictionary         # 发送至服务器的 data 字段（包含所有字段）
var timestamp: int          # 变更时间戳（毫秒）
```

#### 支持的资源与动作

| 资源 | 支持的动作 | 备注 |
|-----|---------|-----|
| task | create, update, delete, reorder | 任务管理 |
| note | create, update, delete | 便签管理 |
| category | create, update, delete | 分类（标签） |

#### 公开方法

```gdscript
# 构造函数
func _init(
    p_resource: String,       # "task" / "note" / "category"
    p_action: String,         # "create" / "update" / "delete" / "reorder"
    p_local_id: int,          # 本地 ID
    p_local_key: String,      # category name 或空字符串
    p_data: Dictionary,       # 数据内容
    p_timestamp: int          # 时间戳
) → void

# 序列化为字典（用于存储/网络传输）
func to_dict() → Dictionary:
    return {
        "resource": resource,
        "action": action,
        "local_id": local_id,
        "local_key": local_key,
        "data": data,
        "timestamp": timestamp
    }

# 从字典反序列化
static func from_dict(d: Dictionary) → SyncChange:
    return SyncChange.new(
        d["resource"],
        d["action"],
        d["local_id"],
        d["local_key"],
        d["data"],
        d["timestamp"]
    )
```

#### 使用示例

##### 创建新任务

```gdscript
# TaskState.gd 中
func create_task(title: String, content: String) → int:
    var new_id = _get_next_id()
    var task_data = {
        "id": new_id,
        "title": title,
        "content": content,
        "created_at": Time.get_unix_time_from_system()
    }
    
    # 1. 更新本地模型
    _tasks[new_id] = TaskData.new(task_data)
    
    # 2. 记录同步变更
    var change = SyncChange.new(
        "task",                          # resource
        "create",                        # action
        new_id,                          # local_id
        "",                              # local_key (task 不用)
        task_data,                       # data
        int(Time.get_unix_time_from_system() * 1000)  # timestamp
    )
    _sync_queue.append(change)
    
    # 3. 持久化到本地
    _save_data()
    
    # 4. 发出信号
    task_created.emit(new_id)
    
    return new_id
```

##### 更新任务

```gdscript
func update_task(task_id: int, updated_data: Dictionary) → void:
    if task_id not in _tasks:
        return
    
    # 1. 更新本地模型
    _tasks[task_id].update(updated_data)
    
    # 2. 记录同步变更
    var change = SyncChange.new(
        "task",
        "update",
        task_id,
        "",
        updated_data,
        int(Time.get_unix_time_from_system() * 1000)
    )
    _sync_queue.append(change)
    
    # 3. 触发持久化与信号
    _save_data()
    task_updated.emit(task_id)
```

##### 删除任务

```gdscript
func delete_task(task_id: int) → void:
    if task_id not in _tasks:
        return
    
    # 1. 删除本地数据
    _tasks.erase(task_id)
    
    # 2. 记录同步变更
    var change = SyncChange.new(
        "task",
        "delete",
        task_id,
        "",
        {},  # delete 的 data 为空
        int(Time.get_unix_time_from_system() * 1000)
    )
    _sync_queue.append(change)
    
    # 3. 持久化与信号
    _save_data()
    task_deleted.emit(task_id)
```

##### 重排序任务

```gdscript
func reorder_tasks(new_order: Array[int]) → void:
    # 1. 更新本地排序
    _task_order = new_order
    
    # 2. 记录重排序变更
    var change = SyncChange.new(
        "task",
        "reorder",
        0,              # reorder 的 local_id 为 0
        "",
        {"order": new_order},  # 新顺序
        int(Time.get_unix_time_from_system() * 1000)
    )
    _sync_queue.append(change)
    
    # 3. 持久化与信号
    _save_data()
    tasks_reordered.emit()
```

#### 同步队列向服务器推送

```gdscript
# SyncState.gd 中
func sync_to_server() → void:
    if _sync_queue.is_empty():
        print("无同步项")
        return
    
    # 序列化所有变更记录
    var changes_data = []
    for change in _sync_queue:
        changes_data.append(change.to_dict())
    
    # 发送到服务器
    var response = await ApiClient.post("/sync/batch", {
        "changes": changes_data
    })
    
    if response.status == 200:
        # 清空队列
        _sync_queue.clear()
        print("同步成功")
    else:
        print("同步失败，重试...")
```

---

### 2. free_camera.gd - 自由视角调试相机

**位置**：`scripts/free_camera.gd`  
**继承自**：`Camera3D`  
**用途**：在 3D 编辑器/运行时实时调整视角，用于场景调整、调试、预览

#### 控制映射

| 按键/操作 | 功能 |
|----------|-----|
| **W** | 向前移动 |
| **A** | 向左移动 |
| **S** | 向后移动 |
| **D** | 向右移动 |
| **Q** | 向下移动 |
| **E** | 向上移动 |
| **右键 + 鼠标移动** | 旋转视角 (Pitch & Yaw) |
| **鼠标滚轮向上** | 加速（速度倍数 ×2） |
| **鼠标滚轮向下** | 减速（速度倍数 ÷2） |
| **Shift** | 速度加成（×2.5） |
| **Alt** | 速度减速（×0.4） |

#### 关键属性

```gdscript
@export var initial_speed: float = 4.0       # 基础移动速度 (m/s)
@export_range(0.0, 1.0) var sensitivity: float = 0.25  # 鼠标旋转灵敏度

# 内部状态
var _velocity: Vector3 = Vector3.ZERO        # 当前速度向量
var _vel_multiplier: float = 1.0             # 速度倍数（0.2 ~ 20）
var _acceleration: int = 30                  # 加速度（单位：m/s²）
var _deceleration: int = -10                 # 减速度（制动）
var _mouse_motion: Vector2 = Vector2.ZERO    # 鼠标运动累积
var _pitch: float = 0.0                      # 俯仰角（X 旋转）
var _yaw: float = 0.0                        # 偏航角（Y 旋转）
```

#### 核心实现逻辑

##### 输入处理

```gdscript
func _process(delta: float) → void:
    if not is_current():
        return
    
    # 1. 获取移动输入
    var input_dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
    var up_input = Input.get_action_strength("ui_page_up") - Input.get_action_strength("ui_page_down")
    
    # 2. 计算目标速度
    var target_speed = initial_speed * _vel_multiplier
    if Input.is_action_pressed("ui_shift"):
        target_speed *= 2.5
    if Input.is_action_pressed("ui_alt"):
        target_speed *= 0.4
    
    # 3. 加速/减速物理
    var desired_velocity = (
        global_transform.basis.x * input_dir.x +
        global_transform.basis.y * up_input +
        global_transform.basis.z * input_dir.y
    ) * target_speed
    
    # 平滑速度变化（Drag-like behavior）
    _velocity = _velocity.lerp(desired_velocity, delta * 0.3)
    
    # 4. 应用运动
    global_position += _velocity * delta
    
    # 5. 处理旋转
    _process_rotation(delta)

func _process_rotation(delta: float) → void:
    # 鼠标右键按下时启用旋转
    if Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
        # 捕获鼠标
        Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
        
        # 获取鼠标运动
        var mouse_motion = Input.get_last_mouse_velocity()
        
        # 计算旋转角度
        _yaw -= mouse_motion.x * sensitivity * delta
        _pitch -= mouse_motion.y * sensitivity * delta
        _pitch = clamp(_pitch, -PI / 2, PI / 2)
        
        # 应用旋转
        global_transform.basis = Basis.from_euler(Vector3(_pitch, _yaw, 0))
    else:
        # 释放鼠标
        Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
```

##### 鼠标滚轮速度调整

```gdscript
func _input(event: InputEvent) → void:
    if not is_current():
        return
    
    if event is InputEventMouseButton:
        if event.button_index == MOUSE_BUTTON_WHEEL_UP:
            _vel_multiplier = min(_vel_multiplier * 1.5, 20.0)  # 加速
            print("速度倍数：%.2f" % _vel_multiplier)
        elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
            _vel_multiplier = max(_vel_multiplier / 1.5, 0.2)   # 减速
            print("速度倍数：%.2f" % _vel_multiplier)
```

#### 使用场景

##### 场景调试

```gdscript
# Main3d.gd 中在调试模式启用自由相机
func _ready() → void:
    if DEBUG_MODE:
        _free_camera = Camera3D.new()
        _free_camera.script = load("res://scripts/free_camera.gd")
        add_child(_free_camera)
        _free_camera.current = true
        print("自由相机已启用")
```

##### 实时调整场景布局

```gdscript
# 使用自由相机预览房间装饰物品位置
# 1. 启用自由相机
# 2. WASD 移动、右键旋转到理想视点
# 3. 记录下当前相机位置与旋转
# 4. 调整场景中的物品位置
```

---

### 3. toon_fix_transparent.gd - 着色器自动化应用

**位置**：`scripts/toon_fix_transparent.gd`  
**继承自**：`EditorScenePostImport`  
**用途**：编辑器后处理脚本，导入 3D 模型时自动识别透明/实心物体并应用对应着色器

#### 工作流程

```
导入 3D 模型 (.gltf / .fbx)
    ↓
Godot 编辑器触发 EditorScenePostImport
    ↓
toon_fix_transparent._post_import(scene)
    ↓
遍历 MeshInstance3D 节点
    ├─ 逐个检查 Surface 材质名称
    ├─ 关键词匹配：["glass", "water", "liquid", "trans", "ice"]
    ├─ 如果匹配 → 应用 GLASS_SHADER（透明）
    └─ 否则 → 应用 TOON_SHADER + OUTLINE_SHADER（实心）
    ↓
从原材质迁移纹理、颜色参数
    ↓
应用到新材质
    ↓
返回修改后的场景
```

#### 着色器资源加载

```gdscript
const TOON_SHADER = preload("res://assets/shaders/flexible_toon.gdshader")
const GLASS_SHADER = preload("res://assets/shaders/flexible_toon_transparent.gdshader")
const OUTLINE_SHADER = preload("res://assets/shaders/outline.gdshader")

# 透明物体关键词列表（不区分大小写）
const TRANSPARENT_KEYWORDS = ["glass", "water", "liquid", "trans", "ice", "transparent"]
```

#### 核心实现

##### 场景遍历与材质检查

```gdscript
func _post_import(scene: Node) → Object:
    _process_node(scene)
    return scene

func _process_node(node: Node) → void:
    if node is MeshInstance3D:
        _process_mesh_instance(node)
    
    # 递归处理子节点
    for child in node.get_children():
        _process_node(child)

func _process_mesh_instance(mesh_instance: MeshInstance3D) → void:
    var mesh = mesh_instance.mesh
    if not mesh:
        return
    
    # 遍历每个 Surface
    for surface_idx in range(mesh.get_surface_count()):
        var original_material = mesh_instance.get_active_material(surface_idx)
        if not original_material:
            continue
        
        # 检查材质名称
        var material_name = original_material.resource_name.to_lower()
        var is_transparent = _is_transparent_material(material_name)
        
        # 创建新材质
        var new_material = _create_material(original_material, is_transparent)
        
        # 应用到 Surface（不修改原始 Mesh）
        mesh_instance.set_surface_override_material(surface_idx, new_material)
```

##### 透明度检测

```gdscript
func _is_transparent_material(material_name: String) → bool:
    material_name = material_name.to_lower()
    for keyword in TRANSPARENT_KEYWORDS:
        if keyword in material_name:
            return true
    return false
```

##### 材质创建与参数迁移

```gdscript
func _create_material(original_mat: Material, is_transparent: bool) → StandardMaterial3D:
    var new_mat = StandardMaterial3D.new()
    
    if is_transparent:
        # 应用透明着色器
        new_mat.set_shader(GLASS_SHADER)
        new_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
        
        # 菲涅尔效果（边缘不透明）
        new_mat.set_shader_parameter("fresnel_power", 2.0)
        new_mat.set_shader_parameter("edge_opacity", 0.8)      # 边缘 80% 不透明
        new_mat.set_shader_parameter("center_opacity", 0.1)    # 中心 10% 不透明
        
        # 颜色迁移
        if "albedo_color" in original_mat:
            new_mat.set_shader_parameter("albedo_color", original_mat.albedo_color)
        
    else:
        # 应用卡通着色器 + 描边
        new_mat.set_shader(TOON_SHADER)
        
        # 描边层（单独材质）
        var outline_mat = StandardMaterial3D.new()
        outline_mat.set_shader(OUTLINE_SHADER)
        outline_mat.set_shader_parameter("outline_color", Color.BLACK)
        outline_mat.set_shader_parameter("outline_width", 1.5)
        
        # 颜色与纹理迁移
        _migrate_material_properties(original_mat, new_mat)
    
    return new_mat

func _migrate_material_properties(from_mat: Material, to_mat: StandardMaterial3D) → void:
    # 迁移纹理
    if from_mat.has_method("get_albedo_texture"):
        var texture = from_mat.get_albedo_texture()
        if texture:
            to_mat.albedo_texture = texture
    
    # 迁移颜色
    if from_mat.has_method("get_albedo_color"):
        var color = from_mat.get_albedo_color()
        to_mat.albedo_color = color
    
    # 迁移粗糙度
    if from_mat.has_method("get_roughness"):
        var roughness = from_mat.get_roughness()
        to_mat.roughness = roughness
```

#### 透明材质参数说明

```gdscript
# 菲涅尔效果（Fresnel Effect）- 边缘自然过渡
"fresnel_power": float       # 值越大，菲涅尔效果越强烈
                             # 推荐值：2.0 ~ 5.0

# 边缘不透明度 - 玻璃/水边缘的透明度
"edge_opacity": float        # 0.0 (透明) ~ 1.0 (不透明)
                             # 推荐值：0.7 ~ 0.9

# 中心不透明度 - 物体中心的透明度
"center_opacity": float      # 0.0 (透明) ~ 1.0 (不透明)
                             # 推荐值：0.0 ~ 0.3
```

#### 使用示例

##### VRM 角色导入

```
1. 从 Metaverse 平台导出 VRM 模型
2. 放入 res://assets/3d/character/
3. 编辑器一次性导入处理
4. 自动识别材质：
   - Material_FaceSkin → TOON + OUTLINE
   - Material_HairMat → TOON + OUTLINE
   - Material_EyeGloss → GLASS（透明）
5. 导入完成，角色可即刻使用
```

##### 环境道具导入

```
1. 导入室内装饰模型
2. toon_fix_transparent 自动处理：
   - DeskWood → TOON + OUTLINE（颜色：木色）
   - WindowGlass_Trans → GLASS（半透明）
   - WallPaint → TOON + OUTLINE（颜色：墙色）
3. 调整参数（可选）：
   - glass 材质の edge_opacity: 0.8 → 0.5 (更透明)
```

---

## 插件集成清单

### 插件执行清单

| 插件 | 路径 | 启用状态 | 用途 | 依赖 |
|-----|-----|--------|-----|-----|
| **Godot-MToon-Shader** | `addons/Godot-MToon-Shader/` | ✅ | 二次元卡通着色器 | toon_fix_transparent.gd |
| **ReorderableContainer** | `addons/ReorderableContainer/` | ✅ | 拖拽排序容器 | Task/Calendar |
| **SmoothScroll** | `addons/SmoothScroll/` | ✅ | 平滑滚动（性能优化） | MusicModule/NotebookModule |
| **markdownlabel** | `addons/markdownlabel/` | ✅ | Markdown 文本渲染 | DialogueBox/NoteModule |
| **simple-gui-transitions** | `addons/simple-gui-transitions/` | ✅ | UI 场景切换动画 | GuiTransitions 单例 |
| **sky_3d** | `addons/sky_3d/` | ✅ | 3D 天空盒管理 | Room/Environment |
| **vrm** | `addons/vrm/` | ✅ | VRM 模型导入与动画 | Character 角色 |
| **calendar_library** | `addons/calendar_library/` | ✅ | 日历与日期选择器 | CalendarModule |

### 插件详解

#### 1. Godot-MToon-Shader

**用途**：日式二次元卡通着色器，为 VRM 角色提供专业渲染

**功能**：
- 二次元人物皮肤渲染（描边、漫反射）
- 毛发高光（Specular Highlight）
- 眼睛透光（Eye SSS）
- 轮廓描边（Outline）

**与项目的集成**：
- VRM 角色自动使用 MToon 材质
- `toon_fix_transparent.gd` 后处理脚本自动应用
- 支持自定义描边宽度、颜色

**配置示例**：
```gdscript
# Character.gd 中
var mtoon_material = StandardMaterial3D.new()
mtoon_material.shader = preload("res://addons/Godot-MToon-Shader/mtoon.gdshader")
mtoon_material.set_shader_parameter("outline_width", 1.5)
mtoon_material.set_shader_parameter("outline_color", Color.BLACK)
```

---

#### 2. ReorderableContainer

**用途**：可拖拽排序的容器组件，支持鼠标/触屏拖拽

**依赖关系**：
- **TaskModule** 使用 ReorderableVBox 实现任务拖拽排序
- **CalendarModule** 使用 ReorderableVBox 实现习惯课表排序

**API 示例**：
```gdscript
# TaskModule.gd 中
var reorderable_vbox = ReorderableVBox.new()
reorderable_vbox.items_reordered.connect(_on_task_reordered)
reorderable_vbox.add_child(task_item_scene)
```

---

#### 3. SmoothScroll

**用途**：高性能平滑滚动容器，优化列表滚动体验

**应用场景**：
- **MusicModule**：歌单列表平滑滚动
- **NotebookMobileModule**：笔记列表虚拟化滚动
- **AchievementModule**：成就列表长列表优化

**性能优化原理**：
- 虚拟化：仅渲染可见项
- 缓存复用：滚出视野的项回收并复用

---

#### 4. markdownlabel

**用途**：Markdown 和 BBCode 文本渲染

**支持的格式**：
- Markdown: `# 标题`、`**粗体**`、`_斜体_`、`[链接](url)`
- BBCode: `[b]粗体[/b]`、`[color=red]红色[/color]`

**应用场景**：
- **DialogueBox**：AI 对话中的格式化文本
- **NoteModule**：笔记内容的 Markdown 渲染
- **ChatModule**：聊天消息格式化

**使用示例**：
```gdscript
# DialogueBox.gd 中
var markdown_label = MarkdownLabel.new()
markdown_label.text = """
# 标题
**粗体文本**
> 引用
"""
```

---

#### 5. simple-gui-transitions

**用途**：UI 场景切换动画框架（通过 `GuiTransitions` 单例使用）

**主要方法**：
```gdscript
# 过渡到新场景（带动画）
GuiTransitions.go_to("res://scenes/ui/music_module/music_module.tscn")

# 显示浮窗（带进入动画）
GuiTransitions.show()

# 隐藏浮窗（带退出动画）
GuiTransitions.hide()
```

**内置动画样式**：
- Fade（淡入淡出）
- Slide（滑动进出）
- Scale（缩放进出）
- Rotate（旋转进出）

---

#### 6. sky_3d

**用途**：3D 天空盒与环境编辑器

**功能**：
- 动态天空材质
- 环境光照编辑
- 时间日期 → 天空颜色变化

**与项目的集成**：
- **室外环境**（planet, cherry_blossom）使用 sky_3d 天空
- **EnvironmentController** 根据 SettingState（场景时间）动态切换天空

**配置示例**：
```gdscript
# Main3d.gd 中
var sky_3d = preload("res://addons/sky_3d/Sky3D.tscn").instantiate()
sky_3d.time_of_day = 12.0  # 中午
add_child(sky_3d)
```

---

#### 7. vrm

**用途**：VRM 格式模型导入与骨骼动画播放

**功能**：
- VRM 模型加载与骨骼匹配
- 表情混合形状（Blend Shapes）支持
- 动画状态机集成

**与项目的集成**：
- **Character.gd** 使用 vrm 插件加载 VRM 模型
- **AnimationTree** 驱动 VRM 骨骼动画（action_tree + emotion_tree）
- 表情与动作独立控制

**使用流程**：
```gdscript
# Character.gd 中
var vrm_importer = VRMImporter.new()
var character_model = vrm_importer.load_vrm("res://assets/3d/character/my_character.vrm")
add_child(character_model)
```

---

#### 8. calendar_library

**用途**：日历组件库（Calendar 与 DatePicker）

**包含组件**：
- **Calendar**：月历视图，支持事件标记
- **DatePicker**：日期选择器（弹窗）

**与项目的集成**：
- **CalendarModule** 使用 Calendar 显示习惯课表
- **PomodoroModule** 可用 DatePicker 选择计时开始日期

**使用示例**：
```gdscript
# CalendarModule.gd 中
var calendar = Calendar.new()
calendar.selected_date = Time.get_date_dict_from_system()
calendar.date_selected.connect(_on_date_selected)
add_child(calendar)
```

---

### 插件启用配置

**位置**：`project.godot`

```ini
[editor_plugins]
enabled=PackedStringArray(
    "res://addons/Godot-MToon-Shader/plugin.cfg",
    "res://addons/ReorderableContainer/plugin.cfg",
    "res://addons/SmoothScroll/plugin.cfg",
    "res://addons/markdownlabel/plugin.cfg",
    "res://addons/simple-gui-transitions/plugin.cfg",
    "res://addons/sky_3d/plugin.cfg",
    "res://addons/vrm/plugin.cfg",
    "res://addons/calendar_library/plugin.cfg"
)
```

---

## 快速参考

### TransitionAnimation 使用

```gdscript
# 在 UI 主场景启动时
func _ready() → void:
    TransitionAnimation.play_startup_transition()
    await TransitionAnimation.startup_transition_finished
    _initialize_ui()

# 自定义过渡参数
TransitionAnimation.shutter_duration = 0.5      # 快门时长
TransitionAnimation.focus_pulse_duration = 0.3  # 焦点框时长
TransitionAnimation.block_input_during_transition = true
```

### SyncChange 使用

```gdscript
# 创建同步变更
var change = SyncChange.new(
    "task",
    "create",
    task_id,
    "",
    task_data,
    int(Time.get_unix_time_from_system() * 1000)
)

# 压入同步队列
_sync_queue.append(change)

# 序列化/反序列化
var dict = change.to_dict()
var restored = SyncChange.from_dict(dict)
```

### 自由相机启用

```gdscript
# 在 Main3d.gd 中启用调试模式
if DEBUG_MODE:
    free_camera_enabled = true
    var free_cam = Camera3D.new()
    free_cam.script = load("res://scripts/free_camera.gd")
    add_child(free_cam)
```

### 着色器自动应用

```gdscript
# toon_fix_transparent.gd 自动处理（无需手动调用）
# 导入 VRM/3D 模型时自动执行
# → 透明材质 + GLASS_SHADER
# → 实心材质 + TOON_SHADER + OUTLINE_SHADER
```

### 插件快速导入

```gdscript
# 使用 simple-gui-transitions 切换场景
GuiTransitions.go_to("res://scenes/ui/music_module.tscn")

# 使用 calendar_library 选择日期
var date_picker = DatePicker.new()
date_picker.date_selected.connect(_on_date_selected)

# 使用 markdownlabel 渲染文本
var md_label = MarkdownLabel.new()
md_label.text = "# 标题\n**粗体**"
```

---

## 故障排查

### ❌ TransitionAnimation 不播放

**诊断**：

```gdscript
# 1. 检查 Autoload 注册
if TransitionAnimation == null:
    print("ERROR: TransitionAnimation 未注册为 Autoload")
    return

# 2. 检查节点初始化
if TransitionAnimation._root == null:
    print("ERROR: TransitionAnimation 节点未初始化")
    return

# 3. 检查是否已播放过
if TransitionAnimation._has_played:
    print("WARNING: 过渡动画已播放过，设计中仅播放一次")
    # 如要重播，重置 _has_played = false
```

**修复**：
```gdscript
# 确保在场景树初始化后调用
TransitionAnimation.call_deferred("play_startup_transition")

# 或使用 call_deferred 包装
func _ready() → void:
    await get_tree().process_frame  # 等待场景树初始化
    TransitionAnimation.play_startup_transition()
```

### ❌ SyncChange 序列化失败

**原因分析**：

| 症状 | 原因 | 修复 |
|-----|-----|-----|
| `to_dict()` 返回空 | 字段未初始化 | 检查构造函数参数 |
| `from_dict()` 异常 | 字典字段缺失 | 确保字典包含所有必填字段 |

**检查**：
```gdscript
var change = SyncChange.new("task", "create", 1, "", {}, 0)
var dict = change.to_dict()

# 验证必填字段
assert("resource" in dict)
assert("action" in dict)
assert("local_id" in dict)
assert("timestamp" in dict)
```

### ❌ 自由相机不响应输入

**诊断**：

```gdscript
if not free_camera.is_current():
    print("ERROR: 自由相机未设置为当前相机")
    return

# 检查输入映射
if not InputMap.has_action("ui_up"):
    print("ERROR: 输入映射未定义 ui_up")
    return

# 检查 Input 事件捕获
if Input.get_mouse_mode() == Input.MOUSE_MODE_CONFINED:
    print("WARNING: 鼠标被限制在窗口内")
```

### ❌ 着色器应用失败

**原因分析**：

| 症状 | 原因 | 修复 |
|-----|-----|-----|
| 材质全黑 | 着色器文件路径错误 | 检查 `preload()` 路径 |
| 无法识别透明 | 关键词列表不匹配 | 添加材质名称到 TRANSPARENT_KEYWORDS |
| 描边过粗/过细 | outline_width 参数 | 调整 0.5 ~ 3.0 范围 |

**修复**：
```gdscript
# 添加自定义关键词
const TRANSPARENT_KEYWORDS = ["glass", "water", "custom_transparent"]

# 调整描边宽度
outline_mat.set_shader_parameter("outline_width", 1.0)  # 默认 1.5
```

### ❌ 插件未启用

**检查步骤**：

```
1. Project → Project Settings → Plugins
2. 确认所有必需插件的 Status = Enabled
3. 如仍未启用，重启 Godot 编辑器
4. 检查 project.godot 的 [editor_plugins] 配置
```

**强制启用**：
```gdscript
# 编辑 project.godot
[editor_plugins]
enabled=PackedStringArray("res://addons/Godot-MToon-Shader/plugin.cfg", ...)
```

---

**文档完成** ✓
