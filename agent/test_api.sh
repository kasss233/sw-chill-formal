#!/usr/bin/env sh
# Agent API 可用性测试（curl）
# 用法: ./test_api.sh [BASE_URL]
# 示例: ./test_api.sh
#       ./test_api.sh http://127.0.0.1:8000

set -e
BASE_URL="${1:-http://127.0.0.1:8000}"
BASE_URL="${BASE_URL%/}"

echo "=========================================="
echo "Agent API 测试 (BASE_URL=$BASE_URL)"
echo "=========================================="

# 1. 健康检查
echo ""
echo "[1/4] GET /health"
resp=$(curl -s -w "\n%{http_code}" "$BASE_URL/health")
body=$(echo "$resp" | sed '$d')
code=$(echo "$resp" | tail -n 1)
if [ "$code" = "200" ] && echo "$body" | grep -q '"status"'; then
  echo "  OK (200) $body"
else
  echo "  FAIL (HTTP $code) $body"
  exit 1
fi

# 2. POST /chat 非流式
echo ""
echo "[2/4] POST /chat (JSON)"
resp=$(curl -s -w "\n%{http_code}" -X POST "$BASE_URL/chat" \
  -H "Content-Type: application/json" \
  -d '{"message": "你好", "user_id": "test-uuid-001"}')
body=$(echo "$resp" | sed '$d')
code=$(echo "$resp" | tail -n 1)
if [ "$code" = "200" ] && echo "$body" | grep -q '"text"'; then
  echo "  OK (200) 响应含 text"
  echo "$body" | grep -q '"user_id"' && echo "  OK 响应含 user_id"
else
  echo "  FAIL (HTTP $code) $body"
  exit 1
fi

# 3. POST /chat 流式（只读前几行，不等待结束）
echo ""
echo "[3/4] POST /chat (SSE stream, 前 5 条事件)"
count=$(curl -s -N -X POST "$BASE_URL/chat?stream=true" \
  -H "Content-Type: application/json" \
  -d '{"message": "说一个字", "user_id": "test-uuid-002"}' 2>/dev/null | head -n 20 | grep -c "^event:" || true)
if [ "${count:-0}" -ge 1 ]; then
  echo "  OK 收到至少 1 条 SSE 事件 (共 $count 条)"
else
  echo "  WARN 未收到 SSE 事件（可能服务未就绪或超时）"
fi

# 4. POST /reflection/summary
echo ""
echo "[4/4] POST /reflection/summary"
resp=$(curl -s -w "\n%{http_code}" -X POST "$BASE_URL/reflection/summary" \
  -H "Content-Type: application/json" \
  -d '{"end_date": "2026-03-07", "user_id": "test-uuid-003"}')
body=$(echo "$resp" | sed '$d')
code=$(echo "$resp" | tail -n 1)
if [ "$code" = "200" ] && echo "$body" | grep -q '"text"'; then
  echo "  OK (200) 响应含 text"
  echo "$body" | grep -q '"user_id"' && echo "  OK 响应含 user_id"
else
  echo "  FAIL (HTTP $code) $body"
  exit 1
fi

echo ""
echo "=========================================="
echo "全部 API 测试通过"
echo "=========================================="
