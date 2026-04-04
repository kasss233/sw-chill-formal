"""客户端工具执行抽象：与 Godot AgentExecutor 返回结构对齐的同步桩 / 自定义实现。"""
from __future__ import annotations

from typing import Any, Callable, Dict, Optional

# call_id, name, arguments -> result dict（建议含 success / data / error）
ToolExecutorCallable = Callable[[str, str, Dict[str, Any]], Dict[str, Any]]


class DictToolExecutor:
    """按函数名注册 Callable[args_dict] -> result_dict；未注册则返回占位成功，便于联调。"""

    def __init__(self, handlers: Optional[Dict[str, Callable[[Dict[str, Any]], Dict[str, Any]]]] = None):
        self._handlers: Dict[str, Callable[[Dict[str, Any]], Dict[str, Any]]] = dict(handlers or {})

    def register(self, name: str, fn: Callable[[Dict[str, Any]], Dict[str, Any]]) -> None:
        self._handlers[name] = fn

    def __call__(self, call_id: str, name: str, args: Dict[str, Any]) -> Dict[str, Any]:
        fn = self._handlers.get(name)
        if fn is None:
            return {
                "success": True,
                "data": {"_mock": True, "function_call_id": call_id, "name": name, "arguments": args},
                "message": "未注册的工具处理器（Mock 成功，后端/Godot 应实现真实 _fn_<name>）",
            }
        try:
            return fn(args)
        except Exception as e:
            return {"success": False, "error": str(e)}


def default_mock_tool_executor() -> DictToolExecutor:
    """演示用：常见只读工具返回空列表/占位。"""
    ex = DictToolExecutor()

    def _tasks(_: Dict[str, Any]) -> Dict[str, Any]:
        return {"success": True, "data": {"items": [], "total": 0}}

    def _notes(_: Dict[str, Any]) -> Dict[str, Any]:
        return {"success": True, "data": {"items": []}}

    for n in (
        "get_all_tasks",
        "get_incomplete_tasks",
        "get_completed_tasks",
        "get_overdue_tasks",
    ):
        ex.register(n, _tasks)
    for n in ("get_all_notes", "search_notes"):
        ex.register(n, _notes)
    return ex
