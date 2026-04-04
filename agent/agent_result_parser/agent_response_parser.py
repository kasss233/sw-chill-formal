"""
Agent响应解析器
解析AgentResponse，提取function call信息并构建请求格式
"""
import json
import uuid
from typing import Any, Dict, List, Optional, Tuple
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
        """
        if agent_response.function_calls:
            return self._parse_native_function_calls(agent_response.function_calls)
        return self._parse_legacy_operations(agent_response)

    def _parse_native_function_calls(
        self,
        calls: List[Dict[str, Any]],
    ) -> List[FunctionCallEvent]:
        out: List[FunctionCallEvent] = []
        for i, fc in enumerate(calls):
            if not isinstance(fc, dict):
                continue
            name = fc.get("name")
            if not name:
                continue
            self.function_call_counter += 1
            fid = fc.get("id") or fc.get("call_id") or f"fc_{self.function_call_counter:03d}"
            args = fc.get("arguments", fc.get("args", {}))
            if args is None:
                args = {}
            if isinstance(args, str):
                try:
                    args = json.loads(args) if args.strip() else {}
                except json.JSONDecodeError:
                    args = {}
            if not isinstance(args, dict):
                args = {}
            out.append(FunctionCallEvent(id=str(fid), name=str(name), arguments=args))
        return out

    def _parse_legacy_operations(self, agent_response: AgentResponse) -> List[FunctionCallEvent]:
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
        """将Operation转换为FunctionCallEvent"""
        self.function_call_counter += 1
        function_call_id = f"fc_{self.function_call_counter:03d}"

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
        """将Operation映射到函数名和参数（legacy）"""
        if isinstance(operation, TaskCreateOperation):
            return "add_task", {
                "title": operation.task.info.description,
                "due_timestamp": int(operation.task.deadline.timestamp()) if operation.task.deadline else 0
            }

        elif isinstance(operation, TaskUpdateOperation):
            tid = operation.task_id
            task_id = int(tid) if isinstance(tid, str) and tid.isdigit() else (tid if isinstance(tid, int) else 0)
            return "update_task_title", {
                "task_id": task_id,
                "title": operation.task.info.description
            }

        elif isinstance(operation, TaskDeleteOperation):
            tid = operation.task_id
            task_id = int(tid) if isinstance(tid, str) and tid.isdigit() else (tid if isinstance(tid, int) else 0)
            return "remove_task", {
                "task_id": task_id
            }

        elif isinstance(operation, TaskCompleteOperation):
            tid = operation.task_id
            task_id = int(tid) if isinstance(tid, str) and tid.isdigit() else (tid if isinstance(tid, int) else 0)
            return "set_task_completed", {
                "task_id": task_id,
                "completed": True
            }

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

        elif isinstance(operation, FocusStartOperation):
            if operation.focus_type == "tomato":
                return "start_pomodoro", {
                    "work_minutes": 25,
                    "rest_minutes": 5,
                    "loop_times": 1
                }

        elif isinstance(operation, FocusEndOperation):
            return "stop_pomodoro", {}

        return None, {}

    def build_function_result_request(
        self,
        session_id: str,
        function_call_event: FunctionCallEvent,
        success: bool = True,
        message: Optional[str] = None,
        data: Optional[Dict[str, Any]] = None
    ) -> FunctionResultRequest:
        """构建function-results请求"""
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
