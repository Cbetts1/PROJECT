#!/usr/bin/env bash
# lib/aura-core.sh — AIOS core library
# Include guard: safe to source multiple times.
[[ -n "${_AURA_CORE_SH_LOADED:-}" ]] && return 0
_AURA_CORE_SH_LOADED=1

set -o errexit
set -o pipefail
set -o nounset

# AIOS_ROOT: absolute path to the project root (one level above lib/).
AIOS_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Load configuration (sets OS_ROOT, REAL_SHELL, AI_BACKEND, log paths, etc.)
if [[ -f "${AIOS_ROOT}/etc/aios.conf" ]]; then
    # shellcheck source=/dev/null
    . "${AIOS_ROOT}/etc/aios.conf"
else
    echo "WARNING: ${AIOS_ROOT}/etc/aios.conf not found; using built-in defaults" >&2
    OS_ROOT="${AIOS_ROOT}/os_root"
    REAL_SHELL="/bin/bash"
    AIOS_LOG_FILE="${AIOS_ROOT}/var/log/aios.log"
    HEARTBEAT_LOG_FILE="${AIOS_ROOT}/var/log/heartbeat.log"
    HEARTBEAT_INTERVAL_SEC=5
    HEARTBEAT_TARGETS="aios"
fi

# Ensure required directories exist.
mkdir -p "${OS_ROOT}" "${AIOS_ROOT}/var/log" "${AIOS_ROOT}/var/run"

# ---------------------------------------------------------------------------
# Logging
# ---------------------------------------------------------------------------
log() {
    local level="$1"; shift
    local ts
    ts="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
    printf '[%s] [%s] %s\n' "${ts}" "${level}" "$*" | tee -a "${AIOS_LOG_FILE}"
}

# Structured JSON logging for telemetry and analysis
# Usage: log_structured "INFO" "aura-core" "message here" ["optional_extra_json"]
log_structured() {
    local level="$1"
    local component="$2"
    local msg="$3"
    local extra="${4:-}"
    local ts
    ts="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
    
    # Escape special characters in message for JSON
    local escaped_msg
    escaped_msg=$(printf '%s' "$msg" | sed 's/\\/\\\\/g; s/"/\\"/g; s/	/\\t/g' | tr '\n' ' ')
    
    local json="{\"ts\":\"${ts}\",\"level\":\"${level}\",\"component\":\"${component}\",\"msg\":\"${escaped_msg}\""
    
    if [ -n "$extra" ]; then
        json="${json},${extra}"
    fi
    
    json="${json}}"
    
    echo "$json" >> "${AIOS_LOG_FILE}"
}

die() {
    log "ERROR" "$*"
    exit 1
}

# ---------------------------------------------------------------------------
# Command registry (associative array: name -> function)
# ---------------------------------------------------------------------------
declare -A AIOS_COMMANDS

register_command() {
    local name="$1"
    local func="$2"
    AIOS_COMMANDS["${name}"]="${func}"
}

# Returns 0 if the command was found and executed, 127 otherwise.
run_command() {
    local name="$1"; shift || true
    if [[ -n "${AIOS_COMMANDS[${name}]:-}" ]]; then
        "${AIOS_COMMANDS[${name}]}" "$@"
        return 0
    fi
    return 127
}

# ---------------------------------------------------------------------------
# OS_ROOT path resolver — rejects any path that escapes the jail.
# Sets stdout to the resolved absolute path; returns 1 on violation.
# ---------------------------------------------------------------------------
osroot_resolve() {
    local path="$1"

    # Chroot-style semantics matching filesystem.py:
    #   - Absolute paths (starting with /) have their leading / stripped and
    #     are re-joined under OS_ROOT, so /etc/passwd → OS_ROOT/etc/passwd.
    #   - Relative paths are joined under OS_ROOT directly.
    # This means no path can ever escape the jail, even with ../ traversal.
    if [[ "${path}" == /* ]]; then
        path="${OS_ROOT}${path}"
    else
        path="${OS_ROOT}/${path}"
    fi

    # Resolve symlinks and .. components.
    local resolved
    if resolved="$(readlink -f "${path}" 2>/dev/null)"; then
        : # resolved is set
    elif resolved="$(python3 -c "import os, sys; print(os.path.realpath(sys.argv[1]))" "${path}" 2>/dev/null)"; then
        : # Python fallback
    else
        echo "[AIOS] Failed to resolve path: ${path}" >&2
        return 1
    fi

    # Final check: resolved path must still be inside OS_ROOT.
    case "${resolved}" in
        "${OS_ROOT}"|${OS_ROOT}/*)
            echo "${resolved}"
            return 0
            ;;
        *)
            echo "[AIOS] Access denied: '${1}' resolves outside OS_ROOT (${OS_ROOT})" >&2
            return 1
            ;;
    esac
}
