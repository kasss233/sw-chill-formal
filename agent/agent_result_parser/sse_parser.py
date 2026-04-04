"""
SSE事件解析器
将AgentResponse转换为SSE事件格式
"""
import json
import uuid
from typing import Any, Dict, List, Optional, Tuple
from enum import Enum

from response import AgentResponse, Operation
from models.performance import PerformanceSequence


class SSEEventType(str, Enum):
    """SSE事件类型"""
    TEXT_DELTA = "text_delta"
    TEXT_DONE = "text_done"
    FUNCTION_CALL = "function_call"
    ENVIRONMENT = "environment"
    ACTION = "action"
    TTS = "tts"
    ERROR = "error"
    DONE = "done"


class SSEEvent:
    """SSE事件对象"""
    
    def __init__(self, event_type: SSEEventType, data: dict):
        """
        初始化SSE事件
        
        Args:
            event_type: 事件类型
            data: 事件数据（字典）
        """
        self.event_type = event_type
        self.data = data
    
    def to_sse_format(self) -> str:
        """
        转换为SSE格式字符串
        
        Returns:
            SSE格式字符串，格式：event: {type}\ndata: {json}\n\n
        """
        json_data = json.dumps(self.data, ensure_ascii=False)
        return f"event: {self.event_type.value}\ndata: {json_data}\n\n"
    
    def __repr__(self) -> str:
        return f"SSEEvent(type={self.event_type.value}, data={self.data})"


