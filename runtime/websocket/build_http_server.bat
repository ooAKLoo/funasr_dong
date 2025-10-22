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

REM Run CMake with MinGW or Visual Studio generator
echo Running CMake...
echo.
echo Trying to detect available generator...

REM Try MinGW first (if available)
where gcc >nul 2>&1
if %errorlevel%==0 (
    echo Found MinGW GCC, using MinGW Makefiles generator...
    cmake -G "MinGW Makefiles" "%SCRIPT_DIR%"
    set "USE_MINGW=1"
) else (
    REM Try Visual Studio
    echo MinGW not found, trying Visual Studio generator...
    cmake -G "Visual Studio 17 2022" -A x64 "%SCRIPT_DIR%" 2>nul
    if errorlevel 1 (
        cmake -G "Visual Studio 16 2019" -A x64 "%SCRIPT_DIR%" 2>nul
        if errorlevel 1 (
            cmake -G "Visual Studio 15 2017" -A x64 "%SCRIPT_DIR%" 2>nul
            if errorlevel 1 (
                echo.
                echo Error: No suitable compiler found!
                echo.
                echo Please install one of the following:
                echo   1. MinGW-w64: https://www.mingw-w64.org/
                echo   2. Visual Studio with C++ tools: https://visualstudio.microsoft.com/
                echo.
                echo Or run this script from "Developer Command Prompt for VS"
                exit /b 1
            )
        )
    )
    set "USE_MINGW=0"
)

if errorlevel 1 (
    echo CMake configuration failed!
    exit /b 1
)

REM Build the project
echo.
echo Building project...
REM Detect number of processors
set "NUM_PROCESSORS=%NUMBER_OF_PROCESSORS%"
if "%NUM_PROCESSORS%"=="" set "NUM_PROCESSORS=4"

if "%USE_MINGW%"=="1" (
    mingw32-make -j%NUM_PROCESSORS%
) else (
    cmake --build . --config Release --parallel %NUM_PROCESSORS%
)

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
