mod_name="bus"
mod_help="Message bus utilities."

bus_last() {
    tail -n 5 "$OS_ROOT/proc/os.messages" 2>/dev/null
}

bus_count() {
    wc -l "$OS_ROOT/proc/os.messages" 2>/dev/null | awk '{print $1 " messages"}'
}
