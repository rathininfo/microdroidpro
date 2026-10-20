@echo off
title 3. IVAC Cloud Python Listener
cd /d "%~dp0python-client"
echo ====================================================
echo Starting Python Auto-Typer connected to Render Cloud...
echo Connecting to: wss://microdroidpro.onrender.com
echo ====================================================
python otp_autofill.py wss://microdroidpro.onrender.com
pause
