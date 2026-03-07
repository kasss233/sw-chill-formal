"""反思 Agent 测试：config、prompt_builder、agent 与 generate_period_summary pipeline"""
import sys
from pathlib import Path
from datetime import datetime, timedelta

_root = Path(__file__).resolve().parent.parent
if str(_root) not in sys.path:
    sys.path.insert(0, str(_root))


def test_reflection_config():
    """测试 ReflectionAgentConfig 默认值与字段"""
    from agent.reflection_agent import ReflectionAgentConfig
    config = ReflectionAgentConfig(character_name="测试角色", max_tokens=500)
    assert config.character_name == "测试角色"
    assert config.max_tokens == 500


def test_build_system_prompt():
    """测试 prompt_builder.build_system_prompt"""
    from agent.reflection_agent.config import ReflectionAgentConfig
    from agent.reflection_agent.prompt_builder import build_system_prompt
    config = ReflectionAgentConfig(character_name="小镜", style_hint="简洁")
    out = build_system_prompt(config)
    assert "小镜" in out
    assert "简洁" in out


def test_build_user_prompt():
    """测试 prompt_builder.build_user_prompt 结构"""
    from agent.reflection_agent.prompt_builder import build_user_prompt
    start = datetime(2026, 3, 1)
    end = datetime(2026, 3, 7)
    stats = {"tasks": {"total_count": 5, "completed_count": 3}}
    out = build_user_prompt(
        start_date=start,
        end_date=end,
        period="week",
        trigger="manual",
        stats=stats,
        daily_summary={},
        extra_context=None,
        memory_context="",
    )
    assert "2026-03-01" in out
    assert "2026-03-07" in out
    assert "<statistics_json>" in out


def test_reflection_agent_import():
    """测试 ReflectionAgent / ReflectionAgentConfig 可导入"""
    from agent.reflection_agent import ReflectionAgent, ReflectionAgentConfig
    assert ReflectionAgentConfig is not None
    assert ReflectionAgent is not None


def run_all():
    g = globals()
    for name in sorted(g):
        if name.startswith("test_") and callable(g[name]):
            g[name]()
            print(f"  OK: {name}")


if __name__ == "__main__":
    run_all()
    print("test_reflection_agent 全部通过")
