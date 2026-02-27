"""
Parser使用示例
展示如何将AgentResponse转换为SSE事件和function-results请求
"""
from response import AgentResponse, TaskCreateOperation
from models.task import Task, TaskInfo, TaskOwner
from agent_result_parser import SSEParser, FunctionResultsBuilder

# 示例：创建一个AgentResponse
def create_example_response():
    """创建示例AgentResponse"""
    # 创建一个任务操作
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
        text="好的，我已经为你创建了学习任务！",
        performance_sequence=None,
        operations=[operation]
    )


def main():
    """主函数：演示Parser使用"""
    print("=" * 60)
    print("Parser使用示例")
    print("=" * 60)
    
    # 1. 创建示例AgentResponse
    print("\n[1/3] 创建示例AgentResponse...")
    agent_response = create_example_response()
    print(f"  ✓ AgentResponse已创建")
    print(f"    - 文本: {agent_response.text}")
    print(f"    - 操作数量: {len(agent_response.operations)}")
    
    # 2. 解析为SSE事件
    print("\n[2/3] 解析为SSE事件...")
    parser = SSEParser(session_id="sess_example123")
    events = parser.parse_agent_response(agent_response)
    
    print(f"  ✓ 生成了 {len(events)} 个SSE事件:")
    for i, event in enumerate(events, 1):
        print(f"    {i}. {event.event_type.value}")
        print(f"       数据: {event.data}")
    
    # 3. 格式化为SSE流字符串
    print("\n[3/3] 格式化为SSE流字符串...")
    sse_stream = parser.format_events_as_sse_stream(events)
    print("  ✓ SSE流格式:")
    print("-" * 60)
    print(sse_stream)
    print("-" * 60)
    
    # 4. 构建function-results请求（示例）
    print("\n[4/4] 构建function-results请求（示例）...")
    if events:
        # 找到第一个function_call事件
        function_call_event = None
        for event in events:
            if event.event_type.value == "function_call":
                function_call_event = event
                break
        
        if function_call_event:
            function_call_id = function_call_event.data.get("id")
            function_name = function_call_event.data.get("name")
            
            # 构建成功结果
            result_request = FunctionResultsBuilder.build_success_result(
                session_id="sess_example123",
                function_call_id=function_call_id,
                function_name=function_name,
                message="任务创建成功",
                data={"task_id": 5, "title": "学习Python基础"}
            )
            
            print(f"  ✓ Function Results请求:")
            print(f"    - 请求体: {result_request.to_json()}")
            print(f"    - 请求头: {result_request.get_headers('your_access_token')}")
    
    print("\n" + "=" * 60)
    print("示例完成")
    print("=" * 60)


if __name__ == "__main__":
    main()

