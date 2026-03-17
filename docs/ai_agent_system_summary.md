# AI Agent 系统完整架构

本文档总结 `scenes/main/autoload/ai_service` 中的 Godot 端 AI 系统与 `agent/` 中的 Python 后端 Agent 的完整架构、公开 API、函数调用流程。

## 1. 整体架构概览

```
┌───────────────────────────────────────────────────────────┐
│                    Godot 游戏引擎（客户端）                  │
├───────────────────────────────────────────────────────────┤
│ UI 层                                                     │
│  ├─ InputBox         (用户输入)                            │
│  ├─ DialogueBox      (AI 响应显示)                        │
│  └─ signals → ChatState.text_submitted()                 │
├───────────────────────────────────────────────────────────┤
│ 数据层                                                    │
│  └─ ChatState (聊天运行时状态、响应回调)                   │
├───────────────────────────────────────────────────────────┤
│ Agent 系统                                                │
│  ├─ ChatController (业务协调器)                           │
│  ├─ AgentExecutor  (函数执行引擎)                         │
│  ├─ ContextCollector (上下文收集)                         │
│  ├─ CustomAPIAdapter (HTTP/SSE 后端通信)                 │
│  ├─ TTSPlayer      (语音播放)                            │
│  └─ AIService      (OpenAI 兼容直连，备用)               │
└──────────────────┬──────────────────────────────────────┘
                   │ 线程 HTTP/SSE
┌──────────────────▼──────────────────────────────────────┐
│        Python FastAPI/Aiohttp 后端                       │
├───────────────────────────────────────────────────────────┤
│ /chat/messages (SSE)                                      │
│  ├─ ChatAgent.chat_stream()                              │
│  │  ├─ LLM.stream_chat()        (文本生成)               │
│  │  ├─ task_creation_detection  (意图识别)               │
│  │  ├─ task_generation          (任务生成)               │
│  │  └─ SSE 推送 events                                   │
│  │                                                       │
│  └─ ReflectionAgent (周期总结)                           │
│     ├─ ServerAPI.get_statistics()                        │
│     ├─ ServerAPI.get_daily_summary()                     │
│     ├─ LLM.chat()                (生成总结)              │
│     └─ SSE 推送 text_delta events                        │
│                                                         │
│ /chat/function-results (JSON)                           │
│  └─ 接收 Godot 函数执行结果后继续对话                     │
└───────────────────────────────────────────────────────────┘
```

---

## 2. Godot 端 AI 系统详细说明

### 2.1 核心组件一览

| 组件 | 脚本 | 职责 | 信号/API 数量 |
|---|---|---|---|
| ChatController | `chat_controller.gd` | 业务主协调器，响应 UI，调度各子系统 | 8 个信号，6 个公开 API |
| AgentExecutor | `agent_executor.gd` | 函数注册与执行引擎 | 3 个信号，6 个公开 API |
| ContextCollector | `context_collector.gd` | 采集应用状态生成上下文 | 1 个信号，2 个公开 API |
| CustomAPIAdapter | (内部) | 后端 HTTP/SSE 通信 | 3 个信号，7 个公开 API |
| TTSPlayer | `tts_player.gd` | TTS 音频播放与队列管理 | 5 个信号，3 个公开 API |
| AIService | `ai_service.gd` | OpenAI 兼容直连（备用） | 5 个信号，6 个公开 API |

---

### 2.2 ChatController（业务协调器）

**脚本**: [scenes/main/autoload/ai_service/chat_controller.gd](../scenes/main/autoload/ai_service/chat_controller.gd)

核心职责：
- 监听 UI 输入（ChatState.text_submitted）
- 收集应用上下文（ContextCollector）
- 发送后端请求（CustomAPIAdapter）
- 解析 SSE 响应流
- 调度函数执行（AgentExecutor）
- 触发 TTS 播放（TTSPlayer）

#### 公开 API

```gdscript
# 发送消息（支持多模态附件）
func send_message(text: String, images: Array = []) -> bool

# 扩展版本，支持上下文注入
func send_message_extended(text: String, images: Array = [], include_context: bool = true) -> bool

# 取消当前请求
func cancel_request() -> void

# 清空对话历史
func clear_history() -> void

# 查询状态
func get_status() -> Dictionary  # { "is_requesting": bool, "is_streaming": bool, ... }
```

#### 公开信号

```gdscript
signal text_submitted(text: String, attachments: Array)
signal response_started
signal response_chunk(chunk: String)  # 流式文本更新
signal response_completed(full_response: String)
signal response_failed(error: String)
signal function_call_executed(name: String, result: Dictionary)
signal tts_started
signal tts_finished
```

