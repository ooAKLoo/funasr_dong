#!/bin/bash

# FunASR HTTP Server Start Script
# Based on the WebSocket server configuration

set -e

# Default configuration
HOST="0.0.0.0"
PORT=10095
THREAD_NUM=8

# Model paths (same as WebSocket version)
MODELS_BASE="/Users/yangdongju/Desktop/code_project/pc/Ohoo/python-service/models/models/iic"
MODEL_DIR="$MODELS_BASE/SenseVoiceSmall"
VAD_DIR="$MODELS_BASE/speech_fsmn_vad_zh-cn-16k-common-pytorch"
VAD_QUANT=""
PUNC_DIR=""
PUNC_QUANT=""
ITN_TAGGER=""
ITN_VERBALIZER=""

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --model-dir)
            MODEL_DIR="$2"
            shift 2
            ;;
        --vad-dir)
            VAD_DIR="$2"
            shift 2
            ;;
        --vad-quant)
            VAD_QUANT="$2"
            shift 2
            ;;
        --punc-dir)
            PUNC_DIR="$2"
            shift 2
            ;;
        --punc-quant)
            PUNC_QUANT="$2"
            shift 2
            ;;
        --itn-tagger)
            ITN_TAGGER="$2"
            shift 2
            ;;
        --itn-verbalizer)
            ITN_VERBALIZER="$2"
            shift 2
            ;;
        --host)
            HOST="$2"
            shift 2
            ;;
        --port)
            PORT="$2"
            shift 2
            ;;
        --thread-num)
            THREAD_NUM="$2"
            shift 2
            ;;
        --help|-h)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "OPTIONS:"
            echo "  --model-dir PATH       Path to ASR model directory (required)"
            echo "  --vad-dir PATH         Path to VAD model directory"
            echo "  --vad-quant PATH       Path to quantized VAD model"
            echo "  --punc-dir PATH        Path to punctuation model directory"
            echo "  --punc-quant PATH      Path to quantized punctuation model"
            echo "  --itn-tagger PATH      Path to ITN tagger FST"
            echo "  --itn-verbalizer PATH  Path to ITN verbalizer FST"
            echo "  --host HOST            Server host (default: 0.0.0.0)"
            echo "  --port PORT            Server port (default: 10095)"
            echo "  --thread-num NUM       Number of threads (default: 8)"
            echo "  --help, -h             Show this help message"
            echo ""
            echo "Example:"
            echo "  $0 --model-dir /path/to/model --port 8080"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Check if model directory exists
if [ ! -d "$MODEL_DIR" ]; then
    echo "❌ 未找到SenseVoice模型: $MODEL_DIR"
    echo "💡 请检查模型路径是否正确"
    exit 1
fi

# Check VAD model if specified
if [ -n "$VAD_DIR" ] && [ ! -d "$VAD_DIR" ]; then
    echo "⚠️  VAD模型路径不存在，将跳过VAD: $VAD_DIR"
    VAD_DIR=""
fi

echo "🚀 启动 FunASR HTTP 服务器..."
echo "📂 使用模型路径:"
echo "   SenseVoice: $MODEL_DIR"
if [ -n "$VAD_DIR" ]; then
    echo "   VAD: $VAD_DIR"
else
    echo "   VAD: (跳过)"
fi

# Find the executable
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SERVER_EXEC="$SCRIPT_DIR/build/bin/funasr-http-server"

if [ ! -f "$SERVER_EXEC" ]; then
    echo "Error: Server executable not found: $SERVER_EXEC"
    echo "Please build the project first:"
    echo "  cd $SCRIPT_DIR"
    echo "  mkdir -p build && cd build"
    echo "  cmake .. && make"
    exit 1
fi

# Build command line arguments
ARGS="--model-dir $MODEL_DIR --host $HOST --port $PORT --thread-num $THREAD_NUM"

if [ -n "$VAD_DIR" ]; then
    ARGS="$ARGS --vad-dir $VAD_DIR"
fi

if [ -n "$VAD_QUANT" ]; then
    ARGS="$ARGS --vad-quant $VAD_QUANT"
fi

if [ -n "$PUNC_DIR" ]; then
    ARGS="$ARGS --punc-dir $PUNC_DIR"
fi

if [ -n "$PUNC_QUANT" ]; then
    ARGS="$ARGS --punc-quant $PUNC_QUANT"
fi

if [ -n "$ITN_TAGGER" ]; then
    ARGS="$ARGS --itn-tagger $ITN_TAGGER"
fi

if [ -n "$ITN_VERBALIZER" ]; then
    ARGS="$ARGS --itn-verbalizer $ITN_VERBALIZER"
fi

echo "🌐 启动参数:"
echo "   主机: $HOST"
echo "   端口: $PORT"
echo "   线程数: $THREAD_NUM"
echo ""
echo "📡 服务端点:"
echo "   健康检查: http://$HOST:$PORT/health"
echo "   识别接口: http://$HOST:$PORT/recognize"
echo ""
echo "▶️  启动服务器..."
echo "========================================"

# Start the server
exec $SERVER_EXEC $ARGS