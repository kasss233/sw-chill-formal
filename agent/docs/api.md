# Agent 服务 API 说明

本文档描述本仓库内 Agent HTTP 服务暴露的 API、响应结构以及转换为 SSE 流式的规则与示例。

---

## 运行与测试

- **启动服务**：在项目根目录执行 `python run_server.py` 或 `python run.py`（host/port 见 `config/settings.yaml`）
- **Python 测试**：`python test_chat_agent.py`、`python test_reflection_agent.py`、`python test.py`
- **API 可用性（curl）**：
  - Windows：`test_api.bat` 或 `test_api.bat http://127.0.0.1:8000`
  - Linux/macOS：`./test_api.sh` 或 `./test_api.sh http://127.0.0.1:8000`（需 `chmod +x test_api.sh`）

---

## 基础信息

| 项目 | 说明 |
|------|------|
| 默认地址 | `http://127.0.0.1:8000`（可在 `config/settings.yaml` 中修改 `server.host`、`server.port`） |
| 请求/响应格式 | `application/json`，编码 UTF-8 |
| 错误响应 | HTTP 4xx/5xx，body 为 `{"error": "错误描述"}` |

---

## 一、健康检查

### 请求

```http
GET /health
```

### 响应示例（200）

```json
{
  "status": "ok"
}
```

---

## 二、主聊天 Agent（POST /chat）

支持两种响应方式：

- **非流式（默认）**：一次返回完整 JSON（AgentResponse）
- **流式（SSE）**：通过 `Accept: text/event-stream` 或查询参数 `?stream=true` 获取 SSE 流

### 请求

```http
POST /chat
Content-Type: application/json
```

**请求体：**

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| message | string | 是 | 用户输入文本 |
| user_id | string | 否 | 用户 UUID（后端传入，响应中原样带回） |
| uuid | string | 否 | 同 user_id，二选一即可 |
| session_id | string | 否 | 会话 ID（流式时写入 done 事件，便于前端关联） |

### 请求示例（非流式）

```json
{
  "message": "帮我列一个本周学习计划"
}
```

**cURL 示例（非流式）：**

```bash
curl -X POST http://127.0.0.1:8000/chat \
  -H "Content-Type: application/json" \
  -d "{\"message\": \"帮我列一个本周学习计划\"}"
```

**cURL 示例（流式 SSE）：**

```bash
curl -X POST "http://127.0.0.1:8000/chat?stream=true" \
  -H "Content-Type: application/json" \
  -d "{\"message\": \"你好\"}" \
  -N
```

或通过请求头：

```bash
curl -X POST http://127.0.0.1:8000/chat \
  -H "Content-Type: application/json" \
  -H "Accept: text/event-stream" \
  -d "{\"message\": \"你好\"}" \
  -N
```

流式响应为 SSE：先连续收到 `text_delta`（逐片文本），再 `text_done`（完整文本），若有任务等操作则收到若干 `function_call`，最后一条为 `done`。

### 响应结构说明

成功时 HTTP 200，body 为 **AgentResponse** 的 JSON；若请求体中带了 `user_id` 或 `uuid`，响应根级别会多一个 **user_id** 字段（值为请求中的用户 UUID）。

**AgentResponse 字段：**

| 字段 | 类型 | 说明 |
|------|------|------|
| text | string | Agent 的文本回复 |
| performance_sequence | object \| null | 演出脚本序列（当前多为 null） |
| operations | array | 需要前端/客户端执行的操作列表，见下方 Operation 类型 |

**Operation 类型（operations 数组中的每一项）：**

- **TaskCreateOperation**：`action: "create_task"`，含 `task`（Task 对象）
- **TaskUpdateOperation**：`action: "update_task"`，含 `task_id`、`task`
- **TaskDeleteOperation**：`action: "delete_task"`，含 `task_id`
- **TaskCompleteOperation**：`action: "complete_task"`，含 `task_id`
- **ProjectCreateOperation** / **ProjectUpdateOperation** / **ProjectDeleteOperation**
- **SceneComponentOperation**：`action: "update_scene_components"`，含 `components`
- **BGMOperation**：`action: "update_bgm"`，含 `operation_type`（volume/switch/toggle）、`volume`/`track_id`/`play`
- **AmbientNoiseOperation**：`action: "update_ambient_noise"`，含 `enabled`、`volume`
- **FocusStartOperation**：`action: "start_focus"`，含 `focus_type`、`task_id`
- **FocusEndOperation**：`action: "end_focus"`，含 `focus_record_id`

**Task 对象（在 create_task 等操作中出现）结构：**

| 字段 | 类型 | 说明 |
|------|------|------|
| id | string \| null | 任务 ID，新建时多为 null |
| project_id | string | 所属项目，如 "root" |
| info | object | TaskInfo，见下 |
| completed | boolean | 是否已完成 |
| sort_order | number | 排序序号 |
| deadline | string \| null | ISO 日期时间或 null |

**TaskInfo 对象：**

