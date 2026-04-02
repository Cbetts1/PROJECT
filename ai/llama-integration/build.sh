#!/bin/bash
# ai/llama-integration/build.sh
# Clones and compiles llama.cpp targeting the current platform (aarch64 preferred).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LLAMA_DIR="$SCRIPT_DIR/llama.cpp"
BIN_DIR="$SCRIPT_DIR/bin"
JOBS="${JOBS:-$(nproc)}"

log() { echo "[llama-build] $*"; }

mkdir -p "$BIN_DIR"

# Clone if not present
if [[ ! -d "$LLAMA_DIR" ]]; then
    log "Cloning llama.cpp..."
    git clone --depth 1 https://github.com/ggerganov/llama.cpp.git "$LLAMA_DIR"
else
    log "llama.cpp already present, pulling latest..."
    git -C "$LLAMA_DIR" pull --ff-only 2>/dev/null || log "Offline or already up-to-date"
fi

# Detect compiler
if command -v clang >/dev/null 2>&1; then
    CMAKE_EXTRA="-DCMAKE_C_COMPILER=clang -DCMAKE_CXX_COMPILER=clang++"
else
    CMAKE_EXTRA=""
fi

log "Configuring cmake (jobs=$JOBS)..."
cmake -S "$LLAMA_DIR" -B "$LLAMA_DIR/build" \
    -DLLAMA_NATIVE=OFF \
    -DLLAMA_BUILD_TESTS=OFF \
    -DLLAMA_BUILD_EXAMPLES=ON \
    -DCMAKE_BUILD_TYPE=Release \
    $CMAKE_EXTRA

log "Building llama-cli and llama-server..."
cmake --build "$LLAMA_DIR/build" \
    --config Release \
    -j "$JOBS" \
    --target llama-cli llama-server

cp "$LLAMA_DIR/build/bin/llama-cli"    "$BIN_DIR/"
cp "$LLAMA_DIR/build/bin/llama-server" "$BIN_DIR/"

log "Build complete. Binaries in $BIN_DIR/"
ls -lh "$BIN_DIR/"
