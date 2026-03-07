"""
SimpleServerAPI：ServerAPI 的简单实现

用途：
- 在后端尚未部署或统计接口尚未完成时，本地用一些预设数据模拟服务端返回，
  便于调试「反思与总结」相关流程。

说明：
- 这里只对 ReflectionAgent 依赖的方法（get_statistics / get_daily_summary）
  做了稍微真实一点的模拟，其余方法返回占位数据或简单 True。
- 真正落地时，请在后端实现真实的统计逻辑，然后编写一个正式的
  ServerAPI 实现类替换本 SimpleServerAPI。
"""

from __future__ import annotations

from datetime import datetime, timedelta
from typing import List, Optional, Dict, Any

from models.focus import FocusRecord, FocusType
from models.performance import PerformanceSequence
from models.task import Project, Task, TaskInfo, TaskOwner
from .server_api import ServerAPI


class SimpleServerAPI(ServerAPI):
    """
    ServerAPI 的简单内存实现。

    - 使用少量硬编码的任务与专注记录，生成一个「看起来合理」的统计结果；
    - 主要服务于 ReflectionAgent 的本地测试，不考虑持久化与多用户。
    """

    def __init__(self) -> None:
        # 简单构造一些示例任务与专注记录
        today = datetime.now().date()

        self._projects: List[Project] = [
            Project(
                id="root",
                name="默认项目",
                color="#FFB74D",
                owner=TaskOwner.USER,
                completed=False,
                sort_order=0,
            )
        ]

        self._tasks: List[Task] = [
            Task(
                id="task_1",
                project_id="root",
                info=TaskInfo(
                    description="完成本周课程作业",
                    owner=TaskOwner.USER,
                ),
                completed=True,
                sort_order=0,
                deadline=datetime.combine(today, datetime.min.time()),
            ),
            Task(
                id="task_2",
                project_id="root",
                info=TaskInfo(
                    description="坚持三天早起阅读 30 分钟",
                    owner=TaskOwner.USER,
                ),
                completed=False,
                sort_order=1,
            ),
        ]

        # 模拟几条专注记录（番茄钟）
        self._focus_records: List[FocusRecord] = []
        start = datetime.now() - timedelta(hours=3)
        self._focus_records.append(
            FocusRecord(
                id="focus_1",
                start_time=start,
                end_time=start + timedelta(minutes=25),
                duration=25 * 60,
                focus_type=FocusType.TOMATO,
                task_id="task_1",
            )
        )

    # ====== 任务相关 ======

    def get_projects(self) -> List[Project]:
        return list(self._projects)

    def get_project(self, project_id: str) -> Optional[Project]:
        for p in self._projects:
            if p.id == project_id:
                return p
        return None

    def create_project(self, project: Project) -> Project:
        self._projects.append(project)
        return project

    def update_project(self, project_id: str, project: Project) -> Project:
        for idx, p in enumerate(self._projects):
            if p.id == project_id:
                self._projects[idx] = project
                break
        return project

    def delete_project(self, project_id: str) -> bool:
        before = len(self._projects)
        self._projects = [p for p in self._projects if p.id != project_id]
        return len(self._projects) < before

    def get_tasks(self, project_id: Optional[str] = None) -> List[Task]:
        if project_id is None:
            return list(self._tasks)
        return [t for t in self._tasks if t.project_id == project_id]

    def get_task(self, task_id: str) -> Optional[Task]:
        for t in self._tasks:
            if t.id == task_id:
                return t
        return None

    def create_task(self, task: Task) -> Task:
        # 简单追加；不做 ID 去重校验
        self._tasks.append(task)
        return task

    def update_task(self, task_id: str, task: Task) -> Task:
        for idx, t in enumerate(self._tasks):
            if t.id == task_id:
                self._tasks[idx] = task
                break
        return task

    def delete_task(self, task_id: str) -> bool:
        before = len(self._tasks)
        self._tasks = [t for t in self._tasks if t.id != task_id]
        return len(self._tasks) < before

    def complete_task(self, task_id: str) -> bool:
        t = self.get_task(task_id)
        if not t:
            return False
        t.completed = True
        return True

    def uncomplete_task(self, task_id: str) -> bool:
        t = self.get_task(task_id)
        if not t:
       	    return False
        t.completed = False
        return True

    def reorder_tasks(self, task_ids: List[str]) -> bool:
        # 简单按照给定顺序重排
        id_to_task = {t.id: t for t in self._tasks if t.id is not None}
        new_list: List[Task] = []
        for sort_order, tid in enumerate(task_ids):
            task = id_to_task.get(tid)
            if task:
                task.sort_order = sort_order
                new_list.append(task)
        # 其余未出现在 task_ids 中的追加在后面
        used_ids = set(task_ids)
        rest = [t for t in self._tasks if t.id not in used_ids]
        new_list.extend(rest)
        self._tasks = new_list
        return True

    # ====== 专注相关 ======

    def start_focus(
        self, focus_type: FocusType, task_id: Optional[str] = None
    ) -> FocusRecord:
        start = datetime.now()
        record = FocusRecord(
            id=f"focus_{len(self._focus_records) + 1}",
            start_time=start,
            duration=0,
            focus_type=focus_type,
            task_id=task_id,
        )
        self._focus_records.append(record)
        return record

    def end_focus(self, focus_record_id: str) -> FocusRecord:
        for rec in self._focus_records:
            if rec.id == focus_record_id:
                if rec.end_time is None:
                    rec.end_time = datetime.now()
                    rec.duration = int((rec.end_time - rec.start_time).total_seconds())
                return rec
        # 找不到就返回一个占位对象
        return FocusRecord(
            id=focus_record_id,
            start_time=datetime.now(),
            end_time=datetime.now(),
            duration=0,
            focus_type=FocusType.FREE,
        )

    def get_focus_records(
        self,
        start_date: Optional[datetime] = None,
        end_date: Optional[datetime] = None,
        task_id: Optional[str] = None,
    ) -> List[FocusRecord]:
        records = list(self._focus_records)
        if start_date is not None:
            records = [r for r in records if r.start_time >= start_date]
        if end_date is not None:
            records = [r for r in records if r.start_time <= end_date]
        if task_id is not None:
            records = [r for r in records if r.task_id == task_id]
        return records

    # ====== 场景 / 音频 / 演出（占位实现） ======

    def update_scene_components(self, component_configs: Dict[str, Any]) -> bool:
        return True

    def update_bgm(
        self,
        action: str,
        volume: Optional[float] = None,
        track_id: Optional[str] = None,
        play: Optional[bool] = None,
    ) -> bool:
        return True

    def update_ambient_noise(self, enabled: bool, volume: float = 0.5) -> bool:
        return True

    def play_performance(self, performance_sequence: PerformanceSequence) -> bool:
        return True

    # ====== 统计相关（ReflectionAgent 主要依赖部分） ======

    def get_daily_summary(self, date: datetime) -> Dict[str, Any]:
        """
        返回某一天的概览信息。

        注意：这里只是示例结构，用于演示 ReflectionAgent 如何消费数据。
        真正后端实现可以自由扩展字段，但建议至少保留这些 key，方便文档对齐。
        """
        date_str = date.strftime("%Y-%m-%d")
        completed_tasks = [t for t in self._tasks if t.completed]

        total_focus_seconds = sum(r.duration for r in self._focus_records)
        total_focus_minutes = round(total_focus_seconds / 60)

        return {
            "date": date_str,
            "tasks": {
                "completed_count": len(completed_tasks),
                "total_count": len(self._tasks),
            },
            "pomodoro": {
                "total_focus_minutes": total_focus_minutes,
                "session_count": len(self._focus_records),
            },
            # 下面这些字段在真实后端中需要从对应模块收集
            "habits": {
                "checkin_rate": 0.8,  # 示例值：80% 打卡率
            },
            "energy": {
                "average_energy_level": 0.7,  # 0-1 区间的主观精力水平
            },
            "emotion": {
                "dominant_mood": "平稳偏积极",
            },
        }

    def get_statistics(
        self,
        start_date: datetime,
        end_date: datetime,
        period: str = "day",
    ) -> Dict[str, Any]:
        """
        返回一段时间内的综合统计信息。

        字段说明请参考 docs/reflection_agent.md 中的「统计数据结构」章节。
        这里给出一个最小可用的示例结构。
        """
        days = max(1, (end_date.date() - start_date.date()).days + 1)

        total_tasks = len(self._tasks)
        completed_tasks = len([t for t in self._tasks if t.completed])
        completion_rate = (completed_tasks / total_tasks) if total_tasks > 0 else 0.0

        total_focus_seconds = sum(r.duration for r in self._focus_records)
        total_focus_minutes = round(total_focus_seconds / 60)

        return {
            "meta": {
                "start_date": start_date.strftime("%Y-%m-%d"),
                "end_date": end_date.strftime("%Y-%m-%d"),
                "period": period,
                "days": days,
            },
            "tasks": {
                "total_count": total_tasks,
                "completed_count": completed_tasks,
                "completion_rate": completion_rate,
                # 示例：可以在真实后端里按星期 / 时段再细分
                "by_weekday": {},
                "by_time_block": {},
            },
            "habits": {
                # 示例字段：真实后端需接入习惯系统的打卡记录
                "average_checkin_rate": 0.75,
                "streak_days": 3,
            },
            "pomodoro": {
                "total_focus_minutes": total_focus_minutes,
                "session_count": len(self._focus_records),
                "average_session_minutes": (
                    total_focus_minutes / len(self._focus_records)
                    if self._focus_records
                    else 0
                ),
            },
            "energy": {
                # 示例：真实实现应给出「一天内能量曲线」等更细致数据
                "average_energy_level": 0.68,
                "high_energy_periods": ["上午", "傍晚"],
                "low_energy_periods": ["深夜"],
            },
            "emotion": {
                # 示例：真实实现可基于聊天情绪分析得到情绪轨迹
                "overall_mood_trend": "略微向上",
                "positive_ratio": 0.72,
                "negative_ratio": 0.12,
            },
        }

