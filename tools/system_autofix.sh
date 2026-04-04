#!/usr/bin/env bash
# tools/system_autofix.sh — Safe Automatic System Repair Tool
# © 2026 Chris Betts | AIOSCPU Official
#
# Performs safe, reversible fixes:
# 1. Creates backup before any changes
# 2. Rotates oversized logs
# 3. Removes orphaned PID files
# 4. Fixes permissions on bin/ and rc2.d/
# 5. Quarantines broken symlinks
#
# All fixes are logged to OS/var/log/autofix.log
#
# Usage:
#   bash tools/system_autofix.sh [--dry-run]
#
# Options:
#   --dry-run    Report what would be done without making changes
#
# Exit codes:
#   0 — Success (or dry-run complete)
#   1 — Error during fix

set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AIOS_ROOT="${AIOS_ROOT:-$(cd "$SCRIPT_DIR/.." && pwd)}"
OS_ROOT="${OS_ROOT:-$AIOS_ROOT/OS}"

DRY_RUN=0
FIXES=0

for arg in "$@"; do
    case "$arg" in
        --dry-run|-n) DRY_RUN=1 ;;
        --help|-h)
            echo "Usage: $0 [--dry-run]"
            echo "Performs safe, reversible automatic fixes."
            echo ""
            echo "Options:"
            echo "  --dry-run    Report what would be done without making changes"
            exit 0
            ;;
    esac
done

# Setup
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
BACKUP_DIR="$OS_ROOT/var/backup/autofix-$TIMESTAMP"
LOG_FILE="$OS_ROOT/var/log/autofix.log"
MAX_LOG_SIZE=$((5 * 1024 * 1024))  # 5MB

# Ensure log directory exists
mkdir -p "$(dirname "$LOG_FILE")"

log() {
    local msg="[$(date '+%Y-%m-%dT%H:%M:%SZ')] $*"
    echo "$msg"
    [ "$DRY_RUN" -eq 0 ] && echo "$msg" >> "$LOG_FILE" || true
}

log_fix() {
    FIXES=$((FIXES + 1))
    log "[FIX] $*"
}

log_dry() {
    log "[DRY-RUN] Would: $*"
}

create_backup_dir() {
    if [ "$DRY_RUN" -eq 0 ] && [ ! -d "$BACKUP_DIR" ]; then
        mkdir -p "$BACKUP_DIR"
        log "Created backup directory: $BACKUP_DIR"
    fi
}

log "=== AIOS System Autofix ==="
log "AIOS_ROOT: $AIOS_ROOT"
log "OS_ROOT: $OS_ROOT"
if [ "$DRY_RUN" -eq 1 ]; then
    log "Mode: DRY RUN (no changes will be made)"
else
    log "Mode: LIVE (changes will be made)"
fi
log ""

# ---------------------------------------------------------------------------
# Fix 1: Rotate oversized logs
# ---------------------------------------------------------------------------
log "--- Fix 1: Rotate oversized logs ---"

LOG_DIRS=(
    "$OS_ROOT/var/log"
    "$AIOS_ROOT/var/log"
)

