#!/usr/bin/env bash
# lib/aura-peer.sh — Peer-to-peer AIOS device networking
#
# Provides functions for discovering, registering, and communicating with
# other AIOS devices on the local network or over a WireGuard VPN.
#
# Peer state is stored in OS_ROOT/mirror/peer/ (one file per peer device).
# The handshake protocol is a lightweight JSON exchange over HTTP.
#
# Functions:
#   aura_peer_announce     — announce this device to local peers
#   aura_peer_discover     — discover AIOS peers via mDNS or subnet sweep
#   aura_peer_list         — list known peers
#   aura_peer_connect <id> — open an SSH tunnel to a peer
#   aura_peer_ping <id>    — ping a specific peer's API

[[ -n "${_AURA_PEER_SH_LOADED:-}" ]] && return 0
_AURA_PEER_SH_LOADED=1

# shellcheck source=lib/aura-core.sh
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/aura-core.sh"

PEER_DIR="${OS_ROOT}/mirror/peer"
PEER_LOG="${OS_ROOT}/var/log/aura-peer.log"
PEER_API_PORT="${AIOS_API_PORT:-8080}"
THIS_DEVICE_ID="${AIOS_DEVICE_ID:-$(hostname 2>/dev/null || echo aios-$(date +%s | tr -d '[:space:]' | rev | cut -c1-6 | rev))}"

mkdir -p "${PEER_DIR}" 2>/dev/null || true

_peer_log() { printf '[%s] [peer] %s\n' "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" "$*" >> "${PEER_LOG}" 2>/dev/null || true; }

# ---------------------------------------------------------------------------
# aura_peer_announce — broadcast this device's presence
# ---------------------------------------------------------------------------
# Writes a JSON identity file and optionally publishes via avahi-publish.
aura_peer_announce() {
    local identity_file="${PEER_DIR}/${THIS_DEVICE_ID}.json"
    local hostname; hostname="$(hostname 2>/dev/null || echo unknown)"
    cat > "${identity_file}" <<JSON
{
  "device_id": "${THIS_DEVICE_ID}",
  "hostname":  "${hostname}",
  "api_port":  ${PEER_API_PORT},
  "aios_version": "1.0.0",
  "announced_at": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
}
JSON
    _peer_log "Announced self as ${THIS_DEVICE_ID} (${hostname}:${PEER_API_PORT})"
    echo "[peer] Announced: ${THIS_DEVICE_ID} on port ${PEER_API_PORT}"
}

