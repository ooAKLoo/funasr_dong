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

# Clear old CMake cache if exists
if (Test-Path "CMakeCache.txt") {
    Write-Host "Clearing old CMake cache..." -ForegroundColor Yellow
    Remove-Item "CMakeCache.txt" -Force
    Remove-Item "CMakeFiles" -Recurse -Force -ErrorAction SilentlyContinue
}

# Run CMake with Visual Studio generator
Write-Host ""
Write-Host "Running CMake..." -ForegroundColor Yellow

# Force Visual Studio generator with x64 architecture
cmake -G "Visual Studio 17 2022" -A x64 $SCRIPT_DIR

if ($LASTEXITCODE -ne 0) {
    Write-Host ""
    Write-Host "Error: CMake configuration failed!" -ForegroundColor Red
    Write-Host ""
    Write-Host "Please make sure you have one of the following installed:" -ForegroundColor Yellow
    Write-Host "  1. Visual Studio with C++ tools" -ForegroundColor White
    Write-Host "  2. MinGW-w64" -ForegroundColor White
    Write-Host ""
    Write-Host "If using Visual Studio, run from 'Developer PowerShell for VS'" -ForegroundColor Yellow
    exit 1
}

Write-Host "CMake configuration successful!" -ForegroundColor Green

# Build the project
Write-Host ""
Write-Host "Building project..." -ForegroundColor Yellow
$NUM_PROCESSORS = $env:NUMBER_OF_PROCESSORS
if (-not $NUM_PROCESSORS) {
    $NUM_PROCESSORS = 4
}

cmake --build . --config Release --parallel $NUM_PROCESSORS

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
