@echo off

echo ==========================================================
echo  AiNOMEATOR CLI - Environment Setup
echo ==========================================================
echo.

:: 1. Verify Python installation
echo [*] Checking Python installation...
python --version >nul 2>&1
if errorlevel 1 goto NO_PYTHON

:: 2. Create Virtual Environment
if exist venv goto VENV_EXISTS
echo [*] Creating Python virtual environment (venv)...
python -m venv venv
if errorlevel 1 goto VENV_FAIL
echo [SUCCESS] Virtual environment created successfully.
goto VENV_DONE

:VENV_EXISTS
echo [*] Virtual environment (venv) already exists. Skipping creation.

:VENV_DONE
echo.

:: 3. Activate Virtual Environment & Install Dependencies
echo [*] Activating virtual environment...
call venv\Scripts\activate.bat
if errorlevel 1 goto ACTIVATE_FAIL

echo [*] Installing dependencies from src/requirements.txt...
echo     This may take a few minutes (installing PyTorch, PANNs, and Gemini)...
python -m pip install --upgrade pip >nul 2>&1
pip install -r src\requirements.txt
if errorlevel 1 goto INSTALL_FAIL
echo [SUCCESS] Dependencies installed successfully.
echo.

:: 4. Setup environment variables file (.env)
if exist .env goto ENV_EXISTS
echo [*] Creating configuration file (.env)...
echo GEMINI_API_KEY=your_gemini_api_key_here> .env
echo [SUCCESS] File .env created.
echo.
echo [IMPORTANT] Please open the ".env" file in your project root and replace
echo             "your_gemini_api_key_here" with your actual Gemini API Key.
echo             Get a free key here: https://aistudio.google.com/apikey
goto ENV_DONE

:ENV_EXISTS
echo [*] Configuration file (.env) already exists. Keeping current setup.

:ENV_DONE
echo.

echo ==========================================================
echo  Setup Completed Successfully!
echo ==========================================================
echo  Next Steps:
echo  1. Configure your API key in the ".env" file.
echo  2. Open Reaper and run the "AiNOMEATOR.lua" script.
echo ==========================================================
echo.
pause
exit /b 0

:NO_PYTHON
echo [ERROR] Python was not found in your system PATH.
echo         Please install Python 3.9+ and ensure "Add Python to PATH" is checked.
echo.
pause
exit /b 1

:VENV_FAIL
echo [ERROR] Failed to create virtual environment.
pause
exit /b 1

:ACTIVATE_FAIL
echo [ERROR] Failed to activate virtual environment.
pause
exit /b 1

:INSTALL_FAIL
echo [ERROR] Failed to install dependencies.
pause
exit /b 1