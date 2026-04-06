"""按 user_id 写入请求审计日志（延迟、token、回复预览）。可通过环境变量 AGENT_LOG_DIR 指定根目录。"""
from __future__ import annotations

import json
import os
import re
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Dict, Optional

_AUDIT_ROOT = Path(os.environ.get("AGENT_LOG_DIR", "logs/agent_requests")).resolve()


def _safe_uid(user_id: Optional[str]) -> str:
    s = (user_id or "anonymous").strip()
    if not s:
        s = "anonymous"
    s = re.sub(r"[^\w\-.@]", "_", s)[:120]
    return s or "anonymous"


def append_audit_line(
    *,
    user_id: Optional[str],
    session_id: Optional[str],
    trace: Optional[str],
    latency_ms: float,
    usage: Optional[Dict[str, Any]],
    text_preview: str,
    extra: Optional[Dict[str, Any]] = None,
) -> None:
    """追加一行 JSONL 到 logs/agent_requests/<uid>/requests.log"""
    uid = _safe_uid(user_id)
    path = _AUDIT_ROOT / uid
    try:
        path.mkdir(parents=True, exist_ok=True)
    except OSError:
        return
    log_file = path / "requests.log"
    row: Dict[str, Any] = {
        "ts": datetime.now(timezone.utc).isoformat(),
        "user_id": user_id,
        "session_id": session_id,
        "trace": trace,
        "latency_ms": round(latency_ms, 2),
        "usage": usage or {},
        "text_preview": (text_preview or "")[:2000],
    }
    if extra:
        row["extra"] = extra
    try:
        with open(log_file, "a", encoding="utf-8") as f:
            f.write(json.dumps(row, ensure_ascii=False) + "\n")
    except OSError:
        pass
