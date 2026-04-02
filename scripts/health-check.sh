#!/bin/bash
# scripts/health-check.sh
# AIOS system health diagnostics.
#
# Usage:
#   bash scripts/health-check.sh

set -euo pipefail

AIOS_ROOT="${AIOS_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
OS_ROOT="${OS_ROOT:-$AIOS_ROOT/OS}"
CONFIG="$AIOS_ROOT/config/aios.conf"
PID_FILE="$OS_ROOT/var/run/llama-daemon.pid"

MODEL_PATH=""
[[ -f "$CONFIG" ]] && . "$CONFIG"

pass() { echo "  [OK]   $*"; }
warn() { echo "  [WARN] $*"; }
fail() { echo "  [FAIL] $*"; }

echo "=== AIOS Health Check ==="
echo "Time: $(date)"
echo

echo "── OS Layer ──"
[[ -f "$OS_ROOT/etc/os-release"  ]] && pass "os-release present"  || fail "os-release missing"
[[ -f "$OS_ROOT/sbin/init"       ]] && pass "init present"         || fail "init missing"
[[ -f "$OS_ROOT/bin/os-shell"    ]] && pass "os-shell present"     || fail "os-shell missing"
[[ -d "$OS_ROOT/var/log"         ]] && pass "var/log directory"     || fail "var/log missing"
[[ -d "$OS_ROOT/proc/aura"       ]] && pass "aura proc dir"         || warn "aura proc dir missing (run first-boot.sh)"

echo
echo "── AI Layer ──"
LLAMA_BIN="$AIOS_ROOT/ai/llama-integration/bin/llama-cli"
[[ -f "$LLAMA_BIN"   ]] && pass "llama-cli built"    || warn "llama-cli not built (run: bash ai/llama-integration/build.sh)"
[[ -n "$MODEL_PATH" && -f "$MODEL_PATH" ]] && pass "model present ($MODEL_PATH)" \
    || warn "model not found (run: bash ai/model-quantizer/download-model.sh)"

# Inference daemon
if [[ -f "$PID_FILE" ]]; then
    PID=$(cat "$PID_FILE")
    kill -0 "$PID" 2>/dev/null && pass "inference daemon running (PID $PID)" \
        || warn "inference daemon PID file stale"
else
    warn "inference daemon not running"
fi

echo
echo "── Mirror Layer ──"
OVERLAY_BASE="$OS_ROOT/overlay"
[[ -d "$OVERLAY_BASE/upper"  ]] && pass "overlay/upper exists"  || warn "overlay/upper missing"
[[ -d "$OVERLAY_BASE/merged" ]] && pass "overlay/merged exists" || warn "overlay/merged missing"

echo
echo "── Memory ──"
TOTAL_RAM=$(awk '/^MemTotal/{print int($2/1024)}' /proc/meminfo 2>/dev/null || echo 0)
FREE_RAM=$(awk '/^MemAvailable/{print int($2/1024)}' /proc/meminfo 2>/dev/null || echo 0)
echo "  Total: ${TOTAL_RAM} MB"
echo "  Free:  ${FREE_RAM} MB"
[[ $FREE_RAM -gt 1000 ]] && pass "Sufficient free RAM" || warn "Low free RAM (${FREE_RAM} MB)"

echo
echo "── Storage ──"
if command -v df >/dev/null 2>&1; then
    FREE_STORAGE=$(df -m "$AIOS_ROOT" 2>/dev/null | awk 'NR==2{print $4}' || echo 0)
    echo "  Free: ${FREE_STORAGE} MB at $AIOS_ROOT"
    [[ $FREE_STORAGE -gt 2000 ]] && pass "Sufficient storage" || warn "Low storage (${FREE_STORAGE} MB)"
fi

echo
echo "── Thermal ──"
THERMAL_FILE="/sys/class/thermal/thermal_zone0/temp"
if [[ -f "$THERMAL_FILE" ]]; then
    TEMP_C=$(( $(cat "$THERMAL_FILE") / 1000 ))
    echo "  CPU Temp: ${TEMP_C}°C"
    [[ $TEMP_C -lt 70 ]] && pass "Temperature OK" || warn "High temperature: ${TEMP_C}°C"
else
    echo "  Thermal zone not accessible"
fi

echo
echo "=== End Health Check ==="
