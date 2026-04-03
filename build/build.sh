#!/usr/bin/env bash
# build/build.sh — AIOS-Lite llama.cpp build script
# © 2026 Chris Betts | AIOSCPU Official | AI-generated, fully legal
#
# Clones and compiles llama.cpp for the current platform.
# Supports: hosted Linux/macOS, Android (Termux), cross-compiled ARM.
#
# Usage:
#   bash build/build.sh [options]
#
# Options:
#   --target <hosted|termux|arm64>   Build target (default: hosted)
#   --jobs <n>                       Parallel build jobs (default: nproc)
#   --clean                          Remove build dir before building
#   --no-metal                       Disable Metal GPU (macOS)
#   --no-cublas                      Disable CUDA (NVIDIA GPU)
#   --help                           Show this help
#
# After building, llama-cli is placed at:
#   build/llama.cpp/llama-cli
# and a symlink is created at OS/bin/llama-cli.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BUILD_DIR="$SCRIPT_DIR/llama.cpp"
LLAMA_REPO="https://github.com/ggerganov/llama.cpp.git"
LLAMA_TAG="master"   # or pin to a release, e.g. "b3248"

# Defaults
TARGET="hosted"
JOBS=$(nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 4)
CLEAN=0
NO_METAL=0
NO_CUBLAS=0

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------
while [[ $# -gt 0 ]]; do
    case "$1" in
        --target)   TARGET="$2"; shift 2 ;;
        --jobs)     JOBS="$2"; shift 2 ;;
        --clean)    CLEAN=1; shift ;;
        --no-metal) NO_METAL=1; shift ;;
        --no-cublas) NO_CUBLAS=1; shift ;;
        --help|-h)
            sed -n '3,20p' "$0"
            exit 0
            ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

# ---------------------------------------------------------------------------
# Helper functions
# ---------------------------------------------------------------------------
info()    { echo "[build] $*"; }
success() { echo "[build] ✓ $*"; }
warn()    { echo "[build] ⚠ $*" >&2; }
die()     { echo "[build] ✗ $*" >&2; exit 1; }

