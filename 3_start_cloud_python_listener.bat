@echo off
title IVAC Cloud Python Auto-Typer
cd /d "%~dp0python-client"
echo ==========================================================
echo       IVAC CLOUD AUTO-TYPER (Zero-Collision Client)
echo ==========================================================
echo Connecting to: wss://microdroidpro.onrender.com
echo.
set /p PC_ID="Enter PC / Slot Number for this PC (e.g. 1, 2, 3...) [Default 1]: "
if "%PC_ID%"=="" set PC_ID=1
echo.
echo [Starting Auto-Typer exclusively for PC / Slot #%PC_ID%...]
echo ==========================================================
python otp_autofill.py wss://microdroidpro.onrender.com --device %PC_ID%
pause
