"""
Agent核心实现
整合LLM、记忆、任务生成等功能
"""
import re
from datetime import datetime
from typing import List, Optional, Dict, Any

from pydantic import BaseModel

from interfaces.llm import LLMInterface, LLMMessage
from interfaces.memory import MemoryInterface
from interfaces.server_api import ServerAPI
from models.task import Task
from response import AgentResponse


class AgentConfig(BaseModel):
    """Agent配置"""
    character_name: str = "女孩"
    character_personality: str = "温柔、体贴，以鼓励和支持为主"
    system_prompt_template: str = """你是一位名为{character_name}的AI陪伴角色。
性格特点：{character_personality}
你需要陪伴用户，提供情感支持和生产力协助。
在与用户对话时，要符合你的角色设定，并考虑上下文中的记忆信息。

你的能力：
你可以帮助用户管理任务和项目。当用户请求创建任务列表、添加任务、安排学习计划等时，
你应该积极地提供建议并准备创建相应的任务（具体任务创建由系统完成，你只需要提供友好的回复）。

重要要求：
1. 你必须使用中文与用户对话
2. 回复要符合你的角色设定，语气要{character_personality}
3. 回复要简洁、温暖、自然，就像朋友间的对话
4. 当用户请求创建任务或学习计划时，除了文字回复，系统会自动为你创建相应的任务"""
    
    # LLM参数
    temperature: float = 0.7
    max_tokens: Optional[int] = None
    
    # 记忆相关
    memory_top_k: int = 5
    memory_max_tokens: int = 2000


