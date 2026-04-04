"""
从仓库内与 Godot 共用的 function_definitions.json 构建「工具目录」供系统提示词注入。
权威路径默认为 Godot 项目下的 scenes/main/autoload/ai_service/function_definitions.json。
"""
from __future__ import annotations

import json
from pathlib import Path
from typing import Any, Dict, List, Optional, Set


def repo_root_from_agent_package() -> Path:
    """agent/core/function_definitions.py → 仓库根目录（含 scenes/、agent/）。"""
    return Path(__file__).resolve().parent.parent.parent


def default_function_definitions_path() -> Path:
    return repo_root_from_agent_package() / "scenes/main/autoload/ai_service/function_definitions.json"


def resolve_definitions_path(config_path: Optional[str]) -> Path:
    if not config_path or not str(config_path).strip():
        return default_function_definitions_path()
    p = Path(config_path)
    if p.is_absolute():
        return p
    # 相对仓库根
    return (repo_root_from_agent_package() / p).resolve()


def load_function_definitions(path: Path) -> List[Dict[str, Any]]:
    if not path.exists():
        return []
    raw = path.read_text(encoding="utf-8")
    data = json.loads(raw)
    if not isinstance(data, list):
        return []
    out: List[Dict[str, Any]] = []
    for item in data:
        if isinstance(item, dict) and item.get("name"):
            out.append(item)
    return out


def function_names(definitions: List[Dict[str, Any]]) -> Set[str]:
    return {str(d.get("name", "")) for d in definitions if d.get("name")}


def format_tools_for_prompt(definitions: List[Dict[str, Any]]) -> str:
    """将函数定义列表格式化为适合 system prompt 的 Markdown。"""
    if not definitions:
        return "（当前未加载任何可调用的工具定义文件，请仅输出对话与空的 function_calls。）"
    lines: List[str] = ["## 你可使用的工具（function_calls 中的 name 必须与下列 name 完全一致）", ""]
    for d in definitions:
        name = d.get("name", "")
        desc = d.get("description", "")
        lines.append(f"- **{name}**：{desc}")
        params = d.get("parameters")
        if isinstance(params, dict) and params:
            lines.append(f"  - 参数 schema：`{json.dumps(params, ensure_ascii=False)}`")
        lines.append("")
    return "\n".join(lines).rstrip()
