"""
Agent响应解析器
解析AgentResponse，提取function call信息并构建请求格式
"""
import json
import uuid
from typing import List, Dict, Any, Optional, Tuple
from dataclasses import dataclass

from response import AgentResponse, Operation
from response import (
    TaskCreateOperation, TaskUpdateOperation, TaskDeleteOperation, TaskCompleteOperation,
    BGMOperation, FocusStartOperation, FocusEndOperation
)


@dataclass
class FunctionCallEvent:
    """Function Call事件（对应SSE function_call事件）"""
    id: str
    name: str
    arguments: Dict[str, Any]
    
    def to_dict(self) -> Dict[str, Any]:
        """转换为字典格式（对应SSE data字段）"""
        return {
            "id": self.id,
            "name": self.name,
            "arguments": self.arguments
        }
    
    def to_sse_data(self) -> str:
        """转换为SSE data格式的JSON字符串"""
        return json.dumps(self.to_dict(), ensure_ascii=False)


@dataclass
class FunctionResultRequest:
    """Function Results请求对象"""
    session_id: str
    function_call_id: str
    function_name: str
    result: Dict[str, Any]
    
    def to_dict(self) -> Dict[str, Any]:
        """转换为请求体字典"""
        return {
            "session_id": self.session_id,
            "function_call_id": self.function_call_id,
            "function_name": self.function_name,
            "result": self.result
        }
    
    def to_json(self) -> str:
        """转换为JSON字符串"""
        return json.dumps(self.to_dict(), ensure_ascii=False, indent=2)
    
    def get_headers(self, access_token: Optional[str] = None) -> Dict[str, str]:
        """
        获取请求头（用于调试）
        
        Args:
            access_token: 访问令牌（可选）
            
        Returns:
            请求头字典
        """
        headers = {
            "Content-Type": "application/json",
            "Accept": "text/event-stream"
        }
        if access_token:
            headers["Authorization"] = f"Bearer {access_token}"
        return headers


class AgentResponseParser:
    """Agent响应解析器"""
    
    def __init__(self):
        """初始化解析器"""
        self.function_call_counter = 0
    
    def parse_agent_response(
        self,
        agent_response: AgentResponse
    ) -> List[FunctionCallEvent]:
        """
        解析AgentResponse，提取function call事件
        
        Args:
            agent_response: Agent响应对象
            
        Returns:
            FunctionCallEvent列表
        """
        function_calls = []
        
        for operation in agent_response.operations:
            function_call = self._operation_to_function_call(operation)
            if function_call:
                function_calls.append(function_call)
        
        return function_calls
    
    def _operation_to_function_call(
        self,
        operation: Operation
    ) -> Optional[FunctionCallEvent]:
        """
        将Operation转换为FunctionCallEvent
        
        Args:
            operation: 操作对象
            
        Returns:
            FunctionCallEvent对象，如果无法转换则返回None
        """
        self.function_call_counter += 1
        function_call_id = f"fc_{self.function_call_counter:03d}"
        
        # 根据操作类型映射到函数名和参数
        function_name, arguments = self._map_operation_to_function(operation)
        
        if not function_name:
            return None
        
        return FunctionCallEvent(
            id=function_call_id,
            name=function_name,
            arguments=arguments
        )
    
    def _map_operation_to_function(
        self,
        operation: Operation
    ) -> Tuple[Optional[str], Dict[str, Any]]:
        """
        将Operation映射到函数名和参数
        
        Args:
            operation: 操作对象
            
        Returns:
            (函数名, 参数字典) 元组，如果无法映射则返回(None, {})
        """
        # 任务相关操作
        if isinstance(operation, TaskCreateOperation):
            return "add_task", {
                "title": operation.task.info.description,
                "due_timestamp": int(operation.task.deadline.timestamp()) if operation.task.deadline else 0
            }
        
        elif isinstance(operation, TaskUpdateOperation):
            # 尝试从task_id提取数字ID
            task_id = 0
            if operation.task_id and operation.task_id.isdigit():
                task_id = int(operation.task_id)
            
            return "update_task_title", {
                "task_id": task_id,
                "title": operation.task.info.description
            }
        
        elif isinstance(operation, TaskDeleteOperation):
            task_id = 0
            if operation.task_id and operation.task_id.isdigit():
                task_id = int(operation.task_id)
            
            return "remove_task", {
                "task_id": task_id
            }
        
        elif isinstance(operation, TaskCompleteOperation):
            task_id = 0
            if operation.task_id and operation.task_id.isdigit():
                task_id = int(operation.task_id)
            
            return "set_task_completed", {
                "task_id": task_id,
                "completed": True
            }
        
        # BGM操作
        elif isinstance(operation, BGMOperation):
            if operation.operation_type == "volume":
                return "set_bgm_volume", {
                    "volume": operation.volume or 0.5
                }
            elif operation.operation_type == "switch":
                return "play_music", {
                    "track_name": operation.track_id or ""
                }
            elif operation.operation_type == "toggle":
                return "toggle_playback", {}
        
        # 专注操作
        elif isinstance(operation, FocusStartOperation):
            if operation.focus_type == "tomato":
                return "start_pomodoro", {
                    "work_minutes": 25,
                    "rest_minutes": 5,
                    "loop_times": 1
                }
        
        elif isinstance(operation, FocusEndOperation):
            return "stop_pomodoro", {}
        
        # 未知操作类型
        return None, {}
    
    def build_function_result_request(
        self,
        session_id: str,
        function_call_event: FunctionCallEvent,
        success: bool = True,
        message: Optional[str] = None,
        data: Optional[Dict[str, Any]] = None
    ) -> FunctionResultRequest:
        """
        构建function-results请求
        
        Args:
            session_id: 会话ID
            function_call_event: FunctionCallEvent对象
            success: 是否成功
            message: 结果消息（可选）
            data: 附加数据（可选）
            
        Returns:
            FunctionResultRequest对象
        """
        result = {
            "success": success
        }
        if message:
            result["message"] = message
        if data:
            result["data"] = data
        
        return FunctionResultRequest(
            session_id=session_id,
            function_call_id=function_call_event.id,
            function_name=function_call_event.name,
            result=result
        )