class Agent:
    """Agent核心类"""
    
    def __init__(
        self,
        llm: LLMInterface,
        memory: MemoryInterface,
        server_api: ServerAPI,
        config: Optional[AgentConfig] = None
    ):
        """
        初始化Agent
        
        Args:
            llm: LLM接口实现
            memory: 记忆接口实现
            server_api: Server API接口实现
            config: Agent配置
        """
        self.llm = llm
        self.memory = memory
        self.server_api = server_api
        self.config = config or AgentConfig()
        
        # 对话历史（可考虑限制长度）
        self.conversation_history: List[LLMMessage] = []
    
    def _get_system_prompt(self) -> str:
        """获取系统提示词"""
        return self.config.system_prompt_template.format(
            character_name=self.config.character_name,
            character_personality=self.config.character_personality
        )
    
    def _get_context_messages(self, user_message: str) -> List[LLMMessage]:
        """
        构建包含记忆上下文的消息列表
        
        Args:
            user_message: 用户消息
            
        Returns:
            消息列表
        """
        # 获取相关记忆
        memory_context = self.memory.get_memory_context(
            query=user_message,
            max_tokens=self.config.memory_max_tokens
        )
        
        # 构建系统提示词（包含记忆上下文）
        system_prompt = self._get_system_prompt()
        if memory_context:
            system_prompt += f"\n\n相关记忆：\n{memory_context}"
        
        messages = [LLMMessage(role="system", content=system_prompt)]
        
        # 添加对话历史（可选：限制长度）
        messages.extend(self.conversation_history[-10:])  # 保留最近10轮对话
        
        # 添加当前用户消息
        messages.append(LLMMessage(role="user", content=user_message))
        
        return messages
    
    def _detect_task_creation_intent(self, user_message: str) -> bool:
        """
        检测用户是否有创建任务的意图
        
        Args:
            user_message: 用户消息
            
        Returns:
            是否有创建任务意图
        """
        task_keywords = ["列表", "任务", "计划", "学习计划", "待办", "清单", "帮我列", "安排"]
        return any(keyword in user_message for keyword in task_keywords)
    
    def chat(self, user_message: str) -> AgentResponse:
        """
        处理用户对话
        
        Args:
            user_message: 用户消息
            
        Returns:
            Agent响应（包含文本、演出脚本和操作）
        """
        # 构建消息
        messages = self._get_context_messages(user_message)
        
        # 调用LLM生成响应
        llm_response = self.llm.chat(
            messages=messages,
            temperature=self.config.temperature,
            max_tokens=self.config.max_tokens
        )
        
        response_text = llm_response.content
        performance_sequence = None  # TODO: 从LLM响应中解析演出脚本
        operations = []
        
        # 检测任务创建意图并生成操作
        if self._detect_task_creation_intent(user_message):
            try:
                tasks = self.generate_tasks_from_conversation(user_message)
                # 将任务转换为TaskCreateOperation
                from response import TaskCreateOperation
                for task in tasks:
                    operations.append(TaskCreateOperation(task=task))
            except NotImplementedError:
                # 如果任务生成方法未实现，跳过
                pass
            except Exception as e:
                # 记录错误但不影响对话流程
                print(f"[警告] 任务生成失败: {e}")
        
        # 更新对话历史
        self.conversation_history.append(LLMMessage(role="user", content=user_message))
        self.conversation_history.append(LLMMessage(role="assistant", content=response_text))
        
        # 保存对话到记忆（可选择性保存重要对话）
        # self.memory.add_memory(...)
        
        return AgentResponse(
            text=response_text,
            performance_sequence=performance_sequence,
            operations=operations
        )
    
    def generate_tasks_from_conversation(self, conversation_text: str) -> List[Task]:
        """
        从对话生成任务列表
        
        Args:
            conversation_text: 对话文本
            
        Returns:
            生成的任务列表
        """
        from models.task import Task, TaskInfo, TaskOwner
        
        # 构建任务生成的提示词
        task_generation_prompt = f"""用户请求：{conversation_text}

请根据用户的请求，生成一个结构化的任务列表。任务应该是具体的、可执行的步骤。

要求：
1. 任务数量控制在3-8个之间
2. 每个任务应该是清晰、具体的行动项
3. 任务应该按照逻辑顺序排列
4. 用简洁的中文描述每个任务（每个任务描述不超过30字）

请按以下格式输出任务列表，每行一个任务：
1. 任务描述1
2. 任务描述2
3. 任务描述3
..."""
        
        # 调用LLM生成任务描述
        messages = [
            LLMMessage(role="system", content="你是一个任务规划助手，擅长将用户的目标转化为具体的任务列表。"),
            LLMMessage(role="user", content=task_generation_prompt)
        ]
        
        llm_response = self.llm.chat(
            messages=messages,
            temperature=0.7,
            max_tokens=500
        )
        
        # 解析任务列表（从文本中提取任务描述）
        tasks = []
        task_text = llm_response.content
        
        # 简单解析：提取编号列表中的任务
        lines = task_text.split('\n')
        sort_order = 0
        for line in lines:
            line = line.strip()
            if not line:
                continue
            
            # 匹配 "1. 任务描述" 或 "- 任务描述" 格式
            match = re.match(r'^\d+[\.、]\s*(.+)$', line) or re.match(r'^[-•]\s*(.+)$', line)
            if match:
                task_description = match.group(1).strip()
                if task_description:
                    # 创建任务对象
                    task = Task(
                        id=None,  # ID由server API生成
                        project_id="root",  # 默认项目
                        info=TaskInfo(
                            description=task_description,
                            owner=TaskOwner.GIRL  # 由女孩创建的任务
                        ),
                        sort_order=sort_order
                    )
                    tasks.append(task)
                    sort_order += 1
        
        # 如果解析失败，至少创建一个基础任务
        if not tasks:
            # 从用户消息中提取关键词作为任务描述
            task_description = conversation_text[:50]  # 取前50个字符
            task = Task(
                id=None,
                project_id="root",
                info=TaskInfo(
                    description=f"完成：{task_description}",
                    owner=TaskOwner.GIRL
                ),
                sort_order=0
            )
            tasks.append(task)
        
        return tasks
    
    def suggest_task_schedule(self, tasks: List[Task]) -> Dict[str, Any]:
        """
        为用户合理安排任务时间
        
        Args:
            tasks: 任务列表
            
        Returns:
            时间安排建议（字典格式）
        """
        # TODO: 实现时间安排建议逻辑
        raise NotImplementedError("需要实现时间安排建议逻辑")
    
    def generate_summary(
        self,
        start_date: datetime,
        end_date: datetime,
        period: str = "week"
    ) -> str:
        """
        生成个性化周报/总结
        
        Args:
            start_date: 开始日期
            end_date: 结束日期
            period: 时间段（week/month等）
            
        Returns:
            总结文本
        """
        # 获取统计数据
        stats = self.server_api.get_statistics(start_date, end_date, period)
        
        # TODO: 使用LLM生成个性化的总结文本
        raise NotImplementedError("需要实现总结生成逻辑")

