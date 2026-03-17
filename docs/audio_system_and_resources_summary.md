# 音频系统与资源管理完全指南

**版本**：1.0 | **作者**：AI Agent | **最后更新**：2024

---

## 📖 目录

1. [整体架构](#整体架构)
2. [MusicState 数据源](#musicstate-数据源)
3. [AudioPlayer 音频引擎](#audioplayer-音频引擎)
4. [MusicState 与 AudioPlayer 协作](#musicstate-与-audioplayer-协作)
5. [AudioRes 资源库](#audiores-资源库)
6. [RoomDecorRes 房间装饰资源](#roomdecorres-房间装饰资源)
7. [快速参考](#快速参考)
8. [故障排查](#故障排查)

---

## 整体架构

### 三层音频数据流

```
┌─────────────────────────────────────────────────────────────────┐
│                     MusicModule (UI)                            │
│                   用户交互入口 (播放、暂停、切曲目)                   │
└────────┬─────────────────────────────────────────────────────────┘
         │ 调用 MusicState API
         ↓
┌─────────────────────────────────────────────────────────────────┐
│                   MusicState (Autoload 单例)                     │
│          纯数据源：管理播放状态、歌单、播放模式、导入记录           │
│                 ✓ 持久化到 user://music_data.json               │
│                 ✓ 发出信号驱动 UI 与音频引擎                      │
└────────┬─────────────────────────────────────────────────────────┘
         │ 发出信号（track_changed、playback_state_changed 等）
         ↓
┌─────────────────────────────────────────────────────────────────┐
│                   AudioPlayer (Autoload 场景)                    │
│              音频履行层：监听 MusicState 信号，执行播放/暂停      │
│           负责淡入淡出、音量管理、音效播放、资源初始化            │
└─────────────────────────────────────────────────────────────────┘
         │
         ↓
   🔊 Godot AudioStreamPlayer（底层音频输出）
```

**核心原则**：
- **MusicState**：数据层，持有所有状态与配置，不直接操作音频
- **AudioPlayer**：执行层，仅监听 MusicState 信号做出反应，不修改 MusicState 数据
- **UI Module**：调用 MusicState API，监听 MusicState 信号更新表现
- **禁止**：UI 或其他对象直接操作 AudioPlayer（违反三层架构）

---

## MusicState 数据源

**位置**：`scenes/main/autoload/audio_player/music_state.gd`  
**继承自**：`Node`  
**注册为 Autoload**：`MusicState`（全局唯一）

### 核心职责

| 职责 | 持久化 | 关键方法 |
|------|-------|--------|
| 播放模式管理 | ✓ | `set_play_mode()`, `cycle_play_mode()`, `get_play_mode_name()` |
| 当前曲目/歌单管理 | ✓ | `set_track()`, `set_playlist()` |
| 播放导航（顺序/随机/单曲循环） | ✗ | `play_next()`, `play_previous()`, `replay_current()` |
| 歌单管理（CRUD） | ✓ | `create_playlist()`, `delete_playlist()`, `add_track_to_playlist()` |
| 导入曲目管理 | ✓ | `add_imported_track()`, `remove_imported_track()` |
| 内置曲目删除记录 | ✓ | `add_removed_builtin()`, `is_builtin_removed()` |
| 数据同步接口 | ✗ | `export_data()`, `import_data()` |

### 播放模式枚举 (PlayMode)

```gdscript
enum PlayMode {
    SEQUENTIAL = 0,    # 顺序播放 - 歌单逐首播放，播完后轮转
    RANDOM = 1,        # 随机播放 - Fisher-Yates 洗牌，全随机池选择
    SINGLE_LOOP = 2    # 单曲循环 - 重复播放当前曲目，手动切换后更新
}
```

### 运行时状态属性（不持久化）

```gdscript
var current_track: String           # 当前播放曲目名称
var is_playing: bool                # 播放中标志
var current_track_index: int        # 当前曲目在歌单中的索引
var current_playlist: String        # 当前歌单名称
var play_mode: int                  # 当前播放模式（SEQUENTIAL/RANDOM/SINGLE_LOOP）
```

### 持久化状态（存储到 `user://music_data.json`）

```gdscript
# 数据模型
{
    "version": 1,
    "playlists": {
        "默认歌单": ["推荐曲目1", "推荐曲目2", ...],
        "自建歌单": ["曲目A", "曲目B", ...]
    },
    "imported_tracks": {
        "用户导入曲目": "user://music/custom_song.ogg",
        ...
    },
    "removed_builtin_tracks": ["已删除曲目1", "已删除曲目2"],
    "play_mode": 0,
    "last_track": "当前曲目"
}
```

### 公开 API 详解

#### 播放控制

```gdscript
# 设置当前曲目（检查曲目有效性）
func set_track(track_name: String, playlist_index: int = 0) -> bool

# 设置播放/暂停状态
func set_playing(playing: bool) → void

# 切换播放/暂停状态
func toggle_playback() → void

# 通知曲目播放完毕（由 AudioPlayer 调用）
func notify_track_finished() → void

# 播放下一首（导航逻辑：顺序/随机/单曲循环）
func play_next() → bool

# 播放上一首
func play_previous() → bool

# 重放当前曲目
func replay_current() → void
```

#### 播放模式

```gdscript
# 设置播放模式 (0=SEQUENTIAL, 1=RANDOM, 2=SINGLE_LOOP)
func set_play_mode(mode: int) → void

# 循环切换播放模式 SEQUENTIAL → RANDOM → SINGLE_LOOP → SEQUENTIAL
func cycle_play_mode() → void

# 获取播放模式名称（用于 UI 显示）
func get_play_mode_name() → String  # 返回 "顺序" / "随机" / "单曲循环"
```

#### 歌单操作（CRUD）

```gdscript
# 创建新歌单
func create_playlist(playlist_name: String) → bool

# 删除歌单（不删除内置歌单）
func delete_playlist(playlist_name: String) → bool

# 设置当前歌单
func set_playlist(playlist_name: String) → void

# 添加曲目到歌单
func add_track_to_playlist(playlist_name: String, track_name: String) → bool

# 从歌单移除曲目
func remove_track_from_playlist(playlist_name: String, track_name: String) → bool

# 从所有歌单移除曲目
func remove_track_from_all_playlists(track_name: String) → void

# 获取歌单中的所有曲目
func get_playlist_tracks(playlist_name: String) → Array[String]

# 获取所有歌单名称
func get_all_playlist_names() → Array[String]

# 获取所有歌单数据（用于导入/导出）
func get_all_playlists_data() → Dictionary
```

#### 导入与删除管理

```gdscript
# 添加导入曲目（支持 .ogg, .wav, .mp3）
func add_imported_track(track_name: String, file_path: String) → void

# 移除导入曲目
func remove_imported_track(track_name: String) → void

# 标记内置曲目为已删除（持久化记录）
func add_removed_builtin(track_name: String) → void

# 检查曲目是否为导入曲目
func is_imported_track(track_name: String) → bool

# 检查内置曲目是否被删除
func is_builtin_removed(track_name: String) → bool

# 获取所有导入曲目（字典：名称 → 文件路径）
func get_imported_tracks() → Dictionary

# 获取所有已删除的内置曲目
func get_removed_builtin_tracks() → Array[String]
```

#### 数据同步

```gdscript
# 导出数据（用于上传到服务器）
func export_data() → Dictionary

# 导入数据（从服务器拉取覆盖本地）
func import_data(data: Dictionary) → void

# 从 user://music_data.json 加载持久化数据
func load_data() → void
```

### 信号体系（13 个关键信号）

```gdscript
# ━━━ 播放状态信号 ━━━

# 曲目改变时发出（old_track → new_track）
signal track_changed(track_name: String)

# 播放/暂停状态改变时发出
signal playback_state_changed(is_playing: bool)

# 播放模式改变时发出（0/1/2：顺序/随机/单曲循环）
signal play_mode_changed(mode: int)

# 当前歌单改变时发出
signal playlist_changed(playlist_name: String)

# 曲目播放完毕时发出（自动触发，由 notify_track_finished() 调用）
signal track_finished


# ━━━ 歌单操作信号 ━━━

# 创建新歌单时发出
signal playlist_created(playlist_name: String)

# 删除歌单时发出
signal playlist_deleted(playlist_name: String)

# 曲目添加到歌单时发出
signal track_added_to_playlist(playlist_name: String, track_name: String)

# 曲目从歌单移除时发出
signal track_removed_from_playlist(playlist_name: String)


# ━━━ 导入/删除信号 ━━━

# 导入曲目添加时发出
signal imported_track_added(track_name: String)

# 导入曲目移除时发出
signal imported_track_removed(track_name: String)

# 内置曲目被标记为删除时发出
signal builtin_track_removed(track_name: String)


# ━━━ 系统信号 ━━━

# 持久化数据加载完毕时发出（应用启动时）
signal data_loaded
```

### 随机播放算法

MusicState 在 RANDOM 模式下采用 **Fisher-Yates 洗牌算法**：

```gdscript
# 初始化随机池（使用 Fisher-Yates 洗牌）
func _shuffle_playlist() → void:
    var tracks = get_playlist_tracks(current_playlist)
    _shuffled_tracks = tracks.duplicate()
    
    # Fisher-Yates 洗牌
    for i in range(_shuffled_tracks.size() - 1, 0, -1):
        var j = randi() % (i + 1)
        var temp = _shuffled_tracks[i]
        _shuffled_tracks[i] = _shuffled_tracks[j]
        _shuffled_tracks[j] = temp
    
    _shuffle_index = 0

# 获取下一首（随机池指针递进）
func play_next() → bool:
    if play_mode == RANDOM:
        _shuffle_index = (_shuffle_index + 1) % _shuffled_tracks.size()
        set_track(_shuffled_tracks[_shuffle_index])
        return true
    # ... 其他模式处理
```

**特点**：
- 全曲单不重复（直到洗牌重置）
- 支持 `play_previous()` 倒序遍历
- 歌单切换自动重新洗牌

---

## AudioPlayer 音频引擎

**位置**：`scenes/main/autoload/audio_player/audio_player.tscn` + `audio_player.gd`  
**继承自**：`Node`  
**注册为 Autoload**：`AudioPlayer`

### 核心职责

| 职责 | 实现 |
|------|-----|
| 音频资源初始化 | `_init_audio_players()` - 从 AudioRes 加载 BGM、SFX |
| 曲目播放/暂停 | 监听 MusicState 信号，用 Tween 淡入淡出 |
| 曲目切换 | `_on_track_changed()` - 停止旧曲目，启动新曲目 |
| 音量管理 | `set_bgm_volume()`, `set_sfx_volume()` - 实时调节 |
| 音效播放 | `play_sound_effect()` - 即时音效 |
| AudioStreamPlayer 池管理 | 为 BGM/SFX 维护独立的 AudioStreamPlayer 节点 |

### 淡入淡出配置

```gdscript
@export var fade_enabled: bool = true           # 启用/禁用淡入淡出
@export var fade_in_duration: float = 1.0       # BGM 淡入时长（秒）
@export var fade_out_duration: float = 1.0      # BGM 淡出时长（秒）

# 淡入淡出样条曲线
# 0 = Linear  |  1 = EaseIn  |  2 = EaseOut  |  3 = EaseInOut
@export var fade_curve: int = 3                 # 默认 EaseInOut
```

### 音量转换函数

```gdscript
# 线性音量（0.0 ~ 1.0）→ Godot dB 值（-80 ~ 0）
func _linear_to_target_db(linear_volume: float) → float:
    if linear_volume <= 0.0:
        return -80.0  # 完全静音
    elif linear_volume >= 1.0:
        return 0.0    # 全音量
    else:
        # 使用 Godot 内置 linear_to_db() 函数
        return linear_to_db(linear_volume)

# 示例：linear_volume = 0.5 → db ≈ -6.02 dB
```

### 公开 API

#### 播放控制

```gdscript
# 播放音效（名称必须在 AudioRes 中定义）
func play_sound_effect(effect_name: String) → void

# 立即停止当前 BGM（无淡出）
func stop_bgm() → void

# 获取当前是否在播放
func is_playing() → bool
```

#### 音量管理

```gdscript
# 设置 BGM 音量（0.0 ~ 1.0 线性值）
func set_bgm_volume(volume: float) → void

# 获取当前 BGM 音量
func get_bgm_volume() → float

# 设置 SFX 音量
func set_sfx_volume(volume: float) → void

# 获取当前 SFX 音量
func get_sfx_volume() → float
```

#### 资源管理

```gdscript
# 从 AudioRes 加载并添加 BGM
func add_bgm_from_resource(audio_item: AudioItem) → void

# 从 AudioRes 加载并添加 SFX
func add_sound_effect_from_resource(audio_item: AudioItem) → void
```

### 淡入淡出实现细节

#### 播放新曲目时的淡入淡出流程

```gdscript
func _on_track_changed(track_name: String) → void:
    # 1. 淡出旧曲目（如果存在）
    if _current_bgm_player:
        var tween = create_tween()
        tween.set_ease(Tween.EASE_OUT)
        tween.set_trans(Tween.TRANS_QUAD)
        tween.tween_property(_current_bgm_player, "volume_db", -80, fade_out_duration)
        await tween.finished
        _current_bgm_player.stop()
    
    # 2. 切换到新曲目
    _current_track = track_name
    _current_bgm_player = _get_bgm_player_for_track(track_name)
    
    # 3. 淡入新曲目
    var tween = create_tween()
    tween.set_ease(Tween.EASE_IN)
    tween.set_trans(Tween.TRANS_QUAD)
    _current_bgm_player.volume_db = -80  # 从完全静音开始
    _current_bgm_player.play()
    tween.tween_property(_current_bgm_player, "volume_db", current_bgm_db, fade_in_duration)
```

**时间轴示例**（fade_duration = 1.0s）：

```
时间    |  旧 BGM volume_db  |  新 BGM volume_db  |  状态
--------|--------------------|--------------------|--------
0.00s   |      -6.0 dB       |      None          | 淡出开始
0.50s   |     -30.0 dB       |      None          | 淡出中段
1.00s   |     -80.0 dB       |     -80.0 dB       | 旧停止，新启动
1.50s   |        ×           |     -40.0 dB       | 淡入中段
2.00s   |        ×           |     -6.0 dB        | 淡入完毕
```

---

## MusicState 与 AudioPlayer 协作

### 信号连接流程

```
MusicModule.button_play_pressed()
    ↓
MusicState.set_playing(true)
    ↓ 发出信号
signal playback_state_changed(true)
    ↓
AudioPlayer._on_playback_state_changed(true)
    ↓ 调用
AudioPlayer._play_current_track()
    ↓
Tween: volume_db: -80 → current_bgm_db (1.0s, EaseInOut)
    ↓
🔊 播放声音
```

### 完整交互序列

#### 场景 1：用户点击「切换曲目」

```
─────────────────────────────────────────────────────────────────

1️⃣ 用户交互
   MusicModule 组件检测到用户点击「下一首」按钮

2️⃣ UI 层调用 State API
   MusicModule.on_next_button_pressed()
     ↓
   MusicState.play_next()  # 根据 play_mode 返回下一首曲目名称

3️⃣ MusicState 传播信号
   MusicState 发出：signal track_changed("New Track")
   (新曲目会设置为 is_playing=true，自动通知播放)

4️⃣ AudioPlayer 监听信号并重新加载
   AudioPlayer._on_track_changed("New Track")
     ↓
   # 停止旧曲目
   Tween: _current_bgm_player volume_db → -80 (1.0s)
   await Tween.finished
   _current_bgm_player.stop()
     ↓
   # 加载新曲目
   _current_bgm_player = _get_bgm_player_for_track("New Track")
   _current_bgm_player.stream = _get_track_stream("New Track")
     ↓
   # 播放并淡入
   _current_bgm_player.play()
   Tween: _current_bgm_player volume_db → 0 (1.0s)

5️⃣ UI 层监听 State 信号更新表现
   MusicModule._on_track_changed("New Track")
     ↓
   label_track_name.text = "New Track"
   # 更新歌词、封面等 UI
```

#### 场景 2：用户改变播放模式

```
MusicModule.on_play_mode_button_pressed()
    ↓
MusicState.cycle_play_mode()  # SEQUENTIAL → RANDOM → SINGLE_LOOP
    ↓ 发出信号
signal play_mode_changed(1)  # 新模式
    ↓
MusicModule._on_play_mode_changed(1)
    ↓
# UI 显示新模式图标 (顺序 → 随机 → 单曲)
play_mode_icon.texture = PlayMode.ICONS[1]  # 随机图标
```

#### 场景 3：在 RANDOM 模式下播放下一首

```
call play_next() (MusicState)
    ↓
if play_mode == RANDOM:
    _shuffle_index = (_shuffle_index + 1) % _shuffled_tracks.size()
    track = _shuffled_tracks[_shuffle_index]
    ↓
set_track(track)
    ↓ 发出信号
signal track_changed(track)
    ↓
AudioPlayer._on_track_changed(track)
    ↓
# 执行淡入淡出 (同场景 1)
```

### 时序图：完整交互

```
时间  │ MusicModule │ MusicState │ AudioPlayer │ 音频输出
──────┼─────────────┼────────────┼─────────────┼──────────
0ms   │ 点击"下一首" │            │             │
      │             │ play_next()│             │
      │             │ (RANDOM)   │             │
      │             │            │             │
50ms  │             │ 计算随机下    │             │
      │             │ 一首        │             │
      │             │ track_ch..  │             │
100ms │             │ ↓ signal   │ ~on_track   │
      │             │            │ _changed()  │
      │             │            │ 淡出旧曲（1s）│ 音量↓
150ms │ 更新 UI      │            │ ↓           │ 音量↓
      │ label_track │            │ 加载新曲    │ (停止)
200ms │ _name       │            │             │
      │             │            │ 淡入新曲（1s）│ 播放新曲
250ms │             │            │ ↓volume_db  │ 音量↑
      │             │            │ ↓           │ 音量↑
1100ms│             │            │ 淡入完毕    │ 播放中 🎵
```

---

## AudioRes 资源库

**位置**：`resource/audio_res/audio_res.gd` (Resource 类)  
**继承自**：`Resource`

### 职责

管理应用内所有音频资源（BGM、SFX），支持编辑器配置和运行时导入。

### 数据结构

```gdscript
extends Resource
class_name AudioRes

# Export 数组，在 Inspector 中配置
@export var BGM: Array[AudioItem]              # 背景音乐列表
@export var sound_effect: Array[AudioItem]     # 音效列表

# 动态添加 BGM 时发出
signal bgm_added(name: String)
```

### 数据模型：AudioItem

**位置**：`resource/audio_res/audio_item/audio_item.gd`

```gdscript
extends Resource
class_name AudioItem

@export var name: String        # 曲目/音效名称（唯一标识）
@export var stream: AudioStream # Godot 原生 AudioStream 对象
                                 # 支持类型：AudioStreamOggVorbis(.ogg)
                                 #           AudioStreamWAV(.wav)
                                 #           AudioStreamMP3(.mp3)
```

**编辑器配置位置**：
- BGM 列表：`resource/audio_res/audio_items/bgm/` (多个 .tres 文件)
- SFX 列表：`resource/audio_res/audio_items/sfx/` (多个 .tres 文件)

### 公开 API

#### 音频加载

```gdscript
# 从文件路径加载 AudioStream（支持 .ogg, .wav, .mp3）
static func _load_audio_stream(file_path: String) → AudioStream:
    var file_ext = file_path.get_extension().to_lower()
    
    match file_ext:
        "ogg":
            var stream = AudioStreamOggVorbis.new()
            stream.data = FileAccess.get_file_as_bytes(file_path)
            return stream
        "wav":
            return AudioStreamWAV.new()  # 直接加载
        "mp3":
            return AudioStreamMP3.new()  # 直接加载
        _:
            push_error("不支持的格式：" + file_ext)
            return null
```

#### BGM 管理

```gdscript
# 添加 BGM 从文件（运行时导入）
func add_bgm(name: String, file_path: String) → void:
    var stream = _load_audio_stream(file_path)
    if stream:
        var item = AudioItem.new()
        item.name = name
        item.stream = stream
        BGM.append(item)
        bgm_added.emit(name)

# 移除 BGM
func remove_bgm(name: String) → void:
    for i in range(BGM.size()):
        if BGM[i].name == name:
            BGM.remove_at(i)
            break

# 按名称查找 BGM
func get_bgm_item_by_name(name: String) → AudioItem:
    for item in BGM:
        if item.name == name:
            return item
    return null
```

#### SFX 管理

```gdscript
# 获取音效 Item（使用同 BGM 的 get_*_item_by_name 逻辑）
func get_sfx_item_by_name(effect_name: String) → AudioItem:
    for item in sound_effect:
        if item.name == effect_name:
            return item
    return null
```

### 资源目录结构

```
resource/audio_res/
├── audio_res.gd              # AudioRes 主类
├── audio_res.tres            # AudioRes 实例配置（Autoload 初始化用）
└── audio_items/
    ├── bgm/
    │   ├── bgm_01_morning.tres
    │   ├── bgm_02_night.tres
    │   └── ...
    └── sfx/
        ├── sfx_click.tres
        ├── sfx_notify.tres
        └── ...
```

---

## RoomDecorRes 房间装饰资源

**位置**：`resource/room_decor_res/room_decor_res.gd` (Resource 类)  
**继承自**：`Resource`

### 职责

定义房间中所有可装饰的物品及其属性（名称、分类、解锁等级、图标）。

### 数据结构

```gdscript
extends Resource
class_name RoomDecorRes

@export var decor_items: Array[RoomDecorItem]  # 所有装饰物品列表
```

### 数据模型：RoomDecorItem

**位置**：`resource/room_decor_res/room_decor_item/room_decor_item.gd`

```gdscript
extends Resource
class_name RoomDecorItem

@export var name: String              # 物品唯一名称 (如 "desk_01")
@export var category: String          # 物品分类 (如 "furniture", "wall_decor", "floor")
@export var display_name: String      # UI 显示名称 (如 "木质书桌")
@export var description: String       # 物品描述
@export var required_level: int = 1   # 解锁所需等级

@export var icon: Texture2D           # 物品图标（UI 列表显示）
@export var model_path: String        # 3D 模型路径（3D 场景中加载）
@export var price: int = 0            # 金币价格（可选）
```

### 与 LevelState 的协作

装饰物品解锁与等级系统集成：

```gdscript
# RoomDecorModule 显示可购买列表时，检查用户等级
func _on_decor_list_updated() → void:
    for decor in room_decor_res.decor_items:
        var is_unlocked = LevelState.current_level >= decor.required_level
        
        if is_unlocked:
            # 显示物品为可购买状态
            add_decor_button(decor)
        else:
            # 显示为锁定状态 (等级 X 解锁)
            add_locked_decor_button(decor, "等级 %d 解锁" % decor.required_level)
```

### 关键特点

- **不存储 3D 模型**：只存储 `model_path`，3D 场景中动态加载（节省内存）
- **编辑器配置**：在 Inspector 中编辑 decor_items 数组，支持序列化
- **关键字段说明**：

| 字段 | 用途 | 示例 |
|-----|-----|-----|
| name | 数据库 ID，确保唯一性 | "desk_wooden_01" |
| category | 分类筛选（UI Tab） | "furniture" / "wall" / "floor" |
| display_name | 用户可见名称 | "木质书桌" |
| required_level | 与 LevelState 关联 | 10 |
| icon | UI 缩略图 | Texture2D (64x64) |
| model_path | 加载 3D 模型 | "res://assets/3d/decor/desk_01.tscn" |

---

## 快速参考

### MusicState 常用操作

```gdscript
# 播放具体曲目
MusicState.set_track("曲目名称")
MusicState.set_playing(true)

# 尝试播放下一首
if MusicState.play_next():
    print("切换到：", MusicState.current_track)

# 切换播放模式
MusicState.cycle_play_mode()  # SEQUENTIAL → RANDOM → SINGLE_LOOP

# 创建自定义歌单
MusicState.create_playlist("我的最爱")
MusicState.add_track_to_playlist("我的最爱", "曲目名称")

# 导入用户曲目
MusicState.add_imported_track("自定义曲目", "user://music/my_song.ogg")

# 删除内置曲目
MusicState.add_removed_builtin("不喜欢的曲目名")
```

### AudioPlayer 常用操作

```gdscript
# 调节 BGM 音量
AudioPlayer.set_bgm_volume(0.5)  # 50% 音量

# 播放音效
AudioPlayer.play_sound_effect("click")

# 检查是否正在播放
if AudioPlayer.is_playing():
    print("音乐播放中...")
else:
    print("音乐已暂停")
```

### AudioRes 常用操作

```gdscript
# 编辑器中配置 BGM 列表（Inspector 拖拽）
# 运行时访问
var bgm_item = AudioRes.get_bgm_item_by_name("BGM_01")
if bgm_item:
    print("BGM 音频流：", bgm_item.stream)

# 运行时导入曲目
AudioRes.add_bgm("用户导入曲目", "user://music/custom.ogg")
```

### 监听关键信号

```gdscript
# MusicModule 中监听
MusicState.track_changed.connect(_on_track_changed)
MusicState.playback_state_changed.connect(_on_playback_state_changed)
MusicState.play_mode_changed.connect(_on_play_mode_changed)
MusicState.data_loaded.connect(_on_data_loaded)

# 回调函数
func _on_track_changed(track_name: String) → void:
    label_track_name.text = track_name
    # 更新歌词、封面等

func _on_playback_state_changed(is_playing: bool) → void:
    play_button.modulate.color = Color.GREEN if is_playing else Color.GRAY

func _on_play_mode_changed(mode: int) → void:
    var mode_name = ["顺序", "随机", "单曲循环"][mode]
    tooltip.text = "播放模式：%s" % mode_name
```

---

## 故障排查

### ❌ 问题：音乐不播放

**诊断流程**：

```
1. 检查 MusicState 初始化
   if MusicState.current_track == "":
       print("ERROR: current_track 为空，未设置曲目")
       return

2. 检查 AudioPlayer 初始化
   if AudioPlayer._audiostream_player == null:
       print("ERROR: AudioStreamPlayer 未初始化")
       return

3. 检查 AudioRes 加载
   var bgm_item = AudioRes.get_bgm_item_by_name(track_name)
   if bgm_item == null or bgm_item.stream == null:
       print("ERROR: 找不到曲目或 stream 为空")
       return

4. 检查播放状态
   print("is_playing: ", MusicState.is_playing)
   print("volume_db: ", AudioPlayer._current_bgm_player.volume_db)
   if volume_db <= -80:
       print("WARNING: 音量过低（可能静音）")
```

**常见原因**：
- ✗ `MusicState.set_playing(false)` 被意外调用
- ✗ `AudioPlayer.set_bgm_volume(0)` 设置为 0
- ✗ AudioRes 中未配置任何曲目
- ✗ 曲目名称拼写错误

**修复**：
```gdscript
# 重置播放状态
MusicState.set_track("有效的曲目名")
MusicState.set_playing(true)
AudioPlayer.set_bgm_volume(1.0)
```

### ❌ 问题：淡入淡出卡顿或不流畅

**原因分析**：

| 症状 | 原因 | 修复 |
|-----|-----|-----|
| 淡入/淡出突然跳跃 | 时长配置过短 | ↑ 增大 `fade_in_duration`、`fade_out_duration` |
| 音量变化线性不平滑 | 曲线设置不当 | 改用 `EASE_IN_OUT`（曲线值 3） |
| Tween 中途打断 | 新 Tween 未等待旧 Tween | 使用 `await tween.finished` 确保完成 |

**检查和修复**：
```gdscript
# 启用淡入淡出
AudioPlayer.fade_enabled = true

# 调整时间（默认 1.0s 通常足够）
AudioPlayer.fade_in_duration = 1.5   # 增加到 1.5 秒
AudioPlayer.fade_out_duration = 1.5

# 使用 EaseInOut 曲线（最平滑）
AudioPlayer.fade_curve = 3  # Tween.EASE_IN_OUT
```

### ❌ 问题：随机播放重复曲目

**根因**：Fisher-Yates 洗牌未正确重置

**修复**：
```gdscript
# 强制重新洗牌
MusicState.set_playlist(MusicState.current_playlist)  # 切换歌单
MusicState.cycle_play_mode()  # 改变模式再改回
MusicState.cycle_play_mode()
```

### ❌ 问题：导入曲目无法播放

**诊断**：

```gdscript
# 检查文件是否存在
var file_path = "user://music/my_song.ogg"
if not ResourceLoader.exists(file_path):
    print("ERROR: 文件不存在 - ", file_path)
    return

# 检查文件格式
var ext = file_path.get_extension().to_lower()
if ext not in ["ogg", "wav", "mp3"]:
    print("ERROR: 不支持的格式 - ", ext)
    return

# 尝试手动加载测试
var stream = AudioStreamOggVorbis.new()
stream.data = FileAccess.get_file_as_bytes(file_path)
if stream.data.is_empty():
    print("ERROR: 文件读取失败或为空")
    return
```

**常见原因**：
- ✗ 文件格式不支持（需要 .ogg / .wav / .mp3）
- ✗ 文件路径不正确（检查 `user://` 前缀）
- ✗ 文件权限不足（无读权限）

### ❌ 问题：歌单数据丢失

**背景**：MusicState 持久化文件损坏或版本不匹配

**恢复步骤**：

```gdscript
# 1. 检查持久化文件
var save_path = "user://music_data.json"
if ResourceLoader.exists(save_path):
    var data = JSON.parse_string(FileAccess.get_file_as_string(save_path))
    print("数据版本：", data.get("version", "未知"))
else:
    print("WARNING: 保存文件不存在，使用默认值")

# 2. 手动重置
MusicState.call_deferred("_init_with_defaults")

# 3. 重新导入用户歌单
MusicState.create_playlist("恢复的歌单")
# 手动添加曲目...
```

### ✅ 调试模式

启用音频系统监控：

```gdscript
# 在 _ready 中添加
func _debug_audio_system() → void:
    MusicState.track_changed.connect(func(name): print("[MUSIC] 曲目切换：", name))
    MusicState.playback_state_changed.connect(func(is_playing): 
        print("[MUSIC] 播放状态：", "播放中" if is_playing else "暂停"))
    MusicState.play_mode_changed.connect(func(mode):
        print("[MUSIC] 模式切换：", ["顺序", "随机", "单曲循环"][mode]))
```

---

**文档完成** ✓
