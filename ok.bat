@echo off

:: Quick help -----------------------------------------------------------
if "%~1"=="" (
    echo Usage:  g prompt
    echo Example: g tell me a joke
    exit /b 1
)

gemini --yolo --prompt "%*"
