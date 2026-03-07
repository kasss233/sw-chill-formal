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
