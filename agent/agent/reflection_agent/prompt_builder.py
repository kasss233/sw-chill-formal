"""反思 Agent 提示词构建层：系统提示 + 用户提示"""
import json
from datetime import datetime
from typing import Dict, Any, List, Optional

from .config import ReflectionAgentConfig


def build_system_prompt(config: ReflectionAgentConfig) -> str:
    """构造系统提示词"""
    base = (
        f"你是一位名为「{config.character_name}」的 AI 陪伴角色，"
        f"性格：{config.character_personality}。\n"
        "你是一个独立的虚拟形象，有自己的视角和语气，"
        "在需要做『反思与总结』时被叫出来，"
        "根据系统提供的客观统计数据和上下文，"
        "从你的视角来帮助用户看清这段时间的状态，而不是代替用户说话或替用户写自述。\n\n"
        "重要要求：\n"
        "1. 必须使用简体中文。\n"
        "2. 你的总结必须严格依赖给定的统计数据，禁止自己胡乱编造数字；"
        "   如果某项数据缺失，可以用定性的方式轻描淡写带过，但不要瞎猜具体数值。\n"
        "3. 输出结构建议为三层：\n"
        "   - 数据概览：本阶段完成了什么、任务/习惯/专注的大致情况；\n"
        "   - 模式洞察：哪些时间段效率高、哪些场景容易拖延或消耗能量；\n"
        "   - 下阶段建议：围绕课表/任务安排、精力分配和情绪照顾给出 2-4 条具体可执行建议。\n"
        "4. 语气要自然、温暖，像一个了解用户日常的朋友，用第一人称「我」来称呼自己，"
        "   对用户多用第二人称「你」，适当表达理解和肯定；"
        "   不要替用户使用第一人称「我」来描述（例如不要写成\"我这周很累\"，"
        "   而是写成\"这周你在……我看得出来你有点累\"）。\n"
        f"5. 文风提示：{config.style_hint}\n"
    )
    bg = (config.character_background or "").strip()
    if bg:
        base += "\n【背景与经历】\n" + bg
    return base


def build_user_prompt(
    start_date: datetime,
    end_date: datetime,
    period: str,
    trigger: str,
    stats: Dict[str, Any],
    daily_summary: Dict[str, Any],
    extra_context: Optional[str],
    memory_context: str,
) -> str:
    """将统计与上下文整理成用户侧提示"""
    start_str = start_date.strftime("%Y-%m-%d")
    end_str = end_date.strftime("%Y-%m-%d")
    trigger_desc = {
        "daily": "这是一次【每日】结束时的复盘。",
        "weekly": "这是一次【每周】例行复盘。",
        "manual": "这是用户手动触发的一次阶段性复盘。",
    }.get(trigger, "这是一次阶段性复盘。")
    lines: List[str] = []
    lines.append(f"{trigger_desc}\n本次统计区间为：{start_str} ~ {end_str}，统计粒度为：{period}。")
    lines.append("\n【一、结构化统计数据（请作为事实依据）】")
    lines.append("下面是系统预先计算好的统计结果（JSON 结构），包含任务、习惯、番茄钟、能量和对话情绪等信息：")
    lines.append("\n<statistics_json>")
    lines.append(_safe_pretty_json(stats))
    lines.append("</statistics_json>")
    if daily_summary:
        lines.append("\n【二、区间末尾当天概览】（例如今天的完成情况与专注情况）：")
        lines.append("<daily_summary_json>")
        lines.append(_safe_pretty_json(daily_summary))
        lines.append("</daily_summary_json>")
    if memory_context:
        lines.append("\n【三、记忆系统给出的语境片段】（可用于理解用户近期状态，但不要当作精确统计）：")
        lines.append(memory_context)
    if extra_context:
        lines.append("\n【四、额外语境补充】（来自调用方，比如用户自己写的总结开头）：")
        lines.append(extra_context)
    lines.append("\n请你基于以上所有信息，按照系统提示中的要求，给出一份结构清晰、语气温柔的总结。")
    return "\n".join(lines)


def _safe_pretty_json(data: Dict[str, Any]) -> str:
    try:
        return json.dumps(data, ensure_ascii=False, indent=2)
    except Exception:
        return str(data)
