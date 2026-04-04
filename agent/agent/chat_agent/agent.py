"""
主聊天 Agent 核心：仅拼接各层（prompt、context、task_intent、task_generation）
支持一次性 chat() 与流式 chat_stream()。
"""
from __future__ import annotations

from datetime import datetime
from typing import List, Optional, Dict, Any, Generator, Tuple

from interfaces.llm import LLMInterface, LLMMessage
from interfaces.memory import MemoryInterface
from interfaces.server_api import ServerAPI
from models.task import Task
from response import AgentResponse

from .config import AgentConfig
from .context import get_context_messages
from .prompt import get_system_prompt
from .task_intent import detect_task_creation_intent
from .task_generation import generate_tasks_from_conversation

try:
    from core.logger import get_logger as _get_logger

    _log = _get_logger(__name__)
except ModuleNotFoundError:  # 极少数导入路径下无 core
    import logging

    _log = logging.getLogger(__name__)


class Agent:
    """主聊天 Agent：组合 prompt、context、任务意图检测、任务生成各层"""

    def __init__(
        self,
        llm: LLMInterface,
        memory: MemoryInterface,
        server_api: ServerAPI,
        config: Optional[AgentConfig] = None,
    ):
        self.llm = llm
        self.memory = memory
        self.server_api = server_api
        self.config = config or AgentConfig()
        self.conversation_history: List[LLMMessage] = []

    def chat(self, user_message: str) -> AgentResponse:
        messages = get_context_messages(
            memory=self.memory,
            conversation_history=self.conversation_history,
            user_message=user_message,
            config=self.config,
        )
        max_tokens = self.config.max_tokens or 1000
        llm_response = self.llm.chat(
            messages=messages,
            temperature=self.config.temperature,
            max_tokens=max_tokens,
        )
        response_text = llm_response.content
        operations = []
        if detect_task_creation_intent(user_message):
            try:
                tasks = generate_tasks_from_conversation(
                    self.llm, self.config, user_message
                )
                from response import TaskCreateOperation
                for task in tasks:
                    operations.append(TaskCreateOperation(task=task))
            except NotImplementedError:
                pass
            except Exception as e:
                from core.logger import get_logger
                get_logger(__name__).warning("任务生成失败: %s", e)
        self.conversation_history.append(LLMMessage(role="user", content=user_message))
        self.conversation_history.append(LLMMessage(role="assistant", content=response_text))
        return AgentResponse(
            text=response_text,
            performance_sequence=None,
            operations=operations,
        )

    def chat_stream(
        self,
        user_message: str,
        session_id: Optional[str] = None,
    ) -> Generator[Tuple[str, Dict[str, Any]], None, None]:
        """
        流式对话：先逐片推送文本（text_delta），再 text_done，再 function_call（若有），最后 done。

        Yields:
            (event_type, data) 元组，如 ("text_delta", {"content": "..."})、("text_done", {"content": "..."})、
            ("function_call", {"id": "fc_001", "name": "add_task", "arguments": {...}})、("done", {"message_id": ..., "session_id": ...})
        """
        from agent_result_parser.sse_parser import SSEParser, SSEEventType

        _log.info(
            "chat_stream 开始: session_id=%s user_msg_len=%s",
            session_id,
            len(user_message or ""),
        )

        messages = get_context_messages(
            memory=self.memory,
            conversation_history=self.conversation_history,
            user_message=user_message,
            config=self.config,
        )
        max_tokens = self.config.max_tokens or 1000
        response_text_parts: List[str] = []

        # 1) 流式生成文本，逐片 yield text_delta
        if hasattr(self.llm, "stream_chat"):
            _log.info("chat_stream: 进入 LLM stream_chat（若长时间无下一条日志，多半卡在下游 API）")
            chunk_index = 0
            for chunk in self.llm.stream_chat(
                messages=messages,
                temperature=self.config.temperature,
                max_tokens=max_tokens,
            ):
                if chunk:
                    chunk_index += 1
                    response_text_parts.append(chunk)
                    if chunk_index == 1:
                        _log.info("chat_stream: 收到首个 LLM 分片 len=%s", len(chunk))
                    elif chunk_index % 40 == 0:
                        _log.debug("chat_stream: 已收到 %s 片 LLM 输出", chunk_index)
                    yield ("text_delta", {"content": chunk})
            _log.info("chat_stream: LLM stream_chat 结束, 分片数=%s 合并长度=%s", chunk_index, sum(len(p) for p in response_text_parts))
        else:
            _log.info("chat_stream: 使用非流式 LLM chat()")
            llm_response = self.llm.chat(
                messages=messages,
                temperature=self.config.temperature,
                max_tokens=max_tokens,
            )
            response_text_parts.append(llm_response.content)
            yield ("text_delta", {"content": llm_response.content})

        response_text = "".join(response_text_parts)

        # 2) 任务意图与操作（与 chat() 一致）
        _log.info("chat_stream: 开始任务意图检测 / 可选任务生成")
        operations = []
        if detect_task_creation_intent(user_message):
            _log.info("chat_stream: 检测到任务创建意图，调用 generate_tasks_from_conversation（可能再次请求 LLM）")
            try:
                tasks = generate_tasks_from_conversation(
                    self.llm, self.config, user_message
                )
                from response import TaskCreateOperation
                for task in tasks:
                    operations.append(TaskCreateOperation(task=task))
                _log.info("chat_stream: 任务生成完成 tasks=%s", len(tasks))
            except NotImplementedError:
                pass
            except Exception as e:
                _log.warning("任务生成失败: %s", e)
        else:
            _log.info("chat_stream: 无任务创建意图，跳过二次 LLM")

        self.conversation_history.append(LLMMessage(role="user", content=user_message))
        self.conversation_history.append(LLMMessage(role="assistant", content=response_text))

        # 3) text_done（完整文本）
        _log.info("chat_stream: yield text_done len=%s", len(response_text))
        yield ("text_done", {"content": response_text})

        # 4) function_call 与 done：复用 SSEParser 的映射
        resp = AgentResponse(
            text=response_text,
            performance_sequence=None,
            operations=operations,
        )
        parser = SSEParser(session_id=session_id or "")
        events = parser.parse_agent_response(resp)
        _log.info("chat_stream: SSEParser 产出事件数=%s", len(events))
        for ev in events:
            if ev.event_type == SSEEventType.TEXT_DONE:
                continue  # 已在上方 yield
            _log.debug("chat_stream: yield 解析事件 type=%s", ev.event_type.value)
            yield (ev.event_type.value, ev.data)
        _log.info("chat_stream 全部事件已产出")

    def generate_tasks_from_conversation(self, conversation_text: str) -> List[Task]:
        """对外暴露：从对话生成任务列表（委托给 task_generation 层）"""
        return generate_tasks_from_conversation(
            self.llm, self.config, conversation_text
        )

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
