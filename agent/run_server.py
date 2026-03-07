#!/usr/bin/env python3
"""启动 Agent HTTP 服务（host/port 从 config/settings.yaml 读取）"""
import sys
from pathlib import Path

# 确保项目根在 path 中
_root = Path(__file__).resolve().parent
if str(_root) not in sys.path:
    sys.path.insert(0, str(_root))

from http_server.server import run_server

if __name__ == "__main__":
    run_server()
