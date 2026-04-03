mod_name="intent"
mod_help="Intent engine: classify user input and route to the correct handler."
# © 2026 Chris Betts | AIOSCPU Official | AI-generated, fully legal
#
# Provides:
#   intent_classify  <text>   → prints one of: filesystem process network
#                                memory bridge system chat
#   intent_route     <text>   → executes the most appropriate handler
#   intent_log       <class> <text>
#   intent_history             → prints recent intent log

INTENT_LOG="${OS_ROOT}/var/log/intent.log"
INTENT_STATE="${OS_ROOT}/proc/aura/intent"
mkdir -p "$INTENT_STATE" "$(dirname "$INTENT_LOG")"

# ---------------------------------------------------------------------------
# Intent classification
# ---------------------------------------------------------------------------
# Returns a single lowercase word for the detected intent class.
# Order matters: more specific patterns are checked first.
intent_classify() {
    text="$*"
    lower=$(printf '%s' "$text" | tr '[:upper:]' '[:lower:]')

    # --- Filesystem ---
    case "$lower" in
        ls\ *|list\ *|dir\ *|"ls"|"list"|"dir"|\
        cat\ *|show\ *|read\ *|\
        mkdir\ *|make\ dir\ *|\
        rm\ *|remove\ *|delete\ *|\
        cp\ *|copy\ *|mv\ *|move\ *|rename\ *|\
        find\ *|search\ file*|"where is"*|"find file"*)
            echo "filesystem"; return ;;
    esac

    # --- Process ---
    case "$lower" in
        ps|"list processes"|"show processes"|processes|\
        kill\ *|"kill process"*|\
        start\ *|stop\ *|restart\ *|\
        "what's running"|"what is running")
            echo "process"; return ;;
    esac

    # --- Network ---
    case "$lower" in
        ping\ *|"ping"|ifconfig|"ip addr"|"network"|interfaces|\
        "net status"|"show network"|netinfo|\
        "am i connected"|"check network")
            echo "network"; return ;;
    esac

    # --- Memory ---
    case "$lower" in
        "mem.set"*|"mem.get"*|"mem.list"*|"mem.search"*|\
        "sem.set"*|"sem.get"*|"sem.search"*|\
        "recall"*|"remember"*|"forget"*|\
        "what do you know"*|"what do you remember"*)
            echo "memory"; return ;;
    esac

    # --- Bridge ---
    case "$lower" in
        bridge*|mirror*|\
        "connect to"*|"mount"*|"unmount"*|\
        "detect device"*|ios*|android*|\
        "ssh to"*|"remote"*)
            echo "bridge"; return ;;
    esac

    # --- System/OS control ---
    case "$lower" in
        status|services|"system status"|sysinfo|uptime|disk|\
        "show status"|"os info"|"kernel info"|\
        upgrade|update|install|\
        reboot|shutdown|halt|\
        "mode "*|"set mode"*)
            echo "system"; return ;;
    esac

    # --- Fallback: chat (natural language / AI) ---
    echo "chat"
}

# ---------------------------------------------------------------------------
# Intent routing
# ---------------------------------------------------------------------------
# Looks up the intent class and dispatches to the right aura module.
# Returns 0 if handled, 127 if the intent class has no handler.
intent_route() {
    text="$*"
    class=$(intent_classify "$text")
    intent_log "$class" "$text"
    bus_publish "intent" "class=$class input=$text"

    case "$class" in
        filesystem)
            # Try natural-language → fs command via aura-fs module if loaded
            if command -v aura_fs_dispatch >/dev/null 2>&1; then
                aura_fs_dispatch "$text"
            else
                echo "[intent] filesystem: $text"
            fi
            ;;
        process)
            if command -v aura_proc_dispatch >/dev/null 2>&1; then
                aura_proc_dispatch "$text"
            else
                echo "[intent] process: $text"
            fi
            ;;
        network)
            echo "[intent] network: $text"
            ;;
        memory)
            echo "[intent] memory: $text"
            ;;
        bridge)
            echo "[intent] bridge: $text"
            ;;
        system)
            echo "[intent] system: $text"
            ;;
        chat)
            # Let the LLM handle it
            if command -v llm_query >/dev/null 2>&1; then
                llm_query "$text"
            else
                echo "[intent] chat (no LLM): $text"
            fi
            ;;
        *)
            echo "[intent] unknown class: $class" >&2
            return 127
            ;;
    esac
}

# ---------------------------------------------------------------------------
# Logging
# ---------------------------------------------------------------------------
intent_log() {
    class="$1"; shift
    text="$*"
    ts=$(date '+%Y-%m-%dT%H:%M:%SZ')
    echo "[$ts] class=$class input=$text" >> "$INTENT_LOG"
    # Persist last intent for introspection
    printf '%s' "$class" > "$INTENT_STATE/last_class"
    printf '%s' "$text"  > "$INTENT_STATE/last_input"
}

# ---------------------------------------------------------------------------
# History
# ---------------------------------------------------------------------------
intent_history() {
    n="${1:-20}"
    tail -n "$n" "$INTENT_LOG" 2>/dev/null || echo "(no intent history)"
}
