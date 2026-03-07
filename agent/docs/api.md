# Agent 服务 API 说明

本文档描述本仓库内 Agent HTTP 服务暴露的 API（与后端业务 API 区分）。

## 基础信息

| 项目 | 说明 |
|------|------|
| 默认地址 | `http://127.0.0.1:8000`（可通过配置文件修改 host/port） |
| 数据格式 | 请求/响应 `application/json`，编码 UTF-8 |

## 端点

### 健康检查

```
GET /health
```

**响应（200）：**

```json
{ "status": "ok" }
```

### 主聊天 Agent

```
POST /chat
```

**请求体：**

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| message | string | 是 | 用户输入文本 |

**响应（200）：** 见 `AgentResponse`（text、performance_sequence、operations 等）

### 反思总结 Agent

```
POST /reflection/summary
```

**请求体：**

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| end_date | string | 是 | 区间结束日期，格式 YYYY-MM-DD 或 ISO |
| start_date | string | 否 | 开始日期，默认 end_date - 6 天 |
| period | string | 否 | 统计粒度，默认 "week" |
| trigger | string | 否 | 触发方式："daily" \| "weekly" \| "manual" |
| extra_context | string | 否 | 额外语境文本 |
| precomputed_stats | object | 否 | 预先计算好的统计数据（测试用） |

**响应（200）：** `AgentResponse`（主要为 text 总结）

---

后端业务 API（Task/Note/Auth/Chat/Sync 等）见 [backend_api.md](../backend_api.md)。
