"""
Server API抽象接口
所有需要调用server接口的操作都在此定义抽象方法
具体实现由用户自行完成
"""
from abc import ABC, abstractmethod
from datetime import datetime
from typing import List, Optional, Dict, Any

from models.focus import FocusRecord, FocusType
from models.performance import PerformanceSequence
from models.task import Project, Task


class ServerAPI(ABC):
    """Server API抽象接口"""
    
    # ====== 任务相关操作 ======
    
    @abstractmethod
    def get_projects(self) -> List[Project]:
        """获取所有项目列表"""
        pass
    
    @abstractmethod
    def get_project(self, project_id: str) -> Optional[Project]:
        """获取指定项目"""
        pass
    
    @abstractmethod
    def create_project(self, project: Project) -> Project:
        """创建项目"""
        pass
    
    @abstractmethod
    def update_project(self, project_id: str, project: Project) -> Project:
        """更新项目"""
        pass
    
    @abstractmethod
    def delete_project(self, project_id: str) -> bool:
        """删除项目"""
        pass
    
    @abstractmethod
    def get_tasks(self, project_id: Optional[str] = None) -> List[Task]:
        """获取任务列表，可指定项目ID"""
        pass
    
    @abstractmethod
    def get_task(self, task_id: str) -> Optional[Task]:
        """获取指定任务"""
        pass
    
    @abstractmethod
    def create_task(self, task: Task) -> Task:
        """创建任务"""
        pass
    
    @abstractmethod
    def update_task(self, task_id: str, task: Task) -> Task:
        """更新任务"""
        pass
    
    @abstractmethod
    def delete_task(self, task_id: str) -> bool:
        """删除任务"""
        pass
    
    @abstractmethod
    def complete_task(self, task_id: str) -> bool:
        """标记任务为已完成"""
        pass
    
    @abstractmethod
    def uncomplete_task(self, task_id: str) -> bool:
        """取消任务完成状态"""
        pass
    
    @abstractmethod
    def reorder_tasks(self, task_ids: List[str]) -> bool:
        """重新排序任务"""
        pass
    
    # ====== 专注相关操作 ======
    
    @abstractmethod
    def start_focus(self, focus_type: FocusType, task_id: Optional[str] = None) -> FocusRecord:
        """开始专注"""
        pass
    
    @abstractmethod
    def end_focus(self, focus_record_id: str) -> FocusRecord:
        """结束专注"""
        pass
    
    @abstractmethod
    def get_focus_records(
        self,
        start_date: Optional[datetime] = None,
        end_date: Optional[datetime] = None,
        task_id: Optional[str] = None
    ) -> List[FocusRecord]:
        """获取专注记录列表"""
        pass
    
    # ====== 场景和环境控制 ======
    
    @abstractmethod
    def update_scene_components(self, component_configs: Dict[str, Any]) -> bool:
        """
        更新场景组件
        
        Args:
            component_configs: 组件配置字典，key为组件名，value为配置
            
        Returns:
            是否成功
        """
        pass
    
    @abstractmethod
    def update_bgm(
        self,
        action: str,
        volume: Optional[float] = None,
        track_id: Optional[str] = None,
        play: Optional[bool] = None
    ) -> bool:
        """
        更新背景音乐
        
        Args:
            action: 操作类型 "volume" | "switch" | "toggle"
            volume: 音量（0.0-1.0），当action为volume时使用
            track_id: 歌曲ID，当action为switch时使用
            play: 播放状态，当action为toggle时使用
            
        Returns:
            是否成功
        """
        pass
    
    @abstractmethod
    def update_ambient_noise(self, enabled: bool, volume: float = 0.5) -> bool:
        """
        更新环境白噪音
        
        Args:
            enabled: 是否启用
            volume: 音量（0.0-1.0）
            
        Returns:
            是否成功
        """
        pass
    
    # ====== 演出相关 ======
    
    @abstractmethod
    def play_performance(self, performance_sequence: PerformanceSequence) -> bool:
        """
        播放演出脚本序列
        
        Args:
            performance_sequence: 演出脚本序列
            
        Returns:
            是否成功
        """
        pass
    
    # ====== 统计和查询 ======
    
    @abstractmethod
    def get_daily_summary(self, date: datetime) -> Dict[str, Any]:
        """
        获取当日概览
        
        Args:
            date: 日期
            
        Returns:
            包含已完成任务、专注时间等信息的字典
        """
        pass
    
    @abstractmethod
    def get_statistics(
        self,
        start_date: datetime,
        end_date: datetime,
        period: str = "day"  # day | week | month
    ) -> Dict[str, Any]:
        """
        获取统计信息
        
        Args:
            start_date: 开始日期
            end_date: 结束日期
            period: 统计周期
            
        Returns:
            统计数据字典
        """
        pass

