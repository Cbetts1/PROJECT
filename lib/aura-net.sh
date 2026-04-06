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

# ---------------------------------------------------------------------------
# vpn_up() — Bring up the WireGuard VPN tunnel
# ---------------------------------------------------------------------------
# Usage: vpn_up [interface]   (default: wg-aura, or $AURA_VPN_IFACE)
#
vpn_up() {
    _aura_net_offline_check || return 1
    local iface="${1:-${AURA_VPN_IFACE:-wg-aura}}"
    local conf_dir="${OS_ROOT}/etc/aura/vpn"
    local conf="${conf_dir}/${iface}.conf"
    if [[ ! -f "${conf}" ]]; then
        echo "[net] VPN config not found: ${conf}" >&2
        return 1
    fi
    if ! command -v wg-quick &>/dev/null; then
        echo "[net] wg-quick not found — WireGuard not installed" >&2
        return 1
    fi
    wg-quick up "${conf}"
}

# ---------------------------------------------------------------------------
# vpn_down() — Bring down the WireGuard VPN tunnel
# ---------------------------------------------------------------------------
# Usage: vpn_down [interface]
#
vpn_down() {
    local iface="${1:-${AURA_VPN_IFACE:-wg-aura}}"
    local conf="${OS_ROOT}/etc/aura/vpn/${iface}.conf"
    if command -v wg-quick &>/dev/null && [[ -f "${conf}" ]]; then
        wg-quick down "${conf}"
    else
        echo "[net] Nothing to bring down (wg-quick not found or config missing)" >&2
    fi
}

# ---------------------------------------------------------------------------
# vpn_status() — Show WireGuard interface status
# ---------------------------------------------------------------------------
vpn_status() {
    local iface="${1:-${AURA_VPN_IFACE:-wg-aura}}"
    if command -v wg &>/dev/null; then
        wg show "${iface}" 2>/dev/null || echo "[net] VPN interface ${iface} not active"
    else
        echo "[net] wg (WireGuard tools) not found"
    fi
}

register_command "net.vpn.up"     "vpn_up"
register_command "net.vpn.down"   "vpn_down"
register_command "net.vpn.status" "vpn_status"
