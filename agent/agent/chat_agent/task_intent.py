"""任务意图检测层：判断用户是否有创建任务意图"""
from typing import List, Optional

# 可配置：从 config 或常量读取
DEFAULT_TASK_KEYWORDS = [
    "列表", "任务", "计划", "学习计划", "待办", "清单", "帮我列", "安排",
]


def detect_task_creation_intent(
    user_message: str,
    keywords: Optional[List[str]] = None,
) -> bool:
    """检测用户消息是否包含创建任务的意图"""
    kws = keywords or DEFAULT_TASK_KEYWORDS
    return any(kw in user_message for kw in kws)
