#!/usr/bin/env bash
# tools/recovery-ctl.sh — Recovery Point Management
# © 2026 Chris Betts | AIOSCPU Official
#
# Manages recovery points:
#   - status  — Show current backups and recovery points
#   - create  — Create a named recovery point
#   - list    — List all recovery points
#   - restore — Restore from a recovery point
#   - purge   — Remove old recovery points
#
# Usage:
#   recovery-ctl.sh <action> [args]
#
# Exit codes:
#   0 — Success
#   1 — Error

set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AIOS_ROOT="${AIOS_ROOT:-$(cd "$SCRIPT_DIR/.." && pwd)}"
OS_ROOT="${OS_ROOT:-$AIOS_ROOT/OS}"

RECOVERY_DIR="$OS_ROOT/var/backup/recovery"
LOG_FILE="$OS_ROOT/var/log/recover.log"

mkdir -p "$RECOVERY_DIR" "$(dirname "$LOG_FILE")" 2>/dev/null

_ts() { date '+%Y-%m-%dT%H:%M:%SZ'; }
_log() { echo "[$(_ts)] [recovery-ctl] $*" | tee -a "$LOG_FILE"; }

usage() {
    cat << 'EOF'
Usage: recovery-ctl.sh <action> [args]

Actions:
  status              Show current state and available recovery points
  create <label>      Create a named recovery point
  list                List all recovery points with timestamps
  restore <id>        Restore from a recovery point (interactive)
  purge <days>        Remove recovery points older than N days

Examples:
  recovery-ctl.sh status
  recovery-ctl.sh create before-upgrade
  recovery-ctl.sh list
  recovery-ctl.sh restore 20260102-153045
  recovery-ctl.sh purge 30
EOF
    exit 1
}

