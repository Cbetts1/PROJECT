#!/usr/bin/env bash
# tools/service-ctl.sh — Unified Service Controller
# © 2026 Chris Betts | AIOSCPU Official
#
# Manages AIOS services (rc2.d):
#   - list    — Show all services and their status
#   - status  — Show status of one service
#   - start   — Start a service
#   - stop    — Stop a service
#   - restart — Restart a service
#   - enable  — Enable a service (create symlink)
#   - disable — Disable a service (remove symlink)
#
# Usage:
#   service-ctl.sh <action> [service]
#
# Exit codes:
#   0 — Success
#   1 — Error

set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AIOS_ROOT="${AIOS_ROOT:-$(cd "$SCRIPT_DIR/.." && pwd)}"
OS_ROOT="${OS_ROOT:-$AIOS_ROOT/OS}"

RC2D_DIR="$OS_ROOT/etc/rc2.d"
INITD_DIR="$OS_ROOT/etc/init.d"
SVC_DIR="$OS_ROOT/var/service"
LOG_FILE="$OS_ROOT/var/log/service.log"

mkdir -p "$SVC_DIR" "$(dirname "$LOG_FILE")" 2>/dev/null

_ts() { date '+%Y-%m-%dT%H:%M:%SZ'; }
_log() { echo "[$(_ts)] [service-ctl] $*" >> "$LOG_FILE"; }

usage() {
    cat << 'EOF'
Usage: service-ctl.sh <action> [service]

Actions:
  list                  List all services and their status
  status <service>      Show status of a specific service
  start <service>       Start a service
  stop <service>        Stop a service
  restart <service>     Restart a service
  enable <service>      Enable a service (create S* symlink)
  disable <service>     Disable a service (remove S* symlink)

Examples:
  service-ctl.sh list
  service-ctl.sh status os-kernel
  service-ctl.sh restart aura-agents

Services are managed via rc2.d symlinks to init.d scripts.
EOF
    exit 1
}

