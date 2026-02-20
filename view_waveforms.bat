@echo off
REM ===========================================================================
REM Waveform Viewer Launcher for Moving Average Filter
REM ===========================================================================
REM Description: Opens the most recent simulation waveforms in GTKWave
REM Authors: Jonathan Farah, Jason Qin
REM ===========================================================================

echo.
echo ========================================
echo  Waveform Viewer for Moving Average Filter
echo ========================================
echo.

REM Find the most recent simulation directory
for /f "delims=" %%i in ('dir /b /ad /o-d simulation_results\sim_* 2^>nul') do (
    set "LATEST_SIM=%%i"
    goto :found
)

:notfound
echo ERROR: No simulation results found!
echo Please run the simulation first.
echo.
pause
exit /b 1

:found
echo Latest simulation: %LATEST_SIM%
echo.

set "WAVEFORM_FILE=simulation_results\%LATEST_SIM%\dumpfile.fst"

if not exist "%WAVEFORM_FILE%" (
    echo ERROR: Waveform file not found: %WAVEFORM_FILE%
    echo The simulation may have failed or not generated waveforms.
    echo.
    pause
    exit /b 1
)

echo Opening waveform file: %WAVEFORM_FILE%
echo.

REM Try to find GTKWave in common installation paths
set "GTKWAVE="

if exist "C:\Program Files\gtkwave\bin\gtkwave.exe" (
    set "GTKWAVE=C:\Program Files\gtkwave\bin\gtkwave.exe"
)
if exist "C:\Program Files (x86)\gtkwave\bin\gtkwave.exe" (
    set "GTKWAVE=C:\Program Files (x86)\gtkwave\bin\gtkwave.exe"
)
if exist "%LOCALAPPDATA%\gtkwave\bin\gtkwave.exe" (
    set "GTKWAVE=%LOCALAPPDATA%\gtkwave\bin\gtkwave.exe"
)

if "%GTKWAVE%"=="" (
    echo WARNING: GTKWave not found in standard locations.
    echo Trying to launch with 'gtkwave' command...
    echo.
    gtkwave "%WAVEFORM_FILE%"
    if errorlevel 1 (
        echo.
        echo ERROR: Could not launch GTKWave.
        echo.
        echo Please install GTKWave from: http://gtkwave.sourceforge.net/
        echo Or install via Chocolatey: choco install gtkwave
        echo.
        pause
        exit /b 1
    )
) else (
    echo Launching GTKWave...
    start "" "%GTKWAVE%" "%WAVEFORM_FILE%"
)

echo.
echo GTKWave should open in a moment!
echo.
echo Quick Tips:
echo   - Expand the hierarchy tree on the left
echo   - Select signals and click 'Append' to view them
echo   - Use Zoom controls to navigate the timeline
echo   - Right-click signals for display options (hex, decimal, binary)
echo.
