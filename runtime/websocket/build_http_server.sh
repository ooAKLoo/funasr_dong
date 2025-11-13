#!/bin/bash

# FunASR HTTP Server 构建脚本
# 包含完整的依赖检查和自动配置


set -e  # 遇到错误立即退出
set -o pipefail  # 任何管道命令失败即失败

# ============================================
# 颜色输出
# ============================================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

success() {
    echo -e "${GREEN}✓${NC} $1"
}

warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

error() {
    echo -e "${RED}✗${NC} $1"
}

# ============================================
# 路径配置
# ============================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="$SCRIPT_DIR/build"
RUNTIME_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
ONNXRUNTIME_DIR="$RUNTIME_DIR/onnxruntime"

info "脚本目录: $SCRIPT_DIR"
info "构建目录: $BUILD_DIR"
info "Runtime目录: $RUNTIME_DIR"

# ============================================
# 系统环境检查
# ============================================
echo ""
info "检查系统环境..."

# 检查架构
ARCH=$(uname -m)
success "系统架构: $ARCH"

# 检查操作系统
OS=$(uname -s)
if [ "$OS" != "Darwin" ]; then
    error "此脚本仅支持 macOS"
    exit 1
fi
success "操作系统: macOS"

# ============================================
# 编译器检查
# ============================================
echo ""
info "检查编译器..."

# 优先使用 Apple Clang
if [ -f "/usr/bin/clang" ]; then
    export CC=/usr/bin/clang
    export CXX=/usr/bin/clang++
    export PATH="/usr/bin:/bin:/usr/sbin:/sbin:$PATH"

    CLANG_VERSION=$(/usr/bin/clang --version | head -1)
    success "使用 Apple Clang: $CLANG_VERSION"
else
    error "未找到 Apple Clang，请安装 Xcode Command Line Tools:"
    echo "  sudo xcode-select --install"
    exit 1
fi

# 检查 SDK
SDK_PATH=$(xcrun --show-sdk-path 2>/dev/null || echo "")
if [ -z "$SDK_PATH" ] || [ ! -d "$SDK_PATH" ]; then
    error "未找到 macOS SDK，请重新安装 Xcode Command Line Tools"
    exit 1
fi
success "SDK 路径: $SDK_PATH"

# ============================================
# CMake 检查
# ============================================
echo ""
info "检查 CMake..."

if ! command -v cmake &> /dev/null; then
    error "未找到 CMake，请先安装:"
    echo "  brew install cmake"
    exit 1
fi
CMAKE_VERSION=$(cmake --version | head -1)
success "CMake 版本: $CMAKE_VERSION"

# ============================================
# ONNX Runtime 检查
# ============================================
echo ""
info "检查 ONNX Runtime..."

ONNXRUNTIME_FOUND=false

# 方法1: 检查本地 onnxruntime 目录
info "检查目录: $ONNXRUNTIME_DIR"
if [ -d "$ONNXRUNTIME_DIR/lib" ] && [ -d "$ONNXRUNTIME_DIR/include" ]; then
    success "找到本地 ONNX Runtime: $ONNXRUNTIME_DIR"

    info "检查 lib 目录内容..."
    ls -lh "$ONNXRUNTIME_DIR/lib/" | head -5

    ONNXRUNTIME_FOUND=true

    # 检查架构匹配（简化版，避免 file 命令卡住）
    if [ -f "$ONNXRUNTIME_DIR/lib/libonnxruntime.dylib" ]; then
        info "找到 libonnxruntime.dylib"
        # 使用 lipo 代替 file 命令（更快更可靠）
        if command -v lipo &> /dev/null; then
            LIB_ARCH=$(lipo -info "$ONNXRUNTIME_DIR/lib/libonnxruntime.dylib" 2>/dev/null | grep -o "arm64\|x86_64" | head -1)
            if [ -n "$LIB_ARCH" ]; then
                if [ "$LIB_ARCH" != "$ARCH" ]; then
                    warning "ONNX Runtime 架构 ($LIB_ARCH) 与系统架构 ($ARCH) 不匹配"
                    ONNXRUNTIME_FOUND=false
                else
                    success "ONNX Runtime 架构匹配: $LIB_ARCH"
                fi
            else
                warning "无法检测 ONNX Runtime 架构，假设匹配"
            fi
        else
            warning "lipo 命令不可用，跳过架构检查"
        fi
    elif [ -f "$ONNXRUNTIME_DIR/lib/libonnxruntime.a" ]; then
        success "找到静态库 libonnxruntime.a"
    else
        warning "未找到 ONNX Runtime 库文件"
        info "lib 目录内容:"
        ls -la "$ONNXRUNTIME_DIR/lib/" 2>/dev/null || echo "  (无法列出)"
    fi