#### 外部接口示例

```gdscript
# UI 发起请求
ChatController.send_message("为我创建一个番茄钟任务")

# 监听响应
ChatController.response_started.connect(func(): 
    print("AI 开始响应")
)
ChatController.response_chunk.connect(func(chunk: String):
    print("收到文本块:", chunk)
)
ChatController.function_call_executed.connect(func(name, result):
    print("函数 %s 执行完成: %s" % [name, result])
)
```

---

### 2.3 AgentExecutor（函数执行引擎）

**脚本**: [scenes/main/autoload/ai_service/agent_executor.gd](../scenes/main/autoload/ai_service/agent_executor.gd)

核心职责：
- 注册函数定义与回调
- 执行 Python Agent 调用的 Godot 函数
- 参数校验与类型转换
- 结果序列化与错误处理

#### 已实现函数清单

目前共 11 个任务管理函数（来自 `function_definitions.json`）：

| 函数名 | 参数 | 返回值 | 对应 State 方法 |
|---|---|---|---|
| `add_task` | `title: str, deadline?: str` | `{"success": bool, "data": {"task_id": int, ...}}` | `TaskState.add_task()` |
| `remove_task` | `task_id: int` | `{"success": bool}` | `TaskState.remove_task()` |
| `update_task_title` | `task_id: int, title: str` | `{"success": bool}` | `TaskState.update_task_title()` |
| `set_task_completed` | `task_id: int, completed: bool` | `{"success": bool}` | `TaskState.set_task_completed()` |
| `set_task_due_time` | `task_id: int, deadline: str (ISO8601)` | `{"success": bool}` | `TaskState.set_task_due_time()` |
| `clear_completed_tasks` | 无 | `{"success": bool, "data": {"cleared_count": int}}` | `TaskState.clear_completed()` |
| `get_all_tasks` | 无 | `{"success": bool, "data": [{"id": int, "title": str, ...}, ...]}` | `TaskState.get_all_tasks()` |
| `get_incomplete_tasks` | 无 | `{"success": bool, "data": [...]}` | `TaskState.get_incomplete_tasks()` |
| `get_completed_tasks` | 无 | `{"success": bool, "data": [...]}` | `TaskState.get_completed_tasks()` |
| `get_overdue_tasks` | 无 | `{"success": bool, "data": [...]}` | `TaskState.get_overdue_tasks()` |
| `reorder_task` | `task_id: int, new_position: int, is_completed: bool` | `{"success": bool}` | `TaskState.reorder_task()` |

#### 公开 API

```gdscript
# 注册函数
func register(name: String, callable: Callable, definition: Dictionary = {}) -> void
    # 例: register("my_func", Callable(self, "_my_func"), 
    #     {"name": "my_func", "description": "...", "parameters": {}})

# 注销函数
func unregister(name: String) -> void

# 检查函数是否已注册
func has_function(name: String) -> bool

# 执行函数
func execute(call_id: String, name: String, args: Dictionary) -> Dictionary
    # call_id: 由后端生成的唯一 ID（用于关联回调）
    # 返回: {"success": bool, "data": ?, "error": string?}

# 查询函数定义
func get_function_definitions() -> Array[Dictionary]

# 查询已注册函数名
func get_registered_functions() -> Array[String]
```

#### 公开信号

```gdscript
signal function_executed(call_id: String, name: String, result: Variant)
signal function_failed(call_id: String, name: String, error: String)
signal function_started(call_id: String, name: String)
```

---

### 2.4 ContextCollector（上下文收集器）

**脚本**: [scenes/main/autoload/ai_service/context_collector.gd](../scenes/main/autoload/ai_service/context_collector.gd)

核心职责：
- 自动采集应用当前状态（任务、音乐、番茄钟等）
- 格式化为结构化数据
- 关联到每次请求，增强 Agent 理解

#### 可配置开关

```gdscript
@export var collect_tasks: bool = true
@export var collect_music: bool = true
@export var collect_pomodoro: bool = true
@export var collect_environment: bool = true
@export var collect_notes: bool = false      # 默认不收集（隐私）
@export var collect_habits: bool = true
```

#### 公开 API

```gdscript
# 收集完整上下文
func collect() -> Dictionary
    # 返回所有启用项目的数据

# 转换为提示词片段（用于 Agent 系统提示）
func format_as_prompt(context: Dictionary = {}) -> String
    # 返回格式化的文本，可嵌入 LLM 提示词
```

