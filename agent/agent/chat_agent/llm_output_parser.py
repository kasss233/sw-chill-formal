"""
解析 LLM 完整输出：前置自然语言 + <agent_json>...</agent_json> 结构化块。
"""
from __future__ import annotations

import json
import logging
from dataclasses import dataclass, field
from typing import Any, Dict, List, Optional, Set, Tuple

_log = logging.getLogger(__name__)

AGENT_JSON_BEGIN = "<agent_json>"
AGENT_JSON_END = "</agent_json>"


@dataclass
class StructuredTurn:
    """单次助手回合解析结果。"""

    preamble: str
    text: str
    function_calls: List[Dict[str, Any]] = field(default_factory=list)
    environment: Optional[Dict[str, Any]] = None
    action: Optional[Dict[str, Any]] = None
    had_structured_block: bool = False
    parse_warnings: List[str] = field(default_factory=list)


def _normalize_arguments(raw: Any) -> Dict[str, Any]:
    if raw is None:
        return {}
    if isinstance(raw, dict):
        return raw
    if isinstance(raw, str):
        s = raw.strip()
        if not s:
            return {}
        try:
            parsed = json.loads(s)
            return parsed if isinstance(parsed, dict) else {}
        except json.JSONDecodeError:
            return {}
    return {}


def _normalize_function_call_item(item: Any, index: int) -> Optional[Dict[str, Any]]:
    if not isinstance(item, dict):
        return None
    name = item.get("name")
    if not name:
        return None
    fc_id = item.get("id") or item.get("call_id") or f"fc_{index + 1:03d}"
    args = _normalize_arguments(item.get("arguments", item.get("args")))
    return {"id": str(fc_id), "name": str(name), "arguments": args}


def parse_full(
    raw: str,
    allowed_function_names: Optional[Set[str]] = None,
    strict_function_names: bool = False,
) -> StructuredTurn:
    """
    从整段 LLM 输出解析结构化回合。
    - 若存在 <agent_json>...</agent_json>：标签前为 preamble（自然语言给用户看的正文）；
      JSON 内 `text` 常被模型写成内部说明（如「告知用户…」），故 **非空 preamble 优先** 作为对外 text，
      仅当标签前无正文时才使用 JSON 内 `text`（兼容纯结构化输出）。
    - 若无结构化块：全文视为 preamble，text 与 preamble 相同，无 function_calls。
    """
    raw = raw or ""
    warnings: List[str] = []

    begin_idx = raw.find(AGENT_JSON_BEGIN)
    end_idx = raw.rfind(AGENT_JSON_END)

    if begin_idx == -1 or end_idx == -1 or end_idx <= begin_idx:
        preamble = raw.strip()
        return StructuredTurn(
            preamble=preamble,
            text=preamble,
            function_calls=[],
            environment=None,
            action=None,
            had_structured_block=False,
            parse_warnings=warnings,
        )

    preamble = raw[:begin_idx].strip()
    inner = raw[begin_idx + len(AGENT_JSON_BEGIN) : end_idx].strip()

    function_calls: List[Dict[str, Any]] = []
    env: Optional[Dict[str, Any]] = None
    act: Optional[Dict[str, Any]] = None
    json_text = inner

    try:
        obj = json.loads(json_text)
    except json.JSONDecodeError as e:
        warnings.append(f"agent_json 内 JSON 解析失败: {e}")
        return StructuredTurn(
            preamble=preamble,
            text=preamble,
            function_calls=[],
            environment=None,
            action=None,
            had_structured_block=True,
            parse_warnings=warnings,
        )

    if not isinstance(obj, dict):
        warnings.append("agent_json 根节点不是对象")
        obj = {}

    json_inner_text = str(obj.get("text") or "").strip()
    if preamble.strip():
        text = preamble
    else:
        text = json_inner_text

    raw_calls = obj.get("function_calls", [])
    if raw_calls is None:
        raw_calls = []
    if not isinstance(raw_calls, list):
        raw_calls = []
    for i, it in enumerate(raw_calls):
        fc = _normalize_function_call_item(it, i)
        if fc:
            fname = fc["name"]
            if allowed_function_names is not None and fname not in allowed_function_names:
                msg = f"未知函数名（未在 function_definitions.json 中）: {fname}"
                if strict_function_names:
                    warnings.append(msg)
                    continue
                else:
                    _log.warning(msg)
            function_calls.append(fc)

    env = obj.get("environment")
    if env is not None and not isinstance(env, dict):
        warnings.append("environment 不是对象，已忽略")
        env = None

    act = obj.get("action")
    if act is not None and not isinstance(act, dict):
        warnings.append("action 不是对象，已忽略")
        act = None

    return StructuredTurn(
        preamble=preamble,
        text=text,
        function_calls=function_calls,
        environment=env,
        action=act,
        had_structured_block=True,
        parse_warnings=warnings,
    )


