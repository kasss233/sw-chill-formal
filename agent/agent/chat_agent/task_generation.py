"""任务生成层：从对话文本生成任务列表"""
import re
from typing import List

from interfaces.llm import LLMInterface, LLMMessage
from models.task import Task, TaskInfo, TaskOwner

from .config import AgentConfig


DEFAULT_TASK_PROMPT = """用户请求：{conversation_text}

请根据用户的请求，生成一个结构化的任务列表。任务应该是具体的、可执行的步骤。

要求：
1. 任务数量控制在3-8个之间
2. 每个任务应该是清晰、具体的行动项
3. 任务应该按照逻辑顺序排列
4. 用简洁的中文描述每个任务（每个任务描述不超过30字）

请按以下格式输出任务列表，每行一个任务：
1. 任务描述1
2. 任务描述2
3. 任务描述3
..."""

DEFAULT_TASK_SYSTEM_PROMPT = "你是一个任务规划助手，擅长将用户的目标转化为具体的任务列表。"


def generate_tasks_from_conversation(
    llm: LLMInterface,
    config: AgentConfig,
    conversation_text: str,
) -> List[Task]:
    """从对话文本调用 LLM 生成任务列表并解析为 Task 对象"""
    prompt_tpl = config.task_generation_prompt_template or DEFAULT_TASK_PROMPT
    system_prompt = config.task_generation_system_prompt or DEFAULT_TASK_SYSTEM_PROMPT
    user_prompt = prompt_tpl.format(conversation_text=conversation_text)
    messages = [
        LLMMessage(role="system", content=system_prompt),
        LLMMessage(role="user", content=user_prompt),
    ]
    response = llm.chat(messages=messages, temperature=0.7, max_tokens=500)
    tasks: List[Task] = []
    sort_order = 0
    for line in response.content.split("\n"):
        line = line.strip()
        if not line:
            continue
        match = re.match(r"^\d+[\.、]\s*(.+)$", line) or re.match(r"^[-•]\s*(.+)$", line)
        if match:
            desc = match.group(1).strip()
            if desc:
                tasks.append(Task(
                    id=None,
                    project_id="root",
                    info=TaskInfo(description=desc, owner=TaskOwner.GIRL),
                    sort_order=sort_order,
                ))
                sort_order += 1
    if not tasks:
        tasks.append(Task(
            id=None,
            project_id="root",
            info=TaskInfo(
                description=f"完成：{conversation_text[:50]}",
                owner=TaskOwner.GIRL,
            ),
            sort_order=0,
        ))
    return tasks