# ---------------------------------------------------------------------------
# Show status
# ---------------------------------------------------------------------------
action_status() {
    echo "=== AIOS Recovery Status ==="
    echo ""
    echo "Recovery directory: $RECOVERY_DIR"
    
    local count=$(ls -1d "$RECOVERY_DIR"/*/ 2>/dev/null | wc -l)
    echo "Recovery points: $count"
    
    if [ "$count" -gt 0 ]; then
        echo ""
        echo "Latest recovery points:"
        ls -1dt "$RECOVERY_DIR"/*/ 2>/dev/null | head -5 | while read dir; do
            local name=$(basename "$dir")
            local label=""
            [ -f "$dir/label" ] && label=$(cat "$dir/label")
            echo "  - $name ${label:+($label)}"
        done
    fi
    
    echo ""
    echo "Disk usage: $(du -sh "$RECOVERY_DIR" 2>/dev/null | cut -f1)"
}

# ---------------------------------------------------------------------------
# Create recovery point
# ---------------------------------------------------------------------------
action_create() {
    local label="${1:-manual}"
    
    local timestamp=$(date +%Y%m%d-%H%M%S)
    local point_dir="$RECOVERY_DIR/$timestamp"
    
    _log "Creating recovery point: $timestamp (label: $label)"
    echo "Creating recovery point: $timestamp"
    
    mkdir -p "$point_dir"
    
    # Save label
    echo "$label" > "$point_dir/label"
    
    # Save timestamp
    date > "$point_dir/created"
    
    # Backup config
    if [ -d "$AIOS_ROOT/config" ]; then
        cp -r "$AIOS_ROOT/config" "$point_dir/"
        echo "  - config/"
    fi
    
    # Backup etc
    if [ -d "$AIOS_ROOT/etc" ]; then
        cp -r "$AIOS_ROOT/etc" "$point_dir/"
        echo "  - etc/"
    fi
    
    # Backup OS/sbin
    if [ -d "$OS_ROOT/sbin" ]; then
        mkdir -p "$point_dir/OS"
        cp -r "$OS_ROOT/sbin" "$point_dir/OS/"
        echo "  - OS/sbin/"
    fi
    
    # Backup OS/etc/init.d
    if [ -d "$OS_ROOT/etc/init.d" ]; then
        mkdir -p "$point_dir/OS/etc"
        cp -r "$OS_ROOT/etc/init.d" "$point_dir/OS/etc/"
        echo "  - OS/etc/init.d/"
    fi
    
    # Backup OS/etc/rc2.d
    if [ -d "$OS_ROOT/etc/rc2.d" ]; then
        mkdir -p "$point_dir/OS/etc"
        cp -r "$OS_ROOT/etc/rc2.d" "$point_dir/OS/etc/"
        echo "  - OS/etc/rc2.d/"
    fi
    
    # Calculate size
    local size=$(du -sh "$point_dir" 2>/dev/null | cut -f1)
    echo "$size" > "$point_dir/size"
    
    _log "Recovery point created: $timestamp (size: $size)"
    echo ""
    echo "Recovery point created: $timestamp"
    echo "Size: $size"
}

# ---------------------------------------------------------------------------
# List recovery points
# ---------------------------------------------------------------------------
action_list() {
    echo "=== AIOS Recovery Points ==="
    echo ""
    printf "%-20s %-20s %-10s %s\n" "ID" "CREATED" "SIZE" "LABEL"
    printf "%-20s %-20s %-10s %s\n" "--" "-------" "----" "-----"
    
    for dir in $(ls -1dt "$RECOVERY_DIR"/*/ 2>/dev/null); do
        [ -d "$dir" ] || continue
        
        local id=$(basename "$dir")
        local created=""
        local size=""
        local label=""
        
        [ -f "$dir/created" ] && created=$(head -1 "$dir/created" | cut -d' ' -f1-3)
        [ -f "$dir/size" ] && size=$(cat "$dir/size")
        [ -f "$dir/label" ] && label=$(cat "$dir/label")
        
        printf "%-20s %-20s %-10s %s\n" "$id" "${created:-unknown}" "${size:-?}" "${label:-}"
    done
    
    local total=$(ls -1d "$RECOVERY_DIR"/*/ 2>/dev/null | wc -l)
    echo ""
    echo "Total: $total recovery point(s)"
}

# ---------------------------------------------------------------------------
# Restore from recovery point
# ---------------------------------------------------------------------------
action_restore() {
    local point_id="$1"
    
    [ -z "$point_id" ] && { echo "Error: recovery point ID required"; exit 1; }
    
    local point_dir="$RECOVERY_DIR/$point_id"
    
    if [ ! -d "$point_dir" ]; then
        echo "Error: Recovery point not found: $point_id"
        echo "Run 'recovery-ctl.sh list' to see available points."
        exit 1
    fi
    
    local label=""
    [ -f "$point_dir/label" ] && label=$(cat "$point_dir/label")
    
    echo "=== Restore Recovery Point ==="
    echo "ID: $point_id"
    echo "Label: ${label:-none}"
    echo ""
    echo "This will restore:"
    [ -d "$point_dir/config" ] && echo "  - config/"
    [ -d "$point_dir/etc" ] && echo "  - etc/"
    [ -d "$point_dir/OS/sbin" ] && echo "  - OS/sbin/"
    [ -d "$point_dir/OS/etc/init.d" ] && echo "  - OS/etc/init.d/"
    [ -d "$point_dir/OS/etc/rc2.d" ] && echo "  - OS/etc/rc2.d/"
    echo ""
    
    # Confirmation prompt
    echo -n "Are you sure you want to restore? [y/N] "
    read -r answer
    
    if [[ ! "$answer" =~ ^[Yy]$ ]]; then
        echo "Restore cancelled."
        exit 0
    fi
    
    _log "Restoring from recovery point: $point_id"
    echo ""
    echo "Restoring..."
    
    # Restore config
    if [ -d "$point_dir/config" ]; then
        rm -rf "$AIOS_ROOT/config"
        cp -r "$point_dir/config" "$AIOS_ROOT/"
        echo "  Restored: config/"
    fi
    
    # Restore etc
    if [ -d "$point_dir/etc" ]; then
        rm -rf "$AIOS_ROOT/etc"
        cp -r "$point_dir/etc" "$AIOS_ROOT/"
        echo "  Restored: etc/"
    fi
    
    # Restore OS/sbin
    if [ -d "$point_dir/OS/sbin" ]; then
        rm -rf "$OS_ROOT/sbin"
        cp -r "$point_dir/OS/sbin" "$OS_ROOT/"
        echo "  Restored: OS/sbin/"
    fi
    
    # Restore OS/etc/init.d
    if [ -d "$point_dir/OS/etc/init.d" ]; then
        rm -rf "$OS_ROOT/etc/init.d"
        cp -r "$point_dir/OS/etc/init.d" "$OS_ROOT/etc/"
        echo "  Restored: OS/etc/init.d/"
    fi
    
    # Restore OS/etc/rc2.d
    if [ -d "$point_dir/OS/etc/rc2.d" ]; then
        rm -rf "$OS_ROOT/etc/rc2.d"
        cp -r "$point_dir/OS/etc/rc2.d" "$OS_ROOT/etc/"
        echo "  Restored: OS/etc/rc2.d/"
    fi
    
    _log "Restore complete from: $point_id"
    echo ""
    echo "Restore complete."
    echo "Run 'bash tools/health_check.sh' to verify system state."
}

# ---------------------------------------------------------------------------
# Purge old recovery points
# ---------------------------------------------------------------------------
action_purge() {
    local days="${1:-30}"
    
    echo "=== Purge Old Recovery Points ==="
    echo "Removing recovery points older than $days days..."
    echo ""
    
    local count=0
    local now=$(date +%s)
    local cutoff=$((now - days * 86400))
    
    for dir in "$RECOVERY_DIR"/*/; do
        [ -d "$dir" ] || continue
        
        local id=$(basename "$dir")
        local created_file="$dir/created"
        
        if [ -f "$created_file" ]; then
            local created_ts=$(date -d "$(cat "$created_file")" +%s 2>/dev/null || echo 0)
            
            if [ "$created_ts" -lt "$cutoff" ]; then
                echo "  Removing: $id"
                rm -rf "$dir"
                _log "Purged recovery point: $id"
                count=$((count + 1))
            fi
        fi
    done
    
    echo ""
    echo "Purged $count recovery point(s)"
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
ACTION="${1:-status}"
shift 2>/dev/null || true

case "$ACTION" in
    status)   action_status ;;
    create)   action_create "$@" ;;
    list)     action_list ;;
    restore)  action_restore "$@" ;;
    purge)    action_purge "$@" ;;
    help|--help|-h) usage ;;
    *)
        echo "Unknown action: $ACTION"
        usage
        ;;
esac