#### 公开信号

```gdscript
signal collection_completed(context: Dictionary)
```

#### 返回数据结构

```gdscript
{
    "timestamp": 1710805234,  # 当前时间戳
    "datetime": "2025-03-18 10:20:34",
    
    "tasks": {
        "total": 5,
        "completed": 2,
        "pending": 3,
        "overdue": 1,
        "recent_tasks": [
            {"id": 1, "title": "完成报告", "due_time": "2025-03-18 18:00"},
            {"id": 2, "title": "审核代码", "due_time": "2025-03-20 12:00"}
        ]
    },
    
    "music": {
        "current_track": "夜间工作氛围",
        "is_playing": true,
        "play_mode": "SEQUENTIAL",  # 播放模式
        "current_playlist": "全部音乐"
    },
    
    "pomodoro": {
        "is_running": true,
        "is_work_mode": true,
        "remaining_seconds": 1500,
        "work_duration_seconds": 1500,
        "rest_duration_seconds": 300
    },
    
    "environment": {
        "time_mode": 2,         # 0=白天, 1=黄昏, 2=晚上, 3=同步
        "weather_mode": 0,      # 0=晴天, 1=下雨, 2=下雪
        "outdoor_light_strength": 0.8
    },
    
    "habits": {
        "habit_count": 4,
        "current_week": "2025-W12",
        "week_completion_rate": 0.75,
        "recent_habits": [
            {"name": "早睡早起", "status": "COMPLETED"},
            {"name": "健身", "status": "PENDING"}
        ]
    }
}
```

---

### 2.5 TTSPlayer（语音播放器）

**脚本**: [scenes/main/autoload/ai_service/tts_player.gd](../scenes/main/autoload/ai_service/tts_player.gd)

核心职责：
- 播放 TTS 音频
- 管理播放队列
- 同步口型动画

#### 公开 API

```gdscript
# 播放 TTS 音频
func play(url: String = "", data: PackedByteArray = [], format: String = "mp3") -> void
    # url: 远程 URL 或本地文件路径
    # data: 音频二进制数据（如果 url 为空）
    # format: 音频格式（mp3, wav, ogg）

# 停止播放
func stop() -> void

# 设置角色引用（用于口型同步）
func set_character(node: Node) -> void
```

#### 公开属性

```gdscript
@export var volume: float = 1.0          # 音量（0.0 ~ 1.0）
@export var queue_enabled: bool = true   # 是否启用队列播放
```

#### 公开信号

```gdscript
signal playback_started
signal playback_progress(position: float, duration: float)  # 用于口型同步
signal playback_finished
signal queue_finished
signal playback_error(error: String)
```

---

### 2.6 AIService（OpenAI 兼容直连）

**脚本**: [scenes/main/autoload/ai_service/ai_service.gd](../scenes/main/autoload/ai_service/ai_service.gd)

备用方案，支持直接连接 OpenAI API（仅文本，不支持函数调用）。

#### 公开 API

```gdscript
# 发送单条消息
func send_message(user_message: String, images: Array = [], use_history: bool = true) -> void

# 发送单条消息（不使用历史）
func send_single_message(user_message: String, images: Array = []) -> void

# 历史管理
func clear_history() -> void
func get_history() -> Array[Dictionary]
func set_history(history: Array[Dictionary]) -> void
func add_assistant_message(content: String) -> void

# 状态查询
func is_requesting() -> bool
func is_streaming() -> bool

# 取消请求
func cancel_request() -> void
```

#### 公开信号

```gdscript
signal stream_chunk_received(chunk: String)
signal stream_completed(full_response: String)
signal request_started
signal request_failed(error: String)
signal connection_state_changed(is_connected: bool)
```

---

## 3. Python 后端 Agent 详细说明

### 3.1 架构与组件

```
backend/
├── agent/
│   ├── chat_agent/          # 主聊天 Agent
│   │   ├── agent.py         # 核心类 Agent
│   │   ├── config.py        # 配置参数
│   │   ├── context.py       # 上下文管理
│   │   ├── prompt.py        # 提示词构建
│   │   └── task_generation.py # 任务生成
│   │
│   ├── reflection_agent/    # 反思总结 Agent
│   │   ├── agent.py         # 核心类 ReflectionAgent
│   │   ├── config.py
│   │   └── prompt_builder.py
│   │
│   └── ...
│
├── agent_result_parser/     # SSE 响应解析
│   ├── sse_parser.py
│   └── agent_response_parser.py
│
├── interfaces/              # 抽象接口
│   ├── llm.py               # LLM 接口
│   ├── server_api.py        # 服务端 API
│   └── memory.py            # 记忆管理
│
└── http_server/
    └── server.py            # FastAPI 服务
```

