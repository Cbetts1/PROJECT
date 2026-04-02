#!/bin/bash
# ai/inference-engine/stop-daemon.sh
# Gracefully stops the llama-server inference daemon.

set -euo pipefail

AIOS_ROOT="${AIOS_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)}"
PID_FILE="$AIOS_ROOT/OS/var/run/llama-daemon.pid"

log() { echo "[inference-daemon] $*"; }

if [[ ! -f "$PID_FILE" ]]; then
    log "No PID file found. Daemon may not be running."
    exit 0
fi

PID=$(cat "$PID_FILE")
if kill -0 "$PID" 2>/dev/null; then
    log "Stopping daemon (PID $PID)..."
    kill -TERM "$PID"
    sleep 2
    kill -0 "$PID" 2>/dev/null && kill -KILL "$PID"
    rm -f "$PID_FILE"
    log "Daemon stopped."
else
    log "Daemon not running (stale PID $PID). Cleaning up."
    rm -f "$PID_FILE"
fi
