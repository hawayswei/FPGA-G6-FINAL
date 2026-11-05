@echo off
rem ===========================================================================
rem save.bat - save your work (commit) and upload it (push) to YOUR branch.
rem Backup tool; needs Git for Windows installed. GitHub Desktop does the same.
rem ===========================================================================
setlocal
cd /d "%~dp0\.."

where git >nul 2>nul
if errorlevel 1 goto nogit

for /f "delims=" %%b in ('git rev-parse --abbrev-ref HEAD') do set "BRANCH=%%b"
if /i "%BRANCH%"=="main" goto onmain

echo Current branch: %BRANCH%
echo.
echo Files that will be saved:
git status --short
echo.

git add -A
git diff --cached --quiet
if not errorlevel 1 goto nochange

echo Write a short message in English, format: [area] what you did
echo Example: [cam] add capture state machine
echo Avoid special characters such as ^& ^| ^< ^> and double quotes.
set "MSG="
set /p MSG=Message:
if "%MSG%"=="" goto nomsg

choice /m "Save and upload these changes"
if errorlevel 2 goto cancel

git commit -m "%MSG%"
if errorlevel 1 goto failed
git push -u origin HEAD
if errorlevel 1 goto failed

echo.
echo [OK] Saved and uploaded to branch %BRANCH%.
goto end

:nochange
echo Nothing to save. No files changed.
goto end

:nomsg
git reset >nul 2>nul
echo Empty message. Cancelled. Nothing was committed.
goto end

:cancel
git reset >nul 2>nul
echo Cancelled. Nothing was committed.
goto end

:failed
echo.
echo [FAIL] Something went wrong. Send a screenshot of this window to the integrator.
goto end

:onmain
echo You are on the main branch. Only the integrator works on main. Cancelled.
goto end

:nogit
echo Git for Windows was not found. Install it from https://git-scm.com or use GitHub Desktop instead.

:end
pause
endlocal
