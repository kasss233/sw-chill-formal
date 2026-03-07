#!/usr/bin/env python3
"""统一测试入口：依次运行 chat_agent、reflection_agent 等测试"""
import sys
from pathlib import Path

_root = Path(__file__).resolve().parent
sys.path.insert(0, str(_root))

def main():
    from tests import test_chat_agent
    from tests import test_reflection_agent
    print("=== test_chat_agent ===")
    test_chat_agent.run_all()
    print("=== test_reflection_agent ===")
    test_reflection_agent.run_all()
    print("=== 全部测试通过 ===")

if __name__ == "__main__":
    main()
