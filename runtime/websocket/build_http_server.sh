#!/bin/bash

# Build script for FunASR HTTP Server

set -e  # Exit on any error

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="$SCRIPT_DIR/build"

echo "Building FunASR HTTP Server..."
echo "Source directory: $SCRIPT_DIR"
echo "Build directory: $BUILD_DIR"

# Create build directory
if [ ! -d "$BUILD_DIR" ]; then
    echo "Creating build directory..."
    mkdir -p "$BUILD_DIR"
fi

cd "$BUILD_DIR"

# Check if CMakeLists.txt exists in parent directory
if [ ! -f "$SCRIPT_DIR/CMakeLists.txt" ]; then
    echo "Error: CMakeLists.txt not found in $SCRIPT_DIR"
    exit 1
fi

# Run CMake
echo "Running CMake..."
cmake "$SCRIPT_DIR"

# Build the project
echo "Building project..."
make -j$(nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 4)

echo ""
echo "Build completed successfully!"
echo ""
echo "Executables built:"
if [ -f "bin/funasr-http-server" ]; then
    echo "  ✓ funasr-http-server (HTTP server)"
else
    echo "  ✗ funasr-http-server (failed to build)"
fi

if [ -f "bin/funasr-wss-server" ]; then
    echo "  ✓ funasr-wss-server (WebSocket server)"
else
    echo "  ✗ funasr-wss-server (failed to build)"
fi

echo ""
echo "To run the HTTP server:"
echo "  cd $SCRIPT_DIR"
echo "  ./run_http_server.sh --model-dir /path/to/your/model"
echo ""
echo "To test the HTTP server:"
echo "  python3 test_http_client.py --health"
echo "  python3 test_http_client.py --file /path/to/audio.wav"