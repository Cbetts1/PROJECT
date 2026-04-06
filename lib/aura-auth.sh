#!/usr/bin/env bash
# lib/aura-auth.sh — PAM-style authentication for AIOS-Lite
#
# Provides:
#   authenticate <username> <password>  — verify against OS/etc/shadow
#   auth_check_caps <username> <cap>    — check if user has a capability
#   auth_add_user <username>            — add user interactively
#   auth_passwd <username>              — change a user's password
#
# Shadow file format (OS/etc/shadow):
#   username:SHA256-HASH:salt
#
# Passwords are hashed as: SHA256(salt + password)
# This is a portable implementation using only bash + python3/sha256sum.
# For production hardening, integrate with PAM or system shadow.

[[ -n "${_AURA_AUTH_SH_LOADED:-}" ]] && return 0
_AURA_AUTH_SH_LOADED=1

# shellcheck source=lib/aura-core.sh
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/aura-core.sh"

SHADOW_FILE="${OS_ROOT}/etc/shadow"
PERMS_USERS_DIR="${OS_ROOT}/etc/perms.d/users"

# Ensure shadow and perms dirs exist
mkdir -p "$(dirname "${SHADOW_FILE}")" "${PERMS_USERS_DIR}" 2>/dev/null || true

# ---------------------------------------------------------------------------
# _aura_hash_password <salt> <password> — compute portable password hash
# ---------------------------------------------------------------------------
_aura_hash_password() {
    local salt="$1"
    local password="$2"
    if command -v python3 &>/dev/null; then
        python3 -c "
import hashlib, sys
salt = sys.argv[1]
pw   = sys.argv[2]
print(hashlib.sha256((salt + pw).encode()).hexdigest())
" "${salt}" "${password}"
    elif command -v sha256sum &>/dev/null; then
        printf '%s%s' "${salt}" "${password}" | sha256sum | cut -d' ' -f1
    else
        echo "" # fallback: no hash support
    fi
}

# ---------------------------------------------------------------------------
# _aura_gen_salt — generate a random 16-char hex salt
# ---------------------------------------------------------------------------
_aura_gen_salt() {
    if command -v python3 &>/dev/null; then
        python3 -c "import os; print(os.urandom(8).hex())"
    elif [[ -r /dev/urandom ]]; then
        head -c 8 /dev/urandom | od -An -tx1 | tr -d ' \n' | head -c 16
    else
        date +%s | sha256sum 2>/dev/null | head -c 16 || printf '%016d' "$(date +%s)"
    fi
}

# ---------------------------------------------------------------------------
# authenticate <username> <password>
# Returns 0 on success, 1 on failure
# ---------------------------------------------------------------------------
authenticate() {
    local username="$1"
    local password="$2"

    [[ -f "${SHADOW_FILE}" ]] || {
        audit_log "AUTH_FAIL" "auth" "Shadow file not found"
        return 1
    }

    local line; line="$(grep "^${username}:" "${SHADOW_FILE}" 2>/dev/null || true)"
    if [[ -z "${line}" ]]; then
        audit_log "AUTH_FAIL" "auth" "Unknown user: ${username}"
        return 1
    fi

    local stored_hash salt
    stored_hash="$(echo "${line}" | cut -d: -f2)"
    salt="$(echo "${line}" | cut -d: -f3)"

    local computed_hash
    computed_hash="$(_aura_hash_password "${salt}" "${password}")"

    if [[ "${computed_hash}" == "${stored_hash}" ]]; then
        audit_log "AUTH_OK" "auth" "Authenticated: ${username}"
        return 0
    else
        audit_log "AUTH_FAIL" "auth" "Bad password for: ${username}"
        return 1
    fi
}

# ---------------------------------------------------------------------------
# auth_check_caps <username> <capability>
# Returns 0 if the user holds the requested capability, 1 otherwise
# ---------------------------------------------------------------------------
auth_check_caps() {
    local username="$1"
    local cap="$2"
    local caps_file="${PERMS_USERS_DIR}/${username}.caps"

    # Fall back to operator.caps if no user-specific file
    [[ -f "${caps_file}" ]] || caps_file="${PERMS_USERS_DIR}/operator.caps"
    [[ -f "${caps_file}" ]] || return 1

    # Check for exact match or wildcard (e.g. "fs.*" matches "fs.read")
    local prefix; prefix="${cap%%.*}"
    while IFS= read -r line; do
        [[ -z "${line}" || "${line}" == \#* ]] && continue
        if [[ "${line}" == "${cap}" || "${line}" == "${prefix}.*" || "${line}" == "*" ]]; then
            return 0
        fi
    done < "${caps_file}"

    audit_log "BLOCKED" "caps" "User ${username} missing capability: ${cap}"
    return 1
}

# ---------------------------------------------------------------------------
# auth_add_user <username> — add a new user (prompts for password)
# ---------------------------------------------------------------------------
auth_add_user() {
    local username="$1"
    [[ -z "${username}" ]] && { echo "Usage: auth_add_user <username>" >&2; return 1; }

    if grep -q "^${username}:" "${SHADOW_FILE}" 2>/dev/null; then
        echo "[auth] User '${username}' already exists" >&2
        return 1
    fi

    local password
    read -rs -p "Password for ${username}: " password; echo
    local confirm
    read -rs -p "Confirm password: " confirm; echo
    [[ "${password}" == "${confirm}" ]] || { echo "[auth] Passwords do not match" >&2; return 1; }

    local salt; salt="$(_aura_gen_salt)"
    local hash; hash="$(_aura_hash_password "${salt}" "${password}")"

    echo "${username}:${hash}:${salt}" >> "${SHADOW_FILE}"
    chmod 600 "${SHADOW_FILE}"

    # Create default user caps (guest level)
    if [[ ! -f "${PERMS_USERS_DIR}/${username}.caps" ]]; then
        cp "${PERMS_USERS_DIR}/guest.caps" "${PERMS_USERS_DIR}/${username}.caps" 2>/dev/null || true
    fi

    audit_log "USER_ADDED" "auth" "Added user: ${username}"
    echo "[auth] User '${username}' created."
}

# ---------------------------------------------------------------------------
# auth_passwd <username> — change a user's password
# ---------------------------------------------------------------------------
auth_passwd() {
    local username="$1"
    [[ -z "${username}" ]] && { echo "Usage: auth_passwd <username>" >&2; return 1; }
    grep -q "^${username}:" "${SHADOW_FILE}" 2>/dev/null || { echo "[auth] User not found: ${username}" >&2; return 1; }

    local password
    read -rs -p "New password for ${username}: " password; echo
    local confirm
    read -rs -p "Confirm: " confirm; echo
    [[ "${password}" == "${confirm}" ]] || { echo "[auth] Passwords do not match" >&2; return 1; }

    local salt; salt="$(_aura_gen_salt)"
    local hash; hash="$(_aura_hash_password "${salt}" "${password}")"

    # Update shadow file
    local tmp; tmp="$(mktemp)"
    grep -v "^${username}:" "${SHADOW_FILE}" > "${tmp}" || true
    echo "${username}:${hash}:${salt}" >> "${tmp}"
    mv "${tmp}" "${SHADOW_FILE}"
    chmod 600 "${SHADOW_FILE}"

    audit_log "PASSWD_CHANGED" "auth" "Password changed for: ${username}"
    echo "[auth] Password updated for '${username}'."
}

export -f authenticate auth_check_caps auth_add_user auth_passwd 2>/dev/null || true
