extends CenterContainer
@export var parser : Parser = null;


func _on_button_pressed() -> void:
	if parser == null:
		return;
	parser.parse_and_execute("""{
  "text": "好的，我来帮你创建一个学习计划。我会创建几个任务，然后启动番茄钟来帮助你专注学习，同时播放一些轻松的音乐。",
  "performance_sequence": null,
  "operations": [
    {
	  "action": "create_task",
	  "task": {
		"id": "task_001",
		"project_id": "root",
		"info": {
		  "description": "学习Python基础语法",
		  "created_at": "2026-01-21T15:33:06.706338",
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
    },
    {
	  "action": "create_task",
	  "task": {
		"id": "task_002",
		"project_id": "root",
		"info": {
		  "description": "完成Python练习题",
		  "created_at": "2026-01-21T15:33:06.706338",
		  "owner": "girl"
        },
		"completed": false,
		"sort_order": 1
      }
    },
    {
	  "action": "start_focus",
	  "focus_type": "tomato",
	  "task_id": "task_001"
    },
    {
	  "action": "update_bgm",
	  "operation_type": "switch",
	  "track_id": "轻松学习音乐"
    },
    {
	  "action": "update_bgm",
	  "operation_type": "toggle",
	  "play": true
    }
  ]
}""")
	pass # Replace with function body.


func _on_button_2_pressed() -> void:
	if parser == null:
		return;
	parser.parse_and_execute("""{
  "text": "让我帮你管理一下任务列表。我会创建几个任务，然后更新其中一个，最后标记完成。",
  "performance_sequence": null,
  "operations": [
	{
	  "action": "create_task",
	  "task": {
		"id": "task_003",
		"project_id": "root",
		"info": {
		  "description": "阅读技术文档",
		  "owner": "girl"
		},
		"completed": false,
		"sort_order": 0
	  }
	},
	{
	  "action": "create_task",
	  "task": {
		"id": "task_004",
		"project_id": "root",
		"info": {
		  "description": "编写代码示例",
		  "owner": "girl"
		},
		"completed": false,
		"sort_order": 1
	  }
	},
	{
	  "action": "update_task",
	  "task_id": "task_003",
	  "task": {
		"id": "task_003",
		"project_id": "root",
		"info": {
		  "description": "阅读Python技术文档并做笔记",
		  "owner": "girl"
		},
		"deadline": "2026-01-22T18:00:00.000000",
		"completed": false
	  }
	},
	{
	  "action": "complete_task",
	  "task_id": "task_004"
	}
  ]
}""")
	pass # Replace with function body.


func _on_button_3_pressed() -> void:
	if parser == null:
		return;
	parser.parse_and_execute("""{
  "text": "现在启动番茄钟，帮助你专注工作25分钟，然后休息5分钟。",
  "performance_sequence": null,
  "operations": [
	{
	  "action": "start_focus",
	  "focus_type": "tomato",
	  "task_id": null
	}
  ]
}""")
	pass # Replace with function body.


func _on_button_4_pressed() -> void:
	if parser == null:
		return;
	parser.parse_and_execute("""{
  "text": "让我为你播放一些轻松的音乐，帮助你放松。",
  "performance_sequence": null,
  "operations": [
	{
	  "action": "update_bgm",
	  "operation_type": "switch",
	  "track_id": "轻松背景音乐"
	},
	{
	  "action": "update_bgm",
	  "operation_type": "toggle",
	  "play": true
	}
  ]
}""")
	pass # Replace with function body.


func _on_button_5_pressed() -> void:
	if parser == null:
		return;
	parser.parse_and_execute("""{
  "text": "我为你制定了一个完整的学习计划，包含多个任务。",
  "performance_sequence": null,
  "operations": [
	{
	  "action": "create_task",
	  "task": {
		"id": "task_005",
		"project_id": "root",
		"info": {
		  "description": "学习Python基础语法",
		  "owner": "girl"
		},
		"completed": false,
		"sort_order": 0
	  }
	},
	{
	  "action": "create_task",
	  "task": {
		"id": "task_006",
		"project_id": "root",
		"info": {
		  "description": "查看官方文档和教程",
		  "owner": "girl"
		},
		"completed": false,
		"sort_order": 1
	  }
	},
	{
	  "action": "create_task",
	  "task": {
		"id": "task_007",
		"project_id": "root",
		"info": {
		  "description": "实践编写简单的程序",
		  "owner": "girl"
		},
		"completed": false,
		"sort_order": 2
	  }
	},
	{
	  "action": "create_task",
	  "task": {
		"id": "task_008",
		"project_id": "root",
		"info": {
		  "description": "阅读相关书籍，加深理解",
		  "owner": "girl"
		},
		"completed": false,
		"sort_order": 3
	  }
	},
	{
	  "action": "create_task",
	  "task": {
		"id": "task_009",
		"project_id": "root",
		"info": {
		  "description": "参加线上或线下的学习小组讨论",
		  "owner": "girl"
		},
		"completed": false,
		"sort_order": 4
	  }
	}
  ]
}""")

	pass # Replace with function body.


func _on_button_6_pressed() -> void:
	if parser == null:
		return;
	parser.parse_and_execute("""{
  "text": "让我更新一些任务，并删除不需要的任务。",
  "performance_sequence": null,
  "operations": [
	{
	  "action": "update_task",
	  "task_id": "task_005",
	  "task": {
		"id": "task_005",
		"project_id": "root",
		"info": {
		  "description": "深入学习Python高级特性（装饰器、生成器等）",
		  "owner": "girl"
		},
		"deadline": "2026-01-25T23:59:59.000000",
		"completed": false
	  }
	},
	{
	  "action": "delete_task",
	  "task_id": "task_009"
	}
  ]
}""")
	pass # Replace with function body.