else
    info "未找到本地 ONNX Runtime (检查 lib 和 include 目录)"
fi

# 方法2: 检查 Homebrew 安装的 ONNX Runtime（仅 ARM64）
if [ "$ONNXRUNTIME_FOUND" = false ]; then
    # 强制使用 ARM64 Homebrew
    if [ "$ARCH" = "arm64" ]; then
        ARM_BREW="/opt/homebrew/bin/brew"
        if [ -f "$ARM_BREW" ]; then
            BREW_ONNX=$($ARM_BREW --prefix onnxruntime 2>/dev/null || echo "")
            if [ -n "$BREW_ONNX" ] && [ -d "$BREW_ONNX" ]; then
                info "找到 ARM64 Homebrew ONNX Runtime: $BREW_ONNX"
                ONNXRUNTIME_DIR="$BREW_ONNX"
                ONNXRUNTIME_FOUND=true
                success "将使用 ARM64 Homebrew 安装的 ONNX Runtime"
            fi
        elif [ -f "/usr/local/bin/brew" ]; then
            warning "检测到 Intel (x86_64) Homebrew，但系统是 ARM64"
            warning "请安装 ARM64 版本的 Homebrew:"
            echo "  /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
        fi
    else
        # x86_64 系统，使用标准 Homebrew
        if command -v brew &> /dev/null; then
            BREW_ONNX=$(brew --prefix onnxruntime 2>/dev/null || echo "")
            if [ -n "$BREW_ONNX" ] && [ -d "$BREW_ONNX" ]; then
                info "找到 Homebrew ONNX Runtime: $BREW_ONNX"
                ONNXRUNTIME_DIR="$BREW_ONNX"
                ONNXRUNTIME_FOUND=true
            fi
        fi
    fi
fi

