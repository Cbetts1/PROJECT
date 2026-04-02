#!/bin/bash
# deploy/container-installer.sh
# One-command installer for AIOS hosted mode (Termux on Android).
#
# Usage:
#   bash deploy/container-installer.sh [--uninstall]

set -euo pipefail

AIOS_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SHELL_RC="${HOME}/.bashrc"

log()  { echo "[installer] $*"; }
die()  { echo "[installer] ERROR: $*" >&2; exit 1; }
step() { echo; echo "── $* ──"; }

UNINSTALL=false
[[ "${1:-}" == "--uninstall" ]] && UNINSTALL=true

# ── Uninstall path ────────────────────────────────────────────────────────────
if $UNINSTALL; then
    step "Uninstalling AIOS"
    bash "$AIOS_ROOT/mirror/overlay-manager.sh" unmount 2>/dev/null || true
    bash "$AIOS_ROOT/ai/inference-engine/stop-daemon.sh" 2>/dev/null || true
    bash "$AIOS_ROOT/mirror/sync-daemon.sh" stop 2>/dev/null || true

    # Remove env vars from shell rc
    sed -i '/# AIOS environment/,/# end AIOS/d' "$SHELL_RC" 2>/dev/null || true

    log "AIOS uninstalled. Model weights in llama_model/ were NOT removed."
    exit 0
fi

# ── Detect environment ────────────────────────────────────────────────────────
step "Detecting environment"
OS_TYPE="$(uname -s)"
ARCH="$(uname -m)"
log "OS: $OS_TYPE / Arch: $ARCH"

DEVICE_MODEL="unknown"
if [[ -f /proc/device-tree/model ]]; then
    DEVICE_MODEL=$(cat /proc/device-tree/model 2>/dev/null || echo "unknown")
elif command -v getprop >/dev/null 2>&1; then
    DEVICE_MODEL=$(getprop ro.product.model 2>/dev/null || echo "unknown")
fi
log "Device: $DEVICE_MODEL"

# Detect available RAM (MB)
TOTAL_RAM_MB=$(awk '/^MemTotal/ {print int($2/1024)}' /proc/meminfo 2>/dev/null || echo 0)
log "RAM: ${TOTAL_RAM_MB} MB"

# ── Install Termux packages ────────────────────────────────────────────────────
step "Installing packages"
if command -v pkg >/dev/null 2>&1; then
    pkg update -y 2>/dev/null || true
    pkg install -y git bash python clang cmake make curl wget proot 2>/dev/null || true
elif command -v apt-get >/dev/null 2>&1; then
    apt-get update -qq
    apt-get install -y git bash python3 clang cmake make curl wget
fi

# ── Configure environment ─────────────────────────────────────────────────────
step "Configuring environment"
if ! grep -q '# AIOS environment' "$SHELL_RC" 2>/dev/null; then
    cat >> "$SHELL_RC" << EOF

# AIOS environment
export AIOS_HOME="$AIOS_ROOT"
export OS_ROOT="$AIOS_ROOT/OS"
export PATH="\$AIOS_HOME/OS/bin:\$AIOS_HOME/OS/sbin:\$AIOS_HOME/ai/llama-integration/bin:\$PATH"
alias aios='bash \$AIOS_HOME/OS/sbin/init'
alias ai='bash \$AIOS_HOME/ai/shell-interface/ai-ask.sh'
# end AIOS
EOF
    log "Environment configured in $SHELL_RC"
fi

# ── Build llama.cpp ───────────────────────────────────────────────────────────
step "Building llama.cpp"
if [[ ! -f "$AIOS_ROOT/ai/llama-integration/bin/llama-cli" ]]; then
    bash "$AIOS_ROOT/ai/llama-integration/build.sh"
else
    log "llama-cli already built — skipping."
fi

# ── Download model ────────────────────────────────────────────────────────────
step "Downloading AI model"
if [[ $TOTAL_RAM_MB -ge 7000 ]]; then
    MODEL_NAME="llama-3.1-7b-instruct"
else
    MODEL_NAME="llama-3.2-3b-instruct"
fi
log "Selecting model: $MODEL_NAME (RAM=${TOTAL_RAM_MB}MB)"
bash "$AIOS_ROOT/ai/model-quantizer/download-model.sh" --model "$MODEL_NAME" --quant Q4_K_M

# ── Phone optimizations ───────────────────────────────────────────────────────
step "Applying phone optimizations"
bash "$AIOS_ROOT/deploy/phone-optimizations.sh" || log "Some optimizations require root — skipping."

# ── First boot initialization ─────────────────────────────────────────────────
step "First boot initialization"
bash "$AIOS_ROOT/deploy/first-boot.sh"

step "Installation complete"
log "Run 'aios' or 'bash $AIOS_ROOT/OS/sbin/init' to start AIOS."
log "Run 'source $SHELL_RC' to load environment variables in this session."
