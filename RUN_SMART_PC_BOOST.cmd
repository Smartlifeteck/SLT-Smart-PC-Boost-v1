@echo off
setlocal
cd /d "%~dp0"
powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -File ".\START_SLT_DIAGNOSTIC.ps1"
if errorlevel 1 (
  echo SLT Smart PC Boost encountered an error on launch. See STARTUP_ERROR.txt for details.
  pause
)
