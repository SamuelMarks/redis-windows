@echo off
setlocal EnableDelayedExpansion

if "%~1"=="" (
    echo Usage: %0 ^<tag^> [project] [--local-only]
    echo Example: %0 unstable redis
    echo Example: %0 8.0.0 valkey --local-only
    exit /b 1
)

set TAG=%~1
set PROJECT=%~2
set LOCAL_ONLY=0

if "%PROJECT%"=="--local-only" (
    set PROJECT=redis
    set LOCAL_ONLY=1
) else if "%~3"=="--local-only" (
    set LOCAL_ONLY=1
)
if "%PROJECT%"=="" set PROJECT=redis

set REPO_DIR=%~dp0
set WORK_DIR=%REPO_DIR%build_work
set SRC_DIR=%WORK_DIR%\%PROJECT%

echo =======================================================
echo Building %PROJECT% for Windows at tag: %TAG%
echo =======================================================

:: Clean and prepare work directory
if exist "%WORK_DIR%" rmdir /s /q "%WORK_DIR%"
mkdir "%WORK_DIR%"
cd /d "%WORK_DIR%"

echo [1/5] Fetching %PROJECT%...
if /i "%PROJECT%"=="redis" (
    set REPO_URL=https://github.com/redis/redis.git
) else (
    set REPO_URL=https://github.com/valkey-io/valkey.git
)

git clone --branch %TAG% --depth 1 %REPO_URL% "%SRC_DIR%"
if errorlevel 1 (
    echo Failed to clone %PROJECT% at tag %TAG%
    exit /b 1
)

cd /d "%SRC_DIR%"

echo [2/5] Applying overlay and patches...
xcopy /E /I /Y "%REPO_DIR%overlay\*" . >nul

for %%f in ("%REPO_DIR%patches\*.patch") do (
    git apply --reject "%%f"
    if errorlevel 1 (
        echo Failed to apply patch %%f
        exit /b 1
    )
)

echo Configuring CMake...
:: Try MSVC 2026 first, fallback to default if not available
cmake -G "Visual Studio 18 2026" -A x64 -B build -S . >nul 2>&1
if errorlevel 1 (
    cmake -B build -S .
    if errorlevel 1 (
       echo CMake configuration failed.
       exit /b 1
    )
)

echo Building %PROJECT%...
cmake --build build --config Release
if errorlevel 1 (
    echo Build failed.
    exit /b 1
)

echo Packaging...
cd build
cpack -G WIX -C Release
cpack -G NSIS -C Release
cpack -G ZIP -C Release
cd ..

echo [3/5] Running E2E Tests...
set SERVER_EXE=build\Release\%PROJECT%-server.exe
set CLI_EXE=build\Release\%PROJECT%-cli.exe

if not exist "%SERVER_EXE%" (
    set SERVER_EXE=build\%PROJECT%-server.exe
    set CLI_EXE=build\%PROJECT%-cli.exe
)

if not exist "%SERVER_EXE%" (
    :: Fallback to redis-server.exe if project is valkey but binary is still redis
    set SERVER_EXE=build\Release\redis-server.exe
    set CLI_EXE=build\Release\redis-cli.exe
    if not exist "!SERVER_EXE!" (
        set SERVER_EXE=build\redis-server.exe
        set CLI_EXE=build\redis-cli.exe
    )
)

if not exist "%SERVER_EXE%" (
    echo Server executable not found, tests cannot run.
    exit /b 1
)

start "%PROJECT% Server" "%SERVER_EXE%"
:: Wait for the server to start
timeout /t 2 /nobreak >nul

echo Running CLI commands...
"%CLI_EXE%" PING > e2e_test.log
"%CLI_EXE%" SET testkey "Hello Windows" >> e2e_test.log
"%CLI_EXE%" GET testkey >> e2e_test.log
"%CLI_EXE%" KEYS * >> e2e_test.log
"%CLI_EXE%" FLUSHDB >> e2e_test.log

:: Kill the server
taskkill /f /im %PROJECT%-server.exe >nul 2>&1
taskkill /f /im redis-server.exe >nul 2>&1

:: Verify test output
findstr /C:"PONG" e2e_test.log >nul
if errorlevel 1 (
    echo E2E Test failed: Missing PONG response.
    type e2e_test.log
    exit /b 1
)

findstr /C:"Hello Windows" e2e_test.log >nul
if errorlevel 1 (
    echo E2E Test failed: Missing SET/GET response.
    type e2e_test.log
    exit /b 1
)

echo E2E Tests passed successfully.

if "!LOCAL_ONLY!"=="1" (
    echo.
    echo --local-only flag provided. Skipping git tag, push, and GitHub release.
    echo Done! Build and tests completed successfully.
    exit /b 0
)

echo [4/5] Pushing new git tag...
cd /d "%REPO_DIR%"

:: Delete old tag and releases locally and remotely
echo Deleting old tag and release if they exist...
git tag -d %TAG% >nul 2>&1
git push origin --delete %TAG% >nul 2>&1
gh release delete %TAG% --cleanup-tag -y >nul 2>&1

echo Tagging repository with %TAG%...
git tag %TAG%
git push origin %TAG%
if errorlevel 1 (
    echo Failed to push tag to origin.
    exit /b 1
)

echo [5/5] Creating GitHub release...
:: Gather all files to upload
set ASSETS="%SRC_DIR%\build\*.msi" "%SRC_DIR%\build\*.zip" "%SRC_DIR%\build\Release\*.exe" "%SRC_DIR%\build\bin\Release\*.exe"
:: If single config generator was used, Release won't exist.
if exist "%SRC_DIR%\build\redis-server.exe" set ASSETS="%SRC_DIR%\build\*.msi" "%SRC_DIR%\build\*.zip" "%SRC_DIR%\build\*.exe" "%SRC_DIR%\build\bin\*.exe"

gh release create %TAG% %ASSETS% --title "%PROJECT% %TAG% for Windows" --notes "Automated local build of %PROJECT% %TAG% for Windows"

if errorlevel 1 (
    echo Failed to create GitHub release.
    exit /b 1
)

echo Done! Release %TAG% published successfully.
