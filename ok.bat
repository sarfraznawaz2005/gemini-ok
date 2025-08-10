@echo off
rem g.bat — Gemini ▸ Glow (single-line prompts, rendered as Markdown)

:: Quick help -----------------------------------------------------------
if "%~1"=="" (
    echo Usage:  g prompt
    echo Example: g tell me a joke
    exit /b 1
)

:: If Gemini’s TUI adds ANSI colours that confuse Glow, un-comment next line
:: set "NO_COLOR=1"

:: Ask Gemini, then pipe its Markdown straight into Glow’s stdin (the “-” arg)
:: Install glow if not already installed with: choco install glow

gemini -y --show-memory-usage -p "%*" | glow -