def _max_prefix_length_is_substr_of_marker(buffer: str, marker: str) -> int:
    """返回 buffer 结尾可匹配 marker 前缀的最大长度（用于避免把未完成标签当正文发出）。"""
    max_len = min(len(buffer), len(marker) - 1)
    for l in range(max_len, 0, -1):
        if marker[:l] == buffer[-l:]:
            return l
    return 0


class StreamingStructuredParser:
    """
    流式解析：在收到 chunk 时尽可能把「<agent_json> 之前」的正文以 text_delta 形式产出；
    结构块闭合后一次性 parse JSON。
    """

    def __init__(self) -> None:
        self._buf = ""
        self._phase = "preamble"  # preamble | structured | closed
        self._preamble_emitted_len = 0
        self._struct_start_idx: int = 0

    def feed(self, chunk: str) -> Tuple[str, Optional[StructuredTurn]]:
        """
        处理新 chunk。
        返回 (text_delta_for_user, structured_turn_if_json_closed_else_None)
        """
        if chunk:
            self._buf += chunk

        if self._phase == "closed":
            return "", None

        if self._phase == "preamble":
            idx = self._buf.find(AGENT_JSON_BEGIN)
            if idx == -1:
                safe_trim = _max_prefix_length_is_substr_of_marker(self._buf, AGENT_JSON_BEGIN)
                emit_end = len(self._buf) - safe_trim
                if emit_end > self._preamble_emitted_len:
                    delta = self._buf[self._preamble_emitted_len : emit_end]
                    self._preamble_emitted_len = emit_end
                    return delta, None
                return "", None

            # 进入 structured：先吐出 preamble 剩余
            delta_prefix = ""
            if idx > self._preamble_emitted_len:
                delta_prefix = self._buf[self._preamble_emitted_len : idx]
                self._preamble_emitted_len = idx
            self._phase = "structured"
            inner_start = idx + len(AGENT_JSON_BEGIN)
            self._struct_start_idx = inner_start
            # 继续在本轮尝试找闭合
            return delta_prefix, self._try_close_structured()

        # structured
        return "", self._try_close_structured()

    def _try_close_structured(self) -> Optional[StructuredTurn]:
        end_rel = self._buf.find(AGENT_JSON_END, self._struct_start_idx)
        if end_rel == -1:
            return None
        inner = self._buf[self._struct_start_idx : end_rel].strip()
        self._phase = "closed"
        preamble = self._buf[: self._buf.find(AGENT_JSON_BEGIN)].strip()
        turn = parse_full(
            preamble
            + "\n"
            + AGENT_JSON_BEGIN
            + "\n"
            + inner
            + "\n"
            + AGENT_JSON_END,
        )
        return turn

    def close(self) -> Optional[StructuredTurn]:
        """
        流结束：若无闭合标签，降级为仅 preamble。
        """
        if self._phase == "closed":
            return None
        if self._phase == "preamble":
            preamble = self._buf.strip()
            return StructuredTurn(
                preamble=preamble,
                text=preamble,
                had_structured_block=False,
            )
        # structured 但未闭合
        _log.warning("流结束仍未找到 %s，降级为 preamble", AGENT_JSON_END)
        preamble = self._buf[: self._buf.find(AGENT_JSON_BEGIN)].strip()
        return StructuredTurn(
            preamble=preamble,
            text=preamble,
            had_structured_block=False,
            parse_warnings=["未闭合的 agent_json"],
        )
