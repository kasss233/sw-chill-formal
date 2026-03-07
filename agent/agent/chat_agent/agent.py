"""
主聊天 Agent 实现
整合 LLM、记忆、任务生成等功能
"""
import re
from datetime import datetime
from typing import List, Optional, Dict, Any

from pydantic import BaseModel

from interfaces.llm import LLMInterface, LLMMessage
from interfaces.memory import MemoryInterface
from interfaces.server_api import ServerAPI
from models.task import Task
from response import AgentResponse


class AgentConfig(BaseModel):
    """Agent 配置（可从 config/chat_agent.yaml 加载）"""
    character_name: str = "女孩"
    character_personality: str = "温柔、体贴，以鼓励和支持为主"
    system_prompt_template: str = """你是一位名为{character_name}的AI陪伴角色。
性格特点：{character_personality}
你需要陪伴用户，提供情感支持和生产力协助。
在与用户对话时，要符合你的角色设定，并考虑上下文中的记忆信息。

你的能力：
你可以帮助用户管理任务和项目。当用户请求创建任务列表、添加任务、安排学习计划等时，
你应该积极地提供建议并准备创建相应的任务（具体任务创建由系统完成，你只需要提供友好的回复）。

重要要求：
1. 你必须使用中文与用户对话
2. 回复要符合你的角色设定，语气要{character_personality}
3. 回复要简洁、温暖、自然，就像朋友间的对话
4. 当用户请求创建任务或学习计划时，除了文字回复，系统会自动为你创建相应的任务"""

    temperature: float = 0.7
    max_tokens: Optional[int] = None
    memory_top_k: int = 5
    memory_max_tokens: int = 2000
    task_generation_prompt_template: Optional[str] = None
    task_generation_system_prompt: Optional[str] = None


class Agent:
    """主聊天 Agent 核心类"""

    def __init__(
        self,
        llm: LLMInterface,
        memory: MemoryInterface,
        server_api: ServerAPI,
        config: Optional[AgentConfig] = None
    ):
        self.llm = llm
        self.memory = memory
        self.server_api = server_api
        self.config = config or AgentConfig()
        self.conversation_history: List[LLMMessage] = []

    def _get_system_prompt(self) -> str:
        return self.config.system_prompt_template.format(
            character_name=self.config.character_name,
            character_personality=self.config.character_personality
        )

    def _get_context_messages(self, user_message: str) -> List[LLMMessage]:
        memory_context = self.memory.get_memory_context(
            query=user_message,
            max_tokens=self.config.memory_max_tokens
        )
        system_prompt = self._get_system_prompt()
        if memory_context:
            system_prompt += f"\n\n相关记忆：\n{memory_context}"
        messages = [LLMMessage(role="system", content=system_prompt)]
        messages.extend(self.conversation_history[-10:])
        messages.append(LLMMessage(role="user", content=user_message))
        return messages

    def _detect_task_creation_intent(self, user_message: str) -> bool:
        task_keywords = ["列表", "任务", "计划", "学习计划", "待办", "清单", "帮我列", "安排"]
        return any(keyword in user_message for keyword in task_keywords)

    def chat(self, user_message: str) -> AgentResponse:
        messages = self._get_context_messages(user_message)
        max_tokens = self.config.max_tokens or 1000
        llm_response = self.llm.chat(
            messages=messages,
            temperature=self.config.temperature,
            max_tokens=max_tokens
        )
        response_text = llm_response.content
        performance_sequence = None
        operations = []
        if self._detect_task_creation_intent(user_message):
            try:
                tasks = self.generate_tasks_from_conversation(user_message)
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
            performance_sequence=performance_sequence,
            operations=operations
        )

    def generate_tasks_from_conversation(self, conversation_text: str) -> List[Task]:
        from models.task import TaskInfo, TaskOwner
        default_task_prompt = """用户请求：{conversation_text}

请根据用户的请求，生成一个结构化的任务列表。任务应该是具体的、可执行的步骤。

要求：
1. 任务数量控制在3-8个之间
2. 每个任务应该是清晰、具体的行动项
3. 任务应该按照逻辑顺序排列
4. 用简洁的中文描述每个任务（每个任务描述不超过30字）

请按以下格式输出任务列表，每行一个任务：
1. 任务描述1
2. 任务描述2
3. 任务描述3
..."""
        task_prompt_template = self.config.task_generation_prompt_template or default_task_prompt
        task_generation_prompt = task_prompt_template.format(conversation_text=conversation_text)
        system_prompt = self.config.task_generation_system_prompt or "你是一个任务规划助手，擅长将用户的目标转化为具体的任务列表。"
        messages = [
            LLMMessage(role="system", content=system_prompt),
            LLMMessage(role="user", content=task_generation_prompt),
        ]
        llm_response = self.llm.chat(messages=messages, temperature=0.7, max_tokens=500)
        tasks = []
        lines = llm_response.content.split("\n")
        sort_order = 0
        for line in lines:
            line = line.strip()
            if not line:
                continue
            match = re.match(r"^\d+[\.、]\s*(.+)$", line) or re.match(r"^[-•]\s*(.+)$", line)
            if match:
                task_description = match.group(1).strip()
                if task_description:
                    tasks.append(Task(
                        id=None,
                        project_id="root",
                        info=TaskInfo(description=task_description, owner=TaskOwner.GIRL),
                        sort_order=sort_order
                    ))
                    sort_order += 1
        if not tasks:
            tasks.append(Task(
                id=None,
                project_id="root",
                info=TaskInfo(
                    description=f"完成：{conversation_text[:50]}",
                    owner=TaskOwner.GIRL
                ),
                sort_order=0
            ))
        return tasks

    def suggest_task_schedule(self, tasks: List[Task]) -> Dict[str, Any]:
        raise NotImplementedError("需要实现时间安排建议逻辑")

    def generate_summary(
        self,
        start_date: datetime,
        end_date: datetime,
        period: str = "week"
    ) -> str:
        self.server_api.get_statistics(start_date, end_date, period)
        raise NotImplementedError("需要实现总结生成逻辑")
