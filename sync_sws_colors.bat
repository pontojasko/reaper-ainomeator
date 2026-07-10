@echo off
REM Sincroniza as cores do Reaper AI Track Namer com o SWS Auto Color diretamente.
cd /d "%~dp0"
if exist venv\Scripts\activate.bat (
    call venv\Scripts\activate.bat
)
python sync_sws_colors.py
