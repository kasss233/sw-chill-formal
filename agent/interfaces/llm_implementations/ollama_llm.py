"""
Ollama LLM实现
使用Ollama的HTTP API进行对话生成
"""
import json
from typing import List, Optional

import requests

from interfaces.llm import LLMInterface, LLMMessage, LLMResponse


class OllamaLLM(LLMInterface):
    """Ollama LLM实现"""
    
    def __init__(self, base_url: str = "http://localhost:11434", model: str = "tinyllama", **kwargs):
        """
        初始化Ollama LLM
        
        Args:
            base_url: Ollama服务地址，默认 http://localhost:11434
            model: 模型名称，默认 tinyllama（1.1B参数，适合测试）
            **kwargs: 其他参数
        """
        self.base_url = base_url.rstrip('/')
        self.model = model
        self.chat_endpoint = f"{self.base_url}/api/chat"
        self.generate_endpoint = f"{self.base_url}/api/generate"
    
    def chat(
        self,
        messages: List[LLMMessage],
        temperature: float = 0.7,
        max_tokens: Optional[int] = None,
        **kwargs
    ) -> LLMResponse:
        """
        实现Ollama对话生成
        
        Args:
            messages: 消息列表
            temperature: 温度参数
            max_tokens: 最大生成token数（Ollama使用num_predict参数）
            **kwargs: 其他参数
            
        Returns:
            LLM响应
        """
        # 转换消息格式为Ollama格式
        ollama_messages = []
        for msg in messages:
            ollama_messages.append({
                "role": msg.role,
                "content": msg.content
            })
        
        # 构建请求参数
        payload = {
            "model": self.model,
            "messages": ollama_messages,
            "temperature": temperature,
            "stream": False
        }
        
        if max_tokens is not None:
            payload["options"] = {
                "num_predict": max_tokens
            }
        
        # 发送请求
        try:
            response = requests.post(
                self.chat_endpoint,
                json=payload,
                timeout=120  # 120秒超时
            )
            response.raise_for_status()
            
            result = response.json()
            content = result.get("message", {}).get("content", "")
            
            return LLMResponse(
                content=content,
                metadata={
                    "model": result.get("model", self.model),
                    "total_duration": result.get("total_duration", 0),
                    "eval_count": result.get("eval_count", 0),
                }
            )
        except requests.exceptions.RequestException as e:
            raise RuntimeError(f"Ollama API调用失败: {str(e)}")
    
    def stream_chat(
        self,
        messages: List[LLMMessage],
        temperature: float = 0.7,
        max_tokens: Optional[int] = None,
        **kwargs
    ):
        """
        实现Ollama流式对话生成
        
        Args:
            messages: 消息列表
            temperature: 温度参数
            max_tokens: 最大生成token数
            **kwargs: 其他参数
            
        Yields:
            str: 生成的文本片段
        """
        # 转换消息格式为Ollama格式
        ollama_messages = []
        for msg in messages:
            ollama_messages.append({
                "role": msg.role,
                "content": msg.content
            })
        
        # 构建请求参数
        payload = {
            "model": self.model,
            "messages": ollama_messages,
            "temperature": temperature,
            "stream": True
        }
        
        if max_tokens is not None:
            payload["options"] = {
                "num_predict": max_tokens
            }
        
        # 发送流式请求
        try:
            response = requests.post(
                self.chat_endpoint,
                json=payload,
                stream=True,
                timeout=120
            )
            response.raise_for_status()
            
            for line in response.iter_lines():
                if line:
                    try:
                        data = json.loads(line)
                        content = data.get("message", {}).get("content", "")
                        if content:
                            yield content
                    except json.JSONDecodeError:
                        continue
        except requests.exceptions.RequestException as e:
            raise RuntimeError(f"Ollama API流式调用失败: {str(e)}")
    
    def count_tokens(self, text: str) -> int:
        """
        实现token计数
        注意：Ollama没有直接的token计数API，这里使用简单估算
        
        Args:
            text: 输入文本
            
        Returns:
            估算的token数量
        """
        # 简单估算：英文约4字符=1token，中文约1.5字符=1token
        # 这里使用更保守的估算：平均每个中文字符1.5个token
        chinese_chars = sum(1 for c in text if '\u4e00' <= c <= '\u9fff')
        other_chars = len(text) - chinese_chars
        
        # 中文：1字符 ≈ 1.5 tokens，英文：4字符 ≈ 1 token
        estimated_tokens = int(chinese_chars * 1.5 + other_chars / 4)
        
        return max(estimated_tokens, len(text) // 4)  # 至少返回一个合理值

