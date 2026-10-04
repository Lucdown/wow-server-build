@echo off
title Put the build recipe in place
cd /d "%~dp0"
if not exist ".github\workflows" mkdir ".github\workflows"
copy /Y "build-tbc.yml" ".github\workflows\build-tbc.yml" >nul
echo Build recipe copied into .github\workflows. Now commit and push in GitHub Desktop.
pause
