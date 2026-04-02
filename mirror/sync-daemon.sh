#!/bin/bash
# mirror/sync-daemon.sh
# Bidirectional sync daemon for critical AIOS data paths.
# Syncs user data between the AIOS upper overlay layer and configured targets
# (e.g., /sdcard/aios-backup or a remote rclone destination).
#
# Usage:
#   bash mirror/sync-daemon.sh start
#   bash mirror/sync-daemon.sh stop
#   bash mirror/sync-daemon.sh sync-now

set -euo pipefail

AIOS_ROOT="${AIOS_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
CONF="$AIOS_ROOT/config/overlay.conf"
PID_FILE="$AIOS_ROOT/OS/var/run/sync-daemon.pid"
LOG_FILE="$AIOS_ROOT/OS/var/log/sync-daemon.log"
INTERVAL=300   # sync every 5 minutes

log()  { echo "[sync-daemon] $(date '+%H:%M:%S') $*" | tee -a "$LOG_FILE"; }
die()  { echo "[sync-daemon] ERROR: $*" >&2; exit 1; }

# ── Load config (env vars take precedence over config file) ──────────────────
_env_sync_source="${SYNC_SOURCE:-}"
_env_sync_target="${SYNC_TARGET:-}"
SYNC_SOURCE="$AIOS_ROOT/OS/overlay/upper"
SYNC_TARGET="/sdcard/aios-backup"
RCLONE_REMOTE=""

[[ -f "$CONF" ]] && . "$CONF"

# Restore environment overrides if they were set before the script ran
[[ -n "$_env_sync_source" ]] && SYNC_SOURCE="$_env_sync_source"
[[ -n "$_env_sync_target" ]] && SYNC_TARGET="$_env_sync_target"

mkdir -p "$(dirname "$PID_FILE")" "$(dirname "$LOG_FILE")"

# ── Perform a single sync pass ────────────────────────────────────────────────
do_sync() {
    log "Sync: $SYNC_SOURCE -> $SYNC_TARGET"
    mkdir -p "$SYNC_TARGET"

    if command -v rsync >/dev/null 2>&1; then
        rsync -a --delete --quiet "$SYNC_SOURCE/" "$SYNC_TARGET/"
    else
        cp -a "$SYNC_SOURCE/." "$SYNC_TARGET/"
    fi

    # Optional cloud sync via rclone
    if [[ -n "$RCLONE_REMOTE" ]] && command -v rclone >/dev/null 2>&1; then
        log "Rclone sync -> $RCLONE_REMOTE"
        rclone sync "$SYNC_TARGET" "$RCLONE_REMOTE" --quiet
    fi

    log "Sync complete."
}

# ── Commands ──────────────────────────────────────────────────────────────────
CMD="${1:-sync-now}"

case "$CMD" in
    start)
        if [[ -f "$PID_FILE" ]] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
            log "Already running (PID $(cat "$PID_FILE"))"
            exit 0
        fi

        log "Starting sync daemon (interval=${INTERVAL}s)..."
        (
            while true; do
                do_sync
                sleep "$INTERVAL"
            done
        ) >> "$LOG_FILE" 2>&1 &

        echo $! > "$PID_FILE"
        log "Sync daemon started (PID $(cat "$PID_FILE"))."
        ;;

    stop)
        if [[ -f "$PID_FILE" ]]; then
            PID=$(cat "$PID_FILE")
            kill -TERM "$PID" 2>/dev/null && log "Sync daemon stopped (PID $PID)."
            rm -f "$PID_FILE"
        else
            log "No PID file found."
        fi
        ;;

    sync-now)
        do_sync
        ;;

    *)
        die "Unknown command: $CMD. Use start|stop|sync-now"
        ;;
esac
