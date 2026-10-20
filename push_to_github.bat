@echo off
title Push to GitHub for Cloud APK Build
cd /d "%~dp0"
echo ====================================================
echo PUSH TO GITHUB TO GET APK DIRECTLY ON YOUR PHONE
echo ====================================================
echo.
echo 1. Go to https://github.com/new and create a new repository.
echo 2. Copy your repository link (e.g. https://github.com/username/repo.git)
echo.
set /p REPO_URL="Paste your GitHub Repository URL here and press Enter: "

if "%REPO_URL%"=="" (
    echo No URL entered. Exiting...
    pause
    exit /b
)

git remote remove origin 2>nul
git remote add origin %REPO_URL%
git branch -M main
echo.
echo Uploading to GitHub...
git push -u origin main

echo.
echo ====================================================
echo SUCCESS! Your code has been uploaded to GitHub!
echo GitHub Actions is now building your APK in the cloud.
echo.
echo In 2 minutes, go to your GitHub Repo -> 'Releases'
echo and download app-release.apk directly on your phone!
echo ====================================================
pause
