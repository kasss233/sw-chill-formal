"""
从外部配置文件加载配置
支持 YAML（推荐）或 JSON；配置目录默认为项目内 config/
"""
from __future__ import annotations

import json
import os
from pathlib import Path
from typing import Any, Dict, Optional

try:
    import yaml
    _HAS_YAML = True
except ImportError:
    _HAS_YAML = False


def _config_dir() -> Path:
    """默认配置目录：与 core 同级的 config"""
    return Path(__file__).resolve().parent.parent / "config"


def _load_file(path: Path) -> Optional[Dict[str, Any]]:
    if not path.exists():
        return None
    raw = path.read_text(encoding="utf-8")
    suffix = path.suffix.lower()
    if suffix in (".yaml", ".yml"):
        if _HAS_YAML:
            return yaml.safe_load(raw)
        raise RuntimeError("需要安装 PyYAML 才能加载 YAML 配置: pip install pyyaml")
    if suffix == ".json":
        return json.loads(raw)
    return None


def load_settings(config_dir: Optional[Path] = None) -> Dict[str, Any]:
    """
    加载全局设置（server、llm、logging）。
    查找顺序：settings.yaml -> settings.json
    """
    base = config_dir or _config_dir()
    for name in ("settings.yaml", "settings.yml", "settings.json"):
        data = _load_file(base / name)
        if data is not None:
            return data
    return {}


def load_chat_agent_config(config_dir: Optional[Path] = None) -> Dict[str, Any]:
    """加载主聊天 Agent 配置"""
    base = config_dir or _config_dir()
    for name in ("chat_agent.yaml", "chat_agent.yml", "chat_agent.json"):
        data = _load_file(base / name)
        if data is not None:
            return data
    return {}


def load_reflection_agent_config(config_dir: Optional[Path] = None) -> Dict[str, Any]:
    """加载反思 Agent 配置"""
    base = config_dir or _config_dir()
    for name in ("reflection_agent.yaml", "reflection_agent.yml", "reflection_agent.json"):
        data = _load_file(base / name)
        if data is not None:
            return data
    return {}


def build_agent_config_from_dict(
    data: Dict[str, Any],
    character_name_key: str = "character_name",
    character_personality_key: str = "character_personality",
    system_prompt_key: str = "system_prompt_template",
    temperature_key: str = "temperature",
    max_tokens_key: str = "max_tokens",
) -> Dict[str, Any]:
    """
    将扁平 dict 转为 AgentConfig 可用的字段。
    用于从 load_chat_agent_config 等得到的 dict 构造 Pydantic Config。
    """
    out: Dict[str, Any] = {}
    if character_name_key in data:
        out["character_name"] = data[character_name_key]
    if character_personality_key in data:
        out["character_personality"] = data[character_personality_key]
    if system_prompt_key in data:
        out["system_prompt_template"] = data[system_prompt_key]
    if temperature_key in data:
        out["temperature"] = float(data[temperature_key])
    if max_tokens_key in data:
        v = data[max_tokens_key]
        out["max_tokens"] = int(v) if v is not None else None
    return out
