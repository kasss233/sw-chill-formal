"""
OpenAI 兼容 Chat Completions HTTP 调用（DeepSeek、OpenAI、多数网关）
POST {base_url}{chat_path}，请求体含 model、messages、stream 等。
"""
from __future__ import annotations

import json
from typing import Any, Dict, Iterator, List, Optional

import requests

from interfaces.llm import LLMInterface, LLMMessage, LLMResponse


def _messages_to_openai(messages: List[LLMMessage]) -> List[Dict[str, str]]:
    return [{"role": m.role, "content": m.content} for m in messages]


class OpenAICompatibleLLM(LLMInterface):
    """单后端：OpenAI 协议 /v1/chat/completions 或根路径 /chat/completions。"""

    def __init__(
        self,
        base_url: str,
        model: str,
        api_key: Optional[str] = None,
        chat_path: str = "/chat/completions",
        extra_headers: Optional[Dict[str, str]] = None,
        timeout_seconds: int = 300,
        **kwargs: Any,
    ) -> None:
        base = base_url.rstrip("/")
        path = chat_path if chat_path.startswith("/") else f"/{chat_path}"
        self._url = f"{base}{path}"
        self.model = model
        self._api_key = api_key
        self._extra_headers = dict(extra_headers or {})
        self._timeout = timeout_seconds

    def _headers(self) -> Dict[str, str]:
        h = {
            "Content-Type": "application/json",
            **self._extra_headers,
        }
        if self._api_key:
            h["Authorization"] = f"Bearer {self._api_key}"
        return h

    def chat(
        self,
        messages: List[LLMMessage],
        temperature: float = 0.7,
        max_tokens: Optional[int] = None,
        **kwargs: Any,
    ) -> LLMResponse:
        payload: Dict[str, Any] = {
            "model": self.model,
            "messages": _messages_to_openai(messages),
            "temperature": temperature,
            "stream": False,
        }
        if max_tokens is not None:
            payload["max_tokens"] = max_tokens

        try:
            r = requests.post(
                self._url,
                headers=self._headers(),
                json=payload,
                timeout=self._timeout,
            )
            r.raise_for_status()
            data = r.json()
        except requests.exceptions.Timeout as e:
            raise RuntimeError(f"OpenAI 兼容 API 超时: {e}") from e
        except requests.exceptions.RequestException as e:
            raise RuntimeError(f"OpenAI 兼容 API 请求失败: {e}") from e
        except json.JSONDecodeError as e:
            raise RuntimeError(f"OpenAI 兼容 API 返回非 JSON: {e}") from e

        content = ""
        choices = data.get("choices") or []
        if choices:
            msg = choices[0].get("message") or {}
            content = msg.get("content") or ""

        return LLMResponse(
            content=content,
            metadata={
                "model": data.get("model", self.model),
                "usage": data.get("usage"),
                "id": data.get("id"),
            },
        )

    def stream_chat(
        self,
        messages: List[LLMMessage],
        temperature: float = 0.7,
        max_tokens: Optional[int] = None,
        **kwargs: Any,
    ) -> Iterator[str]:
        payload: Dict[str, Any] = {
            "model": self.model,
            "messages": _messages_to_openai(messages),
            "temperature": temperature,
            "stream": True,
        }
        if max_tokens is not None:
            payload["max_tokens"] = max_tokens

        # 流式：timeout=(connect, read) — read 为相邻两次从 socket 读到数据的最大间隔
        try:
            r = requests.post(
                self._url,
                headers=self._headers(),
                json=payload,
                stream=True,
                timeout=(10, self._timeout),
            )
            r.raise_for_status()
        except requests.exceptions.RequestException as e:
            raise RuntimeError(f"OpenAI 兼容 API 流式请求失败: {e}") from e

        for raw_line in r.iter_lines(decode_unicode=True):
            if not raw_line:
                continue
            line = raw_line.strip()
            if not line.startswith("data:"):
                continue
            data_str = line[5:].strip()
            if data_str == "[DONE]":
                break
            try:
                obj = json.loads(data_str)
            except json.JSONDecodeError:
                continue
            for choice in obj.get("choices") or []:
                delta = choice.get("delta") or {}
                piece = delta.get("content")
                if piece:
                    yield piece

    def count_tokens(self, text: str) -> int:
        chinese_chars = sum(1 for c in text if "\u4e00" <= c <= "\u9fff")
        other_chars = len(text) - chinese_chars
        estimated = int(chinese_chars * 1.5 + other_chars / 4)
        return max(estimated, len(text) // 4)
