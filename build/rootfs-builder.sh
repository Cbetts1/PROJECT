#!/bin/bash
# rootfs-builder.sh — Assemble the AIOS minimal root filesystem
#
# Creates a compressed squashfs image of the OS/ directory.
# Usage:
#   bash build/rootfs-builder.sh [--output path/to/rootfs.squashfs]

set -euo pipefail

AIOS_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OS_DIR="$AIOS_ROOT/OS"
OUTPUT="${1:-$AIOS_ROOT/build/aios-rootfs.squashfs}"

log() { echo "[rootfs] $*"; }
die() { echo "[rootfs] ERROR: $*" >&2; exit 1; }

command -v mksquashfs >/dev/null 2>&1 || die "mksquashfs not found. Install squashfs-tools."

# ── Ensure required directories exist ────────────────────────────────────────
for dir in bin sbin lib etc var proc tmp dev; do
    mkdir -p "$OS_DIR/$dir"
done
mkdir -p "$OS_DIR/var/log" "$OS_DIR/var/run" "$OS_DIR/var/service"
mkdir -p "$OS_DIR/proc/aura/context" "$OS_DIR/proc/aura/memory"
mkdir -p "$OS_DIR/overlay/upper" "$OS_DIR/overlay/work" "$OS_DIR/overlay/merged"
mkdir -p "$OS_DIR/usr/pkg" "$OS_DIR/var/pkg"

# ── Copy ai binaries if built ─────────────────────────────────────────────────
AI_BIN="$AIOS_ROOT/ai/llama-integration/bin"
if [[ -f "$AI_BIN/llama-cli" ]]; then
    log "Including llama-cli in rootfs..."
    cp "$AI_BIN/llama-cli" "$OS_DIR/bin/llama-cli"
fi

# ── Make scripts executable ───────────────────────────────────────────────────
find "$OS_DIR/bin" "$OS_DIR/sbin" -type f -exec chmod +x {} \; 2>/dev/null || true

# ── Build squashfs image ──────────────────────────────────────────────────────
log "Building squashfs: $OUTPUT"
mksquashfs "$OS_DIR" "$OUTPUT" \
    -comp lz4 \
    -Xhc \
    -noappend \
    -e "$OS_DIR/overlay" \
    -e "$OS_DIR/var/log" \
    -e "$OS_DIR/proc/aura/memory" \
    2>&1

SIZE=$(du -sh "$OUTPUT" | cut -f1)
log "rootfs image built: $OUTPUT ($SIZE)"
