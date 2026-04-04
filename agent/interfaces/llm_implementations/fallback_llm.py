"""
按配置顺序依次尝试多个 LLM 后端；仅在当前后端失败（未产生有效结果）时切换。
流式场景：若已向前端 yield 过内容，则不再切换后端，直接抛出异常。
"""
from __future__ import annotations

import logging
from typing import Any, List, Optional

from interfaces.llm import LLMInterface, LLMMessage, LLMResponse

logger = logging.getLogger(__name__)


class FallbackLLM(LLMInterface):
    def __init__(self, providers: List[LLMInterface], labels: Optional[List[str]] = None) -> None:
        if not providers:
            raise ValueError("FallbackLLM 至少需要 1 个后端")
        self._providers = list(providers)
        self._labels = labels or [type(p).__name__ for p in self._providers]

    def chat(
        self,
        messages: List[LLMMessage],
        temperature: float = 0.7,
        max_tokens: Optional[int] = None,
        **kwargs: Any,
    ) -> LLMResponse:
        errors: List[str] = []
        for i, llm in enumerate(self._providers):
            label = self._labels[i] if i < len(self._labels) else str(i)
            try:
                return llm.chat(
                    messages,
                    temperature=temperature,
                    max_tokens=max_tokens,
                    **kwargs,
                )
            except Exception as e:
                msg = f"[{label}] {e}"
                errors.append(msg)
                logger.warning("LLM 后端失败，尝试下一个: %s", msg)

        raise RuntimeError("所有 LLM 后端均失败:\n" + "\n".join(errors))

    def stream_chat(
        self,
        messages: List[LLMMessage],
        temperature: float = 0.7,
        max_tokens: Optional[int] = None,
        **kwargs: Any,
    ):
        errors: List[str] = []
        for i, llm in enumerate(self._providers):
            label = self._labels[i] if i < len(self._labels) else str(i)
            yielded = False
            try:
                for chunk in llm.stream_chat(
                    messages,
                    temperature=temperature,
                    max_tokens=max_tokens,
                    **kwargs,
                ):
                    yielded = True
                    yield chunk
                return
            except Exception as e:
                if yielded:
                    raise
                msg = f"[{label}] {e}"
                errors.append(msg)
                logger.warning("LLM 流式后端失败，尝试下一个: %s", msg)

        raise RuntimeError("所有 LLM 后端均失败:\n" + "\n".join(errors))

    def count_tokens(self, text: str) -> int:
        return self._providers[0].count_tokens(text)
