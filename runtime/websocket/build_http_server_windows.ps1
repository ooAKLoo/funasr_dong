# Build script for FunASR HTTP Server on Windows with all dependencies

$ErrorActionPreference = "Stop"

$SCRIPT_DIR = Split-Path -Parent $MyInvocation.MyCommand.Path
$BUILD_DIR = Join-Path $SCRIPT_DIR "build"

# Find ONNX Runtime directory
$ONNXRUNTIME_DIR = Get-ChildItem -Path $SCRIPT_DIR -Filter "onnxruntime-win-x64-*" -Directory | Select-Object -First 1 -ExpandProperty FullName

if (-not $ONNXRUNTIME_DIR) {
    Write-Host "Error: ONNX Runtime not found!" -ForegroundColor Red
    Write-Host "Please run setup_dependencies_windows.ps1 first" -ForegroundColor Yellow
    exit 1
}

Write-Host "Building FunASR HTTP Server..." -ForegroundColor Cyan
Write-Host "Source directory: $SCRIPT_DIR"
Write-Host "Build directory: $BUILD_DIR"
Write-Host "ONNX Runtime: $ONNXRUNTIME_DIR"

# Check if httplib.h exists
$HTTPLIB_FILE = Join-Path $SCRIPT_DIR "third_party\httplib.h"
if (-not (Test-Path $HTTPLIB_FILE)) {
    Write-Host "Error: httplib.h not found!" -ForegroundColor Red
    Write-Host "Please run setup_dependencies_windows.ps1 first" -ForegroundColor Yellow
    exit 1
}

# Clean build directory
if (Test-Path $BUILD_DIR) {
    Write-Host "Removing old build directory..." -ForegroundColor Yellow
    Remove-Item -Recurse -Force $BUILD_DIR
}

New-Item -ItemType Directory -Path $BUILD_DIR | Out-Null
Set-Location $BUILD_DIR

# Configure with CMake
Write-Host "`nRunning CMake configuration..." -ForegroundColor Yellow

# Try to find OpenSSL via vcpkg
$VCPKG_ROOT = $env:VCPKG_ROOT
$OPENSSL_ARG = ""
if ($VCPKG_ROOT) {
    Write-Host "Found vcpkg at: $VCPKG_ROOT" -ForegroundColor Green
    $OPENSSL_ARG = "-DOPENSSL_ROOT_DIR=$VCPKG_ROOT\installed\x64-windows"
}

cmake -G "Visual Studio 16 2019" -A x64 `
    -DONNXRUNTIME_DIR="$ONNXRUNTIME_DIR" `
    -DCMAKE_BUILD_TYPE=Release `
    $OPENSSL_ARG `
    $SCRIPT_DIR

if ($LASTEXITCODE -ne 0) {
    Write-Host "`nCMake configuration failed!" -ForegroundColor Red

    if (-not $VCPKG_ROOT) {
        Write-Host "`nOpenSSL may be missing. To install:" -ForegroundColor Yellow
        Write-Host "1. Install vcpkg: git clone https://github.com/Microsoft/vcpkg.git" -ForegroundColor White
        Write-Host "2. cd vcpkg && .\bootstrap-vcpkg.bat" -ForegroundColor White
        Write-Host "3. .\vcpkg install openssl:x64-windows" -ForegroundColor White
        Write-Host "4. Set environment variable: `$env:VCPKG_ROOT = 'C:\path\to\vcpkg'" -ForegroundColor White
    }

    exit 1
}

Write-Host "`nCMake configuration successful!" -ForegroundColor Green

# Build
Write-Host "`nBuilding project..." -ForegroundColor Yellow
$NUM_PROCESSORS = $env:NUMBER_OF_PROCESSORS
if (-not $NUM_PROCESSORS) {
    $NUM_PROCESSORS = 4
}

cmake --build . --config Release --parallel $NUM_PROCESSORS

if ($LASTEXITCODE -ne 0) {
    Write-Host "`nBuild failed!" -ForegroundColor Red
    exit 1
}

Write-Host "`n========================================" -ForegroundColor Green
Write-Host "Build completed successfully!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green

# Find and display built executables
Write-Host "`nLooking for executables..." -ForegroundColor Yellow

$exeLocations = @(
    "bin\Release",
    "Release",
    "bin"
)

foreach ($loc in $exeLocations) {
    $fullPath = Join-Path $BUILD_DIR $loc
    if (Test-Path $fullPath) {
        $exeFiles = Get-ChildItem -Path $fullPath -Filter "*.exe" -ErrorAction SilentlyContinue
        if ($exeFiles) {
            Write-Host "`nFound executables in: $loc" -ForegroundColor Green
            foreach ($exe in $exeFiles) {
                Write-Host "  - $($exe.Name)" -ForegroundColor White
                Write-Host "    Full path: $($exe.FullName)" -ForegroundColor Gray
            }
        }
    }
}

Write-Host "`nTo run the HTTP server:" -ForegroundColor Cyan
Write-Host "  cd $BUILD_DIR\bin\Release" -ForegroundColor White
Write-Host "  .\funasr-http-server.exe --help" -ForegroundColor White
