@echo off
REM ASCII only. Usage: test_api.bat [BASE_URL]
REM Only 2 checks: (1) POST /chat JSON (2) POST /chat SSE. Both must pass.
setlocal EnableDelayedExpansion
cd /d "%~dp0"

set "BASE_URL=%~1"
if "%BASE_URL%"=="" set "BASE_URL=http://127.0.0.1:8000"
if "%BASE_URL:~-1%"=="/" set "BASE_URL=%BASE_URL:~0,-1%"

set CURL_BASE=curl.exe -s -S --noproxy "*" --connect-timeout 5

where curl.exe >nul 2>&1
if errorlevel 1 (
  echo ERROR: curl.exe not found.
  exit /b 1
)

echo ==========================================
echo Chat API test ^(non-stream + SSE^) BASE_URL=%BASE_URL%
echo ==========================================

echo.
echo [1/2] POST /chat non-stream ^(JSON^)
%CURL_BASE% --max-time 120 -X POST "%BASE_URL%/chat" -H "Content-Type: application/json" --data-binary "@%~dp0test_api_chat_body.json" -o test_api_chat.txt
findstr /C:"text" test_api_chat.txt >nul 2>&1
if errorlevel 1 (
  echo   FAIL non-stream /chat
  type test_api_chat.txt
  del test_api_chat.txt 2>nul
  exit /b 1
)
echo   OK non-stream: response has "text"
echo   --- body ^(max 900 chars^) ---
powershell -NoProfile -Command "try { $p='%~dp0test_api_chat.txt'; $c=[IO.File]::ReadAllText($p,[Text.Encoding]::UTF8); if ($c.Length -gt 900) { $c.Substring(0,900) + '...' } else { $c } } catch { Get-Content -LiteralPath '%~dp0test_api_chat.txt' -Raw -Encoding UTF8 }"
echo   ---
del test_api_chat.txt 2>nul

echo.
echo [2/2] POST /chat SSE stream ^(?stream=true^)
echo   ^(may take up to 120s; server uses Connection:close so curl exits when stream ends^)
del "%~dp0test_api_sse_raw.txt" 2>nul
%CURL_BASE% --max-time 120 -N -X POST "%BASE_URL%/chat?stream=true" -H "Content-Type: application/json" --data-binary "@%~dp0test_api_stream_body.json" -o "%~dp0test_api_sse_raw.txt"
set "RAW_SIZE=0"
if exist "%~dp0test_api_sse_raw.txt" for %%F in ("%~dp0test_api_sse_raw.txt") do set "RAW_SIZE=%%~zF"
if !RAW_SIZE! equ 0 (
  echo   FAIL stream: empty body ^(server down, timeout, or error^)
  del "%~dp0test_api_sse_raw.txt" 2>nul
  exit /b 1
)
findstr /C:"event:" "%~dp0test_api_sse_raw.txt" >nul 2>&1
if errorlevel 1 (
  echo   FAIL stream: no SSE "event:" lines ^(not valid SSE^)
  echo   --- raw head ---
  powershell -NoProfile -Command "Get-Content -LiteralPath '%~dp0test_api_sse_raw.txt' -Encoding UTF8 -TotalCount 20 -ErrorAction SilentlyContinue"
  echo   ---
  del "%~dp0test_api_sse_raw.txt" 2>nul
  exit /b 1
)
echo   OK stream: bytes=!RAW_SIZE! and at least one "event:" line
echo   Full SSE saved to: %~dp0test_api_sse_last_capture.txt ^(overwrite each run^)
powershell -NoProfile -Command "& { $p='%~dp0test_api_sse_raw.txt'; $out='%~dp0test_api_sse_last_capture.txt'; Copy-Item -LiteralPath $p -Destination $out -Force; $a=Get-Content -LiteralPath $p -Encoding UTF8; $n=$a.Count; $ev=($a | Where-Object { $_ -like 'event:*' }).Count; Write-Host ('  SSE stats: data_lines=' + $n + ' event_fields=' + $ev); if ($n -le 150) { Write-Host '  --- full SSE below ---'; $a | ForEach-Object { $_ } } else { Write-Host '  --- first 45 lines ---'; $a[0..44] | ForEach-Object { $_ }; Write-Host ('  --- ... omitted ' + ($n-70) + ' lines; see test_api_sse_last_capture.txt ... ---'); Write-Host '  --- last 25 lines ---'; $a[($n-25)..($n-1)] | ForEach-Object { $_ } }; Write-Host '  ---' }"
del "%~dp0test_api_sse_raw.txt" 2>nul

echo.
echo ==========================================
echo PASS: non-stream + SSE stream both OK
echo ==========================================
endlocal
exit /b 0
