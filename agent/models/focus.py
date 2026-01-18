"""
专注模块相关数据模型
"""
from datetime import datetime
from enum import Enum
from typing import Optional
from pydantic import BaseModel, Field


class FocusType(str, Enum):
    """专注类型"""
    TOMATO = "tomato"  # 番茄钟
    FREE = "free"  # 自由专注
    TASK_TRIGGERED = "task_triggered"  # 任务触发


class FocusRecord(BaseModel):
    """专注记录"""
    id: str = Field(description="记录ID")
    start_time: datetime = Field(description="开始时间")
    end_time: Optional[datetime] = Field(None, description="结束时间，None表示正在进行")
    duration: int = Field(0, description="时长（秒）")
    focus_type: FocusType = Field(description="专注类型")
    task_id: Optional[str] = Field(None, description="关联的任务ID（如果有）")
    
    @property
    def is_active(self) -> bool:
        """是否正在进行中"""
        return self.end_time is None

