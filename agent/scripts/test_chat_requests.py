#!/usr/bin/env python3
"""
构造 /chat 请求并验证返回格式。

用法（在仓库根目录）：
  py agent/scripts/test_chat_requests.py local
  py agent/scripts/test_chat_requests.py local --batch
  py agent/scripts/test_chat_requests.py http --base-url http://127.0.0.1:8000
  py agent/scripts/test_chat_requests.py http --base-url http://127.0.0.1:8000 --stream

说明：
  - local：不启服务、不发 HTTP，仅在当前进程内调 Agent + Mock LLM（http_server 终端不会有任何 /chat 日志）。
    要看服务端日志请用子命令 http。
  - local --batch：一轮回复内塞入所有 function_calls，压力解析与 SSE 事件列。
  - http：对已运行的 agent/http_server 发 POST /chat，打印 JSON 或 SSE 事件列表（依赖真实 LLM，工具不一定全触发）。

  环境变量 AGENT_INVOKE_LOG=0 可关闭 [Agent调用] 控制台行（local 模式默认已临时设为 0，除非加 --show-invoke-log）。
"""
from __future__ import annotations

import argparse
import json
import os
import sys
import uuid
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen

# agent 包根目录加入 path（与 tests 一致）
_AGENT_DIR = Path(__file__).resolve().parent.parent
if str(_AGENT_DIR) not in sys.path:
    sys.path.insert(0, str(_AGENT_DIR))


def _dummy_for_prop(prop_name: str, schema: dict, *, depth: int = 0) -> Any:
    if depth > 8 or not isinstance(schema, dict):
        return None
    if "enum" in schema and isinstance(schema["enum"], list) and schema["enum"]:
        return schema["enum"][0]
    t = schema.get("type")
    if t == "array":
        items = schema.get("items")
        if isinstance(items, dict) and items.get("type") == "object":
            return [_dummy_object(items, depth=depth + 1)]
        if isinstance(items, dict):
            v = _dummy_for_prop(prop_name, items, depth=depth + 1)
            return [v] if v is not None else []
        return []
    if t == "object":
        return _dummy_object(schema, depth=depth + 1)
    if t == "integer":
        return 1
    if t == "number":
        return 0.5
    if t == "boolean":
        return False
    if t == "string":
        pn = prop_name.lower()
        if pn == "week_key" or pn.endswith("week_key"):
            return "2026-W10"
        if "deadline" in pn or pn == "date_key":
            return "2026-04-04T12:00:00" if "deadline" in pn else "2026-04-04"
        if pn == "query":
            return "test"
        if pn in ("text", "title", "content", "name", "playlist_name", "track_name"):
            return "test"
        return "test"
    return "test"


def _dummy_object(schema: dict, depth: int = 0) -> dict:
    props = schema.get("properties") or {}
    required = schema.get("required") or []
    out: Dict[str, Any] = {}
    for k in required:
        out[k] = _dummy_for_prop(k, props.get(k) or {}, depth=depth + 1)
    return out


def build_minimal_arguments(tool_def: Dict[str, Any]) -> Dict[str, Any]:
    params = tool_def.get("parameters")
    if not isinstance(params, dict):
        return {}
    return _dummy_object(params)


def _wrap_agent_json(
    text: str,
    function_calls: List[Dict[str, Any]],
    *,
    environment: Optional[dict] = None,
    action: Optional[dict] = None,
) -> str:
    from agent.chat_agent.llm_output_parser import AGENT_JSON_BEGIN, AGENT_JSON_END

    payload = {
        "text": text,
        "function_calls": function_calls,
        "environment": environment,
        "action": action,
    }
    inner = json.dumps(payload, ensure_ascii=False)
    return f"前置说明可忽略。\n{AGENT_JSON_BEGIN}\n{inner}\n{AGENT_JSON_END}"


