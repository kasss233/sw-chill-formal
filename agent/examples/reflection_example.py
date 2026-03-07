"""
ReflectionAgent 使用示例

作用：
- 展示如何初始化「反思与总结」Agent，并生成一段时间的阶段性总结。

运行方式（在仓库根目录）：
    python -m agent.examples.reflection_example

注意：
- 示例默认使用 Ollama 本地模型（qwen2:1.5b），你也可以自行替换为自己的 LLM 实现；
- 如果本机没有启动 Ollama 服务，脚本会给出友好提示并退出。
"""

from datetime import datetime, timedelta

from agent.reflection_agent import ReflectionAgent, ReflectionAgentConfig
from interfaces.llm_implementations.ollama_llm import OllamaLLM
from interfaces.memory import MemoryInterface
from interfaces.simple_server_api import SimpleServerAPI


class DummyMemory(MemoryInterface):
    """最简记忆实现，用于示例与测试。"""

    def add_memory(self, content: str, metadata=None, importance: float = 1.0) -> str:
        return "dummy_memory_id"

    def search_memories(self, query: str, top_k: int = 5, filters=None):
        return []

    def update_memory(self, memory_id: str, content=None, metadata=None, importance=None) -> bool:
        return True

    def delete_memory(self, memory_id: str) -> bool:
        return True

    def get_memory_context(self, query: str, max_tokens: int = 2000, filters=None) -> str:
        # 示例中不提供真实记忆，只返回空字符串
        return ""


def main() -> None:
    print("=" * 60)
    print("反思与总结 Agent 测试 - 使用 Ollama (qwen2:1.5b)")
    print("=" * 60)

    # 1. 初始化 LLM
    print("\n[1/4] 初始化 LLM (Ollama)...")
    try:
        llm = OllamaLLM(
            base_url="http://localhost:11434",
            model="qwen2:1.5b",
        )
        print("  ✓ LLM 已初始化，模型：qwen2:1.5b")
    except Exception as e:
        print(f"  ✗ LLM 初始化失败：{e}")
        print("  提示：请确认 Ollama 服务已启动，并且已拉取模型，例如：")
        print("        ollama pull qwen2:1.5b")
        return

    # 2. 初始化 ServerAPI 与 Memory
    print("\n[2/4] 初始化 SimpleServerAPI 与 DummyMemory...")
    server_api = SimpleServerAPI()
    memory = DummyMemory()
    print("  ✓ SimpleServerAPI 与 DummyMemory 已就绪（使用内置示例数据）")

    # 3. 创建 ReflectionAgent
    print("\n[3/4] 创建 ReflectionAgent 实例...")
    config = ReflectionAgentConfig(
        character_name="女孩",
        character_personality="温柔、体贴，会认真看数据，但说话方式像跟朋友聊天",
        temperature=0.7,
        max_tokens=800,
    )

    agent = ReflectionAgent(
        llm=llm,
        server_api=server_api,
        memory=memory,
        config=config,
    )
    print("  ✓ ReflectionAgent 已创建")

    # 4. 生成一段时间的总结
    print("\n[4/4] 生成本周总结示例...")
    print("-" * 60)

    end_date = datetime.now()
    start_date = end_date - timedelta(days=6)

    extra_context = (
        "用户备注：这周的整体感觉是事情有点多，"
        "有几天状态不太好，但也完成了一些重要任务。"
    )

    try:
        response = agent.generate_period_summary(
            start_date=start_date,
            end_date=end_date,
            period="week",
            trigger="weekly",
            precomputed_stats=None,  # 不传则由 SimpleServerAPI 提供示例统计
            extra_context=extra_context,
        )

        print("生成的总结文本：\n")
        print(response.text)
        print("\n" + "-" * 60)
        print(f"文本长度：{len(response.text)} 字符")
    except Exception as e:
        print(f"  ✗ 生成总结失败：{e}")
        import traceback

        traceback.print_exc()

    print("\n" + "=" * 60)
    print("测试结束")
    print("=" * 60)


if __name__ == "__main__":
    main()

