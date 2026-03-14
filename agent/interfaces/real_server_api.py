"""
RealServerAPI：调用真实后端 http://106.54.18.206:8000/api/v1

需在配置或环境变量中提供 base_url、access_token（可选）。
未实现的方法（写操作、专注、场景等）返回占位或 NotImplementedError。
"""
from __future__ import annotations

import json
import urllib.request
import urllib.error
from datetime import datetime
from typing import List, Optional, Dict, Any

from models.focus import FocusRecord, FocusType
from models.performance import PerformanceSequence
from models.task import Project, Task, TaskInfo, TaskOwner

from .server_api import ServerAPI


def _parse_api_response(body: bytes) -> Dict[str, Any]:
    try:
        return json.loads(body.decode("utf-8"))
    except (json.JSONDecodeError, UnicodeDecodeError):
        return {"code": -1, "message": "invalid response", "data": None}


def _get(
    url: str,
    headers: Dict[str, str],
    timeout: float = 10.0,
) -> Dict[str, Any]:
    req = urllib.request.Request(url, headers=headers, method="GET")
    with urllib.request.urlopen(req, timeout=timeout) as resp:
        return _parse_api_response(resp.read())


def _backend_task_to_task(item: Dict[str, Any]) -> Task:
    """后端任务项转为 Task 模型"""
    tid = item.get("id")
    task_id = str(tid) if tid is not None else None
    due_ts = item.get("due_timestamp") or 0
    deadline = datetime.fromtimestamp(due_ts) if due_ts else None
    return Task(
        id=task_id,
        project_id="root",
        info=TaskInfo(
            description=item.get("title") or "新任务",
            owner=TaskOwner.USER,
        ),
        completed=bool(item.get("is_completed", False)),
        sort_order=int(item.get("order", 0)),
        deadline=deadline,
    )