class FixedLLM:
    """仅返回固定 content 的 LLM（实现 LLMInterface 子集）。"""

    def __init__(self, content: str):
        self._content = content

    def chat(self, messages, temperature=0.7, max_tokens=None, **kwargs):
        from interfaces.llm import LLMResponse

        return LLMResponse(content=self._content)

    def stream_chat(self, messages, temperature=0.7, max_tokens=None, **kwargs):
        yield self._content

    def count_tokens(self, text: str) -> int:
        return max(1, len(text) // 4)


class EmptyMemory:
    def get_memory_context(self, *a, **k):
        return ""

    def add_memory(self, *a, **k):
        return ""

    def search_memories(self, *a, **k):
        return []

    def update_memory(self, *a, **k):
        return True

    def delete_memory(self, *a, **k):
        return True


def _validate_agent_response_dict(d: Dict[str, Any]) -> List[str]:
    """检查与客户端相关的顶层字段是否存在（值可为空）。"""
    errs = []
    for key in ("text", "function_calls", "environment", "action", "operations"):
        if key not in d:
            errs.append(f"缺少字段: {key}")
    return errs


def _print_response_summary(tag: str, resp_dump: Dict[str, Any], sse_types: List[str]) -> None:
    fc = resp_dump.get("function_calls") or []
    print(f"\n=== {tag} ===")
    print(f"  text 长度: {len(resp_dump.get('text') or '')}")
    print(f"  function_calls 条数: {len(fc)}")
    if fc:
        names = [x.get("name") for x in fc if isinstance(x, dict)]
        print(f"  工具: {names[:20]}{' ...' if len(names) > 20 else ''}")
    print(f"  environment: {resp_dump.get('environment')}")
    print(f"  action: {resp_dump.get('action')}")
    print(f"  SSE 事件序列: {sse_types}")


def run_local(batch: bool, verbose: int, show_invoke_log: bool) -> int:
    if show_invoke_log:
        os.environ["AGENT_INVOKE_LOG"] = "1"
    else:
        os.environ["AGENT_INVOKE_LOG"] = "0"

    print(
        "【说明】local 模式只在当前进程内调用 Agent（Mock LLM），不会连接 http_server。\n"
        "  因此另一个终端里运行的 `py -m agent.http_server.server` 不会出现本次请求的访问日志。\n"
        "  若需验证服务端与真实 LLM，请在仓库根目录执行：\n"
        "    py agent/scripts/test_chat_requests.py http --base-url http://127.0.0.1:8000\n"
    )

    from agent.chat_agent.agent import Agent
    from agent.chat_agent.config import AgentConfig
    from agent.chat_agent.llm_output_parser import parse_full
    from agent_result_parser.sse_parser import SSEParser
    from interfaces.simple_server_api import SimpleServerAPI

    try:
        from agent.core.function_definitions import (
            default_function_definitions_path,
            function_names,
            load_function_definitions,
        )
    except ModuleNotFoundError:
        from core.function_definitions import (
            default_function_definitions_path,
            function_names,
            load_function_definitions,
        )

    path = default_function_definitions_path()
    defs = load_function_definitions(path)
    if not defs:
        print(f"未加载到工具定义: {path}", file=sys.stderr)
        return 1
    allowed = function_names(defs)
    config = AgentConfig(max_tool_rounds=0, strict_function_names=True)

    if batch:
        calls: List[Dict[str, Any]] = []
        for i, d in enumerate(defs):
            name = str(d.get("name", ""))
            if not name:
                continue
            args = build_minimal_arguments(d)
            calls.append({"id": f"fc_{i}_{name}", "name": name, "arguments": args})
        raw = _wrap_agent_json("批量工具探测", calls, environment={"time_mode": 0}, action={"pose": "greet"})
        agent = Agent(FixedLLM(raw), EmptyMemory(), SimpleServerAPI(), config=config)
        resp = agent.chat(
            "batch",
            user_id="test-user",
            session_id="test-session",
            request_trace_id="batch-" + uuid.uuid4().hex[:8],
        )
        dump = resp.model_dump(mode="json")
        turn = parse_full(raw, allowed_function_names=allowed, strict_function_names=True)
        if len(turn.function_calls) != len(calls):
            print(
                f"警告: 解析到的 function_calls 条数 {len(turn.function_calls)} != 构造 {len(calls)}",
                file=sys.stderr,
            )
        parser = SSEParser(session_id="test-session")
        events = parser.parse_agent_response(resp, session_id="test-session")
        types = [e.event_type.value for e in events]
        err = _validate_agent_response_dict(dump)
        if err:
            print("校验失败:", err, file=sys.stderr)
            return 1
        _print_response_summary("local-batch", dump, types)
        fc_events = types.count("function_call")
        if fc_events != len(resp.function_calls):
            print(f"警告: function_call 事件数 {fc_events} vs response.function_calls {len(resp.function_calls)}", file=sys.stderr)
        print(f"\n本地 batch 完成: 工具定义 {len(defs)} 条，单轮 function_calls {len(calls)}")
        return 0

    ok = 0
    fail = 0
    sample_dump: Optional[Dict[str, Any]] = None
    sample_types: Optional[List[str]] = None
    for i, d in enumerate(defs):
        name = str(d.get("name", ""))
        if not name:
            continue
        args = build_minimal_arguments(d)
        raw = _wrap_agent_json(f"测试工具 {name}", [{"id": f"fc_{i}", "name": name, "arguments": args}])
        agent = Agent(FixedLLM(raw), EmptyMemory(), SimpleServerAPI(), config=config)
        try:
            resp = agent.chat(
                "用户句占位",
                user_id="local-user",
                session_id="local-session",
                request_trace_id=f"ft-{i}",
            )
        except Exception as e:
            print(f"[FAIL] {name}: {e}", file=sys.stderr)
            fail += 1
            continue
        dump = resp.model_dump(mode="json")
        err = _validate_agent_response_dict(dump)
        if err:
            print(f"[FAIL] {name}: {err}", file=sys.stderr)
            fail += 1
            continue
        if not resp.function_calls or resp.function_calls[0].get("name") != name:
            print(f"[FAIL] {name}: function_calls 回传 name 不一致: {resp.function_calls}", file=sys.stderr)
            fail += 1
            continue
        parser = SSEParser(session_id="local-session")
        events = parser.parse_agent_response(resp, session_id="local-session")
        types = [e.event_type.value for e in events]
        if "done" not in types:
            print(f"[FAIL] {name}: SSE 缺少 done", file=sys.stderr)
            fail += 1
            continue
        if "function_call" not in types:
            print(f"[FAIL] {name}: SSE 缺少 function_call", file=sys.stderr)
            fail += 1
            continue
        ok += 1
        if sample_dump is None and verbose:
            sample_dump = dump
            sample_types = types
        if verbose >= 2:
            print(f"[OK] {name} args_keys={list(args.keys())} sse={types}")

    if sample_dump is not None:
        _print_response_summary("local 样例（首条 verbose）", sample_dump, sample_types or [])
    print(f"\n本地 per-tool: 通过 {ok}，失败 {fail}，合计工具 {len(defs)}")
    return 0 if fail == 0 else 1


def _parse_sse_body(body: str) -> List[Tuple[str, dict]]:
    events: List[Tuple[str, dict]] = []
    for block in body.split("\n\n"):
        block = block.strip()
        if not block:
            continue
        ev_name: Optional[str] = None
        data_line: Optional[str] = None
        for line in block.split("\n"):
            if line.startswith("event:"):
                ev_name = line[len("event:") :].strip()
            elif line.startswith("data:"):
                data_line = line[len("data:") :].strip()
        if ev_name and data_line is not None:
            try:
                events.append((ev_name, json.loads(data_line)))
            except json.JSONDecodeError:
                events.append((ev_name, {"_raw": data_line}))
    return events


def run_http(base_url: str, stream: bool, message: str) -> int:
    base = base_url.rstrip("/")
    url = f"{base}/chat"
    body: Dict[str, Any] = {
        "message": message,
        "session_id": f"http-{uuid.uuid4().hex[:8]}",
        "user_id": f"user-{uuid.uuid4().hex[:8]}",
        "request_trace_id": f"http-{uuid.uuid4().hex[:12]}",
    }
    payload = json.dumps(body, ensure_ascii=False).encode("utf-8")
    print("请求 URL:", url)
    print("请求体:", json.dumps(body, ensure_ascii=False))

    headers = {"Content-Type": "application/json; charset=utf-8"}
    if stream:
        headers["Accept"] = "text/event-stream"

    req = Request(url, data=payload, method="POST", headers=headers)
    try:
        with urlopen(req, timeout=300) as resp:
            raw = resp.read().decode("utf-8")
    except HTTPError as e:
        print(f"HTTP {e.code}: {e.read().decode('utf-8', errors='replace')}", file=sys.stderr)
        return 1
    except URLError as e:
        print(f"连接失败: {e}", file=sys.stderr)
        return 1

    if stream:
        events = _parse_sse_body(raw)
        print(f"\nSSE 事件数: {len(events)}")
        for i, (et, data) in enumerate(events):
            keys = list(data.keys()) if isinstance(data, dict) else type(data).__name__
            preview = json.dumps(data, ensure_ascii=False)[:200]
            print(f"  [{i}] {et} keys={keys} data≈{preview}")
        fcc = sum(1 for et, _ in events if et == "function_call")
        print(f"function_call 事件: {fcc}")
        return 0

    try:
        data = json.loads(raw)
    except json.JSONDecodeError:
        print("非 JSON 响应:", raw[:2000], file=sys.stderr)
        return 1

    print("\n响应 JSON 顶层键:", list(data.keys()))
    err = _validate_agent_response_dict(data)
    if err:
        print("字段校验:", err, file=sys.stderr)
    fc = data.get("function_calls") or []
    print(f"text 预览: {(data.get('text') or '')[:120]!r}...")
    print(f"function_calls 条数: {len(fc)}")
    for j, item in enumerate(fc[:15]):
        if isinstance(item, dict):
            print(f"  [{j}] {item.get('name')} id={item.get('id')}")
    if len(fc) > 15:
        print(f"  ... 其余 {len(fc) - 15} 条")
    print("environment:", data.get("environment"))
    print("action:", data.get("action"))
    return 0


def main() -> int:
    ap = argparse.ArgumentParser(description="构造 chat 请求并检查返回格式")
    sub = ap.add_subparsers(dest="mode", required=True)

    p_local = sub.add_parser("local", help="Mock LLM，覆盖 function_definitions 中全部工具（不经过 HTTP）")
    p_local.add_argument("--batch", action="store_true", help="单条回复包含所有 function_calls")
    p_local.add_argument(
        "--show-invoke-log",
        action="store_true",
        help="打印 Agent 的 [Agent调用] 行（默认关闭以免 93 条刷屏）",
    )
    p_local.add_argument("-v", "--verbose", action="count", default=0)

    p_http = sub.add_parser("http", help="POST 到已运行的 HTTP Agent")
    p_http.add_argument("--base-url", default="http://127.0.0.1:8000", help="含协议与主机端口，勿尾斜杠")
    p_http.add_argument("--stream", action="store_true", help="Accept: text/event-stream")
    p_http.add_argument(
        "--message",
        default="列出我的任务并添加一条标题为「联调测试」的无截止日任务。",
        help="用户消息（真实 LLM 时不保证触发全部工具）",
    )

    args = ap.parse_args()
    if args.mode == "local":
        return run_local(
            batch=args.batch,
            verbose=args.verbose,
            show_invoke_log=args.show_invoke_log,
        )
    if args.mode == "http":
        return run_http(args.base_url, args.stream, args.message)
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
