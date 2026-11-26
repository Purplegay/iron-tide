@echo off
chcp 65001 >nul
setlocal
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0launch_game.ps1"
if errorlevel 1 (
  echo 游戏启动或运行时发生错误。请查看上方信息，按任意键关闭窗口。
  pause
  exit /b 1
)
exit /b 0
