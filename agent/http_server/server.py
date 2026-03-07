"""
基于标准库 http.server 的简单 HTTP 服务

目标：
- 为现有的两个 Agent（主聊天 Agent 与反思 Agent）提供一个响应式 HTTP 服务接口；
- 尽量不改动已有代码，只在 `agent/http_server` 目录下新增文件。

端口与路由（默认）：
- GET  /health                    → 健康检查
- POST /chat                      → 主聊天 Agent，对应 Agent.chat(...)
- POST /reflection/summary        → 反思 Agent，对应 ReflectionAgent.generate_period_summary(...)

启动方式（在仓库根目录）：
    python -m agent.http_server.server

依赖：
- 需要本地已启动 Ollama 服务（默认 http://localhost:11434），并有可用模型（例如 qwen2:1.5b）。
"""

from __future__ import annotations

import json
from http.server import BaseHTTPRequestHandler, HTTPServer
from urllib.parse import urlparse
from datetime import datetime, timedelta
from typing import Optional, Dict, Any

from agent import Agent, AgentConfig
from agent.reflection_agent import ReflectionAgent, ReflectionAgentConfig
from interfaces.llm_implementations.ollama_llm import OllamaLLM
from interfaces.memory import MemoryInterface
from interfaces.simple_server_api import SimpleServerAPI


# ====== 简单 Memory 实现（与示例类似） ======

class DummyMemory(MemoryInterface):
    """最简记忆实现，用于 HTTP 服务环境。"""

    def add_memory(self, content: str, metadata=None, importance: float = 1.0) -> str:
        return "dummy_memory_id"

    def search_memories(self, query: str, top_k: int = 5, filters=None):
        return []

    def update_memory(self, memory_id: str, content=None, metadata=None, importance=None) -> bool:
        return True

    def delete_memory(self, memory_id: str) -> bool:
        return True

    def get_memory_context(self, query: str, max_tokens: int = 2000, filters=None) -> str:
        # 当前不做真实记忆检索，返回空字符串即可
        return ""


# ====== Agent 实例初始化（全局单例） ======

def _init_llm() -> OllamaLLM:
    # 与示例保持一致，默认使用 qwen2:1.5b
    return OllamaLLM(
        base_url="http://localhost:11434",
        model="qwen2:1.5b",
    )


LLM_INSTANCE = _init_llm()
MEMORY_INSTANCE: MemoryInterface = DummyMemory()
SERVER_API_INSTANCE = SimpleServerAPI()

# 主聊天 Agent
CHAT_AGENT = Agent(
    llm=LLM_INSTANCE,
    memory=MEMORY_INSTANCE,
    server_api=SERVER_API_INSTANCE,
    config=AgentConfig(
        character_name="女孩",
        character_personality="温柔、体贴，以鼓励和支持为主",
        temperature=0.7,
        max_tokens=800,
    ),
)

# 反思 Agent
REFLECTION_AGENT = ReflectionAgent(
    llm=LLM_INSTANCE,
    server_api=SERVER_API_INSTANCE,
    memory=MEMORY_INSTANCE,
    config=ReflectionAgentConfig(
        character_name="女孩",
        character_personality=(
            "温柔、体贴，作为一个独立的虚拟形象陪在用户身边，"
            "善于站在自己的视角观察用户的状态，"
            "既会肯定用户的努力，也能温和地指出问题并给出具体建议"
        ),
        temperature=0.7,
        max_tokens=800,
    ),
)


# ====== HTTP 处理器 ======

