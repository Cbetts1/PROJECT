#!/bin/bash
# deploy/phone-optimizations.sh
# Applies Samsung Galaxy S21 FE hardware optimizations.
# Most settings require root access.
#
# Usage:
#   bash deploy/phone-optimizations.sh [--no-root]

set -euo pipefail

AIOS_ROOT="${AIOS_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
CONFIG="$AIOS_ROOT/config/aios.conf"
LOG="$AIOS_ROOT/OS/var/log/optimizations.log"

NO_ROOT=false
[[ "${1:-}" == "--no-root" ]] && NO_ROOT=true

log()  { echo "[phone-opt] $*" | tee -a "$LOG"; }
root_exec() {
    if $NO_ROOT; then
        log "  (skipped, --no-root) $*"
        return 0
    fi
    if [[ $(id -u) -eq 0 ]]; then
        eval "$@"
    elif command -v su >/dev/null 2>&1; then
        su -c "$*"
    else
        log "  (skipped, no root) $*"
    fi
}

mkdir -p "$(dirname "$LOG")"

# ── Load config ───────────────────────────────────────────────────────────────
LLAMA_CPU_AFFINITY="${LLAMA_CPU_AFFINITY:-1-3}"
SYSTEM_CPU_AFFINITY="${SYSTEM_CPU_AFFINITY:-4-7}"
ZRAM_SIZE_MB="${ZRAM_SIZE_MB:-4096}"
THERMAL_LIMIT_C="${THERMAL_LIMIT_C:-68}"

[[ -f "$CONFIG" ]] && . "$CONFIG"

log "Applying S21 FE optimizations..."

# ── CPU governor ──────────────────────────────────────────────────────────────
log "Setting CPU governor to schedutil..."
for cpu_dir in /sys/devices/system/cpu/cpu*/cpufreq; do
    [[ -f "$cpu_dir/scaling_governor" ]] && \
        root_exec "echo schedutil > $cpu_dir/scaling_governor"
done

# ── VM overcommit for large mmap (model loading) ─────────────────────────────
log "Enabling vm.overcommit_memory=1..."
root_exec "echo 1 > /proc/sys/vm/overcommit_memory"

# ── Reduce OOM aggressiveness ─────────────────────────────────────────────────
log "Adjusting OOM settings..."
root_exec "echo 0 > /proc/sys/vm/oom_kill_allocating_task"
root_exec "echo 200 > /proc/sys/vm/overcommit_ratio"

# ── Set up zram swap ──────────────────────────────────────────────────────────
log "Configuring zram (${ZRAM_SIZE_MB}MB)..."
if [[ -d /sys/block/zram0 ]]; then
    root_exec "echo 0 > /sys/block/zram0/reset 2>/dev/null || true"
    root_exec "echo lz4 > /sys/block/zram0/comp_algorithm 2>/dev/null || true"
    root_exec "echo ${ZRAM_SIZE_MB}M > /sys/block/zram0/disksize"
    root_exec "mkswap /dev/block/zram0 2>/dev/null || true"
    root_exec "swapon /dev/block/zram0 -p 100 2>/dev/null || true"
    log "zram enabled."
else
    log "zram not available on this device."
fi

# ── Disable battery optimization for Termux ───────────────────────────────────
log "Disabling battery optimization for Termux..."
root_exec "dumpsys deviceidle whitelist +com.termux 2>/dev/null || true"

# ── Set wakelock for inference ────────────────────────────────────────────────
log "Requesting wakelock..."
if command -v termux-wake-lock >/dev/null 2>&1; then
    termux-wake-lock &
    log "Termux wakelock active."
fi

# ── Apply CPU affinity to current shell ───────────────────────────────────────
if command -v taskset >/dev/null 2>&1; then
    log "Setting CPU affinity: big cores $LLAMA_CPU_AFFINITY for inference."
fi

log "Phone optimizations complete."
