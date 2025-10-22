@echo off
REM Build script for FunASR HTTP Server (Windows)

setlocal enabledelayedexpansion

set "SCRIPT_DIR=%~dp0"
set "BUILD_DIR=%SCRIPT_DIR%build"

echo Building FunASR HTTP Server...
echo Source directory: %SCRIPT_DIR%
echo Build directory: %BUILD_DIR%

REM Create build directory
if not exist "%BUILD_DIR%" (
    echo Creating build directory...
    mkdir "%BUILD_DIR%"
)

cd /d "%BUILD_DIR%"

REM Check if CMakeLists.txt exists in parent directory
if not exist "%SCRIPT_DIR%CMakeLists.txt" (
    echo Error: CMakeLists.txt not found in %SCRIPT_DIR%
    exit /b 1
)

REM Run CMake
echo Running CMake...
cmake "%SCRIPT_DIR%"
if errorlevel 1 (
    echo CMake configuration failed!
    exit /b 1
)

REM Build the project
echo Building project...
REM Detect number of processors
set "NUM_PROCESSORS=%NUMBER_OF_PROCESSORS%"
if "%NUM_PROCESSORS%"=="" set "NUM_PROCESSORS=4"

cmake --build . --config Release --parallel %NUM_PROCESSORS%
if errorlevel 1 (
    echo Build failed!
    exit /b 1
)

echo.
echo Build completed successfully!
echo.
echo Executables built:

if exist "bin\Release\funasr-http-server.exe" (
    echo   [OK] funasr-http-server.exe (HTTP server^)
) else if exist "bin\funasr-http-server.exe" (
    echo   [OK] funasr-http-server.exe (HTTP server^)
) else if exist "Release\funasr-http-server.exe" (
    echo   [OK] funasr-http-server.exe (HTTP server^)
) else (
    echo   [X] funasr-http-server.exe (failed to build^)
)

if exist "bin\Release\funasr-wss-server.exe" (
    echo   [OK] funasr-wss-server.exe (WebSocket server^)
) else if exist "bin\funasr-wss-server.exe" (
    echo   [OK] funasr-wss-server.exe (WebSocket server^)
) else if exist "Release\funasr-wss-server.exe" (
    echo   [OK] funasr-wss-server.exe (WebSocket server^)
) else (
    echo   [X] funasr-wss-server.exe (failed to build^)
)

echo.
echo To run the HTTP server:
echo   cd %SCRIPT_DIR%
echo   run_http_server.bat --model-dir C:\path\to\your\model
echo.
echo To test the HTTP server:
echo   python test_http_client.py --health
echo   python test_http_client.py --file C:\path\to\audio.wav

endlocal
