@echo off
setlocal EnableExtensions DisableDelayedExpansion
title Tech Priests V22C - Fetch and Run REAL Factorio GUI Capture
echo.
echo Tech Priests: condenser V22C native Factorio client proof
echo This one-click launcher fetches only the approved capture/source paths,
echo then runs the installed real Factorio graphical client in YOUR desktop.
echo It never changes Windows services, Steam installs or normal game saves.
echo.
where git.exe >nul 2>nul
if errorlevel 1 (
    echo ERROR: Git for Windows is required.
    echo Install Git or use RUN_CONDENSER_V22C_IN_GAME_CAPTURE.cmd from a checkout.
    pause
    exit /b 2
)
where powershell.exe >nul 2>nul
if errorlevel 1 (
    echo ERROR: Windows PowerShell is required.
    pause
    exit /b 3
)
set "DEST=%USERPROFILE%\Documents\TechPriests-V22C-GUI-%RANDOM%-%RANDOM%"
if exist "%DEST%" (
    echo ERROR: A capture destination already exists; refusing overwrite.
    pause
    exit /b 4
)
echo Fetching isolated source into:
echo %DEST%
git.exe clone --depth 1 --filter=blob:none --sparse --no-checkout https://github.com/mrcalzon02/Tech-Priests.git "%DEST%"
if errorlevel 1 (
    echo ERROR: Could not fetch Tech-Priests. No game was launched.
    pause
    exit /b 5
)
git.exe -C "%DEST%" sparse-checkout set ci/condenser_v22c tech-priests_src art/source-to-3d/condenser-v21/captures/v22c
if errorlevel 1 (
    echo ERROR: Could not select genuine condenser source files.
    pause
    exit /b 6
)
git.exe -C "%DEST%" checkout --detach origin/main
if errorlevel 1 (
    echo ERROR: Source checkout failed. No game was launched.
    pause
    exit /b 7
)
if not exist "%DEST%\RUN_CONDENSER_V22C_IN_GAME_CAPTURE.cmd" (
    echo ERROR: Missing approved native screenshot launcher.
    pause
    exit /b 8
)
echo.
echo Checkout ready. Native Factorio screenshots will be retained in this folder.
pushd "%DEST%"
call "%DEST%\RUN_CONDENSER_V22C_IN_GAME_CAPTURE.cmd"
set "RC=%ERRORLEVEL%"
popd
echo.
echo Checkout / screenshot evidence directory:
echo %DEST%
echo Native capture exit code: %RC%
echo.
pause
exit /b %RC%
