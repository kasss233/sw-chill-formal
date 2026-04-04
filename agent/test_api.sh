#!/usr/bin/env sh
# Usage: ./test_api.sh [BASE_URL]
# Only 2 checks: (1) POST /chat JSON (2) POST /chat SSE. Both must pass.
set -e
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
BASE_URL="${1:-http://127.0.0.1:8000}"
BASE_URL="${BASE_URL%/}"

echo "=========================================="
echo "Chat API test (non-stream + SSE) BASE_URL=$BASE_URL"
echo "=========================================="

echo ""
echo "[1/2] POST /chat non-stream (JSON)"
resp=$(curl -s -S --noproxy '*' --connect-timeout 5 --max-time 120 -w "\n%{http_code}" -X POST "$BASE_URL/chat" \
  -H "Content-Type: application/json" \
  --data-binary "@$SCRIPT_DIR/test_api_chat_body.json")
body=$(echo "$resp" | sed '$d')
code=$(echo "$resp" | tail -n 1)
if [ "$code" != "200" ] || ! echo "$body" | grep -q '"text"'; then
  echo "  FAIL non-stream /chat (HTTP $code)"
  echo "$body"
  exit 1
fi
echo "  OK non-stream: response has \"text\""
echo "  --- body (max 900 chars) ---"
echo "$body" | head -c 900 || true
echo ""
echo "  ---"

echo ""
echo "[2/2] POST /chat SSE stream (?stream=true)"
SSE_RAW="$SCRIPT_DIR/test_api_sse_raw.txt"
rm -f "$SSE_RAW"
curl -s -S --noproxy '*' --connect-timeout 5 --max-time 120 -N -X POST "$BASE_URL/chat?stream=true" \
  -H "Content-Type: application/json" \
  --data-binary "@$SCRIPT_DIR/test_api_stream_body.json" \
  -o "$SSE_RAW"
if [ ! -s "$SSE_RAW" ]; then
  echo "  FAIL stream: empty body"
  rm -f "$SSE_RAW"
  exit 1
fi
if ! grep -q '^event:' "$SSE_RAW"; then
  echo "  FAIL stream: no SSE lines starting with event:"
  head -n 20 "$SSE_RAW"
  rm -f "$SSE_RAW"
  exit 1
fi
bytes=$(wc -c < "$SSE_RAW" | tr -d ' ')
lines=$(wc -l < "$SSE_RAW" | tr -d ' ')
events=$(grep -c '^event:' "$SSE_RAW" || true)
echo "  OK stream: bytes=$bytes lines=$lines event: fields=$events"
LAST="$SCRIPT_DIR/test_api_sse_last_capture.txt"
cp -f "$SSE_RAW" "$LAST"
echo "  Full SSE saved to: $LAST"
if [ "${lines:-0}" -le 150 ]; then
  echo "  --- full SSE below ---"
  cat "$SSE_RAW"
else
  echo "  --- first 45 lines ---"
  head -n 45 "$SSE_RAW"
  omit=$((lines - 70))
  echo "  --- ... omitted $omit lines; see test_api_sse_last_capture.txt ... ---"
  echo "  --- last 25 lines ---"
  tail -n 25 "$SSE_RAW"
fi
echo "  ---"
rm -f "$SSE_RAW"

echo ""
echo "=========================================="
echo "PASS: non-stream + SSE stream both OK"
echo "=========================================="
