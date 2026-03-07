"""系统提示词层：根据配置生成系统提示"""
from .config import AgentConfig


def get_system_prompt(config: AgentConfig) -> str:
    """根据配置返回系统提示词"""
    return config.system_prompt_template.format(
        character_name=config.character_name,
        character_personality=config.character_personality,
    )
