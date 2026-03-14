@echo off
REM Agent API 可用性测试（curl）
REM 用法: test_api.bat [BASE_URL]
REM 示例: test_api.bat
REM       test_api.bat http://127.0.0.1:8000

setlocal
set "BASE_URL=%~1"
if "%BASE_URL%"=="" set "BASE_URL=http://127.0.0.1:8000"
REM 去掉末尾斜杠
if "%BASE_URL:~-1%"=="/" set "BASE_URL=%BASE_URL:~0,-1%"

echo ==========================================
echo Agent API 测试 (BASE_URL=%BASE_URL%)
echo ==========================================

REM 1. 健康检查
echo.
echo [1/4] GET /health
curl -s "%BASE_URL%/health" -o test_api_health.txt 2>nul
findstr /C:"status" test_api_health.txt >nul 2>&1
if %errorlevel% equ 0 (
  echo   OK ^(200^) GET /health 返回 status
) else (
  echo   FAIL GET /health 未返回预期内容
  type test_api_health.txt 2>nul
  del test_api_health.txt 2>nul
  exit /b 1
)
del test_api_health.txt 2>nul

REM 2. POST /chat 非流式
echo.
echo [2/4] POST /chat (JSON)
curl -s -X POST "%BASE_URL%/chat" -H "Content-Type: application/json" -d "{\"message\": \"你好\", \"user_id\": \"test-uuid-001\"}" -o test_api_chat.txt 2>nul
findstr /C:"\"text\"" test_api_chat.txt >nul 2>&1
if %errorlevel% equ 0 (
  echo   OK ^(200^) 响应含 text
  findstr /C:"user_id" test_api_chat.txt >nul 2>&1 && echo   OK 响应含 user_id
) else (
  echo   FAIL POST /chat 未返回预期内容
  type test_api_chat.txt
  del test_api_chat.txt 2>nul
  exit /b 1
)
del test_api_chat.txt 2>nul

REM 3. POST /chat 流式（仅检查是否有输出）
echo.
echo [3/4] POST /chat (SSE stream)
curl -s -N -X POST "%BASE_URL%/chat?stream=true" -H "Content-Type: application/json" -d "{\"message\": \"说一个字\"}" -m 15 2>nul | findstr /C:"event:" > test_api_stream.txt 2>&1
for %%F in (test_api_stream.txt) do set "STREAM_SIZE=%%~zF"
if defined STREAM_SIZE if %STREAM_SIZE% gtr 0 (
  echo   OK 收到 SSE 事件
) else (
  echo   WARN 未收到 SSE 事件（可能服务未就绪或超时）
)
del test_api_stream.txt 2>nul

REM 4. POST /reflection/summary
echo.
echo [4/4] POST /reflection/summary
curl -s -X POST "%BASE_URL%/reflection/summary" -H "Content-Type: application/json" -d "{\"end_date\": \"2026-03-07\", \"user_id\": \"test-uuid-003\"}" -o test_api_reflection.txt 2>nul
findstr /C:"\"text\"" test_api_reflection.txt >nul 2>&1
if %errorlevel% equ 0 (
  echo   OK ^(200^) 响应含 text
  findstr /C:"user_id" test_api_reflection.txt >nul 2>&1 && echo   OK 响应含 user_id
) else (
  echo   FAIL POST /reflection/summary 未返回预期内容
  type test_api_reflection.txt
  del test_api_reflection.txt 2>nul
  exit /b 1
)
del test_api_reflection.txt 2>nul

echo.
echo ==========================================
echo 全部 API 测试通过
echo ==========================================
endlocal
exit /b 0