| 字段 | 类型 | 说明 |
|------|------|------|
| description | string | 任务描述（标题） |
| owner | string | "user" \| "girl" |
| created_at | string | ISO 日期时间 |

### 响应示例（200）— 仅文本

未带 user_id 时：

```json
{
  "text": "好的，这周我们可以这样安排学习：先复习课本第一章，然后做配套习题，最后整理错题本。",
  "performance_sequence": null,
  "operations": []
}
```

请求体带 `user_id`（或 `uuid`）时，响应会多出 `user_id`：

```json
{
  "text": "好的，这周我们可以这样安排学习：...",
  "performance_sequence": null,
  "operations": [],
  "user_id": "usr_abc123"
}
```

### 响应示例（200）— 文本 + 创建任务

```json
{
  "text": "好的，我为你整理了一个本周学习计划，并已经添加到你的任务列表里啦～",
  "performance_sequence": null,
  "operations": [
    {
      "action": "create_task",
      "task": {
        "id": null,
        "project_id": "root",
        "info": {
          "description": "复习课本第一章",
          "owner": "girl",
          "created_at": "2026-03-07T12:00:00"
        },
        "completed": false,
        "sort_order": 0,
        "deadline": null
      }
    },
    {
      "action": "create_task",
      "task": {
        "id": null,
        "project_id": "root",
        "info": {
          "description": "做配套习题",
          "owner": "girl",
          "created_at": "2026-03-07T12:00:00"
        },
        "completed": false,
        "sort_order": 1,
        "deadline": null
      }
    }
  ]
}
```

### 错误示例（400 / 500）

**缺少 message（400）：**

```json
{
  "error": "缺少 message 字段或为空"
}
```

**服务异常（500）：**

```json
{
  "error": "Agent 处理失败: ..."
}
```

---

## 三、反思总结 Agent（POST /reflection/summary）

### 请求

```http
POST /reflection/summary
Content-Type: application/json
```

**请求体：**

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| end_date | string | 是 | 区间结束日期，格式 YYYY-MM-DD 或完整 ISO |
| start_date | string | 否 | 开始日期，默认 end_date 往前 6 天 |
| period | string | 否 | 统计粒度，默认 "week"（如 "day" / "month"） |
| trigger | string | 否 | 触发方式："daily" / "weekly" / "manual" |
| extra_context | string | 否 | 额外语境文本 |
| precomputed_stats | object | 否 | 预先计算好的统计数据（测试或外部统计时传入） |
| user_id | string | 否 | 用户 UUID（响应中原样带回） |
| uuid | string | 否 | 同 user_id，二选一即可 |

### 请求示例

```json
{
  "end_date": "2026-03-07",
  "start_date": "2026-03-01",
  "period": "week",
  "trigger": "manual"
}
```

**cURL 示例：**

```bash
curl -X POST http://127.0.0.1:8000/reflection/summary \
  -H "Content-Type: application/json" \
  -d "{\"end_date\": \"2026-03-07\", \"period\": \"week\"}"
```

### 响应结构说明

成功时 HTTP 200，body 同样为 **AgentResponse** 的 JSON；若请求中带了 `user_id` 或 `uuid`，响应根级别会多 **user_id** 字段。

反思接口通常只使用：

- **text**：阶段性总结正文（数据概览、模式洞察、建议等）
- **performance_sequence**：null
- **operations**：[]（反思不产生操作）

### 响应示例（200）

```json
{
  "text": "这周你一共完成了 3 项任务，完成率不错～ 从数据上看，你在工作日的上午效率更高，下午容易分心。建议下周把重要任务尽量排在上午，下午安排一些轻量事项或休息。",
  "performance_sequence": null,
  "operations": []
}
```

### 错误示例（400）

**缺少 end_date：**

```json
{
  "error": "缺少 end_date 字段（格式示例：2026-02-27）"
}
```

**日期格式错误：**

```json
{
  "error": "end_date 格式错误，建议使用 YYYY-MM-DD 或完整 ISO 格式"
}
```

---

## 四、AgentResponse 转成 SSE 的规则与示例

当需要以 **SSE（Server-Sent Events）** 形式推送给前端时，可将一次 HTTP 返回的 **AgentResponse** 转成多条 SSE 事件。前端可据此实现流式展示或与后端 B 类 Function Calling 协议对齐。

### 4.1 事件类型与顺序

| 事件类型 | 说明 | 何时出现 |
|----------|------|----------|
| text_done | 一段完整文本结束 | 当 `AgentResponse.text` 非空时 |
| function_call | 请求前端执行本地函数 | 每个 `operations` 中可映射为 function 的操作各一条 |
| tts | 语音合成（URL 或 base64 等） | 当 `performance_sequence` 非空且可提取 TTS 内容时（当前多为空） |
| done | 本回合结束 | 始终在最后一条 |

**推荐顺序：** `text_done`（若有）→ 若干 `function_call`（若有）→ `tts`（若有）→ `done`。

### 4.2 SSE 格式约定

每条事件为两行（或更多行），以换行结尾，事件之间用空行分隔：

