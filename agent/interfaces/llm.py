"""
LLM抽象接口
实现类：openai_llm.py, ollama_llm.py
"""
from abc import ABC, abstractmethod
from typing import List, Optional, Dict, Any
from pydantic import BaseModel, Field


class LLMMessage(BaseModel):
    """LLM消息"""
    role: str = Field(description="角色：system, user, assistant")
    content: str = Field(description="消息内容")


class LLMResponse(BaseModel):
    """LLM响应"""
    content: str = Field(description="生成的文本内容")
    metadata: Dict[str, Any] = Field(default_factory=dict, description="额外元数据")


class LLMInterface(ABC):
    """LLM抽象接口"""
    
    @abstractmethod
    def chat(
        self,
        messages: List[LLMMessage],
        temperature: float = 0.7,
        max_tokens: Optional[int] = None,
        **kwargs
    ) -> LLMResponse:
        """
        执行对话生成
        
        Args:
            messages: 消息列表
            temperature: 温度参数
            max_tokens: 最大生成token数
            **kwargs: 其他参数
            
        Returns:
            LLM响应
        """
        pass
    
    @abstractmethod
    def stream_chat(
        self,
        messages: List[LLMMessage],
        temperature: float = 0.7,
        max_tokens: Optional[int] = None,
        **kwargs
    ):
        """
        流式对话生成（生成器）
        
        Args:
            messages: 消息列表
            temperature: 温度参数
            max_tokens: 最大生成token数
            **kwargs: 其他参数
            
        Yields:
            str: 生成的文本片段
        """
        pass
    
    @abstractmethod
    def count_tokens(self, text: str) -> int:
        """
        计算文本的token数量
        
        Args:
            text: 输入文本
            
        Returns:
            token数量
        """
        pass