### 3.2 ChatAgent（主聊天 Agent）

**脚本**: `agent/agent/chat_agent/agent.py`

#### 核心方法

```python
class Agent:
    def chat(user_message: str) -> AgentResponse:
        """一次性聊天（无流式）"""
        # 返回完整响应
    
    def chat_stream(user_message: str, session_id: Optional[str]) -> Generator[Tuple[str, Dict], None, None]:
        """流式聊天（SSE）"""
        # 逐块生成并 yield (chunk, metadata)
    
    def generate_tasks_from_conversation(conversation_text: str) -> List[Task]:
        """从对话提取任务"""
        # 调用 LLM 生成任务列表
    
    def suggest_task_schedule(tasks: List[Task]) -> Dict[str, Any]:
        """为任务建议调度（NotImplementedError）"""
    
    def generate_summary(start_date, end_date, period="week") -> str:
        """生成总结（NotImplementedError）"""
```

#### 子层方法

```python
def get_system_prompt() -> str:
    """系统提示词（角色定义、行为指南）"""

def get_context_messages(user_message: str) -> List[Dict]:
    """构建完整消息列表（含历史 + 新消息）"""
    # 返回 [
    #   {"role": "system", "content": system_prompt},
    #   {"role": "user", "content": "...", "timestamp": ...},
    #   {"role": "assistant", "content": "...", "timestamp": ...},
    #   ...
    # ]

def detect_task_creation_intent(user_message: str) -> bool:
    """检测用户是否想创建任务"""
    # 使用关键词或 LLM 判断

def generate_tasks_from_conversation(llm, config, user_message: str) -> List[Task]:
    """基于对话内容，调用 LLM 生成任务"""
    # 返回 [
    #   {"title": "完成报告", "deadline": "2025-03-20 18:00", ...},
    #   ...
    # ]
```

#### 支持的操作

1. **一般聊天**（流式和非流式）
2. **任务创建意图检测**（主动识别用户是否在描述任务）
3. **任务自动生成**（从对话中提取并创建任务）
4. **对话历史管理**（维护会话上下文）
5. **性能分析**（预留接口，API 可用但逻辑未实现）

### 3.3 ReflectionAgent（反思与总结 Agent）

**脚本**: `agent/agent/reflection_agent/agent.py`

#### 核心方法

```python
class ReflectionAgent:
    def generate_period_summary(
        start_date: datetime,
        end_date: datetime,
        period: str = "week",                  # "day", "week", "month"
        trigger: str = "manual",               # "manual", "auto"
        precomputed_stats: Optional[Dict] = None,
        extra_context: Optional[str] = None
    ) -> AgentResponse:
        """生成周期总结（周报/月报/日报）"""
        # 依赖链（下略）
        # 返回 AgentResponse(text=总结文本, operations=[])
```

#### 依赖链

1. **获取统计数据**：调用 `ServerAPI.get_statistics(start_date, end_date, period)`
   - 返回：任务完成情况、专注时间、习惯执行率等
   
2. **获取日常总结**：调用 `ServerAPI.get_daily_summary(end_date)`
   - 返回：当日概览、关键事项
   
3. **获取历史反思**（可选）：调用 `Memory.get_memory_context()`
   - 返回：之前的反思痕迹、个人见解
   
4. **构建系统提示词**
   - 定义反思风格、输出格式
   
5. **构建用户提示词**
   - 注入统计数据 + 日常总结 + 附加上下文
   
6. **调用 LLM**
   - `llm.chat(messages)` 生成总结文本
   
7. **返回结果**
   - `AgentResponse(text=summary_text, operations=[])`

#### 支持的操作

- 日总结（当日概览）
- 周总结（周度评估）
- 月总结（月度回顾）
- 基于真实统计数据（不猜测）
- 自定义触发方式（manual/auto）
- 额外上下文注入（e.g., 用户笔记）

---

## 4. 函数调用详细流程

### 4.1 完整流程（文本 + 函数调用）

