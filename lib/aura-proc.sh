#!/usr/bin/env bash
# lib/aura-proc.sh — process inspection commands
[[ -n "${_AURA_PROC_SH_LOADED:-}" ]] && return 0
_AURA_PROC_SH_LOADED=1

# shellcheck source=lib/aura-core.sh
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/aura-core.sh"

aura_proc_ps() {
    ps aux | head -n 50
}

aura_proc_kill() {
    if [[ $# -lt 1 || -z "${1:-}" ]]; then
        echo "Usage: proc.kill <pid>" >&2; return 1
    fi
    local pid="$1"
    if ! [[ "${pid}" =~ ^[0-9]+$ ]]; then
        echo "[proc] Invalid PID: ${pid}" >&2; return 1
    fi
    kill "${pid}"
    echo "[proc] Sent SIGTERM to PID ${pid}"
}

register_command "proc.ps"   "aura_proc_ps"
register_command "proc.kill" "aura_proc_kill"