```
event: <事件类型>
data: <JSON 字符串>

```

- `event`：事件类型，如 `text_done`、`function_call`、`tts`、`done`
- `data`：单行 JSON，UTF-8 编码（中文不转义为 `\uxxxx` 时使用 `ensure_ascii=False`）

### 4.3 各事件 data 结构

**text_done**

```json
{"content": "Agent 的完整文本回复"}
```

**function_call**（与 backend_api 中 B 类函数一致）

```json
{
  "id": "fc_001",
  "name": "add_task",
  "arguments": {
    "title": "复习课本第一章",
    "due_timestamp": 0
  }
}
```

- `id`：本 function_call 唯一 ID，前端回传结果时需带上
- `name`：函数名（如 add_task、remove_task、set_task_completed 等）
- `arguments`：该函数的参数字典

**tts**（当前多为占位）

```json
{"url": "https://...", "format": "mp3"}
```
或流式：`{"chunk_index": 0, "data": "base64...", "format": "mp3", "is_last": false}`

**done**

```json
{
  "message_id": "msg_abc123",
  "session_id": "sess_xyz"
}
```

若请求体中带了 `user_id` 或 `uuid`，流式接口会在 **done** 事件的 `data` 中带回 **user_id**：

```json
{
  "message_id": "msg_abc123",
  "session_id": "sess_xyz",
  "user_id": "usr_abc123"
}
```

### 4.4 Operation → function_call 映射（主聊天 Agent）

| Operation 类型 | SSE function_call name | arguments 示例 |
|----------------|------------------------|----------------|
| TaskCreateOperation | add_task | `{"title": "任务描述", "due_timestamp": 0}` |
| TaskUpdateOperation | update_task_title | `{"task_id": 1, "title": "新标题"}` |
| TaskDeleteOperation | remove_task | `{"task_id": 1}` |
| TaskCompleteOperation | set_task_completed | `{"task_id": 1, "completed": true}` |
| BGMOperation (volume) | set_bgm_volume | `{"volume": 0.5}` |
| BGMOperation (switch) | play_music | `{"track_name": "xxx"}` |
| BGMOperation (toggle) | toggle_playback | `{}` |
| FocusStartOperation (tomato) | start_pomodoro | `{"work_minutes": 25, "rest_minutes": 5, "loop_times": 1}` |
| FocusEndOperation | stop_pomodoro | `{}` |

无法映射的 Operation（如部分项目/场景操作）不会生成 function_call 事件。

### 4.5 完整 SSE 流示例 — 主聊天（文本 + 两个创建任务）

假设 AgentResponse 为：

```json
{
  "text": "好的，已为你添加两个任务～",
  "performance_sequence": null,
  "operations": [
    {"action": "create_task", "task": {"id": null, "project_id": "root", "info": {"description": "复习第一章", "owner": "girl"}, "completed": false, "sort_order": 0, "deadline": null}},
    {"action": "create_task", "task": {"id": null, "project_id": "root", "info": {"description": "做习题", "owner": "girl"}, "completed": false, "sort_order": 1, "deadline": null}}
  ]
}
```

转换后的 SSE 流（文本）：

```
event: text_done
data: {"content": "好的，已为你添加两个任务～"}

event: function_call
data: {"id": "fc_001", "name": "add_task", "arguments": {"title": "复习第一章", "due_timestamp": 0}}

event: function_call
data: {"id": "fc_002", "name": "add_task", "arguments": {"title": "做习题", "due_timestamp": 0}}

event: done
data: {"message_id": "msg_abc123", "session_id": "sess_xyz"}

```

### 4.6 完整 SSE 流示例 — 反思总结（仅文本）

反思接口返回的 AgentResponse 通常只有 text，无 operations，对应 SSE 为：

```
event: text_done
data: {"content": "这周你一共完成了 3 项任务，完成率不错～..."}

event: done
data: {"message_id": "msg_def456", "session_id": ""}

```

### 4.7 代码侧转换入口

- **agent_result_parser.interface**：`agent_response_to_sse_text_list(agent_response_json: str, quiet: bool = False) -> List[str]`  
  传入 AgentResponse 的 JSON 字符串，返回按顺序排列的 SSE 事件字符串列表（每项为 `"event: xxx\ndata: xxx\n"`）。`quiet=True` 时不打印解析过程，便于后端/库化使用。
- **agent_result_parser.sse_parser**：`SSEParser.parse_agent_response(agent_response)`  
  传入 AgentResponse 对象，返回 `List[SSEEvent]`，再通过 `event.to_sse_format()` 得到每条 SSE 字符串（含末尾 `\n\n`）。

---

## 五、与后端业务 API 的关系

本服务为 **Agent 侧 HTTP 服务**（对话与反思）。  
业务后端 API（Auth、Task 查询、Note、AI Chat 会话、Sync 等）见项目内 [backend_api.md](../backend_api.md)。  
前端可先调用本 Agent 服务拿到 AgentResponse，再按上文规则转为 SSE 推给客户端，或由后端网关将 Agent 输出转为 SSE 再转发。