check_deps() {
    local missing=()
    for cmd in git cmake make; do
        command -v "$cmd" &>/dev/null || missing+=("$cmd")
    done
    if [[ ${#missing[@]} -gt 0 ]]; then
        warn "Missing build tools: ${missing[*]}"
        info "Install with:"
        info "  apt: sudo apt install git cmake build-essential"
        info "  pkg: pkg install git cmake make clang"
        info "  brew: brew install git cmake"
        die "Please install missing tools and retry."
    fi
    # C++ compiler
    if ! command -v c++ &>/dev/null && ! command -v g++ &>/dev/null && ! command -v clang++ &>/dev/null; then
        die "No C++ compiler found. Install g++ or clang++."
    fi
}

# ---------------------------------------------------------------------------
# Clone or update llama.cpp
# ---------------------------------------------------------------------------
prepare_source() {
    if [[ "$CLEAN" -eq 1 && -d "$BUILD_DIR" ]]; then
        info "Cleaning build directory: $BUILD_DIR"
        rm -rf "$BUILD_DIR"
    fi

    if [[ -d "$BUILD_DIR/.git" ]]; then
        info "Updating llama.cpp source..."
        (cd "$BUILD_DIR" && git fetch --depth=1 origin "$LLAMA_TAG" && git checkout FETCH_HEAD)
    else
        info "Cloning llama.cpp from $LLAMA_REPO ..."
        git clone --depth=1 "$LLAMA_REPO" "$BUILD_DIR"
    fi
    success "Source ready at $BUILD_DIR"
}

# ---------------------------------------------------------------------------
# Build
# ---------------------------------------------------------------------------
build_hosted() {
    info "Building for host platform ($(uname -s)/$(uname -m))..."
    cd "$BUILD_DIR"

    CMAKE_ARGS=(
        -DCMAKE_BUILD_TYPE=Release
        -DLLAMA_BUILD_TESTS=OFF
        -DLLAMA_BUILD_EXAMPLES=ON
    )

    # macOS Metal GPU
    if [[ "$(uname -s)" == "Darwin" && "$NO_METAL" -eq 0 ]]; then
        info "Enabling Metal (macOS GPU)"
        CMAKE_ARGS+=(-DLLAMA_METAL=ON)
    fi

    # CUDA (NVIDIA)
    if command -v nvcc &>/dev/null && [[ "$NO_CUBLAS" -eq 0 ]]; then
        info "Enabling CUDA (NVIDIA GPU)"
        CMAKE_ARGS+=(-DLLAMA_CUBLAS=ON)
    fi

    cmake -B build "${CMAKE_ARGS[@]}"
    cmake --build build --config Release -j "$JOBS"
    success "Build complete."
}

build_termux() {
    info "Building for Termux (Android)..."
    cd "$BUILD_DIR"

    # Termux uses clang by default; disable Metal/CUDA
    cmake -B build \
        -DCMAKE_BUILD_TYPE=Release \
        -DLLAMA_BUILD_TESTS=OFF \
        -DLLAMA_BUILD_EXAMPLES=ON \
        -DLLAMA_METAL=OFF \
        -DLLAMA_CUBLAS=OFF \
        -DCMAKE_C_COMPILER=clang \
        -DCMAKE_CXX_COMPILER=clang++

    cmake --build build --config Release -j "$JOBS"
    success "Termux build complete."
}

build_arm64() {
    info "Cross-compiling for arm64 (aarch64-linux-gnu)..."
    command -v aarch64-linux-gnu-g++ &>/dev/null || \
        die "aarch64-linux-gnu-g++ not found. Install: sudo apt install gcc-aarch64-linux-gnu g++-aarch64-linux-gnu"

    cd "$BUILD_DIR"
    cmake -B build \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_SYSTEM_NAME=Linux \
        -DCMAKE_SYSTEM_PROCESSOR=aarch64 \
        -DCMAKE_C_COMPILER=aarch64-linux-gnu-gcc \
        -DCMAKE_CXX_COMPILER=aarch64-linux-gnu-g++ \
        -DLLAMA_BUILD_TESTS=OFF \
        -DLLAMA_BUILD_EXAMPLES=ON \
        -DLLAMA_METAL=OFF \
        -DLLAMA_CUBLAS=OFF

    cmake --build build --config Release -j "$JOBS"
    success "arm64 cross-compile complete."
}

# ---------------------------------------------------------------------------
# Install binary
# ---------------------------------------------------------------------------
install_binary() {
    local bin_path=""
    # llama.cpp recent builds put it here:
    for candidate in \
        "$BUILD_DIR/build/bin/llama-cli" \
        "$BUILD_DIR/build/bin/main" \
        "$BUILD_DIR/build/llama-cli" \
        "$BUILD_DIR/build/main"; do
        if [[ -f "$candidate" && -x "$candidate" ]]; then
            bin_path="$candidate"
            break
        fi
    done

    if [[ -z "$bin_path" ]]; then
        warn "Could not find llama-cli binary after build."
        warn "Searched: $BUILD_DIR/build/bin/llama-cli  and similar paths."
        warn "Binary may be in: $BUILD_DIR/build/"
        ls "$BUILD_DIR/build/bin/" 2>/dev/null || ls "$BUILD_DIR/build/" 2>/dev/null | head -10
        return 1
    fi

    # Create symlink in OS/bin
    local os_bin="$REPO_ROOT/OS/bin/llama-cli"
    ln -sf "$bin_path" "$os_bin"
    success "Installed: $os_bin → $bin_path"
    info "Binary size: $(du -sh "$bin_path" | cut -f1)"
    info ""
    info "Test: $bin_path --version"
    "$bin_path" --version 2>/dev/null || true
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
info "AIOS-Lite llama.cpp builder"
info "Target: $TARGET | Jobs: $JOBS"
echo ""

check_deps
prepare_source

case "$TARGET" in
    hosted)  build_hosted ;;
    termux)  build_termux ;;
    arm64)   build_arm64 ;;
    *)       die "Unknown target: $TARGET. Choose: hosted | termux | arm64" ;;
esac

install_binary

echo ""
success "Done! Place a .gguf model in llama_model/ and run:"
info "  OS_ROOT=\$(pwd)/OS bash OS/bin/os-shell"
info "  > ask hello"
