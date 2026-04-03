#!/usr/bin/env bash
# lib/aura-net.sh — network commands
[[ -n "${_AURA_NET_SH_LOADED:-}" ]] && return 0
_AURA_NET_SH_LOADED=1

# shellcheck source=lib/aura-core.sh
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/aura-core.sh"

aura_net_ping() {
    local host="${1:-8.8.8.8}"
    ping -c 4 "${host}"
}

aura_net_ifconfig() {
    if command -v ip >/dev/null 2>&1; then
        ip addr show
    elif command -v ifconfig >/dev/null 2>&1; then
        ifconfig
    else
        echo "[net] Neither 'ip' nor 'ifconfig' found" >&2; return 1
    fi
}

register_command "net.ping"     "aura_net_ping"
register_command "net.ifconfig" "aura_net_ifconfig"
