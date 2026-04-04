"""主聊天 Agent 配置模型"""
from typing import Optional

from pydantic import BaseModel


class AgentConfig(BaseModel):
    """Agent 配置（可从 config/chat_agent.yaml 加载）"""
    character_name: str = "女孩"
    character_personality: str = "温柔、体贴，以鼓励和支持为主"
    system_prompt_template: str = """你是一位名为{character_name}的AI陪伴角色。
性格特点：{character_personality}
你需要陪伴用户，提供情感支持和生产力协助。
在与用户对话时，要符合你的角色设定，并考虑上下文中的记忆信息。

你的能力：
你可以帮助用户管理任务和项目。当用户请求创建任务列表、添加任务、安排学习计划等时，
你应该积极地提供建议并准备创建相应的任务（具体任务创建由系统完成，你只需要提供友好的回复）。

重要要求：
1. 你必须使用中文与用户对话
2. 回复要符合你的角色设定，语气要{character_personality}
3. 回复要简洁、温暖、自然，就像朋友间的对话
4. 当用户需要操作 App 内能力时，在 agent_json 的 function_calls 中填写对应工具，不要仅停留在文字描述"""

    temperature: float = 0.7
    max_tokens: Optional[int] = None
    memory_top_k: int = 5
    memory_max_tokens: int = 2000
    task_generation_prompt_template: Optional[str] = None
    task_generation_system_prompt: Optional[str] = None
    ## 与 Godot 共用的函数定义 JSON；空字符串表示使用默认路径（scenes/main/autoload/ai_service/function_definitions.json）
    function_definitions_path: str = ""
    ## 为 True 时保留旧版「意图检测 + 二次 LLM 生成 TaskCreateOperation」路径（默认关闭，由模型在 agent_json 中输出 function_calls）
    legacy_task_pipeline: bool = False
    ## 为 True 时丢弃不在 function_definitions.json 中出现的 function name（并写入解析警告日志）
    strict_function_names: bool = False
    ## 工具自回归最大轮数（每轮：LLM → function_calls → 执行 → 再 LLM）。0 表示关闭，单轮行为与旧版一致。
    max_tool_rounds: int = 0
    ## none | heuristic：首轮前是否注入轻量规划提示（不额外调用 LLM）
    planner_mode: str = "none"
