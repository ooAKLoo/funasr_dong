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

# Fix C++ "and" keyword for Windows MSVC
Write-Host "`nFixing C++ syntax for Windows..." -ForegroundColor Yellow
$cppFile = Join-Path $SCRIPT_DIR "..\onnxruntime\src\ct-transformer-online.cpp"
if (Test-Path $cppFile) {
    $content = Get-Content $cppFile -Raw
    if ($content -match '\band\b') {
        $content = $content -replace '\band\b', '&&'
        Set-Content -Path $cppFile -Value $content -NoNewline
        Write-Host "Fixed 'and' keyword" -ForegroundColor Green
    }
}

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

# Use Ninja generator (works with VS Developer PowerShell)
Write-Host "Using Ninja generator with x64 architecture..." -ForegroundColor Green

# Set environment to force x64 compilation
$env:VSCMD_ARG_TGT_ARCH = "x64"

cmake -G Ninja `
    -DCMAKE_BUILD_TYPE=Release `
    -DCMAKE_C_COMPILER=cl `
    -DCMAKE_CXX_COMPILER=cl `
    -DONNXRUNTIME_DIR="$ONNXRUNTIME_DIR" `
    -DFFMPEG_DIR="" `
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

# Build with Ninja (only show errors)
Write-Host "`nBuilding project with Ninja..." -ForegroundColor Yellow
Write-Host "This may take a few minutes. Only errors will be shown..." -ForegroundColor Gray

$NUM_PROCESSORS = $env:NUMBER_OF_PROCESSORS
if (-not $NUM_PROCESSORS) {
    $NUM_PROCESSORS = 4
}

# Capture output and only show errors
$output = ninja -j $NUM_PROCESSORS 2>&1 | Out-String
if ($LASTEXITCODE -ne 0) {
    Write-Host "`nBuild failed! Errors:" -ForegroundColor Red
    # Show only error lines
    $output -split "`n" | Where-Object {
        $_ -match "error" -or
        $_ -match "fatal" -or
        $_ -match "failed" -or
        $_ -match "LNK\d+" -or
        $_ -match "无法解析" -or
        $_ -match "冲突"
    } | ForEach-Object {
        Write-Host $_ -ForegroundColor Red
    }
    exit 1
} else {
    Write-Host "Build successful!" -ForegroundColor Green
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
