#!/usr/bin/env bash
# tools/apply-update.sh — AIOS Update Applier
# © 2026 Chris Betts | AIOSCPU Official
#
# Applies updates safely:
#   1. Creates backup of current state
#   2. Runs git pull
#   3. Runs health check
#   4. On failure, rolls back from backup
#
# Usage:
#   bash tools/apply-update.sh [--force]
#
# Exit codes:
#   0 — Update successful
#   1 — Update failed (rolled back)

set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AIOS_ROOT="${AIOS_ROOT:-$(cd "$SCRIPT_DIR/.." && pwd)}"
OS_ROOT="${OS_ROOT:-$AIOS_ROOT/OS}"

BACKUP_DIR="$OS_ROOT/var/backup"
UPDATE_LOG="$OS_ROOT/var/log/update.log"

mkdir -p "$BACKUP_DIR" "$(dirname "$UPDATE_LOG")"

_ts() { date '+%Y-%m-%dT%H:%M:%SZ'; }
_log() { echo "[$(_ts)] $*" | tee -a "$UPDATE_LOG"; }

FORCE=0
for arg in "$@"; do
    case "$arg" in
        --force|-f) FORCE=1 ;;
        --help|-h)
            echo "Usage: $0 [--force]"
            echo "Applies updates with automatic backup and rollback."
            exit 0
            ;;
    esac
done

echo "=== AIOS Update Applier ==="
_log "Update started"

cd "$AIOS_ROOT"

# ---------------------------------------------------------------------------
# Pre-flight checks
# ---------------------------------------------------------------------------
if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    _log "ERROR: Not a git repository"
    exit 1
fi

# Check for local changes
UNCOMMITTED=$(git status --porcelain 2>/dev/null | wc -l)
if [ "$UNCOMMITTED" -gt 0 ] && [ "$FORCE" -eq 0 ]; then
    _log "ERROR: Local changes detected ($UNCOMMITTED files). Use --force to override."
    echo "Uncommitted changes:"
    git status --short | head -5
    exit 1
fi

# Check offline mode
AIOS_CONF="$AIOS_ROOT/config/aios.conf"
[ -f "$AIOS_CONF" ] && . "$AIOS_CONF" 2>/dev/null

if [ "${OFFLINE_MODE:-0}" = "1" ]; then
    _log "ERROR: Offline mode enabled. Cannot update."
    exit 1
fi

# ---------------------------------------------------------------------------
# Create backup
# ---------------------------------------------------------------------------
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
BACKUP_PATH="$BACKUP_DIR/pre-update-$TIMESTAMP"

echo ""
echo "--- Creating Backup ---"
_log "Creating backup at $BACKUP_PATH"

mkdir -p "$BACKUP_PATH"

# Backup critical directories
for dir in config etc; do
    if [ -d "$AIOS_ROOT/$dir" ]; then
        cp -r "$AIOS_ROOT/$dir" "$BACKUP_PATH/"
        _log "Backed up: $dir"
    fi
done

# Backup OS critical files
mkdir -p "$BACKUP_PATH/OS"
for path in sbin/init etc/init.d etc/rc2.d; do
    if [ -e "$OS_ROOT/$path" ]; then
        mkdir -p "$BACKUP_PATH/OS/$(dirname "$path")"
        cp -r "$OS_ROOT/$path" "$BACKUP_PATH/OS/$(dirname "$path")/"
        _log "Backed up: OS/$path"
    fi
done

# Backup tools
if [ -d "$AIOS_ROOT/tools" ]; then
    cp -r "$AIOS_ROOT/tools" "$BACKUP_PATH/"
    _log "Backed up: tools"
fi

# Record current commit
git rev-parse HEAD > "$BACKUP_PATH/commit.txt"
_log "Backup commit: $(cat "$BACKUP_PATH/commit.txt")"

echo "Backup created: $BACKUP_PATH"

# ---------------------------------------------------------------------------
# Apply update
# ---------------------------------------------------------------------------
echo ""
echo "--- Applying Update ---"
_log "Running git pull"

CURRENT_COMMIT=$(git rev-parse --short HEAD)

if git pull 2>&1 | tee -a "$UPDATE_LOG"; then
    NEW_COMMIT=$(git rev-parse --short HEAD)
    _log "Update pulled: $CURRENT_COMMIT -> $NEW_COMMIT"
else
    _log "ERROR: git pull failed"
    echo "Update failed. Backup available at: $BACKUP_PATH"
    exit 1
fi

# ---------------------------------------------------------------------------
# Verify update
# ---------------------------------------------------------------------------
echo ""
echo "--- Verifying Update ---"
_log "Running health check"

HEALTH_CHECK="$AIOS_ROOT/tools/health_check.sh"
if [ -f "$HEALTH_CHECK" ]; then
    if bash "$HEALTH_CHECK" --quiet 2>&1 | tee -a "$UPDATE_LOG"; then
        _log "Health check: PASSED"
        echo "Health check passed."
    else
        _log "Health check: FAILED - initiating rollback"
        echo "Health check failed. Initiating rollback..."
        
        # Rollback
        echo ""
        echo "--- Rolling Back ---"
        
        for dir in config etc tools; do
            if [ -d "$BACKUP_PATH/$dir" ]; then
                rm -rf "$AIOS_ROOT/$dir"
                cp -r "$BACKUP_PATH/$dir" "$AIOS_ROOT/"
                _log "Restored: $dir"
            fi
        done
        
        for path in sbin/init etc/init.d etc/rc2.d; do
            if [ -e "$BACKUP_PATH/OS/$path" ]; then
                rm -rf "$OS_ROOT/$path"
                cp -r "$BACKUP_PATH/OS/$path" "$OS_ROOT/$(dirname "$path")/"
                _log "Restored: OS/$path"
            fi
        done
        
        _log "Rollback complete"
        echo "Rollback complete. System restored to previous state."
        exit 1
    fi
else
    _log "Warning: health_check.sh not found, skipping verification"
    echo "Warning: Could not verify update (health_check.sh not found)"
fi

# ---------------------------------------------------------------------------
# Success
# ---------------------------------------------------------------------------
echo ""
echo "=== Update Complete ==="
_log "Update successful: $CURRENT_COMMIT -> $NEW_COMMIT"
echo "Updated from $CURRENT_COMMIT to $NEW_COMMIT"
echo "Backup saved at: $BACKUP_PATH"
echo ""
echo "Run 'bash tools/health_check.sh' to verify system state."
