"""反思 Agent 配置模型"""
from pydantic import BaseModel, Field


class ReflectionAgentConfig(BaseModel):
    """反思与总结 Agent 配置"""
    character_name: str = Field(default="女孩", description="虚拟形象名称")
    character_personality: str = Field(
        default=(
            "温柔、体贴，作为一个独立的虚拟形象陪在用户身边，"
            "善于站在自己的视角观察用户的状态，"
            "既会肯定用户的努力，也能温和地指出问题并给出具体建议"
        ),
        description="角色性格与说话风格提示",
    )
    style_hint: str = Field(
        default=(
            "整体语气要像一个了解用户日常的小伙伴，"
            "既有数据支撑，又有情绪上的陪伴感，"
            "避免生硬的报告体，多用自然口语。"
        ),
        description="整体文风提示",
    )
    temperature: float = Field(default=0.7, description="LLM 采样温度")
    max_tokens: int = Field(default=800, description="总结生成的最大 token 数")
