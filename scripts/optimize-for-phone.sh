#!/bin/bash
# scripts/optimize-for-phone.sh
# Resource optimization script for Samsung Galaxy S21 FE.
#
# Usage:
#   bash scripts/optimize-for-phone.sh [--zram [SIZE_MB]] [--sync-model]

set -euo pipefail

AIOS_ROOT="${AIOS_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
CONFIG="$AIOS_ROOT/config/aios.conf"

ZRAM=false
ZRAM_SIZE=4096
SYNC_MODEL=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --zram)
            ZRAM=true
            [[ "${2:-}" =~ ^[0-9]+$ ]] && { ZRAM_SIZE="$2"; shift; }
            shift
            ;;
        --sync-model) SYNC_MODEL=true; shift ;;
        *) echo "Unknown option: $1"; shift ;;
    esac
done

log() { echo "[optimize] $*"; }

# Load config
RCLONE_REMOTE=""
[[ -f "$CONFIG" ]] && . "$CONFIG"

# ── zram setup ────────────────────────────────────────────────────────────────
if $ZRAM; then
    log "Setting up ${ZRAM_SIZE}MB zram..."
    if [[ -d /sys/block/zram0 ]]; then
        su -c "echo 0 > /sys/block/zram0/reset 2>/dev/null; \
               echo lz4 > /sys/block/zram0/comp_algorithm 2>/dev/null; \
               echo ${ZRAM_SIZE}M > /sys/block/zram0/disksize; \
               mkswap /dev/block/zram0; \
               swapon /dev/block/zram0 -p 100" 2>/dev/null || log "zram setup requires root"
    else
        log "zram block device not found"
    fi
fi

# ── Swappiness ────────────────────────────────────────────────────────────────
log "Setting vm.swappiness=10..."
su -c "echo 10 > /proc/sys/vm/swappiness" 2>/dev/null || true

# ── Drop caches ───────────────────────────────────────────────────────────────
log "Dropping page cache..."
su -c "echo 3 > /proc/sys/vm/drop_caches" 2>/dev/null || true

# ── Model cloud sync ──────────────────────────────────────────────────────────
if $SYNC_MODEL; then
    MODEL_DIR="$AIOS_ROOT/llama_model"
    if [[ -n "$RCLONE_REMOTE" ]] && command -v rclone >/dev/null 2>&1; then
        log "Syncing model to $RCLONE_REMOTE..."
        rclone sync "$MODEL_DIR" "$RCLONE_REMOTE" --progress
    elif [[ -d /sdcard ]]; then
        log "Backing up model to /sdcard/aios-model-backup..."
        mkdir -p /sdcard/aios-model-backup
        cp -u "$MODEL_DIR"/*.gguf /sdcard/aios-model-backup/ 2>/dev/null || log "No .gguf files to sync"
    else
        log "No sync target configured. Set RCLONE_REMOTE in config/aios.conf."
    fi
fi

log "Optimization complete."
