@echo off
title Run IVAC App on Connected Phone
cd /d "c:\microdroidpro\android-sms-forwarder"
echo ====================================================
echo Running IVAC SMS Forwarder on your Android Phone...
echo Make sure your phone is connected via USB with USB Debugging ON.
echo ====================================================
call C:\flutter\bin\flutter.bat run
pause
