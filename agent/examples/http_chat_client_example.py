"""
HTTP 聊天 Agent 测试脚本

作用：
- 向 `agent.http_server.server` 启动的 HTTP 服务发送 /chat 请求，
  验证主聊天 Agent 的 HTTP 封装是否工作正常。

运行前：
- 先在仓库根目录启动 HTTP 服务：
    python -m agent.http_server.server

运行本脚本（另一个终端）：
    python -m agent.examples.http_chat_client_example
"""

import json

import requests


def main() -> None:
    base_url = "http://127.0.0.1:8000"
    url = f"{base_url}/chat"

    payload = {
        "message": "你好，我这周有点忙，帮我简单整理一下接下来几天的学习安排吧。",
    }

    print(f"POST {url}")
    try:
        resp = requests.post(url, json=payload, timeout=300)
        print(f"状态码: {resp.status_code}")
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

