"""
主聊天 Agent 核心：prompt + context + 结构化输出（function_calls / environment / action）
支持一次性 chat() 与流式 chat_stream()。
"""
from __future__ import annotations

import os
import time
import uuid
from datetime import datetime
from typing import Any, Dict, Generator, List, Optional, Set, Tuple

from interfaces.llm import LLMInterface, LLMMessage
from interfaces.memory import MemoryInterface
from interfaces.server_api import ServerAPI
from models.task import Task
from response import AgentResponse

from .config import AgentConfig
from .context import get_context_messages
from .invoke_log import emit_llm_invoke_single_turn, emit_llm_round_usage, emit_llm_stream_done
from .llm_output_parser import StreamingStructuredParser, StructuredTurn, parse_full
from .gateway_session import clear_pending, get_pending, set_pending
from .orchestrator import apply_plan_to_system_message, format_tool_results_user_message, run_tool_loop
from .planner import get_planner
from .task_intent import detect_task_creation_intent
from .task_generation import generate_tasks_from_conversation
from .tool_executor import ToolExecutorCallable, default_mock_tool_executor

try:
    from agent.core.function_definitions import (
        format_tools_for_prompt,
        function_names,
        load_function_definitions,
        resolve_definitions_path,
    )
except ModuleNotFoundError:
    from core.function_definitions import (
        format_tools_for_prompt,
        function_names,
        load_function_definitions,
        resolve_definitions_path,
    )

try:
    from core.logger import get_logger as _get_logger

    _log = _get_logger(__name__)
except ModuleNotFoundError:
    import logging

    _log = logging.getLogger(__name__)


