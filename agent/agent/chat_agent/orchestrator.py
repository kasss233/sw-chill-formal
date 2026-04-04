"""多轮工具自回归：解析 assistant 的 <agent_json>，执行 function_calls，将结果注入后再调 LLM。"""
from __future__ import annotations

import json
import time
import uuid
from typing import Any, Callable, List, Optional, Tuple

from interfaces.llm import LLMInterface, LLMMessage, LLMResponse

from .invoke_log import emit_llm_invoke, emit_tool_invoke
from .llm_output_parser import StructuredTurn, parse_full
from .planner import PlanResult

try:
    from core.logger import get_logger as _get_logger

    _log = _get_logger(__name__)
except ModuleNotFoundError:
    import logging

    _log = logging.getLogger(__name__)


def format_tool_results_user_message(results: List[Dict[str, Any]]) -> str:
    """将多工具执行结果合并为单条 user 消息，供下一轮 LLM 阅读。"""
    return (
        "以下是工具执行器返回的结果（JSON 数组，每项含 function_call_id、name、result）。"
        "请根据结果继续完成对用户的要求；若信息仍不足，可再次在 <agent_json> 中输出 function_calls。\n"
        + json.dumps(results, ensure_ascii=False)
    )


def run_tool_loop(
    llm: LLMInterface,
    *,
    initial_messages: List[LLMMessage],
    allowed_function_names: set,
    strict_function_names: bool,
    temperature: float,
    max_tokens: Optional[int],
    max_tool_rounds: int,
    tool_executor: Callable[[str, str, dict], dict],
    user_id: Optional[str] = None,
    session_id: Optional[str] = None,
    request_trace_id: Optional[str] = None,
) -> Tuple[str, StructuredTurn, List[str]]:
    """
    在同一会话消息列表上做多轮：LLM → 解析 function_calls → 执行 → 注入 user(tool results) → 再 LLM。

    返回:
        last_raw: 最后一轮 assistant 完整原文
        last_turn: 最后一轮解析结果
        all_raws: 每轮 assistant 原文（调试）
    """
    trace = request_trace_id or uuid.uuid4().hex[:12]
    messages: List[LLMMessage] = list(initial_messages)
    all_raws: List[str] = []
    last_turn: Optional[StructuredTurn] = None
    last_raw = ""

    for round_idx in range(max_tool_rounds + 1):
        t_llm0 = time.perf_counter()
        resp: LLMResponse = llm.chat(
            messages,
            temperature=temperature,
            max_tokens=max_tokens,
        )
        llm_ms = (time.perf_counter() - t_llm0) * 1000.0
        emit_llm_invoke(
            trace=trace,
            user_id=user_id,
            session_id=session_id,
            round_idx=round_idx,
            latency_ms=llm_ms,
        )
        raw = resp.content or ""
        all_raws.append(raw)
        last_raw = raw
        turn = parse_full(
            raw,
            allowed_function_names=allowed_function_names,
            strict_function_names=strict_function_names,
        )
        for w in turn.parse_warnings:
            _log.warning("[orchestrator] round=%s %s", round_idx, w)
        last_turn = turn
        messages.append(LLMMessage(role="assistant", content=raw))

        if not turn.function_calls:
            break

        batch_results: List[Dict[str, Any]] = []
        for i, fc in enumerate(turn.function_calls):
            fc_id = str(
                fc.get("id")
                or fc.get("call_id")
                or f"fc_r{round_idx}_{i}"
            )
            name = str(fc.get("name", ""))
            args = fc.get("arguments", fc.get("args", {}))
            if not isinstance(args, dict):
                args = {}
            t_tool0 = time.perf_counter()
            try:
                result = tool_executor(fc_id, name, args)
            except Exception as e:
                _log.exception("tool_executor 异常: %s", e)
                result = {"success": False, "error": str(e)}
            tool_ms = (time.perf_counter() - t_tool0) * 1000.0
            emit_tool_invoke(
                trace=trace,
                user_id=user_id,
                session_id=session_id,
                round_idx=round_idx,
                tool_name=name,
                call_id=fc_id,
                latency_ms=tool_ms,
                result=result if isinstance(result, dict) else None,
            )
            batch_results.append(
                {"function_call_id": fc_id, "name": name, "result": result}
            )

        messages.append(
            LLMMessage(
                role="user",
                content=format_tool_results_user_message(batch_results),
            )
        )

        if round_idx >= max_tool_rounds:
            _log.warning(
                "[orchestrator] 已达 max_tool_rounds=%s，工具已执行但不再调用下一轮 LLM",
                max_tool_rounds,
            )
            break

    if last_turn is None:
        raise RuntimeError("orchestrator: 无有效解析结果")
    return last_raw, last_turn, all_raws


def apply_plan_to_system_message(
    messages: List[LLMMessage],
    plan: PlanResult,
    memory_extra: str,
) -> List[LLMMessage]:
    """在副本上把 Planner 结论写入 system 首条；可选附加记忆片段。"""
    out = [LLMMessage(role=m.role, content=m.content) for m in messages]
    if not out or out[0].role != "system":
        return out
    suffix_parts: List[str] = []
    if plan.planner_notes:
        suffix_parts.append("[Planner]\n" + plan.planner_notes)
    if plan.need_memory_refresh and memory_extra:
        suffix_parts.append("[补充记忆上下文]\n" + memory_extra.strip())
    if not suffix_parts:
        return out
    sys0 = out[0]
    out[0] = LLMMessage(role="system", content=sys0.content + "\n\n" + "\n\n".join(suffix_parts))
    return out