class SSEParser:
    """SSE事件解析器"""
    
    def __init__(self, session_id: Optional[str] = None):
        """
        初始化SSE解析器
        
        Args:
            session_id: 会话ID（可选，用于done事件）
        """
        self.session_id = session_id
        self.message_id = f"msg_{uuid.uuid4().hex[:8]}"
        self.function_call_counter = 0
    
    def parse_agent_response(
        self,
        agent_response: AgentResponse,
        session_id: Optional[str] = None
    ) -> List[SSEEvent]:
        """
        解析AgentResponse为SSE事件列表
        
        Args:
            agent_response: Agent响应对象
            session_id: 会话ID（可选，覆盖初始化时的session_id）
            
        Returns:
            SSE事件列表
        """
        events = []
        used_session_id = session_id or self.session_id
        
        # 1. 文本回复：先发送text_done（完整文本）
        if agent_response.text:
            events.append(SSEEvent(
                event_type=SSEEventType.TEXT_DONE,
                data={"content": agent_response.text}
            ))

        # 2. 函数调用：优先原生 function_calls，否则 legacy operations
        if agent_response.function_calls:
            events.extend(self._native_function_call_events(agent_response.function_calls))
        else:
            for operation in agent_response.operations:
                function_call_event = self._operation_to_function_call(operation)
                if function_call_event:
                    events.append(function_call_event)

        # 3. 环境与演出（与 Python agent / 后端扩展事件对齐）
        if agent_response.environment:
            events.append(SSEEvent(
                event_type=SSEEventType.ENVIRONMENT,
                data=dict(agent_response.environment),
            ))
        if agent_response.action:
            events.append(SSEEvent(
                event_type=SSEEventType.ACTION,
                data=dict(agent_response.action),
            ))

        # 4. 演出脚本：转换为TTS事件（如果有）
        if agent_response.performance_sequence:
            tts_event = self._performance_to_tts(agent_response.performance_sequence)
            if tts_event:
                events.append(tts_event)

        # 5. 最后发送done事件
        events.append(SSEEvent(
            event_type=SSEEventType.DONE,
            data={
                "message_id": self.message_id,
                "session_id": used_session_id or ""
            }
        ))
        
        return events

    def _native_function_call_events(self, calls: List[Dict[str, Any]]) -> List[SSEEvent]:
        evs: List[SSEEvent] = []
        for fc in calls:
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
            if not isinstance(args, dict):
                args = {}
            evs.append(SSEEvent(
                event_type=SSEEventType.FUNCTION_CALL,
                data={
                    "id": str(fid),
                    "name": str(name),
                    "arguments": args,
                },
            ))
        return evs

    def _operation_to_function_call(self, operation: Operation) -> Optional[SSEEvent]:
        """
        将Operation转换为function_call事件
        
        Args:
            operation: 操作对象
            
        Returns:
            SSE事件（function_call类型），如果无法转换则返回None
        """
        self.function_call_counter += 1
        function_call_id = f"fc_{self.function_call_counter:03d}"
        
        # 根据操作类型映射到函数名和参数
        function_name, arguments = self._map_operation_to_function(operation)
        
        if not function_name:
            return None
        
        return SSEEvent(
            event_type=SSEEventType.FUNCTION_CALL,
            data={
                "id": function_call_id,
                "name": function_name,
                "arguments": arguments
            }
        )
    
    def _map_operation_to_function(self, operation: Operation) -> Tuple[Optional[str], dict]:
        """
        将Operation映射到函数名和参数
        
        Args:
            operation: 操作对象
            
        Returns:
            (函数名, 参数字典) 元组，如果无法映射则返回(None, {})
        """
        from response import (
            TaskCreateOperation, TaskUpdateOperation, TaskDeleteOperation, TaskCompleteOperation,
            ProjectCreateOperation, ProjectUpdateOperation, ProjectDeleteOperation,
            SceneComponentOperation, BGMOperation, AmbientNoiseOperation,
            FocusStartOperation, FocusEndOperation
        )
        
        # 任务相关操作
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
        
        # 项目相关操作（暂不支持，返回None）
        elif isinstance(operation, (ProjectCreateOperation, ProjectUpdateOperation, ProjectDeleteOperation)):
            # 项目操作暂不支持，可能需要扩展function_definitions
            return None, {}
        
        # 场景控制操作
        elif isinstance(operation, SceneComponentOperation):
            # 场景组件操作暂不支持，可能需要扩展function_definitions
            return None, {}
        
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
        
        elif isinstance(operation, AmbientNoiseOperation):
            # 环境音操作暂不支持，可能需要扩展function_definitions
            return None, {}
        
        # 专注相关操作
        elif isinstance(operation, FocusStartOperation):
            if operation.focus_type == "tomato":
                return "start_pomodoro", {
                    "work_minutes": 25,
                    "rest_minutes": 5,
                    "loop_times": 1
                }
            # 其他专注类型暂不支持
            return None, {}
        
        elif isinstance(operation, FocusEndOperation):
            return "stop_pomodoro", {}
        
        # 未知操作类型
        return None, {}
    
    def _performance_to_tts(self, performance_sequence: PerformanceSequence) -> Optional[SSEEvent]:
        """
        将演出脚本序列转换为TTS事件（简化实现）
        
        Args:
            performance_sequence: 演出脚本序列
            
        Returns:
            SSE事件（TTS类型），如果无法转换则返回None
        """
        # 简化实现：从演出脚本中提取文本用于TTS
        # 实际实现可能需要更复杂的逻辑
        texts = []
        for script in performance_sequence.scripts:
            for action in script.actions:
                if hasattr(action, 'text') and action.text:
                    texts.append(action.text)
        
        if texts:
            # 合并所有文本
            content = " ".join(texts)
            # 这里返回一个占位符URL，实际应该调用TTS服务
            return SSEEvent(
                event_type=SSEEventType.TTS,
                data={
                    "url": "",  # 实际应该返回TTS服务生成的URL
                    "format": "mp3"
                }
            )
        
        return None
    
    def format_events_as_sse_stream(self, events: List[SSEEvent]) -> str:
        """
        将事件列表格式化为完整的SSE流字符串
        
        Args:
            events: SSE事件列表
            
        Returns:
            完整的SSE流字符串
        """
        return "".join(event.to_sse_format() for event in events)

