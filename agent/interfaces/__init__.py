"""
抽象接口模块
"""
from .llm import LLMInterface, LLMMessage, LLMResponse
from .memory import MemoryInterface
from .server_api import ServerAPI

__all__ = [
    "LLMInterface",
    "LLMMessage", 
    "LLMResponse",
    "MemoryInterface",
    "ServerAPI",
]

