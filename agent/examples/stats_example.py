"""
统计信息获取测试脚本

作用：
- 用来单独测试 ServerAPI（当前为 SimpleServerAPI）的统计接口，
  不依赖 LLM，也不生成自然语言总结。

运行方式（在仓库根目录）：
    python -m agent.examples.stats_example

你可以在后端实现自己的 ServerAPI 子类后，
把 SimpleServerAPI 替换为你的实现，用同样的脚本检查
get_daily_summary / get_statistics 的返回结构是否符合预期。
"""

from datetime import datetime, timedelta
import json

from interfaces.simple_server_api import SimpleServerAPI


def pretty_print(title: str, data) -> None:
    print("=" * 60)
    print(title)
    print("=" * 60)
    try:
        print(json.dumps(data, ensure_ascii=False, indent=2))
    except TypeError:
        # 如果某些字段不是 JSON 可序列化对象，就直接用 str 展示
        print(str(data))
    print("\n")


def main() -> None:
    print("=" * 60)
    print("统计信息测试 - SimpleServerAPI")
    print("=" * 60)

    api = SimpleServerAPI()

    # 1. 测试 get_daily_summary
    target_date = datetime.now()
    daily = api.get_daily_summary(target_date)
    pretty_print(f"1. get_daily_summary({target_date.date()}) 返回结果：", daily)

    # 2. 测试 get_statistics（最近 7 天，按 week 粒度）
    end_date = datetime.now()
    start_date = end_date - timedelta(days=6)
    stats_week = api.get_statistics(start_date=start_date, end_date=end_date, period="week")
    pretty_print(
        f"2. get_statistics({start_date.date()} ~ {end_date.date()}, period='week') 返回结果：",
        stats_week,
    )

    # 3. 也可以测试按 day 粒度的统计（示例）
    stats_day = api.get_statistics(start_date=end_date, end_date=end_date, period="day")
    pretty_print(
        f"3. get_statistics({end_date.date()} ~ {end_date.date()}, period='day') 返回结果：",
        stats_day,
    )

    print("统计信息测试完成。")


if __name__ == "__main__":
    main()

