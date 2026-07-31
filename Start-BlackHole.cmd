@echo off
setlocal
cd /d "%~dp0"
title Black Hole Launcher

if not exist "%~dp0Launch-BlackHole.ps1" (
  echo [Black Hole] Launch-BlackHole.ps1 was not found.
  echo Extract the complete ZIP before running this file.
  pause
  exit /b 2
)

powershell.exe -NoProfile -ExecutionPolicy Bypass -STA -File "%~dp0Launch-BlackHole.ps1"
if %errorlevel% neq 0 (
  echo.
  echo [Black Hole] Startup failed. See runtime\launcher-error.log
  pause
)