# 如果未找到，尝试自动安装
if [ "$ONNXRUNTIME_FOUND" = false ]; then
    warning "未找到 ONNX Runtime，尝试自动安装..."
    echo ""

    # 尝试使用 ARM64 Homebrew 安装
    ARM_BREW="/opt/homebrew/bin/brew"
    if [ "$ARCH" = "arm64" ] && [ -f "$ARM_BREW" ]; then
        info "使用 ARM64 Homebrew 安装 ONNX Runtime..."

        if $ARM_BREW install onnxruntime; then
            success "ONNX Runtime 已通过 ARM64 Homebrew 安装"

            # 重新检查
            BREW_ONNX=$($ARM_BREW --prefix onnxruntime 2>/dev/null || echo "")
            if [ -n "$BREW_ONNX" ] && [ -d "$BREW_ONNX" ]; then
                ONNXRUNTIME_DIR="$BREW_ONNX"
                ONNXRUNTIME_FOUND=true
                success "ONNX Runtime 路径: $ONNXRUNTIME_DIR"
            fi
        else
            warning "Homebrew 安装失败，尝试下载预编译版本..."
        fi
    elif [ "$ARCH" = "arm64" ]; then
        warning "未找到 ARM64 Homebrew，跳过自动安装"
        info "请先安装 ARM64 Homebrew 或将自动下载预编译版本"
    elif command -v brew &> /dev/null; then
        # x86_64 使用标准 brew
        if brew install onnxruntime; then
            success "ONNX Runtime 已安装"
            BREW_ONNX=$(brew --prefix onnxruntime 2>/dev/null || echo "")
            if [ -n "$BREW_ONNX" ]; then
                ONNXRUNTIME_DIR="$BREW_ONNX"
                ONNXRUNTIME_FOUND=true
            fi
        fi
    fi

    # 如果 Homebrew 失败，尝试下载预编译版本
    if [ "$ONNXRUNTIME_FOUND" = false ]; then
        info "下载 ONNX Runtime 预编译版本..."

        cd "$RUNTIME_DIR"

        if [ "$ARCH" = "arm64" ]; then
            ONNX_VERSION="1.17.0"
            ONNX_FILE="onnxruntime-osx-arm64-${ONNX_VERSION}.tgz"
            ONNX_URL="https://github.com/microsoft/onnxruntime/releases/download/v${ONNX_VERSION}/${ONNX_FILE}"
            ONNX_DIR="onnxruntime-osx-arm64-${ONNX_VERSION}"
        else
            ONNX_VERSION="1.17.0"
            ONNX_FILE="onnxruntime-osx-x86_64-${ONNX_VERSION}.tgz"
            ONNX_URL="https://github.com/microsoft/onnxruntime/releases/download/v${ONNX_VERSION}/${ONNX_FILE}"
            ONNX_DIR="onnxruntime-osx-x86_64-${ONNX_VERSION}"
        fi

        info "下载 URL: $ONNX_URL"

        # 检查是否已下载
        if [ -f "$ONNX_FILE" ]; then
            info "发现已下载的文件: $ONNX_FILE"
        else
            # 尝试下载
            if command -v curl &> /dev/null; then
                info "使用 curl 下载..."
                if curl -L -o "$ONNX_FILE" "$ONNX_URL"; then
                    success "下载完成"
                else
                    error "下载失败"
                    echo ""
                    echo "请手动下载 ONNX Runtime:"
                    echo "  $ONNX_URL"
                    echo ""
                    exit 1
                fi
            elif command -v wget &> /dev/null; then
                info "使用 wget 下载..."
                if wget "$ONNX_URL"; then
                    success "下载完成"
                else
                    error "下载失败"
                    exit 1
                fi
            else
                error "未找到 curl 或 wget，无法下载"
                echo ""
                echo "请手动下载 ONNX Runtime:"
                echo "  $ONNX_URL"
                echo "并解压到: $RUNTIME_DIR/onnxruntime"
                echo ""
                exit 1
            fi
        fi

        # 解压
        info "解压 $ONNX_FILE..."
        if tar -xzf "$ONNX_FILE"; then
            success "解压完成"

            # 重命名为标准路径
            if [ -d "$ONNX_DIR" ]; then
                if [ -d "onnxruntime" ]; then
                    warning "onnxruntime 目录已存在，备份为 onnxruntime.old"
                    rm -rf onnxruntime.old
                    mv onnxruntime onnxruntime.old
                fi

                mv "$ONNX_DIR" onnxruntime
                success "ONNX Runtime 已安装到: $RUNTIME_DIR/onnxruntime"

                ONNXRUNTIME_DIR="$RUNTIME_DIR/onnxruntime"
                ONNXRUNTIME_FOUND=true

                # 清理下载文件
                info "清理下载文件..."
                rm -f "$ONNX_FILE"
            else
                error "解压后未找到预期目录: $ONNX_DIR"
                exit 1
            fi
        else
            error "解压失败"
            exit 1
        fi
    fi
fi

