# Build script for FunASR HTTP Server (Windows PowerShell)

# Exit on any error
$ErrorActionPreference = "Stop"

$SCRIPT_DIR = Split-Path -Parent $MyInvocation.MyCommand.Path
$BUILD_DIR = Join-Path $SCRIPT_DIR "build"

Write-Host "Building FunASR HTTP Server..." -ForegroundColor Cyan
Write-Host "Source directory: $SCRIPT_DIR"
Write-Host "Build directory: $BUILD_DIR"

# Create build directory
if (-not (Test-Path $BUILD_DIR)) {
    Write-Host "Creating build directory..." -ForegroundColor Yellow
    New-Item -ItemType Directory -Path $BUILD_DIR | Out-Null
}

Set-Location $BUILD_DIR

# Check if CMakeLists.txt exists in parent directory
$CMAKE_FILE = Join-Path $SCRIPT_DIR "CMakeLists.txt"
if (-not (Test-Path $CMAKE_FILE)) {
    Write-Host "Error: CMakeLists.txt not found in $SCRIPT_DIR" -ForegroundColor Red
    exit 1
}

# Run CMake with appropriate generator
Write-Host ""
Write-Host "Running CMake..." -ForegroundColor Yellow
Write-Host "Detecting available generator..." -ForegroundColor Cyan

$USE_MINGW = $false
$CMAKE_SUCCESS = $false

# Try MinGW first
$gccExists = Get-Command gcc -ErrorAction SilentlyContinue
if ($gccExists) {
    Write-Host "Found MinGW GCC, using MinGW Makefiles generator..." -ForegroundColor Green
    cmake -G "MinGW Makefiles" $SCRIPT_DIR
    if ($LASTEXITCODE -eq 0) {
        $USE_MINGW = $true
        $CMAKE_SUCCESS = $true
    }
}

# Try Visual Studio generators if MinGW failed or not available
if (-not $CMAKE_SUCCESS) {
    Write-Host "Trying Visual Studio generators..." -ForegroundColor Cyan

    # Try VS 2022
    cmake -G "Visual Studio 17 2022" -A x64 $SCRIPT_DIR 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Using Visual Studio 2022 generator" -ForegroundColor Green
        $CMAKE_SUCCESS = $true
    } else {
        # Try VS 2019
        cmake -G "Visual Studio 16 2019" -A x64 $SCRIPT_DIR 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-Host "Using Visual Studio 2019 generator" -ForegroundColor Green
            $CMAKE_SUCCESS = $true
        } else {
            # Try VS 2017
            cmake -G "Visual Studio 15 2017" -A x64 $SCRIPT_DIR 2>$null
            if ($LASTEXITCODE -eq 0) {
                Write-Host "Using Visual Studio 2017 generator" -ForegroundColor Green
                $CMAKE_SUCCESS = $true
            }
        }
    }
}

if (-not $CMAKE_SUCCESS) {
    Write-Host ""
    Write-Host "Error: No suitable compiler found!" -ForegroundColor Red
    Write-Host ""
    Write-Host "Please install one of the following:" -ForegroundColor Yellow
    Write-Host "  1. MinGW-w64: https://www.mingw-w64.org/" -ForegroundColor White
    Write-Host "  2. Visual Studio with C++ tools: https://visualstudio.microsoft.com/" -ForegroundColor White
    Write-Host ""
    Write-Host "Or run this script from 'Developer PowerShell for VS'" -ForegroundColor Yellow
    exit 1
}

# Build the project
Write-Host ""
Write-Host "Building project..." -ForegroundColor Yellow
$NUM_PROCESSORS = $env:NUMBER_OF_PROCESSORS
if (-not $NUM_PROCESSORS) {
    $NUM_PROCESSORS = 4
}

if ($USE_MINGW) {
    mingw32-make -j$NUM_PROCESSORS
} else {
    cmake --build . --config Release --parallel $NUM_PROCESSORS
}

if ($LASTEXITCODE -ne 0) {
    Write-Host "Build failed!" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "Build completed successfully!" -ForegroundColor Green
Write-Host ""
Write-Host "Executables built:"

# Check for built executables
$httpServerPaths = @(
    "bin\Release\funasr-http-server.exe",
    "bin\funasr-http-server.exe",
    "Release\funasr-http-server.exe"
)

$httpServerFound = $false
foreach ($path in $httpServerPaths) {
    if (Test-Path $path) {
        Write-Host "  ✓ funasr-http-server.exe (HTTP server)" -ForegroundColor Green
        $httpServerFound = $true
        break
    }
}
if (-not $httpServerFound) {
    Write-Host "  ✗ funasr-http-server.exe (failed to build)" -ForegroundColor Red
}

$wssServerPaths = @(
    "bin\Release\funasr-wss-server.exe",
    "bin\funasr-wss-server.exe",
    "Release\funasr-wss-server.exe"
)

$wssServerFound = $false
foreach ($path in $wssServerPaths) {
    if (Test-Path $path) {
        Write-Host "  ✓ funasr-wss-server.exe (WebSocket server)" -ForegroundColor Green
        $wssServerFound = $true
        break
    }
}
if (-not $wssServerFound) {
    Write-Host "  ✗ funasr-wss-server.exe (failed to build)" -ForegroundColor Red
}

Write-Host ""
Write-Host "To run the HTTP server:"
Write-Host "  cd $SCRIPT_DIR"
Write-Host "  .\run_http_server.ps1 --model-dir C:\path\to\your\model"
Write-Host ""
Write-Host "To test the HTTP server:"
Write-Host "  python test_http_client.py --health"
Write-Host "  python test_http_client.py --file C:\path\to\audio.wav"
