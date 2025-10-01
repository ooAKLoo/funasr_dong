#!/bin/bash

# WebSocket FunASR 启动脚本
# Usage: ./run_websocket.sh

set -e

echo "🚀 启动 FunASR WebSocket 服务器 (SenseVoice模型)..."

# 检查当前目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WEBSOCKET_DIR="$SCRIPT_DIR"
BUILD_DIR="$WEBSOCKET_DIR/build"
BIN_DIR="$BUILD_DIR/bin"

# 模型路径配置
MODELS_BASE="/Users/yangdongju/Desktop/code_project/pc/Ohoo/python-service/models/models/iic"
SENSEVOICE_MODEL="$MODELS_BASE/SenseVoiceSmall"
VAD_MODEL="$MODELS_BASE/speech_fsmn_vad_zh-cn-16k-common-pytorch"

# 检查可执行文件
if [ ! -f "$BIN_DIR/funasr-wss-server" ]; then
    echo "❌ 未找到可执行文件: $BIN_DIR/funasr-wss-server"
    echo "💡 请先运行编译脚本: ./compile_websocket.sh"
    exit 1
fi

# 检查模型文件
if [ ! -d "$SENSEVOICE_MODEL" ]; then
    echo "❌ 未找到SenseVoice模型: $SENSEVOICE_MODEL"
    exit 1
fi

if [ ! -d "$VAD_MODEL" ]; then
    echo "❌ 未找到VAD模型: $VAD_MODEL"
    exit 1
fi

echo "📂 使用模型路径:"
echo "   SenseVoice: $SENSEVOICE_MODEL"
echo "   VAD: $VAD_MODEL"

# 切换到bin目录
cd "$BIN_DIR"

echo "🌐 启动参数:"
echo "   端口: 1758"
echo "   监听地址: 0.0.0.0"
echo "   模型: SenseVoice + VAD"

echo ""
echo "▶️  启动服务器..."
echo "========================================"

# 启动WebSocket服务器 (只使用SenseVoice，不使用外部VAD)
./funasr-wss-server \
    --model-dir "$SENSEVOICE_MODEL" \
    --port 1758 \
    --listen-ip 0.0.0.0 \
    --quantize false \
    --vad-dir "" \
    --punc-dir "" \
    --itn-dir ""

echo ""
echo "🛑 服务器已停止"