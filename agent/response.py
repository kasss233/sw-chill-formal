"""
响应结构定义
将响应拆解为更细粒度的操作类型
"""
from typing import Any, Dict, List, Literal, Optional

from pydantic import Field, BaseModel

from models.performance import PerformanceSequence
from models.task import Task, Project


# ====== 基础响应 ======
class Response(BaseModel):
    """Agent响应基类"""
    text: str = Field(description="文本回答")
    performance_sequence: Optional[PerformanceSequence] = Field(None, description="演出脚本序列")


# ====== 操作类型定义 ======

# 任务相关操作
class TaskCreateOperation(BaseModel):
    """创建任务操作"""
    action: Literal["create_task"] = "create_task"
    task: Task = Field(description="要创建的任务对象")


class TaskUpdateOperation(BaseModel):
    """更新任务操作"""
    action: Literal["update_task"] = "update_task"
    task_id: str = Field(description="任务ID")
    task: Task = Field(description="更新后的任务对象")


class TaskDeleteOperation(BaseModel):
    """删除任务操作"""
    action: Literal["delete_task"] = "delete_task"
    task_id: str = Field(description="要删除的任务ID")


class TaskCompleteOperation(BaseModel):
    """完成任务操作"""
    action: Literal["complete_task"] = "complete_task"
    task_id: str = Field(description="要完成的任务ID")


# 项目相关操作
class ProjectCreateOperation(BaseModel):
    """创建项目操作"""
    action: Literal["create_project"] = "create_project"
    project: Project = Field(description="要创建的项目对象")


class ProjectUpdateOperation(BaseModel):
    """更新项目操作"""
    action: Literal["update_project"] = "update_project"
    project_id: str = Field(description="项目ID")
    project: Project = Field(description="更新后的项目对象")


class ProjectDeleteOperation(BaseModel):
    """删除项目操作"""
    action: Literal["delete_project"] = "delete_project"
    project_id: str = Field(description="要删除的项目ID")


# 场景控制相关操作
class SceneComponentOperation(BaseModel):
    """场景组件操作"""
    action: Literal["update_scene_components"] = "update_scene_components"
    components: Dict[str, Any] = Field(description="组件配置字典，key为组件名，value为配置")


class BGMOperation(BaseModel):
    """背景音乐操作"""
    action: Literal["update_bgm"] = "update_bgm"
    operation_type: Literal["volume", "switch", "toggle"] = Field(
        description="操作类型：volume(调整音量), switch(切换歌曲), toggle(切换播放状态)"
    )
    volume: Optional[float] = Field(None, description="音量（0.0-1.0），当operation_type为volume时使用")
    track_id: Optional[str] = Field(None, description="歌曲ID，当operation_type为switch时使用")
    play: Optional[bool] = Field(None, description="播放状态，当operation_type为toggle时使用")


class AmbientNoiseOperation(BaseModel):
    """环境白噪音操作"""
    action: Literal["update_ambient_noise"] = "update_ambient_noise"
    enabled: bool = Field(description="是否启用")
    volume: float = Field(0.5, description="音量（0.0-1.0）")


# 专注相关操作
class FocusStartOperation(BaseModel):
    """开始专注操作"""
    action: Literal["start_focus"] = "start_focus"
    focus_type: Literal["tomato", "free", "task_triggered"] = Field(description="专注类型")
    task_id: Optional[str] = Field(None, description="关联的任务ID（如果有）")


class FocusEndOperation(BaseModel):
    """结束专注操作"""
    action: Literal["end_focus"] = "end_focus"
    focus_record_id: str = Field(description="专注记录ID")


# 联合类型：所有操作类型
Operation = (
    TaskCreateOperation |
    TaskUpdateOperation |
    TaskDeleteOperation |
    TaskCompleteOperation |
    ProjectCreateOperation |
    ProjectUpdateOperation |
    ProjectDeleteOperation |
    SceneComponentOperation |
    BGMOperation |
    AmbientNoiseOperation |
    FocusStartOperation |
    FocusEndOperation
)


class AgentResponse(Response):
    """Agent完整响应（包含文本、演出、原生 function_calls 与可选 environment/action）"""

    operations: List[Operation] = Field(
        default_factory=list,
        description="旧版结构化操作（已弃用主路径，仅兼容反序列化/测试）",
    )
    function_calls: List[Dict[str, Any]] = Field(
        default_factory=list,
        description="与后端/Godot 一致的函数调用列表：id, name, arguments",
    )
    environment: Optional[Dict[str, Any]] = Field(
        default=None,
        description="环境/场景设置载荷（SSE environment 事件）",
    )
    action: Optional[Dict[str, Any]] = Field(
        default=None,
        description="演出动作载荷（SSE action 事件）",
    )
