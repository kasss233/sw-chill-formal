"""
Agent使用示例
展示如何初始化和使用Agent（使用Ollama）
"""
from typing import Optional

# 导入Agent
from agent import Agent, AgentConfig
# 导入Ollama LLM实现
from interfaces.llm_implementations.ollama_llm import OllamaLLM
# 导入接口抽象
from interfaces.memory import MemoryInterface
from interfaces.server_api import ServerAPI
# 导入模型
from models.task import Task, Project


class ExampleMemory(MemoryInterface):
    """示例记忆实现（仅用于演示）"""
    def add_memory(self, content: str, metadata=None, importance=1.0) -> str:
        return "memory_id_1"
    
    def search_memories(self, query: str, top_k=5, filters=None):
        return []
    
    def update_memory(self, memory_id: str, content=None, metadata=None, importance=None) -> bool:
        return True
    
    def delete_memory(self, memory_id: str) -> bool:
        return True
    
    def get_memory_context(self, query: str, max_tokens=2000, filters=None) -> str:
        return ""


class ExampleServerAPI(ServerAPI):
    """示例Server API实现（仅用于演示）"""
    def get_projects(self):
        return []
    
    def get_project(self, project_id: str):
        return None
    
    def create_project(self, project: Project) -> Project:
        return project
    
    def update_project(self, project_id: str, project: Project) -> Project:
        return project
    
    def delete_project(self, project_id: str) -> bool:
        return True
    
    def get_tasks(self, project_id: Optional[str] = None):
        return []
    
    def get_task(self, task_id: str):
        return None
    
    def create_task(self, task: Task) -> Task:
        return task
    
    def update_task(self, task_id: str, task: Task) -> Task:
        return task
    
    def delete_task(self, task_id: str) -> bool:
        return True
    
    def complete_task(self, task_id: str) -> bool:
        return True
    
    def uncomplete_task(self, task_id: str) -> bool:
        return True
    
    def reorder_tasks(self, task_ids: list) -> bool:
        return True
    
    def start_focus(self, focus_type, task_id=None):
        from models.focus import FocusRecord
        from datetime import datetime
        return FocusRecord(
            id="focus_1",
            start_time=datetime.now(),
            duration=0,
            focus_type=focus_type,
            task_id=task_id
        )
    
    def end_focus(self, focus_record_id: str):
        from models.focus import FocusRecord, FocusType
        from datetime import datetime
        return FocusRecord(
            id=focus_record_id,
            start_time=datetime.now(),
            end_time=datetime.now(),
            duration=1800,
            focus_type=FocusType.FREE
        )
    
    def get_focus_records(self, start_date=None, end_date=None, task_id=None):
        return []
    
    def update_scene_components(self, component_configs: dict) -> bool:
        return True
    
    def update_bgm(self, action: str, volume=None, track_id=None, play=None) -> bool:
        return True
    
    def update_ambient_noise(self, enabled: bool, volume=0.5) -> bool:
        return True
    
    def play_performance(self, performance_sequence):
        return True
    
    def get_daily_summary(self, date):
        return {}
    
    def get_statistics(self, start_date, end_date, period="day"):
        return {}


def main():
    """主函数：演示Agent使用"""
    print("=" * 60)
    print("Agent测试 - 使用Ollama (qwen2:1.5b模型)")
    print("=" * 60)
    
    # 1. 初始化Ollama LLM（使用tinyllama小模型，约1.1B参数）
    print("\n[1/5] 初始化Ollama LLM...")
    try:
        llm = OllamaLLM(
            base_url="http://localhost:11434",  # Ollama默认地址
            model="qwen2:1.5b"  # 小模型，适合测试
        )
        print(f"  ✓ LLM已初始化，模型: qwen2:1.5b")
    except Exception as e:
        print(f"  ✗ LLM初始化失败: {e}")
        print("  提示: 请确保Ollama服务已启动，并且已下载tinyllama模型")
        print("  下载命令: ollama pull tinyllama")
        return
    
    # 2. 初始化记忆和Server API（使用示例实现）
    print("\n[2/5] 初始化记忆和Server API...")
    memory = ExampleMemory()
    server_api = ExampleServerAPI()
    print("  ✓ 记忆和Server API已初始化（使用示例实现）")
    
    # 3. 创建Agent配置
    print("\n[3/5] 创建Agent配置...")
    config = AgentConfig(
        character_name="女孩",
        character_personality="温柔、体贴，以鼓励和支持为主",
        temperature=0.7
    )
    print("  ✓ Agent配置已创建")
    print(f"  提示: tinyllama对中文支持可能不够好，如果中文效果不理想，")
    print(f"        可以尝试使用中文模型，例如: qwen2:1.5b 或 phi3:mini")
    
    # 4. 创建Agent实例
    print("\n[4/5] 创建Agent实例...")
    agent = Agent(
        llm=llm,
        memory=memory,
        server_api=server_api,
        config=config
    )
    print("  ✓ Agent实例已创建")
    
    # 5. 使用Agent进行对话
    print("\n[5/5] 开始对话测试...")
    print("-" * 60)
    # user_message = "你好，今天有什么任务要完成吗？"
    # user_message = "你好，今天有什么任务要完成吗？"
    user_message = "你好，我想学习python，帮我列一个学习列表吧！顺便帮我把音乐声音调大一点儿。"
    print(f"用户: {user_message}")
    print("-" * 60)
    
    try:
        # 可选：打印实际发送的系统提示词（调试用）
        debug = False  # 设为True可以看到实际发送的消息
        if debug:
            messages = agent._get_context_messages(user_message)
            print("\n[调试] 实际发送的消息:")
            for i, msg in enumerate(messages):
                print(f"  {i+1}. [{msg.role}]: {msg.content[:200]}..." if len(msg.content) > 200 else f"  {i+1}. [{msg.role}]: {msg.content}")
            print("-" * 60)
        
        response = agent.chat(user_message)
        
        print(f"\nAgent响应: {response.text}")
        print(f"\n响应详情:")
        print(f"  - 文本长度: {len(response.text)} 字符")
        print(f"  - 操作数量: {len(response.operations)}")
        if response.performance_sequence:
            print(f"  - 演出脚本: 已生成")
        else:
            print(f"  - 演出脚本: 无")
        
        # 显示操作详情
        if response.operations:
            print(f"\n操作列表:")
            for i, operation in enumerate(response.operations, 1):
                print(f"  {i}. {operation}")
        else:
            print(f"\n操作列表: 无操作")
            
    except Exception as e:
        print(f"  ✗ 对话失败: {e}")
        import traceback
        traceback.print_exc()
    
    print("\n" + "=" * 60)
    print("测试完成")
    print("=" * 60)


if __name__ == "__main__":
    main()

