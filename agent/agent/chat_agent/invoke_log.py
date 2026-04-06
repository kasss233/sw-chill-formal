"""Agent 调用过程控制台日志：trace / user_id / session_id / 延迟（ms）/ token 用量。"""
from __future__ import annotations

import json
import os
from typing import Any, Dict, Optional


def _invoke_log_enabled() -> bool:
    """环境变量 AGENT_INVOKE_LOG：0/false/no/off 关闭；未设置或其它值开启。"""
    v = (os.environ.get("AGENT_INVOKE_LOG") or "1").strip().lower()
    return v not in ("0", "false", "no", "off")


def _dash(val: Optional[str]) -> str:
    return val if val and str(val).strip() else "-"


def emit_llm_invoke(
    *,
    trace: str,
    user_id: Optional[str],
    session_id: Optional[str],
    round_idx: int,
    latency_ms: float,
) -> None:
    if not _invoke_log_enabled():
        return
    print(
        f"[Agent调用] 触发=llm_chat round={round_idx} trace={trace} user_id={_dash(user_id)} "
        f"session_id={_dash(session_id)} 延迟_ms={latency_ms:.1f}",
        flush=True,
    )


def emit_tool_invoke(
    *,
    trace: str,
    user_id: Optional[str],
    session_id: Optional[str],
    round_idx: int,
    tool_name: str,
    call_id: str,
    latency_ms: float,
    result: Optional[Dict[str, Any]] = None,
) -> None:
    if not _invoke_log_enabled():
        return
    ok = ""
    if result is not None:
        ok = f" success={result.get('success', '?')}"
    print(
        f"[Agent调用] 触发=tool_call function={tool_name} call_id={call_id} round={round_idx} "
        f"trace={trace} user_id={_dash(user_id)} session_id={_dash(session_id)} "
        f"延迟_ms={latency_ms:.1f}{ok}",
        flush=True,
    )


def emit_llm_invoke_single_turn(
    *,
    trace: str,
    user_id: Optional[str],
    session_id: Optional[str],
    latency_ms: float,
    source: str = "chat",
) -> None:
    if not _invoke_log_enabled():
        return
    print(
        f"[Agent调用] 触发=llm_chat({source}) round=0 trace={trace} user_id={_dash(user_id)} "
        f"session_id={_dash(session_id)} 延迟_ms={latency_ms:.1f}",
        flush=True,
    )


def emit_llm_stream_done(
    *,
    trace: str,
    user_id: Optional[str],
    session_id: Optional[str],
    latency_ms: float,
) -> None:
    if not _invoke_log_enabled():
        return
    print(
        f"[Agent调用] 触发=llm_stream round=0 trace={trace} user_id={_dash(user_id)} "
        f"session_id={_dash(session_id)} 延迟_ms={latency_ms:.1f}",
        flush=True,
    )


def emit_llm_round_usage(
    *,
    trace: str,
    user_id: Optional[str],
    session_id: Optional[str],
    round_idx: int,
    usage: Optional[Dict[str, Any]],
) -> None:
    """单次大模型 HTTP 响应附带的用量（不累加多轮；编排模式每轮 LLM 各打一行）。"""
    if not _invoke_log_enabled():
        return
    if not usage:
        detail = "无（上游未返回 usage；Ollama 等可能仅有 eval_count / prompt_eval_count）"
    else:
        detail = json.dumps(usage, ensure_ascii=False)
    print(
        f"[Agent调用] 触发=llm_usage round={round_idx} trace={trace} user_id={_dash(user_id)} "
        f"session_id={_dash(session_id)} 用量={detail}",
        flush=True,
    )
