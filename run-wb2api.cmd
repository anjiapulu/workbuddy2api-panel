@echo off
REM ============================================================
REM  run-wb2api.cmd - gateway entry point used by Task Scheduler
REM
REM  Task Scheduler launches this non-interactively, so no window
REM  ever appears. The scheduler owns the process, so it is NOT
REM  tied to any console or explorer session and survives
REM  everything short of a reboot / explicit stop.
REM
REM  Do not double-click this one for interactive use - use
REM  start-hidden.vbs or start-wb2api.cmd instead.
REM ============================================================

REM %~dp0 keeps config.json / auths / data resolving correctly
cd /d "%~dp0"

if not exist "auths" mkdir "auths"
if not exist "data"  mkdir "data"

"%~dp0wb2api.exe" -config config.json >> "%~dp0data\wb2api.log" 2>&1
