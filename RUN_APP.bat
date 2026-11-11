@echo off
setlocal
cd /d "%~dp0"
if not exist ".venv\Scripts\python.exe" (
    echo Please run INSTALL.bat first.
    pause
    exit /b 1
)
".venv\Scripts\python.exe" main.py
if errorlevel 1 (
    echo.
    echo The app stopped with an error. Read the message above.
    echo Check MySQL service, setup_database.sql and config.ini.
    pause
    exit /b 1
)
