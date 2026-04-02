#!/bin/bash
# build.sh — AIOS build automation script
# Builds llama.cpp, assembles the AIOS rootfs, and optionally creates a
# bootable image.
#
# Usage:
#   bash build/build.sh [--target hosted|standalone|image] [--jobs N]

set -euo pipefail

AIOS_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$AIOS_ROOT/build"
AI_DIR="$AIOS_ROOT/ai/llama-integration"
LLAMA_DIR="$AI_DIR/llama.cpp"
BIN_DIR="$AI_DIR/bin"
JOBS="${JOBS:-$(nproc)}"
TARGET="hosted"

log() { echo "[build] $*"; }
die() { echo "[build] ERROR: $*" >&2; exit 1; }

# ── Parse arguments ──────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
    case "$1" in
        --target) TARGET="$2"; shift 2 ;;
        --jobs)   JOBS="$2";   shift 2 ;;
        *) die "Unknown argument: $1" ;;
    esac
done

log "AIOS Build System"
log "Target  : $TARGET"
log "Jobs    : $JOBS"
log "Root    : $AIOS_ROOT"

# ── Detect toolchain ─────────────────────────────────────────────────────────
detect_toolchain() {
    if command -v aarch64-linux-android-clang >/dev/null 2>&1; then
        CC="aarch64-linux-android-clang"
        CXX="aarch64-linux-android-clang++"
        log "Toolchain: Android NDK clang (aarch64)"
    elif command -v clang >/dev/null 2>&1; then
        CC="clang"
        CXX="clang++"
        log "Toolchain: system clang"
    else
        CC="gcc"
        CXX="g++"
        log "Toolchain: system gcc"
    fi
    export CC CXX
}

# ── Clone / update llama.cpp ─────────────────────────────────────────────────
prepare_llama() {
    mkdir -p "$BIN_DIR"
    if [[ ! -d "$LLAMA_DIR" ]]; then
        log "Cloning llama.cpp..."
        git clone --depth 1 https://github.com/ggerganov/llama.cpp.git "$LLAMA_DIR"
    else
        log "Updating llama.cpp..."
        git -C "$LLAMA_DIR" pull --ff-only || log "Already up-to-date or offline"
    fi
}

# ── Compile llama.cpp ────────────────────────────────────────────────────────
build_llama() {
    log "Compiling llama.cpp (jobs=$JOBS)..."
    cmake -S "$LLAMA_DIR" -B "$LLAMA_DIR/build" \
        -DLLAMA_NATIVE=OFF \
        -DLLAMA_BUILD_TESTS=OFF \
        -DLLAMA_BUILD_EXAMPLES=ON \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_C_COMPILER="$CC" \
        -DCMAKE_CXX_COMPILER="$CXX"

    cmake --build "$LLAMA_DIR/build" \
        --config Release \
        -j "$JOBS" \
        --target llama-cli llama-server

    cp "$LLAMA_DIR/build/bin/llama-cli"    "$BIN_DIR/"
    cp "$LLAMA_DIR/build/bin/llama-server" "$BIN_DIR/"
    log "llama-cli installed to $BIN_DIR/"
}

# ── Build rootfs ─────────────────────────────────────────────────────────────
build_rootfs() {
    log "Building rootfs..."
    bash "$BUILD_DIR/rootfs-builder.sh"
}

# ── Build bootable image ─────────────────────────────────────────────────────
build_image() {
    log "Building bootable image..."
    bash "$AIOS_ROOT/deploy/usb-image-builder.sh" \
        --output "$AIOS_ROOT/aios-s21fe.img" \
        --size 8G
}

# ── Set permissions ───────────────────────────────────────────────────────────
fix_permissions() {
    find "$AIOS_ROOT/OS/bin" "$AIOS_ROOT/OS/sbin" -type f -exec chmod +x {} \;
    find "$AIOS_ROOT" -name '*.sh' -exec chmod +x {} \;
    log "Permissions set."
}

# ── Main ──────────────────────────────────────────────────────────────────────
detect_toolchain
prepare_llama

case "$TARGET" in
    hosted)
        build_llama
        fix_permissions
        log "Hosted build complete. Run: bash OS/sbin/init"
        ;;
    standalone)
        build_llama
        build_rootfs
        fix_permissions
        log "Standalone build complete."
        ;;
    image)
        build_llama
        build_rootfs
        build_image
        fix_permissions
        log "Image build complete: aios-s21fe.img"
        ;;
    *)
        die "Unknown target: $TARGET. Use hosted|standalone|image"
        ;;
esac