# ---------------------------------------------------------------------------
# aura_peer_discover — discover peers via mDNS or subnet scan
# ---------------------------------------------------------------------------
aura_peer_discover() {
    echo "[peer] Discovering AIOS peers ..."
    _peer_log "Starting peer discovery"

    # Method 1: avahi-browse for _aios._tcp
    if command -v avahi-browse &>/dev/null; then
        echo "[peer] Querying mDNS (_aios._tcp) ..."
        local results
        results="$(avahi-browse -r -p -t _aios._tcp 2>/dev/null | grep '^=' || true)"
        if [[ -n "${results}" ]]; then
            echo "${results}" | while IFS=';' read -r _ iface proto name stype domain hostname addr port txt; do
                _aura_peer_register "${name}" "${addr}" "${port}"
            done
        fi
    fi

    # Method 2: check known peers from OS_ROOT/mirror/peer/
    local count=0
    for f in "${PEER_DIR}"/*.json; do
        [[ -f "${f}" ]] || continue
        local id; id="$(basename "${f}" .json)"
        [[ "${id}" == "${THIS_DEVICE_ID}" ]] && continue
        echo "[peer] Known peer: ${id}"
        count=$(( count + 1 ))
    done

    [[ "${count}" -eq 0 ]] && echo "[peer] No peers found."
    _peer_log "Discovery complete (${count} peers)"
}

# ---------------------------------------------------------------------------
# _aura_peer_register — save a discovered peer to the peer directory
# ---------------------------------------------------------------------------
_aura_peer_register() {
    local name="$1" addr="$2" port="$3"
    local peer_file="${PEER_DIR}/${name}.json"
    cat > "${peer_file}" <<JSON
{
  "device_id": "${name}",
  "address":   "${addr}",
  "api_port":  ${port},
  "discovered_at": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
}
JSON
    echo "[peer] Registered: ${name} @ ${addr}:${port}"
    _peer_log "Registered peer ${name} at ${addr}:${port}"
}

# ---------------------------------------------------------------------------
# aura_peer_list — list all known peers
# ---------------------------------------------------------------------------
aura_peer_list() {
    local count=0
    echo "[peer] Known AIOS peers:"
    for f in "${PEER_DIR}"/*.json; do
        [[ -f "${f}" ]] || continue
        local id; id="$(basename "${f}" .json)"
        [[ "${id}" == "${THIS_DEVICE_ID}" ]] && continue
        local addr; addr="$(grep -o '"address": *"[^"]*"' "${f}" 2>/dev/null | cut -d'"' -f4 || echo '?')"
        local port; port="$(grep -o '"api_port": *[0-9]*' "${f}" 2>/dev/null | awk '{print $2}' || echo '?')"
        printf "  %-24s  %s:%s\n" "${id}" "${addr}" "${port}"
        count=$(( count + 1 ))
    done
    [[ "${count}" -eq 0 ]] && echo "  (none)"
    echo "[peer] Total: ${count}"
}

# ---------------------------------------------------------------------------
# aura_peer_ping <device_id> — ping a peer's health endpoint
# ---------------------------------------------------------------------------
aura_peer_ping() {
    local id="${1:-}"
    [[ -z "${id}" ]] && { echo "[peer] Usage: peer.ping <device_id>"; return 1; }
    local peer_file="${PEER_DIR}/${id}.json"
    [[ -f "${peer_file}" ]] || { echo "[peer] Unknown peer: ${id}"; return 1; }

    local addr; addr="$(grep -o '"address": *"[^"]*"' "${peer_file}" 2>/dev/null | cut -d'"' -f4 || echo '')"
    local port; port="$(grep -o '"api_port": *[0-9]*' "${peer_file}" 2>/dev/null | awk '{print $2}' || echo "${PEER_API_PORT}")"
    [[ -z "${addr}" ]] && { echo "[peer] No address for ${id}"; return 1; }

    echo "[peer] Pinging ${id} at ${addr}:${port} ..."
    if command -v curl &>/dev/null; then
        curl -sf --connect-timeout 5 "http://${addr}:${port}/api/v1/health" || \
            echo "[peer] ${id} did not respond"
    else
        echo "[peer] curl not available; using ping ..."
        ping -c 1 "${addr}" 2>/dev/null || echo "[peer] Host unreachable"
    fi
}

# ---------------------------------------------------------------------------
# aura_peer_connect <device_id> — open SSH session to a peer
# ---------------------------------------------------------------------------
aura_peer_connect() {
    local id="${1:-}"
    [[ -z "${id}" ]] && { echo "[peer] Usage: peer.connect <device_id>"; return 1; }
    local peer_file="${PEER_DIR}/${id}.json"
    [[ -f "${peer_file}" ]] || { echo "[peer] Unknown peer: ${id}"; return 1; }
    local addr; addr="$(grep -o '"address": *"[^"]*"' "${peer_file}" 2>/dev/null | cut -d'"' -f4)"
    [[ -z "${addr}" ]] && { echo "[peer] No address for ${id}"; return 1; }
    echo "[peer] Connecting to ${id} (${addr}) via SSH ..."
    ssh "${addr}" -t "bash --login"
}

# Register commands
register_command "peer.announce" "aura_peer_announce"
register_command "peer.discover" "aura_peer_discover"
register_command "peer.list"     "aura_peer_list"
register_command "peer.ping"     "aura_peer_ping"
register_command "peer.connect"  "aura_peer_connect"
