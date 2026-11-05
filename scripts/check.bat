@echo off
rem ===========================================================================
rem check.bat - double-click to test that the whole design still synthesizes.
rem Takes a few minutes. Result: PASS or FAIL. Log: build\check.log
rem If Vivado is installed somewhere else, set the environment variable
rem VIVADO_BAT to the full path of vivado.bat.
rem ===========================================================================
setlocal
cd /d "%~dp0\.."
if not exist build mkdir build
if exist build\check_result.txt del build\check_result.txt

set "VIVADO="
if defined VIVADO_BAT set "VIVADO=%VIVADO_BAT%"
if not defined VIVADO if exist "D:\Xilinx\Vivado\2019.2\bin\vivado.bat" set "VIVADO=D:\Xilinx\Vivado\2019.2\bin\vivado.bat"
if not defined VIVADO if exist "C:\Xilinx\Vivado\2019.2\bin\vivado.bat" set "VIVADO=C:\Xilinx\Vivado\2019.2\bin\vivado.bat"
if not defined VIVADO goto novivado

echo Using Vivado: %VIVADO%
echo Running synthesis check. Please wait...
call "%VIVADO%" -mode batch -nojournal -log build\check.log -source scripts\check.tcl

findstr /b /c:"PASS" build\check_result.txt >nul 2>nul
if errorlevel 1 goto failed
echo.
echo [PASS] The design synthesizes.
goto end

:failed
echo.
echo [FAIL] Synthesis check failed. See build\check.log
echo Send a screenshot of this window and the file build\check.log to the integrator.
goto end

:novivado
echo Vivado 2019.2 was not found in the default folders.
echo Set the environment variable VIVADO_BAT to the full path of vivado.bat and run again.

:end
pause
endlocal
