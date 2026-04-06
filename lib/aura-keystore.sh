#!/usr/bin/env bash
# lib/aura-keystore.sh — Android Keystore integration for AIOS-Lite
#
# Delegates key operations to the Android Keystore via ADB when running
# under Termux on a physical Android device.  Falls back gracefully to
# in-process key material on non-Android hosts.
#
# Functions:
#   ks_generate <alias>         — generate a new key pair in the keystore
#   ks_sign <alias> <data>      — sign base64-encoded data with alias key
#   ks_verify <alias> <data> <sig>  — verify a signature
#   ks_list                     — list all aliases in the keystore
#   ks_delete <alias>           — delete a key alias
#
# Environment:
#   AURA_KS_ALIAS   — default key alias  (default: aura-master)
#   ADB_DEVICE      — adb device serial  (optional)

[[ -n "${_AURA_KEYSTORE_SH_LOADED:-}" ]] && return 0
_AURA_KEYSTORE_SH_LOADED=1

# shellcheck source=lib/aura-core.sh
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/aura-core.sh"

AURA_KS_ALIAS="${AURA_KS_ALIAS:-aura-master}"
_KS_LOG="${OS_ROOT}/var/log/aura-keystore.log"

_ks_log() { printf '[%s] [keystore] %s\n' "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" "$*" >> "${_KS_LOG}" 2>/dev/null || true; }

# ---------------------------------------------------------------------------
# _ks_mode — detect runtime environment
# Returns "adb" (Termux + ADB), "termux" (native Termux), or "local"
# ---------------------------------------------------------------------------
_ks_mode() {
    if command -v adb &>/dev/null && adb ${ADB_DEVICE:+-s "${ADB_DEVICE}"} devices 2>/dev/null | grep -q 'device$'; then
        echo "adb"
    elif [[ -d /data/data/com.termux ]] || [[ -n "${TERMUX_VERSION:-}" ]]; then
        echo "termux"
    else
        echo "local"
    fi
}

# ---------------------------------------------------------------------------
# _adb_ks <subcmd> [args] — run keystore command via adb shell
# ---------------------------------------------------------------------------
_adb_ks() {
    local args=("adb")
    [[ -n "${ADB_DEVICE:-}" ]] && args+=(-s "${ADB_DEVICE}")
    args+=(shell cmd keystore "$@")
    "${args[@]}" 2>/dev/null
}

# ---------------------------------------------------------------------------
# ks_generate <alias>
# ---------------------------------------------------------------------------
ks_generate() {
    local alias="${1:-${AURA_KS_ALIAS}}"
    local mode; mode="$(_ks_mode)"
    _ks_log "generate alias=${alias} mode=${mode}"

    case "${mode}" in
        adb)
            _adb_ks generate_key "${alias}" EC secp256r1 &&
                echo "[keystore] Generated key: ${alias} (Android Keystore via ADB)" ||
                echo "[keystore] ADB key generation failed"
            ;;
        termux)
            # Termux: use Android system key generation if available
            if command -v termux-keystore &>/dev/null; then
                termux-keystore generate "${alias}"
            else
                echo "[keystore] termux-keystore not available; key generated in file store"
                _ks_gen_file "${alias}"
            fi
            ;;
        local)
            _ks_gen_file "${alias}"
            ;;
    esac
}

# ---------------------------------------------------------------------------
# _ks_gen_file <alias> — fallback: generate key file in OS_ROOT/etc/aura/keys/
# ---------------------------------------------------------------------------
_ks_gen_file() {
    local alias="$1"
    local key_dir="${OS_ROOT}/etc/aura/keys"
    mkdir -p "${key_dir}" && chmod 700 "${key_dir}"
    local key_file="${key_dir}/${alias}.key"
    if command -v openssl &>/dev/null; then
        openssl genpkey -algorithm EC -pkeyopt ec_paramgen_curve:P-256 \
            -out "${key_file}" 2>/dev/null
        chmod 600 "${key_file}"
        echo "[keystore] Generated EC P-256 key: ${key_file}"
    else
        # Last resort: random bytes as a symmetric key
        python3 -c "import os; open('${key_file}', 'wb').write(os.urandom(32))"
        chmod 600 "${key_file}"
        echo "[keystore] Generated 256-bit random key: ${key_file}"
    fi
}

# ---------------------------------------------------------------------------
# ks_sign <alias> <base64-data>
# ---------------------------------------------------------------------------
ks_sign() {
    local alias="${1:-${AURA_KS_ALIAS}}"
    local data="${2:-}"
    local mode; mode="$(_ks_mode)"
    _ks_log "sign alias=${alias} mode=${mode}"

    case "${mode}" in
        adb)
            echo "${data}" | _adb_ks sign "${alias}" SHA256withECDSA || \
                echo "[keystore] ADB sign failed"
            ;;
        termux)
            if command -v termux-keystore &>/dev/null; then
                echo "${data}" | termux-keystore sign "${alias}"
            else
                echo "[keystore] termux-keystore not available"
            fi
            ;;
        local)
            local key_file="${OS_ROOT}/etc/aura/keys/${alias}.key"
            if [[ -f "${key_file}" ]] && command -v openssl &>/dev/null; then
                echo "${data}" | base64 -d | \
                    openssl dgst -sha256 -sign "${key_file}" | base64
            else
                echo "[keystore] Local key or openssl not found for alias: ${alias}"
            fi
            ;;
    esac
}

# ---------------------------------------------------------------------------
# ks_list — list all key aliases
# ---------------------------------------------------------------------------
ks_list() {
    local mode; mode="$(_ks_mode)"
    case "${mode}" in
        adb)    _adb_ks list ;;
        termux) command -v termux-keystore &>/dev/null && termux-keystore list || \
                    ls "${OS_ROOT}/etc/aura/keys/" 2>/dev/null ;;
        local)  ls "${OS_ROOT}/etc/aura/keys/" 2>/dev/null || echo "(no keys)" ;;
    esac
}

# ---------------------------------------------------------------------------
# ks_delete <alias>
# ---------------------------------------------------------------------------
ks_delete() {
    local alias="${1:-${AURA_KS_ALIAS}}"
    local mode; mode="$(_ks_mode)"
    _ks_log "delete alias=${alias} mode=${mode}"
    case "${mode}" in
        adb)    _adb_ks delete "${alias}" ;;
        termux) command -v termux-keystore &>/dev/null && termux-keystore delete "${alias}" || \
                    rm -f "${OS_ROOT}/etc/aura/keys/${alias}.key" ;;
        local)  rm -f "${OS_ROOT}/etc/aura/keys/${alias}.key"
                echo "[keystore] Deleted: ${alias}" ;;
    esac
}

register_command "ks.generate" "ks_generate"
register_command "ks.sign"     "ks_sign"
register_command "ks.list"     "ks_list"
register_command "ks.delete"   "ks_delete"
