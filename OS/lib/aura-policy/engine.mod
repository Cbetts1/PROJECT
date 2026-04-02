policy_match() {
    hook="$1"
    payload="$2"

    while read -r line; do
        case "$line" in ""|\#*) continue ;; esac

        # Parse rule
        when=$(echo "$line" | awk '{print $2}')
        pattern=$(echo "$line" | awk '{print $3}')
        action=$(echo "$line" | awk -F'=> ' '{print $2}')

        # Match hook
        [ "$when" = "$hook" ] || continue

        # Match payload
        if [ "$pattern" = "any" ] || echo "$payload" | grep -q "$pattern"; then
            echo "$action"
        fi
    done < "$OS_ROOT/etc/aura/policy.rules"
}

policy_dispatch() {
    hook="$1"
    payload="$2"

    for act in $(policy_match "$hook" "$payload"); do
        if command -v "$act" >/dev/null 2>&1; then
            "$act" "$payload"
        else
            echo "[policy] Unknown action: $act"
        fi
    done
}