# 最终检查
if [ "$ONNXRUNTIME_FOUND" = false ]; then
    error "所有自动安装方法均失败！"
    echo ""
    echo "请手动安装 ONNX Runtime:"
    echo ""
    echo "方法1: 使用 Homebrew"
    echo "  brew install onnxruntime"
    echo ""
    echo "方法2: 手动下载"
    if [ "$ARCH" = "arm64" ]; then
        echo "  curl -L -o onnxruntime.tgz https://github.com/microsoft/onnxruntime/releases/download/v1.17.0/onnxruntime-osx-arm64-1.17.0.tgz"
    else
        echo "  curl -L -o onnxruntime.tgz https://github.com/microsoft/onnxruntime/releases/download/v1.17.0/onnxruntime-osx-x86_64-1.17.0.tgz"
    fi
    echo "  tar -xzf onnxruntime.tgz"
    echo "  mv onnxruntime-* $RUNTIME_DIR/onnxruntime"
    echo ""
    exit 1
fi

success "ONNX Runtime 准备就绪: $ONNXRUNTIME_DIR"

# ============================================
# OpenSSL 检查
# ============================================
echo ""
info "检查 OpenSSL..."

# 检查系统 OpenSSL
if pkg-config --exists openssl 2>/dev/null; then
    OPENSSL_VERSION=$(pkg-config --modversion openssl)
    success "找到 OpenSSL: $OPENSSL_VERSION"
# 检查 Homebrew OpenSSL
elif [ -d "/opt/homebrew/opt/openssl@3" ]; then
    export PKG_CONFIG_PATH="/opt/homebrew/opt/openssl@3/lib/pkgconfig:$PKG_CONFIG_PATH"
    success "找到 Homebrew OpenSSL@3"
elif [ -d "/usr/local/opt/openssl@3" ]; then
    export PKG_CONFIG_PATH="/usr/local/opt/openssl@3/lib/pkgconfig:$PKG_CONFIG_PATH"
    success "找到 Homebrew OpenSSL@3"
else
    warning "未找到 OpenSSL，尝试安装:"
    echo "  brew install openssl@3"
fi

# ============================================
# FFmpeg 检查
# ============================================
echo ""
info "检查 FFmpeg..."

FFMPEG_FOUND=false

# 方法1: 检查本地 ffmpeg 目录
if [ -d "$RUNTIME_DIR/ffmpeg/lib" ]; then
    success "找到本地 FFmpeg: $RUNTIME_DIR/ffmpeg"
    FFMPEG_FOUND=true
fi

# 方法2: 检查 Homebrew FFmpeg（仅 ARM64）
if [ "$FFMPEG_FOUND" = false ]; then
    ARM_BREW="/opt/homebrew/bin/brew"
    if [ "$ARCH" = "arm64" ] && [ -f "$ARM_BREW" ]; then
        BREW_FFMPEG=$($ARM_BREW --prefix ffmpeg 2>/dev/null || echo "")
        if [ -n "$BREW_FFMPEG" ] && [ -d "$BREW_FFMPEG" ]; then
            info "找到 ARM64 Homebrew FFmpeg: $BREW_FFMPEG"
            FFMPEG_DIR="$BREW_FFMPEG"
            FFMPEG_FOUND=true
        fi
    elif [ "$ARCH" != "arm64" ] && command -v brew &> /dev/null; then
        BREW_FFMPEG=$(brew --prefix ffmpeg 2>/dev/null || echo "")
        if [ -n "$BREW_FFMPEG" ] && [ -d "$BREW_FFMPEG" ]; then
            info "找到 Homebrew FFmpeg: $BREW_FFMPEG"
            FFMPEG_DIR="$BREW_FFMPEG"
            FFMPEG_FOUND=true
        fi
    fi
fi

