@echo off
title 1. IVAC Node.js Server
cd /d "%~dp0server"
echo ====================================================
echo Starting Node.js Server on port 3000...
echo ====================================================
node server.js
pause
