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
- LLM 由 `agent/config/settings.yaml` 的 `llm` 段配置：可为 `providers` 列表（OpenAI 兼容 + Ollama 等按顺序回退），
  或旧版单字段 `base_url` + `model`（仅 Ollama）。
"""

from __future__ import annotations

import json
import time
from http.server import BaseHTTPRequestHandler, HTTPServer
from urllib.parse import urlparse
from datetime import datetime, timedelta
from pathlib import Path
from typing import Optional, Dict, Any

from agent import Agent, AgentConfig
from agent.reflection_agent import ReflectionAgent, ReflectionAgentConfig

# run_server.py 把本仓库的 agent/ 目录加入 path 时，core 是顶层包，内层 agent 包里没有 core；
# 从游戏仓库根目录 python -m agent.http_server.server 时则为 agent.core。
try:
    from agent.core.config_loader import (
        load_settings,
        load_chat_agent_config,
        load_reflection_agent_config,
    )
    from agent.core.logger import get_logger, setup_logging
    from agent.core.llm_factory import build_llm_from_settings
except ModuleNotFoundError:  # pragma: no cover - 与 run_server / start_server.bat 一致
    from core.config_loader import (
        load_settings,
        load_chat_agent_config,
        load_reflection_agent_config,
    )
    from core.logger import get_logger, setup_logging
    from core.llm_factory import build_llm_from_settings
from interfaces.memory import MemoryInterface
from interfaces.simple_server_api import SimpleServerAPI
from interfaces.real_server_api import RealServerAPI

logger = get_logger(__name__)


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


# ====== 从配置文件加载并初始化（全局单例） ======

def _load_config(config_dir: Optional[Path] = None) -> None:
    """加载 config 目录下的配置并初始化全局 Agent、LLM 等。"""
    global LLM_INSTANCE, MEMORY_INSTANCE, SERVER_API_INSTANCE, CHAT_AGENT, REFLECTION_AGENT
    settings = load_settings(config_dir)
    chat_cfg = load_chat_agent_config(config_dir)
    reflection_cfg = load_reflection_agent_config(config_dir)

    # 日志
    log_level = (settings.get("logging") or {}).get("level", "info")
    setup_logging(level=log_level)
    logger.info("配置已加载: settings=%s", bool(settings))

    # LLM：settings.yaml 中 llm.providers 顺序回退，或 legacy base_url+model（Ollama）
    llm_opts = settings.get("llm") or {}
    LLM_INSTANCE = build_llm_from_settings(llm_opts)
    MEMORY_INSTANCE = DummyMemory()
    backend = settings.get("backend") or {}
    if backend.get("use_real_api"):
        SERVER_API_INSTANCE = RealServerAPI(
            base_url=backend.get("base_url", "http://106.54.18.206:8000/api/v1"),
            access_token=backend.get("access_token") or None,
        )
        logger.info("使用 RealServerAPI: %s", backend.get("base_url"))
    else:
        SERVER_API_INSTANCE = SimpleServerAPI()

    # 只保留 Pydantic 模型支持的键，避免 extra 报错
    def _agent_config_keys():
        return {f for f in AgentConfig.model_fields}
    def _reflection_config_keys():
        return {f for f in ReflectionAgentConfig.model_fields}

    chat_dict = {k: v for k, v in chat_cfg.items() if k in _agent_config_keys()}
    reflection_dict = {k: v for k, v in reflection_cfg.items() if k in _reflection_config_keys()}

    agent_config = AgentConfig.model_validate(chat_dict) if chat_dict else AgentConfig()
    reflection_agent_config = ReflectionAgentConfig.model_validate(reflection_dict) if reflection_dict else ReflectionAgentConfig()

    CHAT_AGENT = Agent(
        llm=LLM_INSTANCE,
        memory=MEMORY_INSTANCE,
        server_api=SERVER_API_INSTANCE,
        config=agent_config,
    )
    REFLECTION_AGENT = ReflectionAgent(
        llm=LLM_INSTANCE,
        server_api=SERVER_API_INSTANCE,
        memory=MEMORY_INSTANCE,
        config=reflection_agent_config,
    )


# 默认配置目录：http_server 的上级目录下的 config
_CONFIG_DIR = Path(__file__).resolve().parent.parent / "config"
_load_config(_CONFIG_DIR)


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

    def _set_sse_headers(self) -> None:
        """设置 SSE 流式响应头。

        必须使用 Connection: close：本响应无 Content-Length / chunked，
        若 keep-alive，curl 等客户端无法判定 body 结束，会与单线程服务端互相等待而卡死。
        """
        self.send_response(200)
        self.send_header("Content-Type", "text/event-stream; charset=utf-8")
        self.send_header("Cache-Control", "no-cache")
        self.send_header("Connection", "close")
        self.send_header("X-Accel-Buffering", "no")
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

    def _get_user_id(self, body: Dict[str, Any]) -> Optional[str]:
        """从请求体读取用户 UUID，支持 user_id 或 uuid 字段。"""
        return (body or {}).get("user_id") or (body or {}).get("uuid") or None

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

        user_id = self._get_user_id(body)

        # 流式：Accept: text/event-stream 或 query ?stream=true
        want_stream = (
            "text/event-stream" in (self.headers.get("Accept") or "")
            or (urlparse(self.path).query or "").lower().find("stream=true") >= 0
        )
        if want_stream:
            self._handle_chat_stream(message, body.get("session_id"), user_id=user_id)
            return

        try:
            response = CHAT_AGENT.chat(message)
            # Pydantic v2 不再支持 .json(ensure_ascii=...)，用 model_dump 再 json.dumps
            out = response.model_dump(mode="json")
            if user_id is not None:
                out["user_id"] = user_id
            self._set_headers(200)
            self.wfile.write(json.dumps(out, ensure_ascii=False).encode("utf-8"))
        except Exception as e:
            self._set_headers(500)
            self.wfile.write(json.dumps({"error": f"Agent 处理失败: {e}"}).encode("utf-8"))

    def _handle_chat_stream(
        self,
        message: str,
        session_id: Optional[str] = None,
        user_id: Optional[str] = None,
    ) -> None:
        """以 SSE 流式返回 /chat 结果。done 事件中带回 user_id。"""
        t0 = time.perf_counter()
        logger.info(
            "HTTP SSE /chat 开始 session_id=%s user_id=%s message_len=%d",
            session_id,
            user_id,
            len(message or ""),
        )
        try:
            self._set_sse_headers()
            logger.info(
                "HTTP SSE 响应头已发送 (+%.2fs)，开始消费 chat_stream 生成器",
                time.perf_counter() - t0,
            )
            ev_total = 0
            delta_total = 0
            first_ev_t: Optional[float] = None
            for event_type, data in CHAT_AGENT.chat_stream(message, session_id=session_id):
                if first_ev_t is None:
                    first_ev_t = time.perf_counter()
                    logger.info(
                        "HTTP SSE 首个事件 type=%s (距请求开始 %.2fs)",
                        event_type,
                        first_ev_t - t0,
                    )
                ev_total += 1
                if event_type == "text_delta":
                    delta_total += 1
                    if delta_total == 1:
                        logger.debug("HTTP SSE 开始推送 text_delta")
                    elif delta_total % 60 == 0:
                        logger.debug("HTTP SSE 已写 text_delta x%s", delta_total)
                else:
                    logger.info(
                        "HTTP SSE 事件 type=%s ev#%s data_keys=%s",
                        event_type,
                        ev_total,
                        list(data.keys()) if isinstance(data, dict) else type(data).__name__,
                    )
                if event_type == "done" and user_id is not None:
                    data = {**data, "user_id": user_id}
                line = f"event: {event_type}\ndata: {json.dumps(data, ensure_ascii=False)}\n\n"
                self.wfile.write(line.encode("utf-8"))
                self.wfile.flush()
            logger.info(
                "HTTP SSE /chat 正常结束 events=%s text_deltas=%s 总耗时=%.2fs",
                ev_total,
                delta_total,
                time.perf_counter() - t0,
            )
        except Exception as e:
            logger.exception("流式 chat 失败: %s", e)
            # 已发送 SSE 头时无法再改状态码，只能发 error 事件
            err_line = f"event: error\ndata: {json.dumps({'code': 500, 'message': str(e)}, ensure_ascii=False)}\n\n"
            try:
                self.wfile.write(err_line.encode("utf-8"))
                self.wfile.flush()
            except Exception:
                pass

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
            out = response.model_dump(mode="json")
            user_id = self._get_user_id(body)
            if user_id is not None:
                out["user_id"] = user_id
            self._set_headers(200)
            self.wfile.write(json.dumps(out, ensure_ascii=False).encode("utf-8"))
        except Exception as e:
            self._set_headers(500)
            self.wfile.write(json.dumps({"error": f"ReflectionAgent 处理失败: {e}"}).encode("utf-8"))


# ====== 启动入口 ======

def run_server(
    host: Optional[str] = None,
    port: Optional[int] = None,
    config_dir: Optional[Path] = None,
) -> None:
    """启动 HTTP 服务。host/port 未传时从 config/settings 读取。"""
    if host is None or port is None:
        settings = load_settings(config_dir or _CONFIG_DIR)
        srv = settings.get("server") or {}
        host = host or srv.get("host", "127.0.0.1")
        port = port or srv.get("port", 8000)
    server_address = (host, int(port))
    httpd = HTTPServer(server_address, AgentHTTPRequestHandler)
    logger.info("Agent HTTP 服务已启动，监听地址：http://%s:%s", host, port)
    logger.info("可用接口：GET /health, POST /chat, POST /reflection/summary")
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        logger.info("收到中断信号，正在关闭 HTTP 服务...")
        httpd.server_close()


if __name__ == "__main__":
    run_server()

