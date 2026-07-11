@echo off
cd /d "%~dp0\.."
call venv\Scripts\activate.bat
python tests\test_batch.py
pause
