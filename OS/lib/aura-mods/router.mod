mod_name="router"
mod_help="Message router: route typed messages between AIOS components via the bus."
# © 2026 Chris Betts | AIOSCPU Official | AI-generated, fully legal
#
# Provides:
#   router_send   <dest> <msg>    Send a message to a named destination
#   router_recv   <dest>          Read pending messages for a destination
#   router_dispatch <msg>         Classify and dispatch a raw message
#   router_register <dest> <fn>   Register a handler function for a destination
#   router_table                  Print the routing table

ROUTER_DIR="${OS_ROOT}/proc/aura/router"
ROUTER_LOG="${OS_ROOT}/var/log/router.log"
mkdir -p "$ROUTER_DIR" "$(dirname "$ROUTER_LOG")"

# Internal routing table: dest -> handler function name
# Stored as files in ROUTER_DIR/<dest>.handler so it survives re-sourcing.
router_register() {
    dest="$1"
    handler="$2"
    mkdir -p "$ROUTER_DIR"
    printf '%s' "$handler" > "$ROUTER_DIR/${dest}.handler"
}

router_table() {
    echo "Routing table:"
    for f in "$ROUTER_DIR"/*.handler; do
        [ -f "$f" ] || continue
        dest=$(basename "$f" .handler)
        handler=$(cat "$f")
        printf '  %-20s -> %s\n' "$dest" "$handler"
    done
}

# ---------------------------------------------------------------------------
# Send a message to a named destination
# ---------------------------------------------------------------------------
router_send() {
    dest="$1"; shift
    msg="$*"
    ts=$(date '+%Y-%m-%dT%H:%M:%SZ')
    mkdir -p "$ROUTER_DIR/$dest"
    echo "[$ts] $msg" >> "$ROUTER_DIR/$dest/queue"
    echo "[$ts] [->$dest] $msg" >> "$ROUTER_LOG"

    # Publish to message bus as well (if bus module is loaded)
    if command -v bus_publish >/dev/null 2>&1; then
        bus_publish "router" "dest=$dest msg=$msg"
    fi

    # If there's a live handler registered, call it immediately
    handler_file="$ROUTER_DIR/${dest}.handler"
    if [ -f "$handler_file" ]; then
        handler=$(cat "$handler_file")
        if command -v "$handler" >/dev/null 2>&1; then
            "$handler" "$msg"
        fi
    fi
}

# ---------------------------------------------------------------------------
# Receive (drain) pending messages for a destination
# ---------------------------------------------------------------------------
router_recv() {
    dest="$1"
    queue="$ROUTER_DIR/$dest/queue"
    cursor_file="$ROUTER_DIR/$dest/cursor"

    [ -f "$queue" ] || { echo "(no messages for $dest)"; return; }

    cursor=0
    [ -f "$cursor_file" ] && cursor=$(cat "$cursor_file")
    total=$(wc -l < "$queue" | tr -d ' ')

    if [ "$total" -le "$cursor" ]; then
        echo "(no new messages for $dest)"
        return
    fi

    awk -v start="$((cursor+1))" 'NR>=start {print}' "$queue"
    printf '%s' "$total" > "$cursor_file"
}

# ---------------------------------------------------------------------------
# Dispatch an incoming message by inspecting its prefix/type
# ---------------------------------------------------------------------------
# Message format:   <type>:<payload>
#   e.g.  "intent:list /etc"  "event:boot_complete"  "chat:hello world"
router_dispatch() {
    raw="$*"

    if printf '%s' "$raw" | grep -q ':'; then
        msg_type="${raw%%:*}"
        payload="${raw#*:}"
    else
        msg_type="chat"
        payload="$raw"
    fi

    ts=$(date '+%Y-%m-%dT%H:%M:%SZ')
    echo "[$ts] [dispatch] type=$msg_type payload=$payload" >> "$ROUTER_LOG"

    case "$msg_type" in
        intent)
            if command -v intent_route >/dev/null 2>&1; then
                intent_route "$payload"
            else
                echo "[router] intent module not loaded"
            fi
            ;;
        event)
            router_send "events" "$payload"
            ;;
        chat)
            if command -v llm_query >/dev/null 2>&1; then
                llm_query "$payload"
            else
                echo "[router] chat: $payload"
            fi
            ;;
        sysctl)
            router_send "kernel" "$payload"
            ;;
        bot)
            router_send "bots" "$payload"
            ;;
        *)
            echo "[router] unrouted type '$msg_type': $payload" >&2
            ;;
    esac
}

# ---------------------------------------------------------------------------
# Register default destinations
# ---------------------------------------------------------------------------
# Called once when the module is first sourced.
_router_init_defaults() {
    # shell → intent engine
    router_register "shell"  "intent_route"   2>/dev/null || true
    # events → bus broadcast
    router_register "events" "bus_broadcast"  2>/dev/null || true
}
_router_init_defaults
