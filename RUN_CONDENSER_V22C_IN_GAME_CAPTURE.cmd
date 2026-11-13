@echo off
setlocal EnableExtensions DisableDelayedExpansion
title Tech Priests V22C - Real Factorio GUI Condenser Screenshot Capture
cd /d "%~dp0"
echo.
echo Martian Atmospheric Water Condenser V22C
echo REAL Factorio 2.1 graphical screenshot verification
echo 4 orientations x IDLE/WORKING x NORMAL/CLOSE = 16 engine PNGs.
echo -----------------------------------------------------------------
echo Run from the signed-in Windows desktop on the Steam machine.
echo No Administrator access, Windows service changes or game save edits.
echo.
set "SCRIPT=%~dp0ci\condenser_v22c\launch_from_interactive_desktop.ps1"
set "STEAM_GAME=D:\SteamLibrary B\steamapps\common\Factorio\bin\x64\factorio.exe"
if not exist "%SCRIPT%" (
    echo ERROR: Incomplete Tech-Priests checkout; missing:
    echo %SCRIPT%
    echo Refresh the repo's main branch and try again.
    pause
    exit /b 2
)
where powershell.exe >nul 2>nul
if errorlevel 1 (
    echo ERROR: Windows PowerShell is unavailable.
    pause
    exit /b 3
)
if exist "%STEAM_GAME%" (
    echo Found known Steam Factorio installation.
    powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT%" -FactorioExe "%STEAM_GAME%"
) else (
    echo Searching local Steam libraries and known game installation paths.
    powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT%"
)
set "RC=%ERRORLEVEL%"
echo.
if not "%RC%"=="0" (
    echo Native in-game image capture is NOT verified. Exit code %RC%.
    echo See the displayed error and the output directory's error/log receipt.
) else (
    echo Genuine Factorio screenshots PASSED the automated capture tests.
    echo Open the displayed PNG contact sheet; review visual pipe alignment.
    echo The separate ZIP contains the real screenshot evidence.
)
echo.
pause
exit /b %RC%
