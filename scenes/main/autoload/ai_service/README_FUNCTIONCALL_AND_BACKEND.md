# Function Call 与后端新接口对接说明

本文用于指导在当前项目中：

1. 新增一个 Function Call 函数
2. 对接后端新增接口（REST 或 SSE）
3. 联调与排错

适用范围：
- 聊天链路（ChatState -> ChatController -> CustomAPIAdapter）
- 函数执行链路（CustomAPIAdapter -> AgentExecutor -> State API）
- 语音链路（SSE tts 事件 -> TTSPlayer）

---

## 1. 当前链路总览

### 1.1 Function Call 处理路径

- 后端 SSE 事件进入：scenes/main/autoload/ai_service/adapters/custom_api_adapter.gd
- 事件转换为 AIResponse：scenes/main/autoload/ai_service/ai_response.gd
- 控制器分发并执行函数：scenes/main/autoload/ai_service/chat_controller.gd
- 函数注册与实现：scenes/main/autoload/ai_service/agent_executor.gd
- 函数定义声明：scenes/main/autoload/ai_service/function_definitions.json

### 1.2 后端地址与鉴权

- 后端地址来源：AuthState.get_base_url()
- Token 来源：AuthState.get_access_token()
- 地址与登录入口 UI：scenes/main/ui/setting/auth_panel.gd

---

## 2. 如何新增一个 Function Call

示例目标：新增函数 mark_task_urgent。

### 步骤 1：在函数定义文件中声明

编辑 scenes/main/autoload/ai_service/function_definitions.json，新增条目：

```json
{
  "name": "mark_task_urgent",
  "description": "将任务标记为紧急",
  "parameters": {
    "type": "object",
    "properties": {
      "task_id": { "type": "integer", "description": "任务 ID" },
      "urgent": { "type": "boolean", "description": "是否紧急" }
    },
    "required": ["task_id", "urgent"]
  }
}
```

注意：
- name 必须唯一。
- name 会映射到 AgentExecutor 中的方法名 _fn_<name>。

### 步骤 2：在 AgentExecutor 实现函数

编辑 scenes/main/autoload/ai_service/agent_executor.gd，新增：

```gdscript
func _fn_mark_task_urgent(args: Dictionary) -> Dictionary:
	var task_id := int(args.get("task_id", 0))
	var urgent := bool(args.get("urgent", false))
	if task_id <= 0:
		return {"success": false, "error": "task_id 无效"}

	# 这里调用对应 State API，遵守三层架构：只通过 State 修改数据
	var ok := TaskState.set_task_urgent(task_id, urgent)
	if not ok:
		return {"success": false, "error": "任务不存在或更新失败"}

	return {
		"success": true,
		"data": {
			"task_id": task_id,
			"urgent": urgent
		}
	}
```

返回约定：
- 成功：{"success": true, "data": ...}
- 失败：{"success": false, "error": "..."}

### 步骤 3：确认自动注册生效

AgentExecutor 会在初始化时读取 function_definitions.json 并自动注册。

关键点：
- JSON 里有 name
- 脚本里存在 _fn_<name>
- 方法签名为 func _fn_xxx(args: Dictionary) -> Dictionary

### 步骤 4：确认前后端字段一致

后端 function_call 事件应至少包含：

```json
{
  "id": "fc_123",
  "name": "mark_task_urgent",
  "arguments": {
    "task_id": 101,
    "urgent": true
  }
}
```

建议兼容：arguments 为字符串 JSON 的情况。

---

## 3. 如何对接后端新增 REST 接口

分两类：

1. 业务接口（非聊天）
2. 聊天相关接口

### 3.1 业务接口（推荐走 ApiClient）

统一通过 scenes/main/autoload/data/api_client.gd，优点：
- 自动带 Bearer Token
- 401 自动刷新重试
- 统一解析 code/message/data

示例：

```gdscript
var body := {"foo": "bar"}
var result = await ApiClient.api_post("/new/endpoint", body)
if not result.success:
	push_warning("调用失败: %s" % result.message)
	return

var data = result.data
```

