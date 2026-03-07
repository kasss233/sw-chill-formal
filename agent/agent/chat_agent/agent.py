"""
主聊天 Agent 核心：仅拼接各层（prompt、context、task_intent、task_generation）
"""
from datetime import datetime
from typing import List, Optional, Dict, Any

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
                import logging
                logging.getLogger(__name__).warning("任务生成失败: %s", e)
        self.conversation_history.append(LLMMessage(role="user", content=user_message))
        self.conversation_history.append(LLMMessage(role="assistant", content=response_text))
        return AgentResponse(
            text=response_text,
            performance_sequence=None,
            operations=operations,
        )

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
