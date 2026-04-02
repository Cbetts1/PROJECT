#!/bin/bash
# tests/mobile-compat-tests.sh
# Samsung Galaxy S21 FE compatibility validation tests.
# Checks device-specific requirements and constraints.
#
# Usage:
#   bash tests/mobile-compat-tests.sh

set -euo pipefail

AIOS_ROOT="${AIOS_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
CONFIG="$AIOS_ROOT/config/aios.conf"
PASS=0
FAIL=0
WARN_COUNT=0

pass() { echo "  PASS: $*"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $*"; FAIL=$((FAIL + 1)); }
warn() { echo "  WARN: $*"; WARN_COUNT=$((WARN_COUNT + 1)); }

echo "=== AIOS Mobile Compatibility Tests ==="

# ── Architecture ─────────────────────────────────────────────────────────────
echo
echo "── Architecture ──"
ARCH=$(uname -m)
echo "  Detected arch: $ARCH"
case "$ARCH" in
    aarch64|arm64) pass "Architecture is aarch64 (correct for S21 FE)" ;;
    armv7l)        warn "Architecture is 32-bit ARM — recommend 64-bit kernel" ;;
    x86_64)        warn "Architecture is x86_64 — running in emulation/CI" ;;
    *)             fail "Unexpected architecture: $ARCH" ;;
esac

# ── RAM ───────────────────────────────────────────────────────────────────────
echo
echo "── Memory ──"
TOTAL_RAM_MB=$(awk '/^MemTotal/{print int($2/1024)}' /proc/meminfo 2>/dev/null || echo 0)
FREE_RAM_MB=$(awk '/^MemAvailable/{print int($2/1024)}' /proc/meminfo 2>/dev/null || echo 0)
echo "  Total RAM : ${TOTAL_RAM_MB} MB"
echo "  Free  RAM : ${FREE_RAM_MB} MB"

[[ $TOTAL_RAM_MB -ge 5000 ]] && pass "Total RAM >= 5 GB" || fail "Total RAM below 5 GB (${TOTAL_RAM_MB} MB)"
[[ $FREE_RAM_MB  -ge 2000 ]] && pass "Free RAM >= 2 GB"  || warn "Low free RAM (${FREE_RAM_MB} MB) — close background apps"

# Model feasibility
if [[ $TOTAL_RAM_MB -ge 7000 ]]; then
    pass "RAM supports 7B model (Q4_K_M ~4 GB)"
elif [[ $TOTAL_RAM_MB -ge 4000 ]]; then
    pass "RAM supports 3B model (Q4_K_M ~2 GB)"
else
    warn "Low RAM — consider 1B model or enable zram"
fi

# ── Storage ───────────────────────────────────────────────────────────────────
echo
echo "── Storage ──"
FREE_STORAGE_MB=$(df -m "$AIOS_ROOT" 2>/dev/null | awk 'NR==2{print $4}' || echo 0)
echo "  Free storage : ${FREE_STORAGE_MB} MB"
[[ $FREE_STORAGE_MB -ge 8000  ]] && pass "Storage >= 8 GB free"  || fail "Need at least 8 GB free (have ${FREE_STORAGE_MB} MB)"
[[ $FREE_STORAGE_MB -ge 15000 ]] && pass "Storage >= 15 GB free (comfortable)" || warn "Less than 15 GB free"

# ── CPU ───────────────────────────────────────────────────────────────────────
echo
echo "── CPU ──"
CPU_COUNT=$(nproc 2>/dev/null || echo 0)
echo "  CPU cores : $CPU_COUNT"
[[ $CPU_COUNT -ge 8 ]] && pass "8-core CPU detected" || warn "CPU cores: $CPU_COUNT (expected 8 for S21 FE)"

if [[ -f /proc/cpuinfo ]]; then
    CPU_MODEL=$(grep 'Hardware\|model name' /proc/cpuinfo | head -1 | cut -d: -f2 | xargs || echo "unknown")
    echo "  CPU model : $CPU_MODEL"
fi

# ── Thermal sensors ───────────────────────────────────────────────────────────
echo
echo "── Thermal ──"
if [[ -f /sys/class/thermal/thermal_zone0/temp ]]; then
    TEMP_C=$(( $(cat /sys/class/thermal/thermal_zone0/temp) / 1000 ))
    echo "  CPU temp : ${TEMP_C}°C"
    [[ $TEMP_C -lt 50 ]] && pass "CPU temperature nominal"      || warn "Elevated temperature: ${TEMP_C}°C"
    [[ $TEMP_C -lt 68 ]] && pass "Below thermal inference limit" || fail "At or above thermal limit — cool device first"
else
    warn "Thermal zone not accessible (may need root)"
fi

# ── Android / Termux ─────────────────────────────────────────────────────────
echo
echo "── Android / Termux ──"
command -v pkg       >/dev/null 2>&1 && pass "Termux pkg manager available" || warn "Termux pkg not found (CI/non-Android)"
command -v getprop   >/dev/null 2>&1 && pass "Android getprop available"    || warn "Not running on Android"
command -v termux-wake-lock >/dev/null 2>&1 && pass "Termux:API available"  || warn "Termux:API not installed"

# ── AIOS configuration ───────────────────────────────────────────────────────
echo
echo "── AIOS config validation ──"
if [[ -f "$CONFIG" ]]; then
    . "$CONFIG"
    pass "config/aios.conf loads"
    [[ "${LLAMA_CPU_AFFINITY:-}" == "1-3" ]] && pass "CPU affinity set to 1-3" || warn "LLAMA_CPU_AFFINITY not set to 1-3"
    [[ "${THERMAL_LIMIT_C:-0}" -ge 60 ]]     && pass "Thermal limit configured" || fail "THERMAL_LIMIT_C not set"
    [[ "${ZRAM_SIZE_MB:-0}" -ge 2048 ]]       && pass "zram >= 2 GB configured"  || warn "ZRAM_SIZE_MB < 2 GB"
else
    fail "config/aios.conf not found"
fi

echo
echo "=== Results: $PASS passed, $FAIL failed, $WARN_COUNT warnings ==="
[[ $FAIL -eq 0 ]] && exit 0 || exit 1
