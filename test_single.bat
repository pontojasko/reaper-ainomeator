@echo off
REM Testa a classificacao em UM arquivo de audio.
REM Uso: arraste um arquivo de audio em cima deste .bat, ou rode:
REM   test_single.bat caminho\do\audio.wav

if "%~1"=="" (
    echo Uso: test_single.bat caminho\para\audio.wav
    echo Ou arraste um arquivo de audio em cima deste .bat
    pause
    exit /b 1
)

call venv\Scripts\activate.bat
python classify_track.py "%~1"
pause