class Agent:
    """主聊天 Agent：组合 prompt、上下文、可选旧版任务管线"""

    def __init__(
        self,
        llm: LLMInterface,
        memory: MemoryInterface,
        server_api: ServerAPI,
        config: Optional[AgentConfig] = None,
        tool_executor: Optional[ToolExecutorCallable] = None,
    ):
        self.llm = llm
        self.memory = memory
        self.server_api = server_api
        self.config = config or AgentConfig()
        self.conversation_history: List[LLMMessage] = []
        ## 同步工具执行器 (call_id, name, args) -> result；生产环境由 Godot 异步执行，本地联调可传 Mock
        self._tool_executor: Optional[ToolExecutorCallable] = tool_executor
        self._last_llm_usage: Optional[Dict[str, Any]] = None
        ## 编排多轮时：每轮 LLM 单次响应用量（列表顺序即 round 0,1,…）；与 _last_llm_usage 互斥
        self._last_llm_usage_rounds: Optional[List[Dict[str, Any]]] = None
        self._last_assistant_text: str = ""

    def _definitions_path(self):
        return resolve_definitions_path(self.config.function_definitions_path or None)

    def _allowed_function_names(self) -> Set[str]:
        return function_names(load_function_definitions(self._definitions_path()))

    def _tools_markdown(self) -> str:
        defs = load_function_definitions(self._definitions_path())
        return format_tools_for_prompt(defs)

    def _maybe_legacy_operations(self, user_message: str) -> list:
        if not self.config.legacy_task_pipeline:
            return []
        if not detect_task_creation_intent(user_message):
            return []
        try:
            tasks = generate_tasks_from_conversation(self.llm, self.config, user_message)
            from response import TaskCreateOperation

            return [TaskCreateOperation(task=t) for t in tasks]
        except NotImplementedError:
            return []
        except Exception as e:
            _log.warning("legacy_task_pipeline 任务生成失败: %s", e)
            return []

    def _turn_to_response(
        self,
        turn: StructuredTurn,
        user_message: str,
        raw_assistant_content: str,
    ) -> AgentResponse:
        operations = self._maybe_legacy_operations(user_message)
        return AgentResponse(
            text=turn.text,
            performance_sequence=None,
            operations=operations,
            function_calls=list(turn.function_calls),
            environment=turn.environment,
            action=turn.action,
        )

    def _effective_tool_executor(self) -> ToolExecutorCallable:
        if self._tool_executor is not None:
            return self._tool_executor
        return default_mock_tool_executor()

    def _chat_orchestrated(
        self,
        user_message: str,
        *,
        user_id: Optional[str] = None,
        session_id: Optional[str] = None,
        request_trace_id: Optional[str] = None,
    ) -> AgentResponse:
        tools_md = self._tools_markdown()
        base_messages = get_context_messages(
            memory=self.memory,
            conversation_history=self.conversation_history,
            user_message=user_message,
            config=self.config,
            tools_markdown=tools_md,
        )
        allowed = self._allowed_function_names()
        planner = get_planner(self.config.planner_mode)
        plan = planner.plan(user_message, allowed)
        memory_extra = ""
        if plan.need_memory_refresh:
            memory_extra = self.memory.get_memory_context(
                query=user_message,
                max_tokens=self.config.memory_max_tokens,
            ) or ""
        messages = apply_plan_to_system_message(base_messages, plan, memory_extra)
        trace = request_trace_id or uuid.uuid4().hex[:12]
        last_raw, final_turn, _, usage_per_round = run_tool_loop(
            self.llm,
            initial_messages=messages,
            allowed_function_names=allowed,
            strict_function_names=self.config.strict_function_names,
            temperature=self.config.temperature,
            max_tokens=self.config.max_tokens or 1000,
            max_tool_rounds=self.config.max_tool_rounds,
            tool_executor=self._effective_tool_executor(),
            user_id=user_id,
            session_id=session_id,
            request_trace_id=trace,
        )
        self._last_llm_usage = None
        self._last_llm_usage_rounds = usage_per_round
        self._last_assistant_text = (final_turn.text or "").strip()
        self.conversation_history.append(LLMMessage(role="user", content=user_message))
        self.conversation_history.append(LLMMessage(role="assistant", content=last_raw))
        return self._turn_to_response(final_turn, user_message, last_raw)

    def chat(
        self,
        user_message: str,
        *,
        user_id: Optional[str] = None,
        session_id: Optional[str] = None,
        request_trace_id: Optional[str] = None,
    ) -> AgentResponse:
        trace = request_trace_id or uuid.uuid4().hex[:12]
        if self.config.max_tool_rounds > 0:
            return self._chat_orchestrated(
                user_message,
                user_id=user_id,
                session_id=session_id,
                request_trace_id=trace,
            )
        self._last_llm_usage_rounds = None
        tools_md = self._tools_markdown()
        messages = get_context_messages(
            memory=self.memory,
            conversation_history=self.conversation_history,
            user_message=user_message,
            config=self.config,
            tools_markdown=tools_md,
        )
        max_tokens = self.config.max_tokens or 1000
        t0 = time.perf_counter()
        llm_response = self.llm.chat(
            messages=messages,
            temperature=self.config.temperature,
            max_tokens=max_tokens,
        )
        emit_llm_invoke_single_turn(
            trace=trace,
            user_id=user_id,
            session_id=session_id,
            latency_ms=(time.perf_counter() - t0) * 1000.0,
            source="chat",
        )
        raw = llm_response.content or ""
        u = (llm_response.metadata or {}).get("usage") if llm_response.metadata else None
        self._last_llm_usage = u if isinstance(u, dict) else None
        allowed = self._allowed_function_names()
        turn = parse_full(
            raw,
            allowed_function_names=allowed,
            strict_function_names=self.config.strict_function_names,
        )
        self._last_assistant_text = (turn.text or "").strip()
        for w in turn.parse_warnings:
            _log.warning("[chat] %s", w)

        self.conversation_history.append(LLMMessage(role="user", content=user_message))
        self.conversation_history.append(LLMMessage(role="assistant", content=raw))

        emit_llm_round_usage(
            trace=trace,
            user_id=user_id,
            session_id=session_id,
            round_idx=0,
            usage=self._last_llm_usage if isinstance(self._last_llm_usage, dict) else None,
        )
        return self._turn_to_response(turn, user_message, raw)

    def chat_stream(
        self,
        user_message: str,
        session_id: Optional[str] = None,
        *,
        user_id: Optional[str] = None,
        request_trace_id: Optional[str] = None,
        conversation_history_override: Optional[List[LLMMessage]] = None,
        gateway_orchestrator: bool = False,
    ) -> Generator[Tuple[str, Dict[str, Any]], None, None]:
        from agent_result_parser.sse_parser import SSEParser

        trace = request_trace_id or uuid.uuid4().hex[:12]
        # 网关编排时必须在首轮就下发 function_call SSE，不能在进程内跑完 run_tool_loop 再一次性 parse
        if self.config.max_tool_rounds > 0 and not gateway_orchestrator:
            resp = self._chat_orchestrated(
                user_message,
                user_id=user_id,
                session_id=session_id,
                request_trace_id=trace,
            )
            if os.environ.get("AGENT_DEBUG_CHAT", "").strip().lower() in ("1", "true", "yes"):
                _log.info(
                    "[chat_stream 编排] text 预览: %s",
                    (resp.text or "")[:800],
                )
            # 不在此处单独 yield text_delta：parse_agent_response 已按约定发出 function_call → … → text_done。
            # 若抢先发整段 text_delta，Godot 会先进入「正文展示」再收到工具调用，DialogueBox 状态会错乱。
            parser_sse = SSEParser(session_id=session_id or "")
            urounds = self._last_llm_usage_rounds
            for ev in parser_sse.parse_agent_response(
                resp,
                session_id=session_id,
                usage_rounds=urounds if isinstance(urounds, list) and len(urounds) > 0 else None,
            ):
                yield (ev.event_type.value, ev.data)
            return

        self._last_llm_usage_rounds = None
        if gateway_orchestrator and self.config.max_tool_rounds > 0:
            _log.info(
                "[chat_stream] gateway_orchestrator=True：跳过进程内 max_tool_rounds=%s 编排，"
                "工具由网关等待 function-results 后续轮",
                self.config.max_tool_rounds,
            )
        tools_md = self._tools_markdown()
        hist = (
            conversation_history_override
            if conversation_history_override is not None
            else self.conversation_history
        )
        if gateway_orchestrator and session_id:
            clear_pending(session_id)
        messages = get_context_messages(
            memory=self.memory,
            conversation_history=hist,
            user_message=user_message,
            config=self.config,
            tools_markdown=tools_md,
        )
        max_tokens = self.config.max_tokens or 1000

        stream_parser = StreamingStructuredParser()
        final_turn: Optional[StructuredTurn] = None
        raw_parts: List[str] = []

        t_stream0 = time.perf_counter()
        if hasattr(self.llm, "stream_chat"):
            for chunk in self.llm.stream_chat(
                messages=messages,
                temperature=self.config.temperature,
                max_tokens=max_tokens,
            ):
                if not chunk:
                    continue
                raw_parts.append(chunk)
                delta, closed = stream_parser.feed(chunk)
                if delta:
                    yield ("text_delta", {"content": delta})
                if closed:
                    final_turn = closed
        else:
            llm_response = self.llm.chat(
                messages=messages,
                temperature=self.config.temperature,
                max_tokens=max_tokens,
            )
            c = llm_response.content or ""
            raw_parts.append(c)
            delta, closed = stream_parser.feed(c)
            if delta:
                yield ("text_delta", {"content": delta})
            if closed:
                final_turn = closed

        emit_llm_stream_done(
            trace=trace,
            user_id=user_id,
            session_id=session_id,
            latency_ms=(time.perf_counter() - t_stream0) * 1000.0,
        )
        raw = "".join(raw_parts)

        if final_turn is None:
            final_turn = stream_parser.close()
            if final_turn is None:
                allowed = self._allowed_function_names()
                final_turn = parse_full(
                    raw,
                    allowed_function_names=allowed,
                    strict_function_names=self.config.strict_function_names,
                )

        for w in final_turn.parse_warnings:
            _log.warning("[chat_stream] %s", w)

        if not gateway_orchestrator:
            self.conversation_history.append(LLMMessage(role="user", content=user_message))
            self.conversation_history.append(LLMMessage(role="assistant", content=raw))

        if os.environ.get("AGENT_DEBUG_CHAT", "").strip().lower() in ("1", "true", "yes"):
            _log.info(
                "[chat_stream 单轮] text 预览: %s",
                (final_turn.text or "")[:800],
            )

        self._last_assistant_text = (final_turn.text or "").strip()
        resp = self._turn_to_response(final_turn, user_message, raw)
        prompt_est = self.llm.count_tokens(
            "".join(m.content for m in messages if m.content)
        )
        completion_est = self.llm.count_tokens(raw)
        self._last_llm_usage = {
            "estimated": True,
            "prompt_tokens_est": prompt_est,
            "completion_tokens_est": completion_est,
            "total_tokens_est": prompt_est + completion_est,
        }
        emit_llm_round_usage(
            trace=trace,
            user_id=user_id,
            session_id=session_id,
            round_idx=0,
            usage=self._last_llm_usage,
        )
        parser_sse = SSEParser(session_id=session_id or "")
        for ev in parser_sse.parse_agent_response(
            resp, session_id=session_id, usage=self._last_llm_usage
        ):
            if (
                gateway_orchestrator
                and session_id
                and resp.function_calls
                and ev.event_type.value == "done"
            ):
                continue
            yield (ev.event_type.value, ev.data)

        if gateway_orchestrator and session_id and resp.function_calls:
            msgs_after = list(messages) + [LLMMessage(role="assistant", content=raw)]
            set_pending(session_id, msgs_after)
        elif gateway_orchestrator and session_id and not resp.function_calls:
            clear_pending(session_id)

    def chat_stream_after_tool_results(
        self,
        session_id: str,
        tool_results: List[Dict[str, Any]],
        *,
        user_id: Optional[str] = None,
        request_trace_id: Optional[str] = None,
    ) -> Generator[Tuple[str, Dict[str, Any]], None, None]:
        """网关编排：在收到 function-results 后继续一轮 LLM（不执行进程内 tool_executor）。"""
        from agent_result_parser.sse_parser import SSEParser

        trace = request_trace_id or uuid.uuid4().hex[:12]
        # 续轮恒为单次 LLM+parse，不跑 run_tool_loop；与 max_tool_rounds 无关（该字段只影响首路 chat_stream 是否走 _chat_orchestrated）。

        pending = get_pending(session_id)
        if not pending:
            raise ValueError(f"无待续网关会话: session_id={session_id}")

        batch: List[Dict[str, Any]] = []
        for tr in tool_results:
            if not isinstance(tr, dict):
                continue
            fc_id = str(
                tr.get("function_call_id")
                or tr.get("id")
                or ""
            )
            name = str(tr.get("name") or tr.get("function_name") or "")
            result = tr.get("result")
            if not isinstance(result, dict):
                result = {"success": False, "error": "invalid_result"}
            batch.append(
                {"function_call_id": fc_id, "name": name, "result": result}
            )

        messages = list(pending) + [
            LLMMessage(
                role="user",
                content=format_tool_results_user_message(batch),
            )
        ]
        max_tokens = self.config.max_tokens or 1000

        stream_parser = StreamingStructuredParser()
        final_turn: Optional[StructuredTurn] = None
        raw_parts: List[str] = []

        t_stream0 = time.perf_counter()
        if hasattr(self.llm, "stream_chat"):
            for chunk in self.llm.stream_chat(
                messages=messages,
                temperature=self.config.temperature,
                max_tokens=max_tokens,
            ):
                if not chunk:
                    continue
                raw_parts.append(chunk)
                delta, closed = stream_parser.feed(chunk)
                if delta:
                    yield ("text_delta", {"content": delta})
                if closed:
                    final_turn = closed
        else:
            llm_response = self.llm.chat(
                messages=messages,
                temperature=self.config.temperature,
                max_tokens=max_tokens,
            )
            c = llm_response.content or ""
            raw_parts.append(c)
            delta, closed = stream_parser.feed(c)
            if delta:
                yield ("text_delta", {"content": delta})
            if closed:
                final_turn = closed

        emit_llm_stream_done(
            trace=trace,
            user_id=user_id,
            session_id=session_id,
            latency_ms=(time.perf_counter() - t_stream0) * 1000.0,
        )
        raw = "".join(raw_parts)

        if final_turn is None:
            final_turn = stream_parser.close()
            if final_turn is None:
                allowed = self._allowed_function_names()
                final_turn = parse_full(
                    raw,
                    allowed_function_names=allowed,
                    strict_function_names=self.config.strict_function_names,
                )

        for w in final_turn.parse_warnings:
            _log.warning("[chat_stream_after_tool_results] %s", w)

        self._last_assistant_text = (final_turn.text or "").strip()
        resp = self._turn_to_response(final_turn, "", raw)
        prompt_est = self.llm.count_tokens(
            "".join(m.content for m in messages if m.content)
        )
        completion_est = self.llm.count_tokens(raw)
        self._last_llm_usage = {
            "estimated": True,
            "prompt_tokens_est": prompt_est,
            "completion_tokens_est": completion_est,
            "total_tokens_est": prompt_est + completion_est,
        }
        emit_llm_round_usage(
            trace=trace,
            user_id=user_id,
            session_id=session_id,
            round_idx=0,
            usage=self._last_llm_usage,
        )
        parser_sse = SSEParser(session_id=session_id or "")
        for ev in parser_sse.parse_agent_response(
            resp, session_id=session_id, usage=self._last_llm_usage
        ):
            if resp.function_calls and ev.event_type.value == "done":
                continue
            yield (ev.event_type.value, ev.data)

        if resp.function_calls:
            msgs_after = list(messages) + [LLMMessage(role="assistant", content=raw)]
            set_pending(session_id, msgs_after)
        else:
            clear_pending(session_id)

    def generate_tasks_from_conversation(self, conversation_text: str) -> List[Task]:
        """对外暴露：从对话生成任务列表（委托给 task_generation 层）"""
        return generate_tasks_from_conversation(self.llm, self.config, conversation_text)

    def suggest_task_schedule(self, tasks: List[Task]) -> Dict[str, Any]:
        raise NotImplementedError("需要实现时间安排建议逻辑")

    def generate_summary(
        self,
        start_date: datetime,
        end_date: datetime,
        period: str = "week",
    ) -> str:
        self.server_api.get_statistics(start_date, end_date, period)
        raise NotImplementedError("需要实现总结生成逻辑")
