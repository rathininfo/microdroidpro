@echo off
title 4. Build Android APK
cd /d "%~dp0android-sms-forwarder"
echo ====================================================
echo Building Release APK for Android Phone...
echo ====================================================
call C:\flutter\bin\flutter.bat build apk --release
echo.
echo ====================================================
echo If successful, your APK is ready at:
echo %~dp0android-sms-forwarder\build\app\outputs\flutter-apk\app-release.apk
echo ====================================================
pause
