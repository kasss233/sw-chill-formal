"""
记忆/RAG抽象接口
用于维护长期记忆，支持RAG技术
"""
from abc import ABC, abstractmethod
from typing import List, Dict, Any, Optional
from datetime import datetime
from pydantic import BaseModel


class MemoryEntry(BaseModel):
    """记忆条目"""
    id: str
    content: str
    metadata: Dict[str, Any] = {}
    created_at: datetime
    importance: float = 1.0  # 重要性权重，0.0-1.0


class MemoryInterface(ABC):
    """记忆系统抽象接口"""
    
    @abstractmethod
    def add_memory(
        self,
        content: str,
        metadata: Optional[Dict[str, Any]] = None,
        importance: float = 1.0
    ) -> str:
        """
        添加记忆
        
        Args:
            content: 记忆内容
            metadata: 元数据（如任务ID、对话ID等）
            importance: 重要性权重
            
        Returns:
            记忆条目ID
        """
        pass
    
    @abstractmethod
    def search_memories(
        self,
        query: str,
        top_k: int = 5,
        filters: Optional[Dict[str, Any]] = None
    ) -> List[MemoryEntry]:
        """
        检索相关记忆
        
        Args:
            query: 查询文本
            top_k: 返回前k个结果
            filters: 过滤条件（如时间范围、类型等）
            
        Returns:
            相关记忆列表，按相关性排序
        """
        pass
    
    @abstractmethod
    def update_memory(
        self,
        memory_id: str,
        content: Optional[str] = None,
        metadata: Optional[Dict[str, Any]] = None,
        importance: Optional[float] = None
    ) -> bool:
        """
        更新记忆
        
        Args:
            memory_id: 记忆条目ID
            content: 新内容（可选）
            metadata: 新元数据（可选）
            importance: 新重要性（可选）
            
        Returns:
            是否成功
        """
        pass
    
    @abstractmethod
    def delete_memory(self, memory_id: str) -> bool:
        """
        删除记忆
        
        Args:
            memory_id: 记忆条目ID
            
        Returns:
            是否成功
        """
        pass
    
    @abstractmethod
    def get_memory_context(
        self,
        query: str,
        max_tokens: int = 2000,
        filters: Optional[Dict[str, Any]] = None
    ) -> str:
        """
        获取记忆上下文（用于RAG）
        
        将检索到的相关记忆格式化为上下文字符串
        
        Args:
            query: 查询文本
            max_tokens: 最大token数
            filters: 过滤条件
            
        Returns:
            格式化的上下文字符串
        """
        pass

