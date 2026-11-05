@echo off
rem ===========================================================================
rem sync.bat - bring the latest main into YOUR branch (same as GitHub Desktop
rem "Branch > Update from main"). Backup tool; needs Git for Windows installed.
rem Run save.bat first if you have unsaved changes.
rem ===========================================================================
setlocal
cd /d "%~dp0\.."

where git >nul 2>nul
if errorlevel 1 goto nogit

for /f "delims=" %%b in ('git rev-parse --abbrev-ref HEAD') do set "BRANCH=%%b"
if /i "%BRANCH%"=="main" goto onmain

git diff --quiet
if errorlevel 1 goto dirty
git diff --cached --quiet
if errorlevel 1 goto dirty

echo Current branch: %BRANCH%
git fetch origin
if errorlevel 1 goto neterr

git merge --no-edit origin/main
if errorlevel 1 goto conflict

echo.
echo [OK] Your branch now contains the latest main.
echo Next: in the Vivado Tcl Console run
echo     source scripts/create_project.tcl
echo so that new files from teammates appear in your project.
goto end

:conflict
git merge --abort
echo.
echo [CONFLICT] Git could not merge automatically. Nothing was changed.
echo STOP. Take a screenshot of this window and send it to the integrator.
goto end

:dirty
echo You have unsaved changes. Run save.bat first, then run sync.bat again.
goto end

:onmain
echo You are on the main branch. This script is only for member branches.
goto end

:neterr
echo Could not reach GitHub. Check your internet connection and sign-in.
goto end

:nogit
echo Git for Windows was not found. Install it from https://git-scm.com or use GitHub Desktop instead.

:end
pause
endlocal
