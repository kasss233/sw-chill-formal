"""
主聊天 Agent 核心：prompt + context + 结构化输出（function_calls / environment / action）
支持一次性 chat() 与流式 chat_stream()。
"""
from __future__ import annotations

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
from .invoke_log import emit_llm_invoke_single_turn, emit_llm_stream_done
from .llm_output_parser import StreamingStructuredParser, StructuredTurn, parse_full
from .orchestrator import apply_plan_to_system_message, run_tool_loop
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
        last_raw, final_turn, _ = run_tool_loop(
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
        allowed = self._allowed_function_names()
        turn = parse_full(
            raw,
            allowed_function_names=allowed,
            strict_function_names=self.config.strict_function_names,
        )
        for w in turn.parse_warnings:
            _log.warning("[chat] %s", w)

        self.conversation_history.append(LLMMessage(role="user", content=user_message))
        self.conversation_history.append(LLMMessage(role="assistant", content=raw))

        return self._turn_to_response(turn, user_message, raw)

    def chat_stream(
        self,
        user_message: str,
        session_id: Optional[str] = None,
        *,
        user_id: Optional[str] = None,
        request_trace_id: Optional[str] = None,
    ) -> Generator[Tuple[str, Dict[str, Any]], None, None]:
        from agent_result_parser.sse_parser import SSEEventType, SSEParser

        trace = request_trace_id or uuid.uuid4().hex[:12]
        if self.config.max_tool_rounds > 0:
            resp = self._chat_orchestrated(
                user_message,
                user_id=user_id,
                session_id=session_id,
                request_trace_id=trace,
            )
            if resp.text:
                yield ("text_delta", {"content": resp.text})
            yield ("text_done", {"content": resp.text})
            parser_sse = SSEParser(session_id=session_id or "")
            for ev in parser_sse.parse_agent_response(resp, session_id=session_id):
                if ev.event_type == SSEEventType.TEXT_DONE:
                    continue
                yield (ev.event_type.value, ev.data)
            return

        tools_md = self._tools_markdown()
        messages = get_context_messages(
            memory=self.memory,
            conversation_history=self.conversation_history,
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

        self.conversation_history.append(LLMMessage(role="user", content=user_message))
        self.conversation_history.append(LLMMessage(role="assistant", content=raw))

        yield ("text_done", {"content": final_turn.text})

        resp = self._turn_to_response(final_turn, user_message, raw)
        parser_sse = SSEParser(session_id=session_id or "")
        events = parser_sse.parse_agent_response(resp, session_id=session_id)
        for ev in events:
            if ev.event_type == SSEEventType.TEXT_DONE:
                continue
            yield (ev.event_type.value, ev.data)

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
