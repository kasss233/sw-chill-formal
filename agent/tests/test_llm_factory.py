"""LLM 工厂与顺序回退（不发起真实网络请求）"""
import sys
from pathlib import Path

_root = Path(__file__).resolve().parent.parent
if str(_root) not in sys.path:
    sys.path.insert(0, str(_root))


def test_build_legacy_ollama():
    from core.llm_factory import build_llm_from_settings
    from interfaces.llm_implementations.ollama_llm import OllamaLLM

    llm = build_llm_from_settings({"base_url": "http://localhost:11434", "model": "m"})
    assert isinstance(llm, OllamaLLM)


def test_fallback_tries_second_on_first_failure():
    from interfaces.llm import LLMInterface, LLMMessage, LLMResponse
    from core.llm_factory import build_llm_from_settings

    class Bad(LLMInterface):
        def chat(self, messages, temperature=0.7, max_tokens=None, **kwargs):
            raise RuntimeError("down")

        def stream_chat(self, messages, temperature=0.7, max_tokens=None, **kwargs):
            raise RuntimeError("down")
            yield  # pragma: no cover

        def count_tokens(self, text: str) -> int:
            return 1

    class Good(LLMInterface):
        def chat(self, messages, temperature=0.7, max_tokens=None, **kwargs):
            return LLMResponse(content="ok")

        def stream_chat(self, messages, temperature=0.7, max_tokens=None, **kwargs):
            yield "x"

        def count_tokens(self, text: str) -> int:
            return 1

    from interfaces.llm_implementations.fallback_llm import FallbackLLM

    fb = FallbackLLM([Bad(), Good()], labels=["bad", "good"])
    r = fb.chat([LLMMessage(role="user", content="hi")])
    assert r.content == "ok"
    parts = list(fb.stream_chat([LLMMessage(role="user", content="hi")]))
    assert parts == ["x"]


def test_build_from_providers_openai_and_ollama_types():
    from core.llm_factory import build_llm_from_settings
    from interfaces.llm_implementations.fallback_llm import FallbackLLM
    from interfaces.llm_implementations.openai_compatible_llm import OpenAICompatibleLLM
    from interfaces.llm_implementations.ollama_llm import OllamaLLM

    llm = build_llm_from_settings(
        {
            "providers": [
                {"type": "openai_compatible", "base_url": "https://example.com", "model": "m"},
                {"type": "ollama", "base_url": "http://127.0.0.1:11434", "model": "q"},
            ]
        }
    )
    assert isinstance(llm, FallbackLLM)
    assert isinstance(llm._providers[0], OpenAICompatibleLLM)
    assert isinstance(llm._providers[1], OllamaLLM)
