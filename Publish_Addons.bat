@echo off
title Publish Alteroth addons for friends
cd /d "%~dp0"
set ADDONS=C:\WoWServers\TBC-2.4.3.8606-enGB-Repack\Interface\AddOns
if not exist "%ADDONS%" echo Can't find %ADDONS% & pause & exit /b
if not exist "addons" mkdir "addons"
echo Copying your Alteroth addons into this folder so friends can download them...
for %%A in (AlterPower CleanBags CleanBars CleanDefaults CleanMenu CleanMeter CleanMove CleanPlates CleanQuests CleanSkin CleanSpellbook GearFinder) do (
  if exist "%ADDONS%\%%A" robocopy "%ADDONS%\%%A" "addons\%%A" /MIR /XF Completed.lua /NFL /NDL /NJH /NJS /NP >nul
)
echo.
echo Done. Now open GitHub Desktop, Commit, then Push.
echo Your friends run Install_Alteroth_Addons.bat (in their WoW folder) to get or update them.
pause
