#!/usr/bin/env python3
"""统一启动入口：默认启动 HTTP 服务（与 run_server 相同）"""
import sys
from pathlib import Path

_root = Path(__file__).resolve().parent
if str(_root) not in sys.path:
    sys.path.insert(0, str(_root))

from http_server.server import run_server

if __name__ == "__main__":
    run_server()
