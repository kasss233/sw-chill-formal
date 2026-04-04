"""主聊天 Agent 测试：prompt、context、task_intent、task_generation、agent 各层与 pipeline"""
import sys
from pathlib import Path

# 项目根加入 path
_root = Path(__file__).resolve().parent.parent
if str(_root) not in sys.path:
    sys.path.insert(0, str(_root))


def test_prompt_layer():
    """测试 prompt 层：get_system_prompt 返回非空且包含占位替换"""
    from agent.chat_agent.config import AgentConfig
    from agent.chat_agent.prompt import get_system_prompt
    config = AgentConfig(character_name="测试", character_personality="温和")
    out = get_system_prompt(config)
    assert "测试" in out
    assert "温和" in out
    assert "女孩" not in out


def test_task_intent_layer():
    """测试任务意图检测层"""
    from agent.chat_agent.task_intent import detect_task_creation_intent
    assert detect_task_creation_intent("帮我列一个学习计划") is True
    assert detect_task_creation_intent("今天天气怎么样") is False
    assert detect_task_creation_intent("有任务清单吗") is True


def test_context_layer():
    """测试 context 层：无记忆时返回 system + 当前用户消息"""
    from interfaces.memory import MemoryInterface
    from agent.chat_agent.config import AgentConfig
    from agent.chat_agent.context import get_context_messages

    class EmptyMemory(MemoryInterface):
        def get_memory_context(self, query, max_tokens=2000, filters=None):
            return ""
        def add_memory(self, content, metadata=None, importance=1.0):
            return ""
        def search_memories(self, query, top_k=5, filters=None):
            return []
        def update_memory(self, memory_id, content=None, metadata=None, importance=None):
            return True
        def delete_memory(self, memory_id):
            return True

    config = AgentConfig()
    messages = get_context_messages(EmptyMemory(), [], "你好", config)
    assert len(messages) >= 2
    assert messages[0].role == "system"
    assert messages[-1].role == "user" and messages[-1].content == "你好"


def test_chat_agent_import_and_config():
    """测试 Agent/AgentConfig 可导入且配置生效"""
    from agent import Agent, AgentConfig
    config = AgentConfig(character_name="小助手", temperature=0.5)
    assert config.character_name == "小助手"
    assert config.temperature == 0.5


def test_llm_output_parser():
    """结构化围栏与 function_calls 解析"""
    from agent.chat_agent.llm_output_parser import AGENT_JSON_BEGIN, AGENT_JSON_END, parse_full
    allowed = {"add_task"}
    raw = (
        "你好\n"
        f"{AGENT_JSON_BEGIN}\n"
        '{"text":"你好","function_calls":[{"id":"fc_001","name":"add_task","arguments":{"title":"x","deadline":""}}],'
        '"environment":{"time_mode":0},"action":{"pose":"greet"}}\n'
        f"{AGENT_JSON_END}"
    )
    turn = parse_full(raw, allowed_function_names=allowed, strict_function_names=True)
    assert turn.text == "你好"
    assert len(turn.function_calls) == 1
    assert turn.function_calls[0]["name"] == "add_task"
    assert turn.environment and turn.environment.get("time_mode") == 0
    assert turn.action and turn.action.get("pose") == "greet"


def test_chat_stream_events():
    """测试 chat_stream 产出的事件类型与顺序（mock LLM，不依赖 Ollama）"""
    from agent.chat_agent.agent import Agent
    from agent.chat_agent.config import AgentConfig
    from interfaces.llm import LLMInterface, LLMMessage, LLMResponse
    from interfaces.memory import MemoryInterface
    from interfaces.simple_server_api import SimpleServerAPI

    class MockLLMStream(LLMInterface):
        def chat(self, messages, temperature=0.7, max_tokens=None, **kwargs):
            return LLMResponse(content="流式回复内容")
        def stream_chat(self, messages, temperature=0.7, max_tokens=None, **kwargs):
            for c in "流式":
                yield c
            yield "回复"
            yield "内容"
        def count_tokens(self, text):
            return len(text) // 2

    class EmptyMemory(MemoryInterface):
        def get_memory_context(self, *a, **k): return ""
        def add_memory(self, *a, **k): return ""
        def search_memories(self, *a, **k): return []
        def update_memory(self, *a, **k): return True
        def delete_memory(self, *a, **k): return True

    agent = Agent(llm=MockLLMStream(), memory=EmptyMemory(), server_api=SimpleServerAPI(), config=AgentConfig())
    events = list(agent.chat_stream("你好"))
    types = [e[0] for e in events]
    assert "text_delta" in types
    assert "text_done" in types
    assert "done" in types
    assert types[-1] == "done"
    full_content = next((e.get("content") for t, e in events if t == "text_done"), "")
    assert "流式" in full_content and "回复" in full_content and "内容" in full_content


def run_all():
    """运行本模块所有 test_ 函数"""
    g = globals()
    for name in sorted(g):
        if name.startswith("test_") and callable(g[name]):
            g[name]()
            print(f"  OK: {name}")


if __name__ == "__main__":
    run_all()
    print("test_chat_agent 全部通过")
