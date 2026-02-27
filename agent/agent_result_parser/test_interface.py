"""
测试interface.py的功能
"""
from agent_result_parser.interface import agent_response_to_sse_text_list

# 示例1：创建任务
example_1 = """
{
  "text": "好的，我已经为你创建了学习Python基础的任务！",
  "performance_sequence": null,
  "operations": [
    {
      "action": "create_task",
      "task": {
        "id": null,
        "project_id": "root",
        "info": {
          "description": "学习Python基础",
          "created_at": "2024-01-01T00:00:00",
          "last_modified_by": null,
          "owner": "girl",
          "completed_count": 0,
          "total_time_spent": 0,
          "focus_records": [],
          "attachments": []
        },
        "parent_task_id": null,
        "subtasks": [],
        "completed": false,
        "sort_order": 0,
        "repeat": {
          "enabled": false,
          "weekdays": []
        },
        "deadline": null,
        "start_time": null,
        "reminder_enabled": false
      }
    }
  ]
}
"""

# 示例2：纯文本回复
example_2 = """
{
  "text": "你好！今天有什么需要我帮助的吗？",
  "performance_sequence": null,
  "operations": []
}
"""

# 示例3：完成任务
example_3 = """
{
  "text": "好的，我已经将任务标记为完成了！",
  "performance_sequence": null,
  "operations": [
    {
      "action": "complete_task",
      "task_id": "5"
    }
  ]
}
"""


def test_example(example_json: str, title: str):
    """测试单个示例"""
    print(f"\n{'='*80}")
    print(f"测试: {title}")
    print(f"{'='*80}\n")
    
    try:
        sse_list = agent_response_to_sse_text_list(example_json)
        print(f"\n✓ 转换成功，共生成 {len(sse_list)} 个SSE事件")
        return sse_list
    except Exception as e:
        print(f"\n✗ 转换失败: {e}")
        return None


if __name__ == "__main__":
    # 测试所有示例
    test_example(example_1, "示例1：创建任务")
    test_example(example_2, "示例2：纯文本回复")
    test_example(example_3, "示例3：完成任务")