# ---------------------------------------------------------------------------
# Get list of all services
# ---------------------------------------------------------------------------
get_all_services() {
    # Find all init.d scripts
    for script in "$INITD_DIR"/*; do
        [ -f "$script" ] || continue
        basename "$script"
    done | sort
}

# ---------------------------------------------------------------------------
# Get enabled services (those with S* symlinks)
# ---------------------------------------------------------------------------
get_enabled_services() {
    for link in "$RC2D_DIR"/S*; do
        [ -e "$link" ] || continue
        local name=$(basename "$link")
        local svc_name="${name#S[0-9][0-9]-}"
        echo "$svc_name"
    done
}

# ---------------------------------------------------------------------------
# Find rc2.d symlink for a service
# ---------------------------------------------------------------------------
find_rc2d_link() {
    local svc="$1"
    for link in "$RC2D_DIR"/S*-"$svc"; do
        [ -e "$link" ] && echo "$link" && return 0
    done
    return 1
}

# ---------------------------------------------------------------------------
# Get service status
# ---------------------------------------------------------------------------
get_service_status() {
    local svc="$1"
    local health_file="$SVC_DIR/${svc}.health"
    local pid_file="$SVC_DIR/${svc}.pid"
    
    local enabled="disabled"
    local status="stopped"
    local pid=""
    
    # Check if enabled
    if find_rc2d_link "$svc" >/dev/null 2>&1; then
        enabled="enabled"
    fi
    
    # Check health file
    if [ -f "$health_file" ]; then
        if grep -q "status=ok" "$health_file" 2>/dev/null; then
            status="running"
        elif grep -q "status=stopped" "$health_file" 2>/dev/null; then
            status="stopped"
        elif grep -q "status=error" "$health_file" 2>/dev/null; then
            status="error"
        fi
    fi
    
    # Check PID file
    if [ -f "$pid_file" ]; then
        pid=$(cat "$pid_file" 2>/dev/null)
        if [ -n "$pid" ] && [ -d "/proc/$pid" ]; then
            status="running"
        elif [ -n "$pid" ]; then
            status="dead"
        fi
    fi
    
    echo "$enabled:$status:$pid"
}

# ---------------------------------------------------------------------------
# List all services
# ---------------------------------------------------------------------------
action_list() {
    echo "=== AIOS Services ==="
    printf "%-20s %-10s %-10s %s\n" "SERVICE" "ENABLED" "STATUS" "PID"
    printf "%-20s %-10s %-10s %s\n" "-------" "-------" "------" "---"
    
    for svc in $(get_all_services); do
        local info=$(get_service_status "$svc")
        local enabled=$(echo "$info" | cut -d: -f1)
        local status=$(echo "$info" | cut -d: -f2)
        local pid=$(echo "$info" | cut -d: -f3)
        
        printf "%-20s %-10s %-10s %s\n" "$svc" "$enabled" "$status" "${pid:-—}"
    done
}

# ---------------------------------------------------------------------------
# Show service status
# ---------------------------------------------------------------------------
action_status() {
    local svc="$1"
    [ -z "$svc" ] && { echo "Error: service name required"; exit 1; }
    
    local script="$INITD_DIR/$svc"
    [ -f "$script" ] || { echo "Error: service '$svc' not found"; exit 1; }
    
    local info=$(get_service_status "$svc")
    local enabled=$(echo "$info" | cut -d: -f1)
    local status=$(echo "$info" | cut -d: -f2)
    local pid=$(echo "$info" | cut -d: -f3)
    
    echo "Service: $svc"
    echo "  Enabled: $enabled"
    echo "  Status:  $status"
    [ -n "$pid" ] && echo "  PID:     $pid"
    
    local health_file="$SVC_DIR/${svc}.health"
    if [ -f "$health_file" ]; then
        echo "  Health:  $(cat "$health_file")"
    fi
    
    # Try calling the script's status action if it has one
    if [ -x "$script" ]; then
        if grep -q "status)" "$script" 2>/dev/null; then
            echo ""
            echo "--- Service Status Output ---"
            sh "$script" status 2>&1 || true
        fi
    fi
}

# ---------------------------------------------------------------------------
# Start service
# ---------------------------------------------------------------------------
action_start() {
    local svc="$1"
    [ -z "$svc" ] && { echo "Error: service name required"; exit 1; }
    
    local link=$(find_rc2d_link "$svc")
    if [ -z "$link" ]; then
        # Try init.d directly
        local script="$INITD_DIR/$svc"
        [ -f "$script" ] || { echo "Error: service '$svc' not found"; exit 1; }
        link="$script"
    fi
    
    echo "Starting $svc..."
    _log "start $svc"
    
    if sh "$link" start; then
        echo "Service $svc started"
        _log "start $svc: success"
    else
        echo "Failed to start $svc"
        _log "start $svc: failed"
        exit 1
    fi
}

# ---------------------------------------------------------------------------
# Stop service
# ---------------------------------------------------------------------------
action_stop() {
    local svc="$1"
    [ -z "$svc" ] && { echo "Error: service name required"; exit 1; }
    
    local link=$(find_rc2d_link "$svc")
    if [ -z "$link" ]; then
        local script="$INITD_DIR/$svc"
        [ -f "$script" ] || { echo "Error: service '$svc' not found"; exit 1; }
        link="$script"
    fi
    
    echo "Stopping $svc..."
    _log "stop $svc"
    
    if sh "$link" stop; then
        echo "Service $svc stopped"
        _log "stop $svc: success"
    else
        echo "Failed to stop $svc"
        _log "stop $svc: failed"
        exit 1
    fi
}

# ---------------------------------------------------------------------------
# Restart service
# ---------------------------------------------------------------------------
action_restart() {
    local svc="$1"
    action_stop "$svc" || true
    sleep 1
    action_start "$svc"
}

# ---------------------------------------------------------------------------
# Enable service
# ---------------------------------------------------------------------------
action_enable() {
    local svc="$1"
    [ -z "$svc" ] && { echo "Error: service name required"; exit 1; }
    
    local script="$INITD_DIR/$svc"
    [ -f "$script" ] || { echo "Error: service '$svc' not found in init.d"; exit 1; }
    
    # Check if already enabled
    if find_rc2d_link "$svc" >/dev/null 2>&1; then
        echo "Service $svc is already enabled"
        return 0
    fi
    
    # Find next available S number
    local max_num=10
    for link in "$RC2D_DIR"/S*; do
        [ -e "$link" ] || continue
        local num=$(basename "$link" | grep -oE '^S[0-9]+' | tr -d 'S')
        [ -n "$num" ] && [ "$num" -ge "$max_num" ] && max_num=$((num + 10))
    done
    
    # Create symlink
    local link_name="S${max_num}-${svc}"
    ln -s "../init.d/$svc" "$RC2D_DIR/$link_name"
    
    echo "Enabled service $svc ($link_name)"
    _log "enable $svc as $link_name"
}

# ---------------------------------------------------------------------------
# Disable service
# ---------------------------------------------------------------------------
action_disable() {
    local svc="$1"
    [ -z "$svc" ] && { echo "Error: service name required"; exit 1; }
    
    local link=$(find_rc2d_link "$svc")
    if [ -z "$link" ]; then
        echo "Service $svc is not enabled"
        return 0
    fi
    
    # Remove symlink
    rm -f "$link"
    
    echo "Disabled service $svc"
    _log "disable $svc (removed $(basename "$link"))"
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
ACTION="${1:-list}"
shift 2>/dev/null || true

case "$ACTION" in
    list)     action_list ;;
    status)   action_status "$1" ;;
    start)    action_start "$1" ;;
    stop)     action_stop "$1" ;;
    restart)  action_restart "$1" ;;
    enable)   action_enable "$1" ;;
    disable)  action_disable "$1" ;;
    help|--help|-h) usage ;;
    *)
        echo "Unknown action: $ACTION"
        usage
        ;;
esac
