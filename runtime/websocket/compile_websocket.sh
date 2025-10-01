#!/bin/bash
set -e

echo "开始编译 FunASR WebSocket..."

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="$SCRIPT_DIR/build"
ONNXRUNTIME_DIR="$SCRIPT_DIR/onnxruntime-osx-arm64-1.14.0"

[ -d "$BUILD_DIR" ] && rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR" && cd "$BUILD_DIR"

echo "配置CMake..."
cmake .. \
    -DCMAKE_BUILD_TYPE=Release \
    -DONNXRUNTIME_DIR="$ONNXRUNTIME_DIR" \
    -DCMAKE_OSX_ARCHITECTURES=arm64 \
    -DFFMPEG_DIR=/opt/homebrew/opt/ffmpeg \
    -DOPENSSL_ROOT_DIR=/opt/homebrew/opt/openssl@3

echo "编译中..."
make -j$(sysctl -n hw.ncpu) 2>&1 | grep -E "(error:|fatal error:|Built target funasr-wss|Undefined symbols)" || true

if [ -f "$BUILD_DIR/bin/funasr-wss-server" ]; then
    echo "✅ 编译成功！"
    ls -lh "$BUILD_DIR/bin/funasr-wss-"*
else
    echo "❌ 编译失败"
fi