class RealServerAPI(ServerAPI):
    """基于真实后端 API 的 ServerAPI 实现。仅实现查询与统计相关方法。"""

    def __init__(
        self,
        base_url: str = "http://106.54.18.206:8000/api/v1",
        access_token: Optional[str] = None,
        timeout: float = 10.0,
    ):
        self.base_url = base_url.rstrip("/")
        self.access_token = access_token or ""
        self.timeout = timeout

    def _headers(self) -> Dict[str, str]:
        h = {"Content-Type": "application/json", "Accept": "application/json"}
        if self.access_token:
            h["Authorization"] = f"Bearer {self.access_token}"
        return h

    # ====== 任务：仅实现查询（后端 Task API 为只读）======
    def get_projects(self) -> List[Project]:
        return [
            Project(
                id="root",
                name="默认项目",
                color="#FFB74D",
                owner=TaskOwner.USER,
                completed=False,
                sort_order=0,
            )
        ]

    def get_project(self, project_id: str) -> Optional[Project]:
        for p in self.get_projects():
            if p.id == project_id:
                return p
        return None

    def get_tasks(self, project_id: Optional[str] = None) -> List[Task]:
        url = f"{self.base_url}/tasks"
        try:
            out = _get(url, self._headers(), self.timeout)
        except urllib.error.URLError:
            return []
        if out.get("code") != 0 or "data" not in out:
            return []
        data = out["data"]
        items = data.get("items") if isinstance(data, dict) else []
        if not isinstance(items, list):
            return []
        return [_backend_task_to_task(i) for i in items]

    def get_task(self, task_id: str) -> Optional[Task]:
        url = f"{self.base_url}/tasks/{task_id}"
        try:
            out = _get(url, self._headers(), self.timeout)
        except urllib.error.URLError:
            return None
        if out.get("code") != 0 or not out.get("data"):
            return None
        return _backend_task_to_task(out["data"])

    def create_project(self, project: Project) -> Project:
        raise NotImplementedError("后端未暴露项目创建 API，请通过 Sync 或本地实现")

    def update_project(self, project_id: str, project: Project) -> Project:
        raise NotImplementedError("后端未暴露项目更新 API")

    def delete_project(self, project_id: str) -> bool:
        raise NotImplementedError("后端未暴露项目删除 API")

    def create_task(self, task: Task) -> Task:
        raise NotImplementedError("任务写操作由前端 + Sync API 完成")

    def update_task(self, task_id: str, task: Task) -> Task:
        raise NotImplementedError("任务写操作由前端 + Sync API 完成")

    def delete_task(self, task_id: str) -> bool:
        raise NotImplementedError("任务写操作由前端 + Sync API 完成")

    def complete_task(self, task_id: str) -> bool:
        raise NotImplementedError("任务写操作由前端 + Sync API 完成")

    def uncomplete_task(self, task_id: str) -> bool:
        raise NotImplementedError("任务写操作由前端 + Sync API 完成")

    def reorder_tasks(self, task_ids: List[str]) -> bool:
        raise NotImplementedError("任务写操作由前端 + Sync API 完成")

    # ====== 专注 ======
    def start_focus(
        self, focus_type: FocusType, task_id: Optional[str] = None
    ) -> FocusRecord:
        raise NotImplementedError("专注记录请使用本地或专用 API")

    def end_focus(self, focus_record_id: str) -> FocusRecord:
        raise NotImplementedError("专注记录请使用本地或专用 API")

    def get_focus_records(
        self,
        start_date: Optional[datetime] = None,
        end_date: Optional[datetime] = None,
        task_id: Optional[str] = None,
    ) -> List[FocusRecord]:
        return []

    # ====== 场景 / 音频 / 演出 ======
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

    # ====== 统计（ReflectionAgent 依赖）======
    def get_daily_summary(self, date: datetime) -> Dict[str, Any]:
        """基于 GET /tasks 聚合当日概览；若后端有专用日总结接口可替换。"""
        tasks = self.get_tasks()
        date_str = date.strftime("%Y-%m-%d")
        day_start = datetime.strptime(date_str, "%Y-%m-%d")
        day_end = day_start.replace(hour=23, minute=59, second=59, microsecond=999999)
        completed = [t for t in tasks if t.completed and t.deadline and day_start <= t.deadline <= day_end]
        return {
            "date": date_str,
            "tasks": {"completed_count": len(completed), "total_count": len(tasks)},
            "pomodoro": {"total_focus_minutes": 0, "session_count": 0},
            "habits": {"checkin_rate": 0.0},
            "energy": {"average_energy_level": 0.0},
            "emotion": {"dominant_mood": ""},
        }

    def get_statistics(
        self,
        start_date: datetime,
        end_date: datetime,
        period: str = "day",
    ) -> Dict[str, Any]:
        """基于 GET /tasks 聚合区间统计；若后端有专用统计接口可替换。"""
        tasks = self.get_tasks()
        total = len(tasks)
        completed = len([t for t in tasks if t.completed])
        rate = (completed / total) if total else 0.0
        days = max(1, (end_date.date() - start_date.date()).days + 1)
        return {
            "meta": {
                "start_date": start_date.strftime("%Y-%m-%d"),
                "end_date": end_date.strftime("%Y-%m-%d"),
                "period": period,
                "days": days,
            },
            "tasks": {
                "total_count": total,
                "completed_count": completed,
                "completion_rate": rate,
                "by_weekday": {},
                "by_time_block": {},
            },
            "habits": {"average_checkin_rate": 0.0, "streak_days": 0},
            "pomodoro": {
                "total_focus_minutes": 0,
                "session_count": 0,
                "average_session_minutes": 0,
            },
            "energy": {
                "average_energy_level": 0.0,
                "high_energy_periods": [],
                "low_energy_periods": [],
            },
            "emotion": {
                "overall_mood_trend": "",
                "positive_ratio": 0.0,
                "negative_ratio": 0.0,
            },
        }
