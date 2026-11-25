@echo off
chcp 65001 >nul
setlocal
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0launch_game.ps1"
if errorlevel 1 (
  echo Startup failed. See the import log shown above.
  pause
  exit /b 1
)
exit /b 0
