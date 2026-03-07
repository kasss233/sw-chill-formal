"""上下文层：记忆 + 对话历史 + 当前用户消息 -> 消息列表"""
from typing import List

from interfaces.llm import LLMMessage
from interfaces.memory import MemoryInterface

from .config import AgentConfig
from .prompt import get_system_prompt


def get_context_messages(
    memory: MemoryInterface,
    conversation_history: List[LLMMessage],
    user_message: str,
    config: AgentConfig,
    max_history_turns: int = 10,
) -> List[LLMMessage]:
    """
    构建包含记忆与对话历史的完整消息列表。
    """
    memory_context = memory.get_memory_context(
        query=user_message,
        max_tokens=config.memory_max_tokens,
    )
    system_prompt = get_system_prompt(config)
    if memory_context:
        system_prompt += f"\n\n相关记忆：\n{memory_context}"
    messages = [LLMMessage(role="system", content=system_prompt)]
    messages.extend(conversation_history[-max_history_turns:])
    messages.append(LLMMessage(role="user", content=user_message))
    return messages
