"""网关编排多轮工具时：在 Agent 进程内暂存「assistant 之后」的消息链，供收到 tool_results 后继续 LLM。"""
from __future__ import annotations

from typing import Dict, List, Optional

from interfaces.llm import LLMMessage

_pending: Dict[str, List[LLMMessage]] = {}


def set_pending(session_id: str, messages: List[LLMMessage]) -> None:
    if session_id:
        _pending[session_id] = messages


def get_pending(session_id: str) -> Optional[List[LLMMessage]]:
    if not session_id:
        return None
    return _pending.get(session_id)


def clear_pending(session_id: str) -> None:
    if session_id and session_id in _pending:
        del _pending[session_id]
