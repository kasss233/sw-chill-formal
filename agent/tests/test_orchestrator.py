"""Plan + 工具自回归 Orchestrator 测试（不调用真实 LLM）"""
import sys
from pathlib import Path

_root = Path(__file__).resolve().parent.parent
if str(_root) not in sys.path:
    sys.path.insert(0, str(_root))

from agent.chat_agent.config import AgentConfig
from agent.chat_agent.orchestrator import run_tool_loop
from agent.chat_agent.tool_executor import DictToolExecutor
from interfaces.llm import LLMInterface, LLMMessage, LLMResponse
from interfaces.memory import MemoryInterface
from interfaces.simple_server_api import SimpleServerAPI


def test_tool_loop_two_llm_rounds():
    """第一轮产出 get_all_tasks，执行后第二轮无工具，仅文本。"""

    AGENT_JSON = """<agent_json>
{"text":"好","function_calls":[{"id":"fc_001","name":"get_all_tasks","arguments":{}}],"environment":null,"action":null}
</agent_json>"""
    ROUND2 = """好的，看到你的任务列表了。
<agent_json>
{"text":"好的，看到你的任务列表了。","function_calls":[],"environment":null,"action":null}
</agent_json>"""

    class SeqLLM(LLMInterface):
        def __init__(self, seq):
            self._seq = list(seq)
            self._i = 0

        def chat(self, messages, temperature=0.7, max_tokens=None, **kwargs):
            s = self._seq[self._i]
            self._i += 1
            return LLMResponse(content=s)

        def stream_chat(self, messages, temperature=0.7, max_tokens=None, **kwargs):
            yield self.chat(messages, temperature, max_tokens).content

        def count_tokens(self, text):
            return len(text) // 2

    ex = DictToolExecutor()

    def _tasks(_args):
        return {"success": True, "data": {"items": [{"id": 1, "title": "测试"}]}}

    ex.register("get_all_tasks", _tasks)

    llm = SeqLLM([AGENT_JSON, ROUND2])
    base = [
        LLMMessage(role="system", content="你是助手，须输出 agent_json"),
        LLMMessage(role="user", content="我有哪些任务？"),
    ]
    last_raw, last_turn, raws = run_tool_loop(
        llm,
        initial_messages=base,
        allowed_function_names={"get_all_tasks"},
        strict_function_names=False,
        temperature=0.3,
        max_tokens=500,
        max_tool_rounds=3,
        tool_executor=ex,
    )
    assert len(raws) == 2
    assert not last_turn.function_calls
    assert "任务列表" in last_turn.text or "列表" in last_raw


def test_agent_chat_with_orchestrator():
    from agent.chat_agent.agent import Agent

    class SeqLLM(LLMInterface):
        def __init__(self, seq):
            self._seq = list(seq)
            self._i = 0

        def chat(self, messages, temperature=0.7, max_tokens=None, **kwargs):
            s = self._seq[self._i]
            self._i += 1
            return LLMResponse(content=s)

        def stream_chat(self, messages, temperature=0.7, max_tokens=None, **kwargs):
            yield self.chat(messages, temperature, max_tokens).content

        def count_tokens(self, text):
            return len(text) // 2

    class EmptyMem(MemoryInterface):
        def get_memory_context(self, *a, **k):
            return ""

        def add_memory(self, *a, **k):
            return ""

        def search_memories(self, *a, **k):
            return []

        def update_memory(self, *a, **k):
            return True

        def delete_memory(self, *a, **k):
            return True

    R1 = """查任务
<agent_json>
{"text":"查任务","function_calls":[{"name":"get_all_tasks","arguments":{}}],"environment":null,"action":null}
</agent_json>"""
    R2 = """没有未完成项。
<agent_json>
{"text":"没有未完成项。","function_calls":[],"environment":null,"action":null}
</agent_json>"""

    cfg = AgentConfig(max_tool_rounds=2, planner_mode="none")
    ag = Agent(llm=SeqLLM([R1, R2]), memory=EmptyMem(), server_api=SimpleServerAPI(), config=cfg)
    resp = ag.chat("我的任务？")
    assert not resp.function_calls
    assert resp.text


def run_all():
    g = globals()
    for name in sorted(g):
        if name.startswith("test_") and callable(g[name]):
            g[name]()
            print(f"  OK: {name}")


if __name__ == "__main__":
    run_all()
    print("test_orchestrator 全部通过")
