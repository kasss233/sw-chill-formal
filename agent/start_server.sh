#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"

if command -v python3 >/dev/null 2>&1; then
  exec python3 run_server.py
elif command -v python >/dev/null 2>&1; then
  exec python run_server.py
else
  echo "[错误] 未找到 python3 或 python，请先安装 Python 3。" >&2
  exit 1
fi