for log_dir in "${LOG_DIRS[@]}"; do
    [ -d "$log_dir" ] || continue
    
    for logfile in "$log_dir"/*.log; do
        [ -f "$logfile" ] || continue
        
        size=$(stat -c%s "$logfile" 2>/dev/null || stat -f%z "$logfile" 2>/dev/null || echo 0)
        
        if [ "$size" -gt "$MAX_LOG_SIZE" ]; then
            size_mb=$((size / 1024 / 1024))
            
            if [ "$DRY_RUN" -eq 1 ]; then
                log_dry "Rotate log (${size_mb}MB): $logfile"
            else
                create_backup_dir
                
                # Backup
                backup_name=$(basename "$logfile").bak
                cp "$logfile" "$BACKUP_DIR/$backup_name"
                
                # Rotate
                mv "$logfile" "${logfile}.bak"
                touch "$logfile"
                
                log_fix "Rotated log (${size_mb}MB): $logfile"
            fi
        fi
    done
done
log ""

# ---------------------------------------------------------------------------
# Fix 2: Remove orphaned PID files
# ---------------------------------------------------------------------------
log "--- Fix 2: Remove orphaned PID files ---"

PID_DIR="$OS_ROOT/var/service"
if [ -d "$PID_DIR" ]; then
    for pidfile in "$PID_DIR"/*.pid; do
        [ -f "$pidfile" ] || continue
        pid=$(cat "$pidfile" 2>/dev/null || echo "")
        
        if [ -n "$pid" ] && [ "$pid" -gt 0 ] 2>/dev/null; then
            if ! kill -0 "$pid" 2>/dev/null; then
                if [ "$DRY_RUN" -eq 1 ]; then
                    log_dry "Remove orphaned PID file: $pidfile (PID $pid)"
                else
                    create_backup_dir
                    
                    # Backup
                    cp "$pidfile" "$BACKUP_DIR/"
                    
                    # Remove
                    rm -f "$pidfile"
                    
                    log_fix "Removed orphaned PID file: $pidfile (PID $pid)"
                fi
            fi
        fi
    done
fi
log ""

# ---------------------------------------------------------------------------
# Fix 3: Fix permissions on bin/ and rc2.d/
# ---------------------------------------------------------------------------
log "--- Fix 3: Fix permissions ---"

# Fix bin/ directories
BIN_DIRS=(
    "$AIOS_ROOT/bin"
    "$AIOS_ROOT/tools"
    "$OS_ROOT/bin"
    "$OS_ROOT/sbin"
)

for dir in "${BIN_DIRS[@]}"; do
    [ -d "$dir" ] || continue
    
    for file in "$dir"/*; do
        [ -f "$file" ] || continue
        [ -L "$file" ] && continue  # Skip symlinks
        
        # Check if it has a shebang but isn't executable
        if head -c 2 "$file" 2>/dev/null | grep -q '^#!' && [ ! -x "$file" ]; then
            if [ "$DRY_RUN" -eq 1 ]; then
                log_dry "chmod +x $file"
            else
                chmod +x "$file"
                log_fix "chmod +x $file"
            fi
        fi
    done
done

# Fix init.d scripts
if [ -d "$OS_ROOT/etc/init.d" ]; then
    for script in "$OS_ROOT/etc/init.d"/*; do
        [ -f "$script" ] || continue
        
        if [ ! -x "$script" ]; then
            if [ "$DRY_RUN" -eq 1 ]; then
                log_dry "chmod +x $script"
            else
                chmod +x "$script"
                log_fix "chmod +x $script"
            fi
        fi
    done
fi
log ""

# ---------------------------------------------------------------------------
# Fix 4: Quarantine broken symlinks
# ---------------------------------------------------------------------------
log "--- Fix 4: Quarantine broken symlinks ---"

for link in "$OS_ROOT/bin"/*; do
    [ -L "$link" ] || continue
    
    if [ ! -e "$link" ]; then
        if [ "$DRY_RUN" -eq 1 ]; then
            log_dry "Quarantine broken symlink: $link"
        else
            create_backup_dir
            
            # Save symlink info
            target=$(readlink "$link" 2>/dev/null || echo "unknown")
            echo "$link -> $target" >> "$BACKUP_DIR/broken_symlinks.txt"
            
            # Remove
            rm -f "$link"
            
            log_fix "Quarantined broken symlink: $link -> $target"
        fi
    fi
done
log ""

# ---------------------------------------------------------------------------
# Fix 5: Create missing required directories
# ---------------------------------------------------------------------------
log "--- Fix 5: Create missing directories ---"

REQUIRED_DIRS=(
    "$OS_ROOT/var/log"
    "$OS_ROOT/var/service"
    "$OS_ROOT/var/events"
    "$OS_ROOT/var/backup"
    "$OS_ROOT/proc"
    "$OS_ROOT/tmp"
    "$AIOS_ROOT/var/log"
)

for dir in "${REQUIRED_DIRS[@]}"; do
    if [ ! -d "$dir" ]; then
        if [ "$DRY_RUN" -eq 1 ]; then
            log_dry "Create directory: $dir"
        else
            mkdir -p "$dir"
            log_fix "Created directory: $dir"
        fi
    fi
done
log ""

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
log "=== Summary ==="
if [ "$DRY_RUN" -eq 1 ]; then
    log "Dry run complete. No changes made."
    log "Would make $FIXES fix(es)."
    log "Run without --dry-run to apply changes."
else
    log "Fixes applied: $FIXES"
    if [ "$FIXES" -gt 0 ]; then
        log "Backup location: $BACKUP_DIR"
    fi
fi

exit 0
