"""
Parser接口模块
提供将Agent JSON输出转换为SSE文本列表的函数
"""
import json
from typing import List

from response import AgentResponse
from .agent_response_parser import AgentResponseParser, FunctionCallEvent


def agent_response_to_sse_text_list(agent_response_json: str, quiet: bool = False) -> List[str]:
    """
    将Agent的JSON回复转换为SSE文本列表
    
    Args:
        agent_response_json: Agent响应的JSON字符串（AgentResponse的JSON格式）
        quiet: 为 True 时不打印解析过程和结果，便于库化/后端集成
        
    Returns:
        SSE文本列表，每个元素是一个SSE事件格式的字符串
    """
    # 1. 解析JSON为AgentResponse对象
    try:
        data = json.loads(agent_response_json)
        # 使用model_validate处理嵌套对象
        agent_response = AgentResponse.model_validate(data)
    except json.JSONDecodeError as e:
        raise ValueError(f"无效的JSON格式: {e}")
    except Exception as e:
        raise ValueError(f"无法解析为AgentResponse: {e}")
    
    # 2. 解析AgentResponse，提取function call事件
    parser = AgentResponseParser()
    function_calls = parser.parse_agent_response(agent_response)
    
    # 3. 构建SSE文本列表
    sse_text_list = []
    
    # 3.1 文本回复（text_done事件）
    if agent_response.text:
        text_done_data = json.dumps({"content": agent_response.text}, ensure_ascii=False)
        sse_text_list.append(f"event: text_done\ndata: {text_done_data}\n")
    
    # 3.2 Function call事件
    for fc in function_calls:
        function_call_data = fc.to_sse_data()
        sse_text_list.append(f"event: function_call\ndata: {function_call_data}\n")

    # 3.25 environment / action（原生 AgentResponse 字段）
    if agent_response.environment:
        env_data = json.dumps(agent_response.environment, ensure_ascii=False)
        sse_text_list.append(f"event: environment\ndata: {env_data}\n")
    if agent_response.action:
        act_data = json.dumps(agent_response.action, ensure_ascii=False)
        sse_text_list.append(f"event: action\ndata: {act_data}\n")
    
    # 3.3 TTS事件（如果有演出脚本）
    if agent_response.performance_sequence:
        # 简化处理：从演出脚本中提取文本用于TTS
        texts = []
        for script in agent_response.performance_sequence.scripts:
            for action in script.actions:
                if hasattr(action, 'text') and action.text:
                    texts.append(action.text)
        
        if texts:
            tts_data = json.dumps({
                "url": "",  # 实际应该返回TTS服务生成的URL
                "format": "mp3"
            }, ensure_ascii=False)
            sse_text_list.append(f"event: tts\ndata: {tts_data}\n")
    
    # 3.4 Done事件
    done_data = json.dumps({
        "message_id": f"msg_{hash(agent_response_json) % 1000000:06d}",
        "session_id": ""  # 需要从外部传入，这里先留空
    }, ensure_ascii=False)
    sse_text_list.append(f"event: done\ndata: {done_data}\n")
    
    # 4. 打印结果（quiet 时跳过，便于后端/库化使用）
    if not quiet:
        print("=" * 80)
        print("Agent响应转换为SSE文本列表")
        print("=" * 80)
        print(f"\n原始AgentResponse JSON:")
        print(json.dumps(json.loads(agent_response_json), ensure_ascii=False, indent=2))
        print(f"\n解析结果:")
        print(f"  - 文本回复: {agent_response.text[:50]}..." if len(agent_response.text) > 50 else f"  - 文本回复: {agent_response.text}")
        print(f"  - Function Call数量: {len(function_calls)}")
        print(f"  - SSE事件数量: {len(sse_text_list)}")
        print(f"\nSSE文本列表:")
        print("-" * 80)
        for i, sse_text in enumerate(sse_text_list, 1):
            print(f"[事件 {i}]")
            print(sse_text)
        print("-" * 80)
        print("=" * 80)
    
    return sse_text_list

