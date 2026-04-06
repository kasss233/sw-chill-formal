"""Agent 调用过程控制台日志：trace / user_id / session_id / 延迟（ms）/ token 用量。"""
from __future__ import annotations

import json
import os
from typing import Any, Dict, Optional

# tool_call 结果 JSON 预览最大字符数（避免刷屏）
_TOOL_RESULT_PREVIEW_MAX = 900


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


def _format_tool_result_for_log(result: Optional[Dict[str, Any]]) -> str:
    """
    单行摘要：说明是否为 Agent 内置 Mock、列表条数、JSON 长度与截断预览。
    注意：orchestrator 里测的延迟是 **本进程 tool_executor** 耗时，不是 Godot 客户端往返。
    """
    if result is None:
        return "result=(无)"
    if not isinstance(result, dict):
        return f"result_type={type(result).__name__}"
    bits: list[str] = []
    bits.append(f"success={result.get('success', '?')}")
    if result.get("error") is not None:
        err = str(result.get("error"))
        bits.append(f"error={err[:200]}{'…' if len(err) > 200 else ''}")
    data = result.get("data")
    if data is None:
        bits.append("data=None")
    elif isinstance(data, dict):
        if data.get("_mock") is True:
            bits.append("mock=True(Agent内置桩,未接Godot/真实数据)")
        for key in ("items", "tasks", "notes"):
            if key in data and isinstance(data[key], list):
                bits.append(f"{key}_len={len(data[key])}")
                break
        try:
            dj = json.dumps(data, ensure_ascii=False)
            bits.append(f"data_json_len={len(dj)}")
        except Exception:
            bits.append("data_json_len=?")
    else:
        bits.append(f"data_type={type(data).__name__}")
    try:
        rj = json.dumps(result, ensure_ascii=False)
        if len(rj) > _TOOL_RESULT_PREVIEW_MAX:
            bits.append(f"result_preview={rj[:_TOOL_RESULT_PREVIEW_MAX]}…")
        else:
            bits.append(f"result_json={rj}")
    except Exception as e:
        bits.append(f"result_preview_error={e}")
    return " ".join(bits)


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
    detail = _format_tool_result_for_log(result if isinstance(result, dict) else None)
    print(
        f"[Agent调用] 触发=tool_call function={tool_name} call_id={call_id} round={round_idx} "
        f"trace={trace} user_id={_dash(user_id)} session_id={_dash(session_id)} "
        f"延迟_ms={latency_ms:.1f} "
        f"scope=agent进程内tool_executor(非Godot网络RTT,亚毫秒多为内存Mock) "
        f"{detail}",
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
