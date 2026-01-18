"""
任务相关数据模型
层级关系：项目 > 任务 > 子任务 > 信息
"""
from datetime import datetime
from enum import Enum
from typing import List, Optional

from pydantic import BaseModel, Field


class TaskOwner(str, Enum):
    """任务所属者"""
    USER = "user"  # 用户
    GIRL = "girl"  # 女孩（AI）


class RepeatPattern(BaseModel):
    """重复模式"""
    enabled: bool = False
    weekdays: List[int] = Field(default_factory=list, description="周几触发，0-6表示周一到周日")


class TaskInfo(BaseModel):
    """任务信息（基础描述和详情数据）"""
    description: str = Field(description="任务的基本信息描述")
    created_at: datetime = Field(default_factory=datetime.now, description="创建时间")
    last_modified_by: Optional[TaskOwner] = Field(None, description="最后修改者")
    owner: TaskOwner = Field(TaskOwner.USER, description="所属者")
    
    # 扩展字段
    completed_count: int = Field(0, description="完成次数（用于重复任务）")
    total_time_spent: int = Field(0, description="已用时间（秒）")
    focus_records: List[str] = Field(default_factory=list, description="工作记录（专注模式的时间段记录ID）")
    
    # 附加数据（可选）
    attachments: List[dict] = Field(default_factory=list, description="附加数据，如图片、URL、地理定位等")


class Task(BaseModel):
    """任务/子任务（子任务沿用任务结构）"""
    id: Optional[str] = Field(None, description="任务ID，用于唯一标识")
    project_id: str = Field(description="所属项目ID，未指定则为root")
    info: TaskInfo = Field(description="任务信息")
    
    # 层级关系
    parent_task_id: Optional[str] = Field(None, description="父任务ID，None表示顶级任务")
    subtasks: List["Task"] = Field(default_factory=list, description="子任务列表（递归结构）")
    
    # 状态和排序
    completed: bool = Field(False, description="是否已完成")
    sort_order: int = Field(0, description="排序顺序")
    
    # 重复设置
    repeat: RepeatPattern = Field(default_factory=RepeatPattern, description="重复模式")
    
    # 时间规划（扩展功能）
    deadline: Optional[datetime] = Field(None, description="截止日期")
    start_time: Optional[datetime] = Field(None, description="特定开始时间点")
    reminder_enabled: bool = Field(False, description="是否启用提醒")


class Project(BaseModel):
    """项目（任务容器）"""
    id: str = Field(description="项目ID，root为默认项目")
    name: str = Field(description="项目名称")
    color: str = Field(description="显示颜色（用于视觉区分）")
    owner: TaskOwner = Field(TaskOwner.USER, description="所属者")
    completed: bool = Field(False, description="是否已完成")
    sort_order: int = Field(0, description="排序顺序")


# 解决前向引用
Task.model_rebuild()

