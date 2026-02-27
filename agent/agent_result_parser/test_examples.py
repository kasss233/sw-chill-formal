"""
Agent输出示例和测试函数
用于测试Parser的解析功能
"""
import json
from response import AgentResponse, TaskCreateOperation, TaskCompleteOperation, BGMOperation
from models.task import Task, TaskInfo, TaskOwner
from datetime import datetime
from agent_result_parser.agent_response_parser import AgentResponseParser, FunctionResultRequest


def create_example_1() -> AgentResponse:
    """示例1：创建任务"""
    task = Task(
        id=None,
        project_id="root",
        info=TaskInfo(
            description="学习Python基础",
            owner=TaskOwner.GIRL
        ),
        sort_order=0
    )
    
    operation = TaskCreateOperation(task=task)
    
    return AgentResponse(
        text="好的，我已经为你创建了学习Python基础的任务！",
        performance_sequence=None,
        operations=[operation]
    )


def create_example_2() -> AgentResponse:
    """示例2：创建多个任务"""
    tasks = [
        Task(
            id=None,
            project_id="root",
            info=TaskInfo(
                description="学习Python基础语法",
                owner=TaskOwner.GIRL
            ),
            sort_order=0
        ),
        Task(
            id=None,
            project_id="root",
            info=TaskInfo(
                description="完成一个小项目",
                owner=TaskOwner.GIRL
            ),
            sort_order=1
        ),
        Task(
            id=None,
            project_id="root",
            info=TaskInfo(
                description="阅读Python文档",
                owner=TaskOwner.GIRL
            ),
            sort_order=2
        )
    ]
    
    operations = [TaskCreateOperation(task=task) for task in tasks]
    
    return AgentResponse(
        text="我已经为你创建了Python学习计划，包括：学习基础语法、完成小项目和阅读文档。",
        performance_sequence=None,
        operations=operations
    )


def create_example_3() -> AgentResponse:
    """示例3：完成任务"""
    operation = TaskCompleteOperation(task_id="5")
    
    return AgentResponse(
        text="好的，我已经将任务标记为完成了！",
        performance_sequence=None,
        operations=[operation]
    )


def create_example_4() -> AgentResponse:
    """示例4：调整音乐音量"""
    operation = BGMOperation(
        operation_type="volume",
        volume=0.7
    )
    
    return AgentResponse(
        text="我已经将音乐音量调整为70%了。",
        performance_sequence=None,
        operations=[operation]
    )


def create_example_5() -> AgentResponse:
    """示例5：纯文本回复（无操作）"""
    return AgentResponse(
        text="你好！今天有什么需要我帮助的吗？",
        performance_sequence=None,
        operations=[]
    )


def print_parsed_results(
    agent_response: AgentResponse,
    session_id: str = "sess_test123",
    access_token: str = "test_access_token"
):
    """
    解析AgentResponse并打印所有请求格式（用于测试）
    
    Args:
        agent_response: Agent响应对象
        session_id: 会话ID
        access_token: 访问令牌（用于请求头）
    """
    print("=" * 80)
    print("Agent响应解析测试")
    print("=" * 80)
    
    # 1. 打印原始AgentResponse
    print("\n[1] 原始AgentResponse:")
    print(f"  文本: {agent_response.text}")
    print(f"  操作数量: {len(agent_response.operations)}")
    for i, op in enumerate(agent_response.operations, 1):
        print(f"    操作{i}: {op.action}")
    
    # 2. 解析为FunctionCallEvent
    print("\n[2] 解析为FunctionCallEvent:")
    parser = AgentResponseParser()
    function_calls = parser.parse_agent_response(agent_response)
    
    if not function_calls:
        print("  (无function call)")
    else:
        for i, fc in enumerate(function_calls, 1):
            print(f"\n  FunctionCall {i}:")
            print(f"    ID: {fc.id}")
            print(f"    函数名: {fc.name}")
            print(f"    参数: {json.dumps(fc.arguments, ensure_ascii=False, indent=6)}")
            print(f"    SSE格式: event: function_call")
            print(f"              data: {fc.to_sse_data()}")
    
    # 3. 构建Function Results请求（示例：假设所有操作都成功）
    print("\n[3] Function Results请求格式:")
    if function_calls:
        for i, fc in enumerate(function_calls, 1):
            # 构建成功结果
            result_request = parser.build_function_result_request(
                session_id=session_id,
                function_call_event=fc,
                success=True,
                message=f"{fc.name}执行成功",
                data={"example": "data"}
            )
            
            print(f"\n  FunctionResult {i}:")
            print(f"    请求URL: POST /api/v1/chat/function-results")
            print(f"    请求头:")
            headers = result_request.get_headers(access_token)
            for key, value in headers.items():
                print(f"      {key}: {value}")
            print(f"    请求体:")
            print(result_request.to_json())
    else:
        print("  (无function call，无需构建function-results请求)")
    
    print("\n" + "=" * 80)


def run_all_tests():
    """运行所有测试示例"""
    import json
    
    examples = [
        ("示例1：创建单个任务", create_example_1),
        ("示例2：创建多个任务", create_example_2),
        ("示例3：完成任务", create_example_3),
        ("示例4：调整音乐音量", create_example_4),
        ("示例5：纯文本回复", create_example_5),
    ]
    
    for title, create_func in examples:
        print(f"\n{'='*80}")
        print(f"{title}")
        print(f"{'='*80}")
        agent_response = create_func()
        print_parsed_results(agent_response)
        print("\n")


if __name__ == "__main__":
    import json
    run_all_tests()

