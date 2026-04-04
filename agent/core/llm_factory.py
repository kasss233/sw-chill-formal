"""
根据 settings.yaml 中 llm 段构造 LLM 实例：支持多后端顺序回退。
"""
from __future__ import annotations

import os
from typing import Any, Dict, List, Optional

from interfaces.llm import LLMInterface
from interfaces.llm_implementations.fallback_llm import FallbackLLM
from interfaces.llm_implementations.ollama_llm import OllamaLLM
from interfaces.llm_implementations.openai_compatible_llm import OpenAICompatibleLLM


def _resolve_api_key(entry: Dict[str, Any]) -> Optional[str]:
    env_name = entry.get("api_key_env")
    if env_name:
        v = os.environ.get(str(env_name).strip())
        if v:
            return v
    key = entry.get("api_key")
    if key is not None and str(key).strip() != "":
        return str(key).strip()
    return None


def _one_provider(entry: Dict[str, Any], index: int) -> LLMInterface:
    ptype = (entry.get("type") or "ollama").strip().lower()
    if ptype in ("openai_compatible", "openai", "openai_compat"):
        base_url = entry.get("base_url")
        model = entry.get("model")
        if not base_url or not model:
            raise ValueError(f"providers[{index}] openai_compatible 需要 base_url 与 model")
        return OpenAICompatibleLLM(
            base_url=str(base_url),
            model=str(model),
            api_key=_resolve_api_key(entry),
            chat_path=str(entry.get("chat_path") or "/chat/completions"),
            extra_headers=entry.get("extra_headers"),
            timeout_seconds=int(entry.get("timeout_seconds") or 300),
        )
    if ptype == "ollama":
        base_url = entry.get("base_url", "http://localhost:11434")
        model = entry.get("model", "qwen2:1.5b")
        return OllamaLLM(base_url=str(base_url), model=str(model))
    raise ValueError(f"providers[{index}] 未知 type: {ptype}")


def build_llm_from_settings(llm_section: Optional[Dict[str, Any]]) -> LLMInterface:
    """
    - 若存在 llm.providers（非空列表），按顺序构造 FallbackLLM。
    - 否则兼容旧版：llm.base_url + llm.model 视为单个 Ollama。
    """
    section = llm_section or {}
    raw_list = section.get("providers")
    if isinstance(raw_list, list) and len(raw_list) > 0:
        backends: List[LLMInterface] = []
        labels: List[str] = []
        for i, item in enumerate(raw_list):
            if not isinstance(item, dict):
                raise ValueError(f"llm.providers[{i}] 必须为对象")
            backends.append(_one_provider(item, i))
            name = item.get("name")
            labels.append(str(name) if name else f"{item.get('type', '?')}@{i}")
        return FallbackLLM(backends, labels=labels)

    base_url = section.get("base_url", "http://localhost:11434")
    model = section.get("model", "qwen2:1.5b")
    return OllamaLLM(base_url=str(base_url), model=str(model))
