#!/bin/bash
# scripts/benchmark.sh
# Performance benchmarking for AIOS on Samsung Galaxy S21 FE.
#
# Tests:
#   1. CPU throughput (tokens/sec for Llama inference)
#   2. Memory bandwidth
#   3. Storage I/O
#   4. Thermal throttle detection
#
# Usage:
#   bash scripts/benchmark.sh [--full] [--output FILE]

set -euo pipefail

AIOS_ROOT="${AIOS_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
CONFIG="$AIOS_ROOT/config/aios.conf"
OUTPUT_FILE=""
FULL=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --full)   FULL=true; shift ;;
        --output) OUTPUT_FILE="$2"; shift 2 ;;
        *) echo "Unknown option: $1"; shift ;;
    esac
done

log()    { echo "[benchmark] $*"; }
report() { echo "$*"; [[ -n "$OUTPUT_FILE" ]] && echo "$*" >> "$OUTPUT_FILE"; }

[[ -n "$OUTPUT_FILE" ]] && > "$OUTPUT_FILE"

MODEL_PATH=""
LLAMA_CLI="$AIOS_ROOT/ai/llama-integration/bin/llama-cli"
THREADS=3
LLAMA_CPU_AFFINITY=""

[[ -f "$CONFIG" ]] && . "$CONFIG"

report "=== AIOS Benchmark Report ==="
report "Date    : $(date)"
report "Device  : $(getprop ro.product.model 2>/dev/null || echo unknown)"
report "Kernel  : $(uname -r)"
report "Arch    : $(uname -m)"
report "RAM     : $(awk '/^MemTotal/{print int($2/1024)"MB"}' /proc/meminfo)"
report ""

# ── 1. Storage I/O ────────────────────────────────────────────────────────────
log "Storage I/O test..."
TMPFILE=$(mktemp)
T_START=$(date +%s%N)
dd if=/dev/zero of="$TMPFILE" bs=64M count=4 oflag=direct 2>/dev/null
T_END=$(date +%s%N)
WRITE_MS=$(( (T_END - T_START) / 1000000 ))
WRITE_MBPS=$(( 256 * 1000 / (WRITE_MS + 1) ))

T_START=$(date +%s%N)
dd if="$TMPFILE" of=/dev/null bs=64M 2>/dev/null
T_END=$(date +%s%N)
READ_MS=$(( (T_END - T_START) / 1000000 ))
READ_MBPS=$(( 256 * 1000 / (READ_MS + 1) ))

rm -f "$TMPFILE"
report "Storage Write : ~${WRITE_MBPS} MB/s"
report "Storage Read  : ~${READ_MBPS} MB/s"

# ── 2. Thermal check ─────────────────────────────────────────────────────────
THERMAL_FILE="/sys/class/thermal/thermal_zone0/temp"
if [[ -f "$THERMAL_FILE" ]]; then
    TEMP_C=$(( $(cat "$THERMAL_FILE") / 1000 ))
    report "CPU Temp      : ${TEMP_C}°C"
fi

# ── 3. Llama inference benchmark ──────────────────────────────────────────────
if [[ -f "$LLAMA_CLI" && -n "$MODEL_PATH" && -f "$MODEL_PATH" ]]; then
    log "Running Llama inference benchmark..."
    ARGS=(
        --model "$MODEL_PATH"
        --n-predict 50
        --ctx-size 512
        --threads "$THREADS"
        --temp 0
        --no-display-prompt
        --log-disable
        -p "Tell me a very short joke."
    )

    T_START=$(date +%s%N)
    if [[ -n "$LLAMA_CPU_AFFINITY" ]] && command -v taskset >/dev/null 2>&1; then
        taskset -c "$LLAMA_CPU_AFFINITY" "$LLAMA_CLI" "${ARGS[@]}" > /dev/null 2>&1
    else
        "$LLAMA_CLI" "${ARGS[@]}" > /dev/null 2>&1
    fi
    T_END=$(date +%s%N)
    INFER_MS=$(( (T_END - T_START) / 1000000 ))
    TOKS_PER_SEC=$(( 50 * 1000 / (INFER_MS + 1) ))
    report "Llama Inference : ~${TOKS_PER_SEC} tok/s (50 tokens, threads=$THREADS)"
else
    report "Llama Inference : skipped (model or binary not found)"
fi

report ""
report "=== End Benchmark ==="

[[ -n "$OUTPUT_FILE" ]] && log "Report saved: $OUTPUT_FILE"
