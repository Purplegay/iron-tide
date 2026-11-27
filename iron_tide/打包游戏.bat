@echo off
setlocal
chcp 65001 >nul
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0package_game.ps1" %*
set "pack_exit=%errorlevel%"
if "%~1"=="" pause
exit /b %pack_exit%
