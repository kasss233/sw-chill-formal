#!/usr/bin/env python3
"""运行反思 Agent 相关测试"""
import sys
from pathlib import Path

_root = Path(__file__).resolve().parent
sys.path.insert(0, str(_root))

from tests.test_reflection_agent import run_all

if __name__ == "__main__":
    run_all()