# 如果未找到，尝试安装
if [ "$FFMPEG_FOUND" = false ]; then
    warning "未找到 FFmpeg，尝试自动安装..."

    ARM_BREW="/opt/homebrew/bin/brew"
    if [ "$ARCH" = "arm64" ] && [ -f "$ARM_BREW" ]; then
        info "使用 ARM64 Homebrew 安装 FFmpeg..."
        if $ARM_BREW install ffmpeg 2>&1 | grep -v "Warning:" | grep -v "Already installed"; then
            success "FFmpeg 安装成功"
            BREW_FFMPEG=$($ARM_BREW --prefix ffmpeg 2>/dev/null || echo "")
            if [ -n "$BREW_FFMPEG" ]; then
                FFMPEG_DIR="$BREW_FFMPEG"
                FFMPEG_FOUND=true
            fi
        fi
    elif command -v brew &> /dev/null; then
        info "使用 Homebrew 安装 FFmpeg..."
        if brew install ffmpeg 2>&1 | grep -v "Warning:" | grep -v "Already installed"; then
            success "FFmpeg 安装成功"
            BREW_FFMPEG=$(brew --prefix ffmpeg 2>/dev/null || echo "")
            if [ -n "$BREW_FFMPEG" ]; then
                FFMPEG_DIR="$BREW_FFMPEG"
                FFMPEG_FOUND=true
            fi
        fi
    fi
fi

if [ "$FFMPEG_FOUND" = false ]; then
    error "未找到 FFmpeg！"
    echo ""
    echo "FFmpeg 是编译所必需的依赖。请安装:"
    echo "  brew install ffmpeg"
    echo ""
    exit 1
fi

success "FFmpeg 准备就绪: ${FFMPEG_DIR:-$RUNTIME_DIR/ffmpeg}"

# ============================================
# 清理旧构建
# ============================================
echo ""
info "准备构建目录..."

if [ -d "$BUILD_DIR" ]; then
    warning "清理旧的构建目录"
    rm -rf "$BUILD_DIR"
fi

mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"
success "构建目录已创建: $BUILD_DIR"

# ============================================
# CMake 配置
# ============================================
echo ""
info "运行 CMake 配置..."

CMAKE_ARGS=(
    "$SCRIPT_DIR"
    -DCMAKE_BUILD_TYPE=Release
    -DCMAKE_OSX_ARCHITECTURES="$ARCH"
    -DCMAKE_C_COMPILER="$CC"
    -DCMAKE_CXX_COMPILER="$CXX"
    -DCMAKE_OSX_SYSROOT="$SDK_PATH"
    -DONNXRUNTIME_DIR="$ONNXRUNTIME_DIR"
)

# 如果使用 Homebrew 的 ONNX Runtime，添加 include 路径
if [[ "$ONNXRUNTIME_DIR" == *"homebrew"* ]] || [[ "$ONNXRUNTIME_DIR" == *"Cellar"* ]]; then
    info "检测到 Homebrew ONNX Runtime，添加额外的 include 路径"
    # 优先使用 ARM Homebrew 前缀，避免误用 Intel (/usr/local) 库
    if [ "$ARCH" = "arm64" ] && [ -x "/opt/homebrew/bin/brew" ]; then
        HOMEBREW_PREFIX=$(/opt/homebrew/bin/brew --prefix)
    elif command -v brew &>/dev/null; then
        HOMEBREW_PREFIX=$(brew --prefix)
    else
        HOMEBREW_PREFIX="/opt/homebrew"
    fi

    CMAKE_ARGS+=(
        -DCMAKE_CXX_FLAGS="-I${HOMEBREW_PREFIX}/include"
        -DCMAKE_PREFIX_PATH="${HOMEBREW_PREFIX}"
        -DOPENSSL_ROOT_DIR="${HOMEBREW_PREFIX}/opt/openssl@3"
        -DOPENSSL_INCLUDE_DIR="${HOMEBREW_PREFIX}/opt/openssl@3/include"
        -DOPENSSL_CRYPTO_LIBRARY="${HOMEBREW_PREFIX}/opt/openssl@3/lib/libcrypto.dylib"
        -DOPENSSL_SSL_LIBRARY="${HOMEBREW_PREFIX}/opt/openssl@3/lib/libssl.dylib"
    )
    success "Homebrew 前缀: $HOMEBREW_PREFIX"
fi

