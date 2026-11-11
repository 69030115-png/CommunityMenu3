@echo off
setlocal
cd /d "%~dp0"
where py >nul 2>nul
if errorlevel 1 (
    echo Python launcher not found. Install Python with Tkinter and the py launcher.
    pause
    exit /b 1
)
if not exist ".venv\Scripts\python.exe" (
    py -m venv .venv
    if errorlevel 1 goto failed
)
".venv\Scripts\python.exe" -m pip install -r requirements.txt
if errorlevel 1 goto failed
echo.
echo Installation complete. Read README.md, then open RUN_APP.bat.
pause
exit /b 0
:failed
echo Installation failed. Check the message above and your internet connection.
pause
exit /b 1
