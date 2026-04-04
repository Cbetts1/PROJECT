#!/usr/bin/env bash
# tools/event-viewer.sh — AIOS Event Viewer
# © 2026 Chris Betts | AIOSCPU Official
#
# Views events from OS/var/events/:
#   - Lists recent events
#   - Shows event count and types
#   - Supports --tail N and --follow
#   - Can filter by --type
#
# Usage:
#   bash tools/event-viewer.sh [--tail N] [--follow] [--type TYPE]
#
# Exit codes:
#   0 — Success

set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AIOS_ROOT="${AIOS_ROOT:-$(cd "$SCRIPT_DIR/.." && pwd)}"
OS_ROOT="${OS_ROOT:-$AIOS_ROOT/OS}"

EVENTS_DIR="$OS_ROOT/var/events"

TAIL_COUNT=20
FOLLOW=0
EVENT_TYPE=""

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --tail|-n)
            TAIL_COUNT="${2:-20}"
            shift 2
            ;;
        --tail=*)
            TAIL_COUNT="${1#--tail=}"
            shift
            ;;
        --follow|-f)
            FOLLOW=1
            shift
            ;;
        --type|-t)
            EVENT_TYPE="$2"
            shift 2
            ;;
        --type=*)
            EVENT_TYPE="${1#--type=}"
            shift
            ;;
        --help|-h)
            cat << 'EOF'
Usage: event-viewer.sh [options]

Options:
  --tail N, -n N    Show last N events (default: 20)
  --follow, -f      Follow new events (like tail -f)
  --type TYPE       Filter by event type (e.g., "kernel", "service")
  --help, -h        Show this help

Examples:
  event-viewer.sh                     # Show last 20 events
  event-viewer.sh --tail 50           # Show last 50 events
  event-viewer.sh --type kernel       # Show only kernel events
  event-viewer.sh --follow            # Follow new events
EOF
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# ---------------------------------------------------------------------------
# Read event file
# ---------------------------------------------------------------------------
read_event() {
    local file="$1"
    [ -f "$file" ] || return
    
    local content=$(cat "$file" 2>/dev/null)
    local filename=$(basename "$file")
    local timestamp="${filename%.event}"
    
    # Parse event content
    # Format: [YYYY-MM-DD HH:MM:SS] source: message
    local source=$(echo "$content" | grep -oE '\] [^:]+:' | sed 's/\] //' | sed 's/://')
    local message=$(echo "$content" | sed 's/.*\] [^:]*: //')
    
    # Apply type filter
    if [ -n "$EVENT_TYPE" ]; then
        if ! echo "$source" | grep -qi "$EVENT_TYPE"; then
            return
        fi
    fi
    
    echo "$content"
}

# ---------------------------------------------------------------------------
# Show summary
# ---------------------------------------------------------------------------
show_summary() {
    echo "=== AIOS Event Summary ==="
    echo "Events directory: $EVENTS_DIR"
    
    if [ ! -d "$EVENTS_DIR" ]; then
        echo "No events directory found."
        return
    fi
    
    local total=$(ls -1 "$EVENTS_DIR"/*.event 2>/dev/null | wc -l)
    echo "Total events: $total"
    
    if [ "$total" -gt 0 ]; then
        echo ""
        echo "Event types (by count):"
        cat "$EVENTS_DIR"/*.event 2>/dev/null | grep -oE '\] [^:]+:' | sed 's/\] //' | sed 's/://' | sort | uniq -c | sort -rn | head -10
    fi
    echo ""
}

# ---------------------------------------------------------------------------
# List events
# ---------------------------------------------------------------------------
list_events() {
    show_summary
    
    if [ ! -d "$EVENTS_DIR" ]; then
        return
    fi
    
    echo "=== Recent Events (last $TAIL_COUNT) ==="
    [ -n "$EVENT_TYPE" ] && echo "Filter: type=$EVENT_TYPE"
    echo ""
    
    # Get event files sorted by name (timestamp)
    local count=0
    for file in $(ls -1 "$EVENTS_DIR"/*.event 2>/dev/null | sort -r | head -$TAIL_COUNT); do
        local output=$(read_event "$file")
        if [ -n "$output" ]; then
            echo "$output"
            count=$((count + 1))
        fi
    done
    
    if [ $count -eq 0 ]; then
        echo "(No events found)"
    fi
}

# ---------------------------------------------------------------------------
# Follow events
# ---------------------------------------------------------------------------
follow_events() {
    echo "=== Following Events (Ctrl+C to stop) ==="
    [ -n "$EVENT_TYPE" ] && echo "Filter: type=$EVENT_TYPE"
    echo ""
    
    # Track last seen event
    local last_seen=""
    
    while true; do
        if [ -d "$EVENTS_DIR" ]; then
            for file in $(ls -1 "$EVENTS_DIR"/*.event 2>/dev/null | sort); do
                local filename=$(basename "$file")
                
                # Skip if we've already seen this event
                if [ -n "$last_seen" ] && [[ "$filename" < "$last_seen" || "$filename" == "$last_seen" ]]; then
                    continue
                fi
                
                local output=$(read_event "$file")
                if [ -n "$output" ]; then
                    echo "$output"
                fi
                
                last_seen="$filename"
            done
        fi
        
        sleep 1
    done
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
if [ "$FOLLOW" -eq 1 ]; then
    follow_events
else
    list_events
fi
