@echo off
REM Use ASCII only: UTF-8 Chinese breaks cmd.exe on some locales.
cd /d "%~dp0"

set "_PY="
where py >nul 2>&1 && set "_PY=py"
if not defined _PY (
  where python >nul 2>&1 && set "_PY=python"
)
if not defined _PY (
  echo ERROR: Python not found. Install Python 3 or add it to PATH.
  pause
  exit /b 1
)

"%_PY%" run_server.py
if errorlevel 1 (
  echo.
  echo Hint: %_PY% -m pip install -r requirements.txt
  pause
)
