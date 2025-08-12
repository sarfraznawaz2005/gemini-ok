@echo off
setlocal
set "PS1=%~dp0RunGemini.ps1"
powershell -NoProfile -ExecutionPolicy Bypass -File "%PS1%" %*
endlocal
