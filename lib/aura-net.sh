#!/usr/bin/env bash
# lib/aura-net.sh — network commands
[[ -n "${_AURA_NET_SH_LOADED:-}" ]] && return 0
_AURA_NET_SH_LOADED=1

# shellcheck source=lib/aura-core.sh
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/aura-core.sh"

# Check if offline mode is enabled (Level 11)
_aura_net_offline_check() {
    if [[ "${OFFLINE_MODE:-0}" == "1" ]]; then
        echo "[OFFLINE] Network disabled" >&2
        return 1
    fi
    return 0
}

aura_net_ping() {
    _aura_net_offline_check || return 1
    local host="${1:-8.8.8.8}"
    ping -c 4 "${host}"
}

aura_net_ifconfig() {
    # ifconfig is local-only, no offline check needed
    if command -v ip >/dev/null 2>&1; then
        ip addr show
    elif command -v ifconfig >/dev/null 2>&1; then
        ifconfig
    else
        echo "[net] Neither 'ip' nor 'ifconfig' found" >&2; return 1
    fi
}

# Additional network operations with offline guard
aura_net_curl() {
    _aura_net_offline_check || return 1
    curl "$@"
}

aura_net_wget() {
    _aura_net_offline_check || return 1
    wget "$@"
}

register_command "net.ping"     "aura_net_ping"
register_command "net.ifconfig" "aura_net_ifconfig"
