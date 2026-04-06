# Agent I/O、内部架构与后端对接说明

本文面向：**本仓库 `agent/`（Python）维护者**与**另一仓库的后端实现者**。生产环境主链路为 **Godot → 后端 API → SSE → Godot AgentExecutor**；本仓库 Agent 用于 **本地联调、协议对齐与集成测试**。

---

## 1. 输入 / 输出格式

### 1.1 HTTP 入口（`agent/http_server/server.py`）

**请求** `POST /chat`，JSON  body 常用字段：

| 字段 | 类型 | 说明 |
|------|------|------|
| `message` | string | 用户消息（必填） |
| `session_id` | string | 可选；会话 ID，SSE `done` 等事件回传 |
| `user_id` / `uuid` | string | 可选；回包或 `done` 中带出 |

**流式**：请求头 `Accept: text/event-stream` 或 URL 带 `stream=true`。

**非流式响应** JSON（对应 `AgentResponse.model_dump`）核心字段：

| 字段 | 说明 |
|------|------|
| `text` | 对用户展示/入库的助手正文 |
| `function_calls` | `{ id, name, arguments }[]`，与 Godot `function_definitions.json` 一致 |
| `environment` | 可选；环境载荷（与 Godot SSE `environment` 对齐） |
| `action` | 可选；演出载荷（与 Godot SSE `action` 对齐） |
| `operations` | 旧版结构，主路径已不写入；仅兼容反序列化 |
| `performance_sequence` | 可选 |

**流式 SSE** 事件名与 `data`（JSON）须与游戏内 [`README_FUNCTIONCALL_AND_BACKEND.md`](../../scenes/main/autoload/ai_service/README_FUNCTIONCALL_AND_BACKEND.md) 一致，主要包括：

- `text_delta` / `text_done`：`{ "content": "..." }`
- `function_call`：`{ "id", "name", "arguments" }`
- `environment` / `action`：扁平对象
- `tts` / `error` / `done` 等

### 1.2 工具定义唯一来源

与本项目 Godot 共用：[`scenes/main/autoload/ai_service/function_definitions.json`](../../scenes/main/autoload/ai_service/function_definitions.json)。  
Python 侧通过 `agent/config/chat_agent.yaml` 的 `function_definitions_path` 覆盖路径；空则解析为仓库根下上述默认文件。

### 1.3 联调模式说明（避免双套「真理」）

| 模式 | 说明 |
|------|------|
| **A：自包含 `<agent_json>`** | 独立 LLM 在正文中输出「自然语言 + `<agent_json>{...}</agent_json>`」；由 `llm_output_parser` 解析；适合无原生 tool API 的模型。 |
| **B：生产对齐** | 后端托管模型，SSE 直接下发 `function_call`；不要求助手正文夹带围栏。本仓库在 **非编排** 路径下仍用模式 A 驱动本地 LLM；**编排路径**在进程内注入工具结果，仍依赖模型输出围栏 JSON。 |

后端若以 **原生 Function Calling** 驱动，只需保证 **对外 SSE 与 Godot 一致**；内部不必使用 `<agent_json>`。

---

## 2. 内部运行逻辑与架构

### 2.1 分层

```
Planner（可选） → Orchestrator（工具循环） → LLMInterface → parse_full（StructuredTurn）
                      ↓
              ToolExecutor（同步回调；Godot 为异步 HTTP 回传）
```

- **`planner.py`**：`planner_mode` 为 `none` | `heuristic`。启发式下可附加 system 提示、在「涉及记忆」时多拉一段 `MemoryInterface.get_mess...`。
- **`orchestrator.run_tool_loop`**：在 **同一条 messages 链** 上重复「`llm.chat` → `parse_full` → 若有 `function_calls` 则 `tool_executor` → 注入一条 `user`（工具结果 JSON）→ 再 `llm.chat`」，直到无工具或达到 `max_tool_rounds`。
- **`tool_executor.py`**：`DictToolExecutor` 或自建 `(call_id, name, args) -> dict`；返回结构建议与 Godot `AgentExecutor` 一致：`{ "success": bool, "data"?, "error"? }`。
- **`agent.py`**：`max_tool_rounds > 0` 时走 `_chat_orchestrated`；否则单轮 `chat` / `chat_stream` 行为与旧版一致。`chat_stream` 在编排模式下 **内部非流式多轮 LLM**，仅在最后 **一次性** `text_delta` / `text_done` + 与单轮相同的后续事件。

