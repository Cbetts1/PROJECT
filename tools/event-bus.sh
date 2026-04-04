#!/usr/bin/env bash
# tools/event-bus.sh — Simple Event Pub/Sub System
# © 2026 Chris Betts | AIOSCPU Official
#
# A simple synchronous event pub/sub system:
#   - subscribe <type> <handler>  — Register a handler
#   - publish <type> [data]       — Call all handlers
#   - list [type]                 — List handlers
#
# Usage:
#   bash tools/event-bus.sh subscribe boot.complete /path/to/handler.sh
#   bash tools/event-bus.sh publish boot.complete
#
# Handlers are stored in OS/etc/event-handlers/<type>.d/

set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AIOS_ROOT="${AIOS_ROOT:-$(cd "$SCRIPT_DIR/.." && pwd)}"
OS_ROOT="${OS_ROOT:-$AIOS_ROOT/OS}"

HANDLERS_DIR="$OS_ROOT/etc/event-handlers"
LOG_FILE="$OS_ROOT/var/log/events.log"

mkdir -p "$HANDLERS_DIR" "$(dirname "$LOG_FILE")" 2>/dev/null

_ts() { date '+%Y-%m-%dT%H:%M:%SZ'; }
_log() { echo "[$(_ts)] [event-bus] $*" >> "$LOG_FILE"; }

usage() {
    cat << 'EOF'
Usage: event-bus.sh <action> [args]

Actions:
  subscribe <type> <handler>   Register a handler script for event type
  unsubscribe <type> <handler> Remove a handler
  publish <type> [data...]     Publish an event (calls all handlers)
  list [type]                  List handlers (all or for specific type)

Examples:
  event-bus.sh subscribe boot.complete tools/on-boot.sh
  event-bus.sh publish boot.complete
  event-bus.sh list boot.complete
  event-bus.sh unsubscribe boot.complete tools/on-boot.sh

Handlers are called with: <handler> <type> <data>
EOF
    exit 1
}

# ---------------------------------------------------------------------------
# Subscribe a handler
# ---------------------------------------------------------------------------
action_subscribe() {
    local event_type="$1"
    local handler="$2"
    
    [ -z "$event_type" ] && { echo "Error: event type required"; exit 1; }
    [ -z "$handler" ] && { echo "Error: handler script required"; exit 1; }
    
    # Normalize type to directory-safe name
    local type_dir=$(echo "$event_type" | tr '.' '-')
    local handlers_path="$HANDLERS_DIR/${type_dir}.d"
    
    mkdir -p "$handlers_path"
    
    # Create symlink or entry file
    local handler_name=$(basename "$handler")
    local handler_file="$handlers_path/$handler_name"
    
    # Store full path to handler
    if [[ "$handler" == /* ]]; then
        echo "$handler" > "$handler_file"
    else
        echo "$AIOS_ROOT/$handler" > "$handler_file"
    fi
    
    _log "subscribe type=$event_type handler=$handler"
    echo "Subscribed '$handler' to '$event_type'"
}

# ---------------------------------------------------------------------------
# Unsubscribe a handler
# ---------------------------------------------------------------------------
action_unsubscribe() {
    local event_type="$1"
    local handler="$2"
    
    [ -z "$event_type" ] && { echo "Error: event type required"; exit 1; }
    [ -z "$handler" ] && { echo "Error: handler script required"; exit 1; }
    
    local type_dir=$(echo "$event_type" | tr '.' '-')
    local handlers_path="$HANDLERS_DIR/${type_dir}.d"
    local handler_name=$(basename "$handler")
    local handler_file="$handlers_path/$handler_name"
    
    if [ -f "$handler_file" ]; then
        rm -f "$handler_file"
        _log "unsubscribe type=$event_type handler=$handler"
        echo "Unsubscribed '$handler' from '$event_type'"
    else
        echo "Handler not found: $handler_file"
        exit 1
    fi
}

# ---------------------------------------------------------------------------
# Publish an event
# ---------------------------------------------------------------------------
action_publish() {
    local event_type="$1"
    shift 2>/dev/null || true
    local event_data="$*"
    
    [ -z "$event_type" ] && { echo "Error: event type required"; exit 1; }
    
    _log "publish type=$event_type data=$event_data"
    
    local type_dir=$(echo "$event_type" | tr '.' '-')
    local handlers_path="$HANDLERS_DIR/${type_dir}.d"
    
    if [ ! -d "$handlers_path" ]; then
        echo "No handlers registered for '$event_type'"
        return 0
    fi
    
    local count=0
    for handler_file in "$handlers_path"/*; do
        [ -f "$handler_file" ] || continue
        
        local handler_path=$(cat "$handler_file")
        
        if [ -x "$handler_path" ]; then
            echo "Calling handler: $(basename "$handler_file")"
            "$handler_path" "$event_type" $event_data && {
                _log "handler success: $handler_path"
            } || {
                _log "handler failed: $handler_path"
                echo "Warning: Handler failed: $handler_path"
            }
            count=$((count + 1))
        elif [ -f "$handler_path" ]; then
            # Try running with bash
            echo "Calling handler: $(basename "$handler_file")"
            bash "$handler_path" "$event_type" $event_data && {
                _log "handler success: $handler_path"
            } || {
                _log "handler failed: $handler_path"
                echo "Warning: Handler failed: $handler_path"
            }
            count=$((count + 1))
        else
            echo "Warning: Handler not found: $handler_path"
            _log "handler missing: $handler_path"
        fi
    done
    
    echo "Published '$event_type' to $count handler(s)"
}

# ---------------------------------------------------------------------------
# List handlers
# ---------------------------------------------------------------------------
action_list() {
    local event_type="$1"
    
    echo "=== Event Handlers ==="
    
    if [ -n "$event_type" ]; then
        local type_dir=$(echo "$event_type" | tr '.' '-')
        local handlers_path="$HANDLERS_DIR/${type_dir}.d"
        
        echo "Type: $event_type"
        if [ -d "$handlers_path" ]; then
            for handler_file in "$handlers_path"/*; do
                [ -f "$handler_file" ] || continue
                local handler_path=$(cat "$handler_file")
                echo "  - $(basename "$handler_file"): $handler_path"
            done
        else
            echo "  (no handlers)"
        fi
    else
        for type_dir in "$HANDLERS_DIR"/*.d; do
            [ -d "$type_dir" ] || continue
            local type_name=$(basename "$type_dir" .d | tr '-' '.')
            echo ""
            echo "Type: $type_name"
            for handler_file in "$type_dir"/*; do
                [ -f "$handler_file" ] || continue
                local handler_path=$(cat "$handler_file")
                echo "  - $(basename "$handler_file"): $handler_path"
            done
        done
        
        if [ ! -d "$HANDLERS_DIR" ] || [ -z "$(ls -A "$HANDLERS_DIR" 2>/dev/null)" ]; then
            echo "(no event types registered)"
        fi
    fi
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
ACTION="${1:-list}"
shift 2>/dev/null || true

case "$ACTION" in
    subscribe|sub)   action_subscribe "$@" ;;
    unsubscribe|unsub) action_unsubscribe "$@" ;;
    publish|pub)     action_publish "$@" ;;
    list|ls)         action_list "$@" ;;
    help|--help|-h)  usage ;;
    *)
        echo "Unknown action: $ACTION"
        usage
        ;;
esac
