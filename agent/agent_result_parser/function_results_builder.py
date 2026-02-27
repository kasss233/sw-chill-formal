"""
Function Results请求构建器
用于构建function-results接口的请求格式（不实际发送HTTP请求）
"""
import json
from typing import Dict, Any, Optional
from dataclasses import dataclass


@dataclass
class FunctionResultRequest:
    """Function Results请求对象"""
    session_id: str
    function_call_id: str
    function_name: str
    result: Dict[str, Any]
    
    def to_dict(self) -> Dict[str, Any]:
        """转换为字典格式"""
        return {
            "session_id": self.session_id,
            "function_call_id": self.function_call_id,
            "function_name": self.function_name,
            "result": self.result
        }
    
    def to_json(self) -> str:
        """转换为JSON字符串"""
        return json.dumps(self.to_dict(), ensure_ascii=False)
    
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


class FunctionResultsBuilder:
    """Function Results请求构建器"""
    
    @staticmethod
    def build_success_result(
        session_id: str,
        function_call_id: str,
        function_name: str,
        message: Optional[str] = None,
        data: Optional[Dict[str, Any]] = None
    ) -> FunctionResultRequest:
        """
        构建成功结果的请求
        
        Args:
            session_id: 会话ID
            function_call_id: 函数调用ID
            function_name: 函数名称
            message: 结果描述（可选）
            data: 附加数据（可选）
            
        Returns:
            FunctionResultRequest对象
        """
        result = {
            "success": True
        }
        if message:
            result["message"] = message
        if data:
            result["data"] = data
        
        return FunctionResultRequest(
            session_id=session_id,
            function_call_id=function_call_id,
            function_name=function_name,
            result=result
        )
    
    @staticmethod
    def build_error_result(
        session_id: str,
        function_call_id: str,
        function_name: str,
        error_message: str,
        error_code: Optional[int] = None
    ) -> FunctionResultRequest:
        """
        构建错误结果的请求
        
        Args:
            session_id: 会话ID
            function_call_id: 函数调用ID
            function_name: 函数名称
            error_message: 错误消息
            error_code: 错误码（可选）
            
        Returns:
            FunctionResultRequest对象
        """
        result = {
            "success": False,
            "message": error_message
        }
        if error_code:
            result["error_code"] = error_code
        
        return FunctionResultRequest(
            session_id=session_id,
            function_call_id=function_call_id,
            function_name=function_name,
            result=result
        )
    
    @staticmethod
    def build_from_operation_result(
        session_id: str,
        function_call_id: str,
        function_name: str,
        operation_success: bool,
        operation_data: Optional[Dict[str, Any]] = None,
        operation_message: Optional[str] = None
    ) -> FunctionResultRequest:
        """
        从操作结果构建请求
        
        Args:
            session_id: 会话ID
            function_call_id: 函数调用ID
            function_name: 函数名称
            operation_success: 操作是否成功
            operation_data: 操作返回的数据（可选）
            operation_message: 操作消息（可选）
            
        Returns:
            FunctionResultRequest对象
        """
        if operation_success:
            return FunctionResultsBuilder.build_success_result(
                session_id=session_id,
                function_call_id=function_call_id,
                function_name=function_name,
                message=operation_message,
                data=operation_data
            )
        else:
            return FunctionResultsBuilder.build_error_result(
                session_id=session_id,
                function_call_id=function_call_id,
                function_name=function_name,
                error_message=operation_message or "操作失败"
            )

