"""
演出脚本相关数据模型
"""
from typing import List, Optional, Literal
from pydantic import BaseModel, Field


class PerformanceAction(BaseModel):
    """演出动作基类"""
    type: str = Field(description="动作类型")


class AnimationAction(PerformanceAction):
    """人物动作"""
    type: Literal["animation"] = "animation"
    animation_name: str = Field(description="动画名称")
    duration: Optional[float] = Field(None, description="持续时间（秒）")


class AudioAction(PerformanceAction):
    """音频动作"""
    type: Literal["audio"] = "audio"
    audio_name: str = Field(description="音频名称")
    volume: float = Field(1.0, description="音量，0.0-1.0")


class DialogOption(BaseModel):
    """对话框选项"""
    text: str = Field(description="选项文本")
    value: str = Field(description="选项值")


class DialogAction(PerformanceAction):
    """对话框动作"""
    type: Literal["dialog"] = "dialog"
    text: str = Field(description="对话框文本")
    options: List[DialogOption] = Field(default_factory=list, description="可选择选项，空列表表示无选项")


class PerformanceScript(BaseModel):
    """演出脚本（单个动作的集合）"""
    actions: List[PerformanceAction] = Field(
        description="动作列表，包含人物的动作、音频、对话框中的一项或多项"
    )


class PerformanceSequence(BaseModel):
    """演出脚本序列"""
    scripts: List[PerformanceScript] = Field(description="演出脚本序列")
    
    @classmethod
    def from_text(cls, text: str) -> "PerformanceSequence":
        """
        从结构化文本解析演出脚本序列
        具体解析逻辑由实际实现决定
        """
        # TODO: 实现解析逻辑
        raise NotImplementedError("需要实现具体的解析逻辑")


