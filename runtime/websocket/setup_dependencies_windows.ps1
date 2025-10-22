# Setup dependencies for Windows build

$ErrorActionPreference = "Stop"

$SCRIPT_DIR = Split-Path -Parent $MyInvocation.MyCommand.Path

Write-Host "Setting up dependencies for Windows build..." -ForegroundColor Cyan

# 1. Download httplib header
Write-Host "`nDownloading httplib.h..." -ForegroundColor Yellow
$HTTPLIB_DIR = Join-Path $SCRIPT_DIR "third_party"
if (-not (Test-Path $HTTPLIB_DIR)) {
    New-Item -ItemType Directory -Path $HTTPLIB_DIR | Out-Null
}

$HTTPLIB_URL = "https://raw.githubusercontent.com/yhirose/cpp-httplib/v0.14.3/httplib.h"
$HTTPLIB_FILE = Join-Path $HTTPLIB_DIR "httplib.h"

if (Test-Path $HTTPLIB_FILE) {
    Write-Host "httplib.h already exists" -ForegroundColor Green
} else {
    try {
        Invoke-WebRequest -Uri $HTTPLIB_URL -OutFile $HTTPLIB_FILE
        Write-Host "Downloaded httplib.h successfully" -ForegroundColor Green
    } catch {
        Write-Host "Failed to download httplib.h: $_" -ForegroundColor Red
        Write-Host "Please manually download from: $HTTPLIB_URL" -ForegroundColor Yellow
        Write-Host "And save it to: $HTTPLIB_FILE" -ForegroundColor Yellow
    }
}

# 2. Download ONNX Runtime
Write-Host "`nChecking ONNX Runtime..." -ForegroundColor Yellow
$ONNXRUNTIME_VERSION = "1.14.0"
$ONNXRUNTIME_DIR = Join-Path $SCRIPT_DIR "onnxruntime-win-x64-$ONNXRUNTIME_VERSION"

if (Test-Path $ONNXRUNTIME_DIR) {
    Write-Host "ONNX Runtime already exists at: $ONNXRUNTIME_DIR" -ForegroundColor Green
} else {
    Write-Host "ONNX Runtime not found. Downloading..." -ForegroundColor Yellow
    $ONNXRUNTIME_URL = "https://github.com/microsoft/onnxruntime/releases/download/v$ONNXRUNTIME_VERSION/onnxruntime-win-x64-$ONNXRUNTIME_VERSION.zip"
    $ONNXRUNTIME_ZIP = Join-Path $SCRIPT_DIR "onnxruntime.zip"

    try {
        Write-Host "Downloading from: $ONNXRUNTIME_URL" -ForegroundColor Cyan
        Invoke-WebRequest -Uri $ONNXRUNTIME_URL -OutFile $ONNXRUNTIME_ZIP

        Write-Host "Extracting..." -ForegroundColor Yellow
        Expand-Archive -Path $ONNXRUNTIME_ZIP -DestinationPath $SCRIPT_DIR -Force
        Remove-Item $ONNXRUNTIME_ZIP

        Write-Host "ONNX Runtime downloaded successfully" -ForegroundColor Green
    } catch {
        Write-Host "Failed to download ONNX Runtime: $_" -ForegroundColor Red
        Write-Host "`nPlease manually download ONNX Runtime:" -ForegroundColor Yellow
        Write-Host "1. Visit: https://github.com/microsoft/onnxruntime/releases/tag/v$ONNXRUNTIME_VERSION" -ForegroundColor White
        Write-Host "2. Download: onnxruntime-win-x64-$ONNXRUNTIME_VERSION.zip" -ForegroundColor White
        Write-Host "3. Extract to: $SCRIPT_DIR" -ForegroundColor White
        exit 1
    }
}

# 3. Check OpenSSL
Write-Host "`nChecking OpenSSL..." -ForegroundColor Yellow
$openssl = Get-Command openssl -ErrorAction SilentlyContinue
if ($openssl) {
    Write-Host "OpenSSL found at: $($openssl.Source)" -ForegroundColor Green
} else {
    Write-Host "OpenSSL not found. You may need to install it." -ForegroundColor Yellow
    Write-Host "You can install via: " -ForegroundColor White
    Write-Host "  1. vcpkg: vcpkg install openssl:x64-windows" -ForegroundColor White
    Write-Host "  2. Or download from: https://slproweb.com/products/Win32OpenSSL.html" -ForegroundColor White
}

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Setup Summary:" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "httplib.h: " -NoNewline
if (Test-Path $HTTPLIB_FILE) {
    Write-Host "OK" -ForegroundColor Green
} else {
    Write-Host "MISSING" -ForegroundColor Red
}

Write-Host "ONNX Runtime: " -NoNewline
if (Test-Path $ONNXRUNTIME_DIR) {
    Write-Host "OK" -ForegroundColor Green
    Write-Host "  Path: $ONNXRUNTIME_DIR" -ForegroundColor Gray
} else {
    Write-Host "MISSING" -ForegroundColor Red
}

Write-Host "`nNext steps:" -ForegroundColor Yellow
Write-Host "Run: .\build_http_server_windows.ps1" -ForegroundColor White
