"""
反思与总结 Agent

职责：根据一段时间内的统计数据，生成有洞察力的总结与建议。
不直接参与日常对话，只在「每日/每周/手动触发总结」时被调用。
"""
from datetime import datetime
from typing import Optional, Dict, Any, List

from pydantic import BaseModel, Field

from interfaces.llm import LLMInterface, LLMMessage
from interfaces.memory import MemoryInterface
from interfaces.server_api import ServerAPI
from response import AgentResponse


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


class ReflectionAgent:
    """反思与总结专用 Agent。依赖 ServerAPI 统计数据，不自行猜数字。"""

    def __init__(
        self,
        llm: LLMInterface,
        server_api: ServerAPI,
        memory: Optional[MemoryInterface] = None,
        config: Optional[ReflectionAgentConfig] = None,
    ):
        self.llm = llm
        self.server_api = server_api
        self.memory = memory
        self.config = config or ReflectionAgentConfig()

    def generate_period_summary(
        self,
        start_date: datetime,
        end_date: datetime,
        period: str = "week",
        trigger: str = "manual",
        precomputed_stats: Optional[Dict[str, Any]] = None,
        extra_context: Optional[str] = None,
    ) -> AgentResponse:
        stats = precomputed_stats
        if stats is None:
            stats = self.server_api.get_statistics(
                start_date=start_date,
                end_date=end_date,
                period=period,
            )
        try:
            daily_summary = self.server_api.get_daily_summary(end_date)
        except NotImplementedError:
            daily_summary = {}
        memory_context = ""
        if self.memory is not None:
            try:
                memory_context = self.memory.get_memory_context(
                    query="阶段性复盘与总结",
                    max_tokens=800,
                    filters=None,
                )
            except NotImplementedError:
                memory_context = ""
        system_prompt = self._build_system_prompt()
        user_prompt = self._build_user_prompt(
            start_date=start_date,
            end_date=end_date,
            period=period,
            trigger=trigger,
            stats=stats,
            daily_summary=daily_summary,
            extra_context=extra_context,
            memory_context=memory_context,
        )
        messages: List[LLMMessage] = [
            LLMMessage(role="system", content=system_prompt),
            LLMMessage(role="user", content=user_prompt),
        ]
        llm_response = self.llm.chat(
            messages=messages,
            temperature=self.config.temperature,
            max_tokens=self.config.max_tokens,
        )
        return AgentResponse(
            text=llm_response.content,
            performance_sequence=None,
            operations=[],
        )

    def _build_system_prompt(self) -> str:
        return (
            f"你是一位名为「{self.config.character_name}」的 AI 陪伴角色，"
            f"性格：{self.config.character_personality}。\n"
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
            f"5. 文风提示：{self.config.style_hint}\n"
        )

    def _build_user_prompt(
        self,
        start_date: datetime,
        end_date: datetime,
        period: str,
        trigger: str,
        stats: Dict[str, Any],
        daily_summary: Dict[str, Any],
        extra_context: Optional[str],
        memory_context: str,
    ) -> str:
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
        lines.append(self._safe_pretty_json(stats))
        lines.append("</statistics_json>")
        if daily_summary:
            lines.append("\n【二、区间末尾当天概览】（例如今天的完成情况与专注情况）：")
            lines.append("<daily_summary_json>")
            lines.append(self._safe_pretty_json(daily_summary))
            lines.append("</daily_summary_json>")
        if memory_context:
            lines.append("\n【三、记忆系统给出的语境片段】（可用于理解用户近期状态，但不要当作精确统计）：")
            lines.append(memory_context)
        if extra_context:
            lines.append("\n【四、额外语境补充】（来自调用方，比如用户自己写的总结开头）：")
            lines.append(extra_context)
        lines.append("\n请你基于以上所有信息，按照系统提示中的要求，给出一份结构清晰、语气温柔的总结。")
        return "\n".join(lines)

    @staticmethod
    def _safe_pretty_json(data: Dict[str, Any]) -> str:
        try:
            import json
            return json.dumps(data, ensure_ascii=False, indent=2)
        except Exception:
            return str(data)