建议：
- UI Module 不直接改数据
- 网络结果由 State 单例写入，再通过信号刷新 UI

### 3.2 聊天接口（走 CustomAPIAdapter）

当前默认：
- POST /chat/messages（SSE）
- POST /chat/function-results（JSON）

若后端改路径或参数，修改：
- scenes/main/autoload/ai_service/adapters/custom_api_adapter.gd

重点检查：
- 请求体字段（content、session_id、attachments、context）
- 请求头（Authorization、Accept）
- SSE 事件名与数据结构

---

## 4. 如何对接后端新增 SSE 事件

### 4.1 修改事件分发

编辑 scenes/main/autoload/ai_service/adapters/custom_api_adapter.gd 的 _dispatch_event。

新增 event 分支后：
1. 解析 data
2. 包装为 AIResponse
3. 通过 stream_chunk.emit 发给 ChatController

### 4.2 在 ChatController 增加处理逻辑

编辑 scenes/main/autoload/ai_service/chat_controller.gd：
- 在 _on_adapter_stream_chunk 的 match 中加入新类型
- 新增对应 _handle_xxx_response

### 4.3 如需新增 AIResponse 类型

编辑 scenes/main/autoload/ai_service/ai_response.gd：
- 扩展 ResponseType
- 增加字段
- 增加静态构造函数

---

## 5. 语音流（TTS）对接建议

当前状态：
- 已支持接收 tts 事件（url 或 base64 data）
- TTSPlayer 仍为占位实现，未完成真实解码/播放

文件：scenes/main/autoload/ai_service/tts_player.gd

### 5.1 推荐后端语音流协议（SSE）

```text
event: tts_start
data: {"stream_id":"s1","format":"pcm_s16le","sample_rate":24000,"channels":1}

event: tts_chunk
data: {"stream_id":"s1","seq":1,"data":"<base64>"}

event: tts_end
data: {"stream_id":"s1"}
```

### 5.2 客户端实现建议

- 低风险方案：chunk 累积 -> end 后一次性播放
- 真流式方案：使用 AudioStreamGenerator 连续推帧

建议优先低风险方案，确认协议稳定后再升级真流式。

---

## 6. 联调检查清单

### 6.1 Function Call

- function_definitions.json 中存在新函数定义
- AgentExecutor 中存在 _fn_<name> 实现
- 后端 function_call.name 与定义一致
- arguments 字段类型与客户端解析一致
- 函数执行结果已通过 /chat/function-results 回传

### 6.2 后端接口

- base_url 正确（设置页可见）
- 登录成功并有 access_token
- REST 返回结构为 code/message/data
- 错误码与异常路径可被 UI 感知

### 6.3 SSE

- event/data 行格式正确
- done 事件可触发收尾
- error 事件可正确显示

### 6.4 语音

- tts 事件可被 CustomAPIAdapter 识别
- ChatController 能转发给 TTSPlayer
- TTSPlayer 已实现实际播放（非占位）

---

## 7. 常见问题

### Q1：函数已定义但执行提示未知函数

排查：
1. function_definitions.json 的 name 是否与 _fn_<name> 对应
2. AgentExecutor 是否成功初始化并自动注册
3. 方法签名是否为 (args: Dictionary)

### Q2：函数调用参数总是空

原因：后端把 arguments 作为字符串传，客户端只按 Dictionary 取值。

处理：在 custom_api_adapter.gd 中兼容字符串 JSON 解析。

### Q3：收到 tts 事件但没有声音

原因：TTSPlayer 当前是占位实现。

处理：补齐 _play_audio / _download_audio / _decode_audio 的真实逻辑。

---

## 8. 推荐提交策略

一次改动尽量拆成 3 个提交：

1. Function Call：定义 + 执行器 + 单元验证
2. 后端协议：适配器字段与事件改造
3. 语音：播放器实现与稳定性修复

这样便于回滚和定位问题。
