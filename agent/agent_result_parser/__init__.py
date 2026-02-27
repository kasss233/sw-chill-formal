"""
Parser模块
用于将Agent输出转换为后端API所需的格式
"""
from .agent_response_parser import (
    AgentResponseParser,
    FunctionCallEvent,
    FunctionResultRequest
)

__all__ = [
    "AgentResponseParser",
    "FunctionCallEvent",
    "FunctionResultRequest"
]

