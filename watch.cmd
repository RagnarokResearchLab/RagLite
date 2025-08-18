@echo off
setlocal ENABLEDELAYEDEXPANSION

set AUTO_REBUILD_TIME=3

:loop
cls

for /f "tokens=1-4 delims=:.," %%a in ("%time%") do (
    set /a "sh=100*%%a*3600 + 100*%%b*60 + 100*%%c + %%d"
)

call build.bat

for /f "tokens=1-4 delims=:.," %%a in ("%time%") do (
    set /a "eh=100*%%a*3600 + 100*%%b*60 + 100*%%c + %%d"
)

set /a "elapsed=eh-sh"
if !elapsed! lss 0 set /a elapsed+=24*3600*100

set /a "sec = elapsed / 100"
set /a "cs  = elapsed %% 100"
if !cs! lss 10 (set cs=0!cs!)

echo Build finished in !sec!.!cs! seconds

timeout /t %AUTO_REBUILD_TIME% /nobreak >nul
goto loop