```
用户输入
  ↓ "为我创建一个番茄钟任务"
  ↓
InputBox.text_submitted.emit()
  ↓
ChatState.text_submitted.emit(text, attachments=[])
  ↓
ChatController._on_text_submitted(text)
  ├─ ChatState.start_response()
  ├─ ContextCollector.collect()
  │   ↓ 返回 { tasks: {...}, pomodoro: {...}, ... }
  ├─ 构建 HTTP 请求体:
  │   {
  │     "content": "为我创建一个番茄钟任务",
  │     "stream": true,
  │     "attachments": [],
  │     "context": { ... 上下文数据 ... }
  │   }
  │
  └─ CustomAPIAdapter._send_via_adapter(text, context)
      │ [在线程中执行]
      │
      ├─ _execute_request() # POST /chat/messages
      │   ├─ HTTPRequest.request(url, headers, POST, body)
      │   └─ 等待响应 → 200 OK (SSE stream)
      │
      └─ _read_sse_stream() # 在主线程逐行解析
          │
          ├─ 接收 SSE: event: text_delta
          │   data: {"content": "让"}
          │   ↓
          │   ChatState.append_response_text("让")
          │   ↓ [主线程]
          │   DialogueBox._on_response_text_delta("让")
          │   ↓ 显示: "让"
          │
          ├─ 接收 SSE: event: text_delta
          │   data: {"content": "我"}
          │   ↓ 显示: "让我"
          │
          ├─ ... 更多 text_delta ...
          │
          ├─ 接收 SSE: event: text_done
          │   data: {"content": "让我为你创建一个番茄钟任务"}
          │   ↓
          │   ChatState.set_response_text(...)
          │
          ├─ 接收 SSE: event: function_call
          │   data: {
          │     "id": "fc_001",
          │     "name": "add_task",
          │     "arguments": {
          │       "title": "番茄钟工作",
          │       "deadline": "2025-03-18T18:00:00"
          │     }
          │   }
          │   ↓ [主线程]
          │   ChatController._on_adapter_stream_chunk(AIResponse {
          │     type: FUNCTION_CALL,
          │     function_call_id: "fc_001",
          │     function_name: "add_task",
          │     function_args: {...}
          │   })
          │   ↓
          │   ChatController._handle_function_call(ai_response)
          │   ├─ AgentExecutor.execute("fc_001", "add_task", args)
          │   │   ├─ 查找 _fn_add_task() 方法
          │   │   ├─ 参数校验：deadline → 转换为 int 时间戳
          │   │   ├─ 调用 TaskState.add_task(title, timestamp)
          │   │   │   ↓ TaskState 返回新任务数据
          │   │   ├─ 如果成功:
          │   │   │   emit function_executed("fc_001", "add_task", result)
          │   │   │   return {"success": true, "data": {"task_id": 42, ...}}
          │   │   └─ 如果失败:
          │   │       emit function_failed("fc_001", "add_task", error_msg)
          │   │       return {"success": false, "error": "..."}
          │   │
          │   └─ ChatState.notify_function_call_completed()
          │
          ├─ 回传函数结果 → 后端
          │   CustomAPIAdapter._execute_function_result_request({
          │     "session_id": "sess_abc",
          │     "function_call_id": "fc_001",
          │     "function_name": "add_task",
          │     "result": {
          │       "success": true,
          │       "data": {"task_id": 42, "title": "番茄钟工作", ...}
          │     }
          │   })
          │   │ [在线程中 POST /chat/function-results]
          │   └─ 等待 200 OK
          │
          └─ 接收 SSE: event: done
              data: {"message_id": "msg_xyz", "session_id": "sess_abc"}
              ↓ 流结束
              
最终 UI 状态：
  ├─ DialogueBox 显示: "让我为你创建一个番茄钟任务 ✓"
  ├─ TaskModule 刷新，新增任务"番茄钟工作"
  └─ AgentExecutor 发出 function_executed 信号
```

### 4.2 SSE 事件类型参考

| 事件类型 | 数据样例 | 用途 |
|---|---|---|
| `text_delta` | `{"content": "让"}` | 文本流式增量 |
| `text_done` | `{"content": "完整文本..."}` | 文本流完成 |
| `function_call` | `{"id": "fc_001", "name": "add_task", "arguments": {...}}` | 函数调用指令 |
| `tts` | `{"url": "https://...", "format": "mp3"}` | TTS 音频播放 |
| `done` | `{"message_id": "msg_xyz", "session_id": "..."}` | 响应完全完成 |

---

## 5. 错误处理与超时

### 5.1 HTTP 超时

```gdscript
# CustomAPIAdapter 中配置
HTTPRequest.REQUEST_TIMEOUT = 30.0  # 秒
```

超时时发出 `request_failed("Timeout: request exceeded 30 seconds")`

