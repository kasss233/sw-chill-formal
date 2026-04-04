"""Plan 策略层：决定在首轮 LLM 前是否强化记忆检索提示、建议预取工具等。"""
from __future__ import annotations

from abc import ABC, abstractmethod
from dataclasses import dataclass, field
from typing import List, Set


@dataclass
class PlanResult:
    """规划输出（轻量，供 Orchestrator 注入 system / 首轮上下文）。"""

    need_memory_refresh: bool = False
    suggested_prefetch_tools: List[str] = field(default_factory=list)
    planner_notes: str = ""


class Planner(ABC):
    @abstractmethod
    def plan(self, user_message: str, tool_names: Set[str]) -> PlanResult:
        ...


class NoOpPlanner(Planner):
    def plan(self, user_message: str, tool_names: Set[str]) -> PlanResult:
        return PlanResult()


class HeuristicPlanner(Planner):
    """基于关键词的极简规划，无需额外 LLM 调用。"""

    _MEM_HINTS = ("记得", "上次", "之前", "你还记得", "回想", "说过")
    _TASK_HINTS = ("任务", "待办", "清单", "todo")

    def plan(self, user_message: str, tool_names: Set[str]) -> PlanResult:
        text = user_message or ""
        need_mem = any(h in text for h in self._MEM_HINTS)
        prefetch: List[str] = []
        if any(h in text for h in self._TASK_HINTS) and "get_all_tasks" in tool_names:
            prefetch.append("get_all_tasks")
        notes: List[str] = []
        if need_mem:
            notes.append(
                "用户表述涉及过往记忆：请结合 system 中「相关记忆」段落作答；"
                "若记忆不足，可先通过 function_calls 调用只读工具获取当前 App 状态，必要时光友好询问用户。"
            )
        if prefetch:
            notes.append(
                "规划建议：与任务相关的请求可考虑先调用 get_all_tasks 获取列表再执行增删改。"
            )
        return PlanResult(
            need_memory_refresh=need_mem,
            suggested_prefetch_tools=prefetch,
            planner_notes="\n".join(notes),
        )


def get_planner(mode: str) -> Planner:
    m = (mode or "none").strip().lower()
    if m == "heuristic":
        return HeuristicPlanner()
    return NoOpPlanner()
