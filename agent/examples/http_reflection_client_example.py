"""
HTTP 反思 Agent 测试脚本

作用：
- 向 `agent.http_server.server` 启动的 HTTP 服务发送 /reflection/summary 请求，
  验证反思与总结 Agent 的 HTTP 封装是否工作正常。

运行前：
- 先在仓库根目录启动 HTTP 服务：
    python -m agent.http_server.server

运行本脚本（另一个终端）：
    python -m agent.examples.http_reflection_client_example
"""

from datetime import datetime, timedelta
import json

import requests


def main() -> None:
    base_url = "http://127.0.0.1:8000"
    url = f"{base_url}/reflection/summary"

    end_date = datetime.now()
    start_date = end_date - timedelta(days=6)

    payload = {
        "start_date": start_date.strftime("%Y-%m-%d"),
        "end_date": end_date.strftime("%Y-%m-%d"),
        "period": "week",
        "trigger": "weekly",
        "extra_context": "用户备注：这一周感觉事情有点多，但也完成了一些重要任务。",
        # 也可以在这里传入 precomputed_stats 来测试“外部统计 + Agent 总结”的路径：
        # "precomputed_stats": {...}
    }

    print(f"POST {url}")
    print("请求体：")
    print(json.dumps(payload, ensure_ascii=False, indent=2))

    try:
        resp = requests.post(url, json=payload, timeout=300)
        print(f"\n状态码: {resp.status_code}")
        try:
            data = resp.json()
            print("响应 JSON：")
            print(json.dumps(data, ensure_ascii=False, indent=2))
        except json.JSONDecodeError:
            print("响应内容（非 JSON）：")
            print(resp.text)
    except Exception as e:
        print(f"请求失败: {e}")


if __name__ == "__main__":
    main()

