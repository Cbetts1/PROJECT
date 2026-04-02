mod_name="bus"
mod_help="Message bus: publish/subscribe via append log + cursor."

BUS_LOG="${OS_ROOT}/var/log/bus.log"
BUS_CURSOR_DIR="${OS_ROOT}/var/service/bus"

bus_publish() {
    channel="${1:-default}"; shift
    msg="$*"
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    mkdir -p "$(dirname "$BUS_LOG")"
    echo "[$timestamp] [$channel] $msg" >> "$BUS_LOG"
}

bus_subscribe() {
    channel="${1:-default}"
    mkdir -p "$BUS_CURSOR_DIR"
    cursor_file="$BUS_CURSOR_DIR/${channel}.cursor"
    [ -f "$cursor_file" ] || echo "0" > "$cursor_file"
    cursor=$(cat "$cursor_file")
    total=$(wc -l < "$BUS_LOG" 2>/dev/null || echo 0)
    if [ "$total" -gt "$cursor" ]; then
        awk -v start="$((cursor+1))" -v chan="$channel" \
            'NR>=start && $0 ~ "\[" chan "\]" {print}' "$BUS_LOG"
        echo "$total" > "$cursor_file"
    fi
}

bus_broadcast() {
    msg="$*"
    bus_publish "broadcast" "$msg"
}

bus_last() {
    n="${1:-5}"
    tail -n "$n" "$BUS_LOG" 2>/dev/null
}

bus_count() {
    wc -l < "$BUS_LOG" 2>/dev/null | awk '{print $1 " messages"}'
}
