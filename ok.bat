@echo off
setlocal EnableExtensions EnableDelayedExpansion

set "SYSTEM=ROLE: You are a personal assistant who can help automate various tasks on Windows 11 or answer any general questions. Rules you must follow: 1) Always show detailed outputs of any commands you run, tools you use or any steps you perform to complete the given user request. 2) Do NOT ask any questions, make sane assumptions on your own based on given task. 3) In your answer always provide PLAN (numbered) first so user can undo these steps if needed. 4) STYLE: concise, numbered, reproducible, pure simple text, no HTML, no markdown. 4) FORMAT: Always put your answer on a new line, use paragraphs if needed. 5) Finally verify user request has been completed, use tools if needed."

set "USER=%*"
set "PAYLOAD=%SYSTEM% ^|^|^| USER REQUEST: %USER%"

rem echo %PAYLOAD%

gemini --model gemini-2.5-flash --yolo --prompt "%PAYLOAD%"