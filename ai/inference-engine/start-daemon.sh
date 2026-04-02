#!/bin/bash
# ai/inference-engine/start-daemon.sh
# Starts the llama-server inference daemon.
# The daemon exposes a REST API on localhost:8080 and accepts requests
# from the Aura shell.
#
# Usage:
#   bash ai/inference-engine/start-daemon.sh [--port 8080] [--background]

set -euo pipefail

AIOS_ROOT="${AIOS_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)}"
CONFIG="$AIOS_ROOT/config/llama-settings.conf"
LLAMA_SERVER="$AIOS_ROOT/ai/llama-integration/bin/llama-server"
PID_FILE="$AIOS_ROOT/OS/var/run/llama-daemon.pid"
LOG_FILE="$AIOS_ROOT/OS/var/log/llama-daemon.log"

PORT=8080
BACKGROUND=false

log() { echo "[inference-daemon] $*"; }
die() { echo "[inference-daemon] ERROR: $*" >&2; exit 1; }

while [[ $# -gt 0 ]]; do
    case "$1" in
        --port)       PORT="$2";       shift 2 ;;
        --background) BACKGROUND=true; shift   ;;
        *) die "Unknown argument: $1" ;;
    esac
done

# ── Load config ───────────────────────────────────────────────────────────────
MODEL_PATH=""
CONTEXT_SIZE=2048
THREADS=3
LLAMA_CPU_AFFINITY=""
THERMAL_LIMIT_C=68

[[ -f "$CONFIG" ]] && . "$CONFIG"

[[ -z "$MODEL_PATH" ]] && die "MODEL_PATH not configured. Run: bash ai/model-quantizer/download-model.sh"
[[ -f "$MODEL_PATH" ]] || die "Model not found: $MODEL_PATH"
[[ -f "$LLAMA_SERVER" ]] || die "llama-server not built. Run: bash ai/llama-integration/build.sh"

# ── Check if already running ──────────────────────────────────────────────────
if [[ -f "$PID_FILE" ]]; then
    PID=$(cat "$PID_FILE")
    if kill -0 "$PID" 2>/dev/null; then
        log "Daemon already running (PID $PID)"
        exit 0
    fi
fi

# ── Thermal check before starting ────────────────────────────────────────────
check_thermal() {
    THERMAL_FILE="/sys/class/thermal/thermal_zone0/temp"
    if [[ -f "$THERMAL_FILE" ]]; then
        TEMP_MC=$(cat "$THERMAL_FILE")
        TEMP_C=$((TEMP_MC / 1000))
        if [[ $TEMP_C -ge $THERMAL_LIMIT_C ]]; then
            log "WARNING: CPU temperature ${TEMP_C}°C >= limit ${THERMAL_LIMIT_C}°C. Waiting 30s..."
            sleep 30
        fi
    fi
}

check_thermal

mkdir -p "$(dirname "$PID_FILE")" "$(dirname "$LOG_FILE")"

SERVER_ARGS=(
    --model "$MODEL_PATH"
    --ctx-size "$CONTEXT_SIZE"
    --threads "$THREADS"
    --port "$PORT"
    --host 127.0.0.1
    --log-disable
)

log "Starting llama-server on port $PORT..."
log "Model: $MODEL_PATH"

if $BACKGROUND; then
    if [[ -n "$LLAMA_CPU_AFFINITY" ]] && command -v taskset >/dev/null 2>&1; then
        taskset -c "$LLAMA_CPU_AFFINITY" "$LLAMA_SERVER" "${SERVER_ARGS[@]}" \
            >> "$LOG_FILE" 2>&1 &
    else
        "$LLAMA_SERVER" "${SERVER_ARGS[@]}" >> "$LOG_FILE" 2>&1 &
    fi
    echo $! > "$PID_FILE"
    log "Daemon started (PID $(cat "$PID_FILE")). Log: $LOG_FILE"
else
    if [[ -n "$LLAMA_CPU_AFFINITY" ]] && command -v taskset >/dev/null 2>&1; then
        exec taskset -c "$LLAMA_CPU_AFFINITY" "$LLAMA_SERVER" "${SERVER_ARGS[@]}"
    else
        exec "$LLAMA_SERVER" "${SERVER_ARGS[@]}"
    fi
fi
