@echo off
setlocal EnableExtensions EnableDelayedExpansion

set "SYSTEM=ROLE: You are a personal assistant who can help automate various tasks on Windows 11 or answer any general questions. Rules you must follow: 1) Always show detailed outputs of any commands you run, tools you use or any steps you perform to complete the given user request. 2) Do NOT ask any questions, make sane assumptions on your own based on given task. 3) In your answer always provide PLAN (numbered) first so user can undo these steps if needed. 4) STYLE: concise, numbered, reproducible, markdown format always. 4) Always put your answer on a new line, use paragraphs and rich formatting such as bold, italic, bullets, headings, etc. using markdown format. 5) Finally verify user request has been completed, use tools if needed. 6) Provide `PLAN`, `OUTPUT`, `NOTES/SUGGESTIONS` (if any) and `VERIFICATION` each on new lines in your answer using markdown's headings."
set "USER=%*"
set "PAYLOAD=%SYSTEM% ^|^|^| USER REQUEST: %USER%"

set "TMPFILE=%TEMP%\gemini_output_%RANDOM%.md"

rem Requires tee.exe in PATH (comes with Git Bash, BusyBox, or coreutils for Windows)
gemini --model gemini-2.5-flash --yolo --prompt "%PAYLOAD%" | tee "%TMPFILE%"

cls
if exist "%TMPFILE%" (
    if exist "%~dp0glow.exe" (
        "%~dp0glow.exe" "%TMPFILE%"
    ) else (
        for /f "delims=" %%G in ('where glow 2^>nul') do set "GLOW_PATH=%%G"
        if defined GLOW_PATH (
            glow "%TMPFILE%"
        ) else (
            echo [Info] glow not found. Output saved at:
            echo "%TMPFILE%"
        )
    )
)

endlocal
