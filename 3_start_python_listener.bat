@echo off
title 3. IVAC Python OTP Listener
cd /d "%~dp0python-client"
echo ====================================================
echo Starting Python Auto-Typer and Clipboard listener...
echo ====================================================
python otp_autofill.py
pause
