@echo off
setlocal
title Install / update Alteroth addons
cd /d "%~dp0"
if not exist "Wow.exe" goto :notwow

set REALM=100.84.20.72
set URL=https://github.com/Lucdown/wow-server-build/archive/refs/heads/main.zip
set TMPD=%TEMP%\alteroth_addons

echo Downloading the latest Alteroth addons...
if exist "%TMPD%" rmdir /s /q "%TMPD%"
mkdir "%TMPD%"
curl -L -s -f -o "%TMPD%\addons.zip" "%URL%"
if errorlevel 1 goto :fail
tar -xf "%TMPD%\addons.zip" -C "%TMPD%"
if errorlevel 1 goto :fail
set SRC=
for /d %%D in ("%TMPD%\*") do if exist "%%D\addons" set SRC=%%D\addons
if "%SRC%"=="" goto :fail

if not exist "Interface\AddOns" mkdir "Interface\AddOns"
robocopy "%SRC%" "Interface\AddOns" /E /NFL /NDL /NJH /NJS /NP >nul
if errorlevel 8 goto :fail
echo Addons installed.

echo.
echo The server address is %REALM%. Press Enter to use it, or type a different one.
set /p NEWREALM=Address: 
if not "%NEWREALM%"=="" set REALM=%NEWREALM%
> "realmlist.wtf" echo set realmlist %REALM%
for /d %%L in ("Data\*") do if exist "%%L\realmlist.wtf" > "%%L\realmlist.wtf" echo set realmlist %REALM%
echo Realm set to %REALM%.
rmdir /s /q "%TMPD%" 2>nul
echo.
echo All done! Start WoW and log in. Run this again any time to get addon updates.
pause
exit /b

:notwow
echo Put this file in your WoW folder - the one with Wow.exe in it - and run it again.
pause
exit /b

:fail
echo Something went wrong downloading the addons. Check your internet and try again,
echo or send a screenshot of this window to your friend.
pause
exit /b