### 2.2 配置（`AgentConfig` / `chat_agent.yaml`）

| 字段 | 含义 |
|------|------|
| `max_tool_rounds` | `0` 关闭编排；`>0` 为工具自回归最大「LLM→工具」轮数预算（详见代码中达到预算时的日志） |
| `planner_mode` | `none` / `heuristic` |
| `function_definitions_path` | 工具 JSON 路径 |
| `strict_function_names` | 是否丢弃未在 JSON 声明中的 `name` |
| `legacy_task_pipeline` | 是否启用旧版二次 LLM 生成任务 Operation |

### 2.3 状态与历史

- 编排过程中 **工具结果注入消息** 不写入 `conversation_history`；仅追加本轮 **用户句** 与 **最后一轮 assistant 原文**。
- 真实后端应 **会话级** 保存完整 tool 消息供下一轮模型使用。

### 2.4 与 `agent/godot_paser` 的关系

[**`agent/godot_paser/paser.gd`**](../godot_paser/paser.gd) 为历史「离线解析 JSON」脚本；**生产环境不依赖**。主链路为 **后端 SSE + Godot AgentExecutor**。请勿将 Parser 与当前 Python HTTP Agent 混为一条产品链路。

---

## 3. 后端交互逻辑（建议作为契约）

### 3.1 会话与 SSE

- **`session_id`**：全链路一致；新建会话由后端分配并经由 `session_start` 或首包响应返回（与现有 Godot `CustomAPIAdapter` 一致）。
- **`done`**：建议语义为 **「当前这一次「用户消息 → 模型侧输出流」结束」**。若仍 **挂起** 未执行完的 `function_call`（理论上网关应继续推送），则 **不应** 让客户端误以为整条多轮工具链已结束；更稳妥做法是：**每一轮**模型产出结束后发 `done`，客户端若仍有本地 tool 在执行，可忽略或延后处理**下一**次用户输入直至 `function-results` 完成。  
  **请在贵司后端固定一种语义**并在 OpenAPI/对接群中写清，避免双解。

### 3.2 `function_call` 与 `function-results`

- SSE 中每条 `function_call` 的 **`id`** 与 `POST /chat/function-results` 中的 **`function_call_id`** **一一对应**。
- 客户端（Godot）执行 `AgentExecutor.execute` 后，将结果 JSON 回传；后端应 **合并进对话** 并 **再次调用模型**，直到不再产生新工具调用。

### 3.2.1 生产推荐：chill-backend 编排 + Agent HTTP 单轮（`gateway_orchestrator`）

与 Godot 状态对齐的工具体应在 **网关**侧完成「下发 FC → 等待 `function-results` → 再调 Agent」；Python Agent 进程内 **勿** 再用 `max_tool_rounds>0` + `default_mock_tool_executor` 代替客户端。

**`POST /chat`（流式）扩展字段**（与 `agent/http_server/server.py` 一致）：

| 字段 | 说明 |
|------|------|
| `gateway_orchestrator` | `true` 时：若本轮有 `function_calls`，**不**在 SSE 末尾发 `done`，并在进程内暂存消息链供续轮；且 **忽略** `chat_agent.yaml` 的 `max_tool_rounds>0`，**不**走进程内 `_chat_orchestrated`（否则工具在服务端跑完才发 SSE，前端收不到首轮 `function_call`） |
| `history` | `[{ "role", "content" }]`（可选），与 `message` 一起参与 `get_context_messages`，**替代**该 HTTP 单例上一次的 `conversation_history`（用于网关从 DB 注入历史） |
| `tool_results` | 续轮请求体（**无** `message`）：`[{ "function_call_id", "name", "result" }]`，与 orchestrator 的 `format_tool_results_user_message` 对齐 |

