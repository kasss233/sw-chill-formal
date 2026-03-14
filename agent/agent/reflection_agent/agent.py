"""
反思与总结 Agent 核心：仅拼接数据获取 + 提示构建 + LLM 调用
"""
from datetime import datetime
from typing import Optional, Dict, Any, List

from interfaces.llm import LLMInterface, LLMMessage
from interfaces.memory import MemoryInterface
from interfaces.server_api import ServerAPI
from response import AgentResponse

from .config import ReflectionAgentConfig
from .prompt_builder import build_system_prompt, build_user_prompt


class ReflectionAgent:
    """反思与总结专用 Agent。依赖 ServerAPI 统计数据，不自行猜数字。"""

    def __init__(
        self,
        llm: LLMInterface,
        server_api: ServerAPI,
        memory: Optional[MemoryInterface] = None,
        config: Optional[ReflectionAgentConfig] = None,
    ):
        self.llm = llm
        self.server_api = server_api
        self.memory = memory
        self.config = config or ReflectionAgentConfig()

    def generate_period_summary(
        self,
        start_date: datetime,
        end_date: datetime,
        period: str = "week",
        trigger: str = "manual",
        precomputed_stats: Optional[Dict[str, Any]] = None,
        extra_context: Optional[str] = None,
    ) -> AgentResponse:
        stats = precomputed_stats
        if stats is None:
            stats = self.server_api.get_statistics(
                start_date=start_date,
                end_date=end_date,
                period=period,
            )
        try:
            daily_summary = self.server_api.get_daily_summary(end_date)
        except NotImplementedError:
            daily_summary = {}
        memory_context = ""
        if self.memory is not None:
            try:
                memory_context = self.memory.get_memory_context(
                    query="阶段性复盘与总结",
                    max_tokens=800,
                    filters=None,
                )
            except NotImplementedError:
                memory_context = ""
        system_prompt = build_system_prompt(self.config)
        user_prompt = build_user_prompt(
            start_date=start_date,
            end_date=end_date,
            period=period,
            trigger=trigger,
            stats=stats,
            daily_summary=daily_summary,
            extra_context=extra_context,
            memory_context=memory_context,
        )
        messages: List[LLMMessage] = [
            LLMMessage(role="system", content=system_prompt),
            LLMMessage(role="user", content=user_prompt),
        ]
        llm_response = self.llm.chat(
            messages=messages,
            temperature=self.config.temperature,
            max_tokens=self.config.max_tokens,
        )
        return AgentResponse(
            text=llm_response.content,
            performance_sequence=None,
            operations=[],
        )
