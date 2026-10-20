@echo off
title 5. Send Simulated IVAC SMS
cd /d "%~dp0python-client"
echo ====================================================
echo Sending Mock IVAC OTP SMS to Server...
echo ====================================================
python mock_test_sms.py
pause
