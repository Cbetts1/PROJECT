#!/bin/bash
# deploy/first-boot.sh
# First-run initialization for AIOS.
# Safe to re-run — idempotent.
#
# Usage:
#   bash deploy/first-boot.sh [--upgrade]

set -euo pipefail

AIOS_ROOT="${AIOS_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
OS_ROOT="${OS_ROOT:-$AIOS_ROOT/OS}"
IDENTITY_FILE="$OS_ROOT/proc/os.identity"

UPGRADE=false
[[ "${1:-}" == "--upgrade" ]] && UPGRADE=true

log() { echo "[first-boot] $*"; }

# ── Create runtime directories ────────────────────────────────────────────────
log "Creating runtime directories..."
mkdir -p \
    "$OS_ROOT/proc/aura/context" \
    "$OS_ROOT/proc/aura/memory" \
    "$OS_ROOT/var/log" \
    "$OS_ROOT/var/run" \
    "$OS_ROOT/var/service" \
    "$OS_ROOT/var/events" \
    "$OS_ROOT/overlay/upper" \
    "$OS_ROOT/overlay/work" \
    "$OS_ROOT/overlay/merged" \
    "$OS_ROOT/usr/pkg" \
    "$OS_ROOT/var/pkg"

# ── Generate OS identity ───────────────────────────────────────────────────────
if [[ ! -f "$IDENTITY_FILE" ]] || $UPGRADE; then
    log "Writing OS identity..."
    DEVICE_MODEL="unknown"
    command -v getprop >/dev/null 2>&1 && DEVICE_MODEL=$(getprop ro.product.model 2>/dev/null || echo "unknown")
    cat > "$IDENTITY_FILE" << EOF
OS_NAME="AIOS"
OS_VERSION="1.0.0"
OS_VENDOR="AIOS Project"
OS_ARCH="$(uname -m)"
DEVICE_MODEL="$DEVICE_MODEL"
INSTALL_DATE="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
EOF
fi

# ── Initialize Aura memory stores ─────────────────────────────────────────────
log "Initializing Aura memory..."
MEMINDEX="$OS_ROOT/etc/aura/memory.index"
SEMINDEX="$OS_ROOT/etc/aura/semantic.index"
CTXFILE="$OS_ROOT/proc/aura/context/window"

[[ -f "$MEMINDEX" ]] || touch "$MEMINDEX"
[[ -f "$SEMINDEX" ]] || touch "$SEMINDEX"
[[ -f "$CTXFILE"  ]] || touch "$CTXFILE"

# ── Write boot time ───────────────────────────────────────────────────────────
date +%s > "$OS_ROOT/var/boot.time"

# ── Set permissions ───────────────────────────────────────────────────────────
log "Setting permissions..."
find "$OS_ROOT/bin" "$OS_ROOT/sbin" -type f -exec chmod +x {} \; 2>/dev/null || true
find "$AIOS_ROOT" -name '*.sh' -exec chmod +x {} \; 2>/dev/null || true

# ── Write os-release ──────────────────────────────────────────────────────────
cat > "$OS_ROOT/etc/os-release" << EOF
NAME="AIOS"
ID=aios
PRETTY_NAME="AIOS — Portable AI Operating System"
VERSION="1.0.0"
VERSION_ID="1.0.0"
HOME_URL="https://github.com/Cbetts1/PROJECT"
EOF

log "First boot initialization complete."
log "Run: bash $OS_ROOT/sbin/init"