# 添加 FFmpeg 路径
if [ -n "$FFMPEG_DIR" ]; then
    CMAKE_ARGS+=(-DFFMPEG_DIR="$FFMPEG_DIR")
    info "使用 FFmpeg: $FFMPEG_DIR"
elif [ -d "$RUNTIME_DIR/ffmpeg" ]; then
    CMAKE_ARGS+=(-DFFMPEG_DIR="$RUNTIME_DIR/ffmpeg")
    info "使用本地 FFmpeg: $RUNTIME_DIR/ffmpeg"
fi

echo "CMake 参数:"
for arg in "${CMAKE_ARGS[@]}"; do
    echo "  $arg"
done

if cmake "${CMAKE_ARGS[@]}"; then
    success "CMake 配置成功"
else
    error "CMake 配置失败"
    exit 1
fi

# ============================================
# 编译
# ============================================
echo ""
info "开始编译..."

# 获取 CPU 核心数
if command -v sysctl &> /dev/null; then
    NPROC=$(sysctl -n hw.ncpu)
else
    NPROC=4
fi

info "使用 $NPROC 个并行任务编译（仅显示错误信息）..."
echo ""

# 捕获编译输出，只显示错误和进度
BUILD_LOG="$BUILD_DIR/build.log"

if make -j"$NPROC" 2>&1 | tee "$BUILD_LOG" | grep --line-buffered -E "^\[|error:|fatal error:|ld:|clang\+\+: error" | while IFS= read -r line; do
    if [[ "$line" =~ ^\[ ]]; then
        # 显示进度（每10%显示一次）
        if [[ "$line" =~ \[([ 0-9][0-9]?|100)%\] ]]; then
            percent="${BASH_REMATCH[1]}"
            if (( percent % 10 == 0 )); then
                echo -ne "\r进度: $percent% "
            fi
        fi
    else
        # 显示错误
        echo ""
        echo -e "${RED}$line${NC}"
    fi
done; then
    echo ""
    success "编译成功！"
else
    echo ""
    error "编译失败"
    echo ""
    warning "完整编译日志已保存到: $BUILD_LOG"
    echo ""
    echo "最后20行错误信息:"
    echo "----------------------------------------"
    tail -20 "$BUILD_LOG" | grep -E "error:|fatal error:|ld:" || tail -20 "$BUILD_LOG"
    echo "----------------------------------------"
    exit 1
fi

# ============================================
# 验证构建结果
# ============================================
echo ""
info "验证构建结果..."

BUILD_SUCCESS=true

if [ -f "$BUILD_DIR/bin/funasr-http-server" ]; then
    success "HTTP 服务器已构建: bin/funasr-http-server"

    # 检查可执行文件架构
    BIN_ARCH=$(file "$BUILD_DIR/bin/funasr-http-server" | grep -o "arm64\|x86_64")
    if [ "$BIN_ARCH" = "$ARCH" ]; then
        success "可执行文件架构正确: $BIN_ARCH"
    else
        warning "可执行文件架构 ($BIN_ARCH) 与系统架构 ($ARCH) 不匹配"
    fi
else
    error "HTTP 服务器构建失败"
    BUILD_SUCCESS=false
fi

if [ -f "$BUILD_DIR/bin/funasr-wss-server" ]; then
    success "WebSocket 服务器已构建: bin/funasr-wss-server"
else
    warning "WebSocket 服务器未构建（可能未启用）"
fi

# ============================================
# 构建总结
# ============================================
echo ""
echo "======================================"
if [ "$BUILD_SUCCESS" = true ]; then
    success "构建完成！"
    echo ""
    echo "运行 HTTP 服务器:"
    echo "  cd $SCRIPT_DIR"
    echo "  ./build/bin/funasr-http-server \\"
    echo "    --model-dir /path/to/your/model \\"
    echo "    --port 10095"
    echo ""
    echo "测试健康检查:"
    echo "  curl http://localhost:10095/health"
else
    error "构建失败，请检查上述错误信息"
    exit 1
fi
echo "======================================"