**续轮**：首轮 `gateway_orchestrator` + `message` + `history` → 若有 FC 则网关挂起并 `POST .../function-results` → 再 `POST /chat` 仅带 `session_id` + `tool_results` + `gateway_orchestrator`，直至某轮 SSE 出现 `done`（无未决 FC）。

**独立运行 `http_server` 且未传 `gateway_orchestrator`** 时，行为与旧版一致（单轮 SSE + `done`）。

**chill-backend** 在转发 `function_call` 时会 **重写 `id` 为全局唯一**（如 `fc_<uuid>`），避免模型固定输出 `fc_001` 等与 `function_calls` 表主键冲突；客户端回传 `function-results` 时须使用 SSE 里下发的 **`id`**。

### 3.3 流式

- **`text_delta`**：用户可见文本流；纯工具轮可无 delta。
- **`text_done`**：建议为 **当前模型段** 的最终合并文本（与 Godot Dialogue 展示一致）。

### 3.4 `environment` / `action`

- 与 Godot 已实现的消费字段对齐（如 `time_mode`、`weather_mode`、`pose`、`emotion`）；后端可从模型结构化输出中剥离并单独发 SSE 事件。

---

## 4. 相对「纯发一条、等一条回复」后端需新增的能力

| 原先 | 现在 |
|------|------|
| 单次请求内 1 次模型往返 | **同一 `session_id` 下多轮**：每次收到 `function-results` 后 **再次** 调模型 |
| 无显式 tool 状态 | **挂起队列**、超时、失败时错误信息经 `function-results` 或 SSE `error` 透出 |
| 可选：首包巨幕 `context` | **按需**：由模型发只读工具（如 `get_all_tasks` / 将来的 `get_app_context`）由客户端执行并回传结果 |

可选增强：

- **Plan 阶段**：单独路由或首包 `plan` JSON（非必须；也可用 system 约束 + 标准 FC 由模型自行规划）。
- **与 `function_definitions.json` 同步**：后端注册的工具名 / 参数与对方 JSON **逐字一致**，避免 Godot `_fn_<name>` 对不上。

---

## 5. 记忆存哪一侧（待产品填）

- **若记忆在后端**：提供检索类 tool 或内部 RAG，**不要**依赖 Godot 每次塞全量 `context`。  
- **若记忆在客户端**：需定义 **客户端执行的导出 tool** 或由客户端在 `context` 中带摘要；后端在文档中二选一分支描述即可。

---

## 6. 本地快速验证

```bash
cd agent
# 配置 chat_agent.yaml：max_tool_rounds: 2、planner_mode: heuristic
py -m http_server.server
# 另开终端：对 /chat 发流式或非流式请求
```

单元测试：

```bash
cd agent
py -m pytest tests/test_orchestrator.py tests/test_chat_agent.py -q
```

构造 `/chat` 请求、校验 JSON/SSE 与 **覆盖全部 function_definitions 工具名**（Mock LLM，无需起服务）：

```bash
# 仓库根目录
py agent/scripts/test_chat_requests.py local        # 每工具单独一轮，93+ 条全量冒烟
py agent/scripts/test_chat_requests.py local --batch  # 单轮回复内塞入全部 function_calls + env/action
py agent/scripts/test_chat_requests.py http --base-url http://127.0.0.1:8000
py agent/scripts/test_chat_requests.py http --base-url http://127.0.0.1:8000 --stream
```

`http` 子命令依赖已运行的 `py -m agent.http_server.server` 与真实 LLM，不保证模型会真的调用所有工具；全覆盖请以 `local` / `local --batch` 为准。

**注意**：`local` **不会发 HTTP**，只在当前进程调 Agent；`http_server` 终端不会出现对应日志。要看服务端日志必须用 `http` 子命令（或 curl 等）访问正在监听的端口。

---

## 7. 修订记录

- 初版：Plan + `max_tool_rounds` 编排、`tool_executor` 可注入、`agent/docs` 与后端契约说明。