class AgentHTTPRequestHandler(BaseHTTPRequestHandler):
    """统一处理 /chat 与 /reflection/summary 的 HTTP 请求。"""

    server_version = "AgentHTTPServer/0.1"

    # 关闭默认的日志打印，避免控制台过于嘈杂（如需可注释掉）
    def log_message(self, format: str, *args) -> None:  # type: ignore[override]
        # print(f"[HTTP] {self.address_string()} - {format % args}")
        pass

    def _set_headers(self, status: int = 200, content_type: str = "application/json; charset=utf-8") -> None:
        self.send_response(status)
        self.send_header("Content-Type", content_type)
        self.end_headers()

    def _read_json_body(self) -> Optional[Dict[str, Any]]:
        try:
            length = int(self.headers.get("Content-Length", "0"))
        except ValueError:
            length = 0
        if length <= 0:
            return {}
        raw = self.rfile.read(length).decode("utf-8")
        if not raw:
            return {}
        try:
            return json.loads(raw)
        except json.JSONDecodeError:
            return None

    # ---- 路由：GET ----

    def do_GET(self) -> None:  # type: ignore[override]
        parsed = urlparse(self.path)
        if parsed.path == "/health":
            self._set_headers(200)
            self.wfile.write(json.dumps({"status": "ok"}).encode("utf-8"))
        else:
            self._set_headers(404)
            self.wfile.write(json.dumps({"error": "Not Found"}).encode("utf-8"))

    # ---- 路由：POST ----

    def do_POST(self) -> None:  # type: ignore[override]
        parsed = urlparse(self.path)
        if parsed.path == "/chat":
            self._handle_chat()
        elif parsed.path == "/reflection/summary":
            self._handle_reflection_summary()
        else:
            self._set_headers(404)
            self.wfile.write(json.dumps({"error": "Not Found"}).encode("utf-8"))

    # ---- 具体处理逻辑 ----

    def _handle_chat(self) -> None:
        body = self._read_json_body()
        if body is None:
            self._set_headers(400)
            self.wfile.write(json.dumps({"error": "请求体不是合法的 JSON"}).encode("utf-8"))
            return

        message = (body.get("message") or "").strip()
        if not message:
            self._set_headers(400)
            self.wfile.write(json.dumps({"error": "缺少 message 字段或为空"}).encode("utf-8"))
            return

        try:
            response = CHAT_AGENT.chat(message)
            # 直接返回 AgentResponse 的 JSON
            self._set_headers(200)
            self.wfile.write(response.json(ensure_ascii=False).encode("utf-8"))
        except Exception as e:
            self._set_headers(500)
            self.wfile.write(json.dumps({"error": f"Agent 处理失败: {e}"}).encode("utf-8"))

    def _handle_reflection_summary(self) -> None:
        body = self._read_json_body()
        if body is None:
            self._set_headers(400)
            self.wfile.write(json.dumps({"error": "请求体不是合法的 JSON"}).encode("utf-8"))
            return

        # 解析时间区间（必填：end_date；start_date 可选，默认 end_date - 6 天）
        end_date_str = body.get("end_date")
        if not end_date_str:
            self._set_headers(400)
            self.wfile.write(json.dumps({"error": "缺少 end_date 字段（格式示例：2026-02-27）"}).encode("utf-8"))
            return

        try:
            end_date = datetime.fromisoformat(end_date_str)
        except ValueError:
            self._set_headers(400)
            self.wfile.write(json.dumps({"error": "end_date 格式错误，建议使用 YYYY-MM-DD 或完整 ISO 格式"}).encode("utf-8"))
            return

        start_date_str = body.get("start_date")
        if start_date_str:
            try:
                start_date = datetime.fromisoformat(start_date_str)
            except ValueError:
                self._set_headers(400)
                self.wfile.write(json.dumps({"error": "start_date 格式错误，建议使用 YYYY-MM-DD 或完整 ISO 格式"}).encode("utf-8"))
                return
        else:
            # 默认回溯 6 天，构成一周区间
            start_date = end_date - timedelta(days=6)

        period = body.get("period") or "week"
        trigger = body.get("trigger") or "manual"
        extra_context = body.get("extra_context")

        # 可选：允许调用方传入 precomputed_stats，用于测试“外部统计 + Agent 总结”的链路
        precomputed_stats = body.get("precomputed_stats")

        try:
            response = REFLECTION_AGENT.generate_period_summary(
                start_date=start_date,
                end_date=end_date,
                period=period,
                trigger=trigger,
                precomputed_stats=precomputed_stats,
                extra_context=extra_context,
            )
            self._set_headers(200)
            self.wfile.write(response.json(ensure_ascii=False).encode("utf-8"))
        except Exception as e:
            self._set_headers(500)
            self.wfile.write(json.dumps({"error": f"ReflectionAgent 处理失败: {e}"}).encode("utf-8"))


# ====== 启动入口 ======

def run_server(host: str = "127.0.0.1", port: int = 8000) -> None:
    server_address = (host, port)
    httpd = HTTPServer(server_address, AgentHTTPRequestHandler)
    print(f"Agent HTTP 服务已启动，监听地址：http://{host}:{port}")
    print("可用接口：")
    print("  GET  /health")
    print("  POST /chat")
    print("  POST /reflection/summary")
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        print("\n收到中断信号，正在关闭 HTTP 服务...")
        httpd.server_close()


if __name__ == "__main__":
    run_server()

