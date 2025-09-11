@echo off
setlocal enabledelayedexpansion
cls

rem === CONFIG ===
set TESTS=BuildArtifacts\RagLiteTestApp.exe BuildArtifacts\RagLiteTestApp.exe
set CI=%RAGLITE_CONTINUOUS_INTEGRATION%
set FAILURES=0

rem === Build step (measure time with PowerShell) ===
echo Building...
powershell -nologo -noprofile -command ^
    "Measure-Command { & '.\build.bat' } | %% { Write-Host ('Build finished in ' + $_.TotalSeconds + 's') }"
if errorlevel 1 (
    echo Build failed!
    exit /b 1
)

rem === Run tests ===
for %%T in (%TESTS%) do (
    echo.
    echo === Running %%T ===
    start /wait "" %%T
    set EXITCODE=!errorlevel!
    echo Test exited with !EXITCODE!

    if not "!EXITCODE!"=="0" (
        set /a FAILURES+=1
    )
)

rem === Summary ===
echo.
echo All tests finished. Failures: %FAILURES%

if %FAILURES% gtr 0 (
    exit /b 1
) else (
    exit /b 0
)