### 5.2 函数执行失败

```gdscript
# AgentExecutor.execute() 捕获异常
if not _functions.has(name):
    emit function_failed(call_id, name, "Function not found")
    return {"success": false, "error": "Function not found"}
```

### 5.3 后端错误

```python
# Python 后端返回 SSE:
# event: error
# data: {"message": "LLM 连接失败", "code": "LLM_ERROR"}
```

Godot 解析后 emit `response_failed(error_message)`

---

## 6. 快速参考 — 常见操作

### 6.1 发送消息

```gdscript
# 简单文本
ChatController.send_message("为我完成任务")

# 带图片附件
var images = ["path/to/image.png"]
ChatController.send_message("这是什么?", images)

# 不收集上下文（隐私模式）
ChatController.send_message_extended(text, [], false)
```

### 6.2 监听响应

```gdscript
ChatController.response_chunk.connect(func(chunk):
    print("收到:", chunk)
)

ChatController.function_call_executed.connect(func(name, result):
    if result["success"]:
        print("函数 %s 执行成功" % name)
)
```

### 6.3 注册自定义函数

```gdscript
# 在 AgentExecutor 中
AgentExecutor.register(
    "my_function",
    Callable(self, "_my_function"),
    {
        "name": "my_function",
        "description": "我的自定义函数",
        "parameters": {
            "type": "object",
            "properties": {
                "param1": {"type": "string"},
                "param2": {"type": "number"}
            },
            "required": ["param1"]
        }
    }
)

# 实现回调
func _my_function(param1: String, param2: float) -> Dictionary:
    # 业务逻辑
    return {"success": true, "data": "结果"}
```

### 6.4 查询上下文

```gdscript
var context = ContextCollector.collect()
print("待办任务:", context["tasks"]["pending"])
print("当前播放:", context["music"]["current_track"])
```

### 6.5 播放 TTS

```gdscript
# 从 URL
TTSPlayer.play("https://example.com/audio.mp3")

# 从二进制数据
var audio_data = ... # PackedByteArray
TTSPlayer.play("", audio_data, "mp3")

# 等待完成
TTSPlayer.playback_finished.connect(func():
    print("TTS 播放完毕")
)
```

---

## 7. 配置与自定义

### 7.1 后端服务器配置

在 `agent/config/chat_agent.yaml` 或 `agent/config/settings.yaml` 中配置：

```yaml
# 服务器地址
server:
  host: "127.0.0.1"
  port: 8008
  
# LLM 参数
llm:
  model: "gpt-4"
  temperature: 0.7
  max_tokens: 4096
  
# 任务生成
task_generation:
  enabled: true
  confidence_threshold: 0.8
```

### 7.2 ContextCollector 开关

```gdscript
# 在 Inspector 中或代码中关闭某些采集
ContextCollector.collect_tasks = true
ContextCollector.collect_music = false  # 不采集音乐状态
ContextCollector.collect_habits = true
```

### 7.3 TTSPlayer 配置

```gdscript
TTSPlayer.volume = 0.8
TTSPlayer.queue_enabled = true
```

---

## 8. 故障排查

| 问题 | 症状 | 排查步骤 |
|---|---|---|
| 消息无响应 | 点击发送后无反应 | 检查后端服务是否运行；检查 AuthState 令牌有效性 |
| 函数未执行 | function_call 收到但未触发 | 检查 AgentExecutor 是否注册了该函数；查看日志 function_failed 信号 |
| 上下文为空 | Agent 无法理解任务状态 | 检查 ContextCollector 对应采集开关是否启用 |
| TTS 不播放 | 语音无声 | 检查音量；检查 TTSPlayer.playback_error 信号；验证音频数据有效性 |
| SSE 流断开 | 流式响应中途停止 | 检查网络连接；查看后端日志 error 事件 |
| 令牌过期 | response_failed("Unauthorized") | 调用 AuthState.refresh_access_token()；重新发送消息 |

---

## 9. 设计亮点

1. **模块化设计**：ChatController/AgentExecutor/ContextCollector 各司其职，便于扩展。
2. **流式 SSE**：无需等待完整响应，逐字显示提升 UX。
3. **上下文自动采集**：Agent 智能理解应用状态，减轻用户描述负担。
4. **函数即 API**：将 Godot 方法自动映射为 LLM 可调用函数，无缝集成。
5. **错误恢复**：完善的超时/异常处理与用户反馈机制。
6. **多模态支持**：文本 + 图片 + TTS 完整组合。

