#!/usr/bin/env bash
# lib/aura-fs.sh — OS_ROOT-isolated filesystem commands
[[ -n "${_AURA_FS_SH_LOADED:-}" ]] && return 0
_AURA_FS_SH_LOADED=1

# shellcheck source=lib/aura-core.sh
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/aura-core.sh"

aura_fs_ls() {
    local target="${1:-.}"
    local resolved
    resolved="$(osroot_resolve "${target}")" || return 1
    ls -la -- "${resolved}"
}

aura_fs_cat() {
    if [[ $# -lt 1 || -z "${1:-}" ]]; then
        echo "Usage: fs.cat <path>" >&2; return 1
    fi
    local resolved
    resolved="$(osroot_resolve "$1")" || return 1
    cat -- "${resolved}"
}

aura_fs_write() {
    if [[ $# -lt 2 ]]; then
        echo "Usage: fs.write <path> <text...>" >&2; return 1
    fi
    local target="$1"; shift
    local resolved
    resolved="$(osroot_resolve "${target}")" || return 1
    mkdir -p "$(dirname "${resolved}")"
    printf "%s\n" "$*" > "${resolved}"
    echo "[fs] Written to ${target}"
}

aura_fs_mkdir() {
    if [[ $# -lt 1 || -z "${1:-}" ]]; then
        echo "Usage: fs.mkdir <path>" >&2; return 1
    fi
    local resolved
    resolved="$(osroot_resolve "$1")" || return 1
    mkdir -p -- "${resolved}"
    echo "[fs] Created ${1}"
}

aura_fs_rm() {
    if [[ $# -lt 1 || -z "${1:-}" ]]; then
        echo "Usage: fs.rm <path>" >&2; return 1
    fi
    local resolved
    resolved="$(osroot_resolve "$1")" || return 1
    # Refuse to remove OS_ROOT itself.
    if [[ "${resolved}" == "${OS_ROOT}" ]]; then
        echo "[fs] Refusing to remove OS_ROOT root" >&2; return 1
    fi
    rm -rf -- "${resolved}"
    echo "[fs] Removed ${1}"
}

aura_fs_cp() {
    if [[ $# -lt 2 ]]; then
        echo "Usage: fs.cp <src> <dest>" >&2; return 1
    fi
    local src_r dest_r
    src_r="$(osroot_resolve "$1")" || return 1
    dest_r="$(osroot_resolve "$2")" || return 1
    mkdir -p "$(dirname "${dest_r}")"
    cp -r -- "${src_r}" "${dest_r}"
    echo "[fs] Copied ${1} -> ${2}"
}

aura_fs_mv() {
    if [[ $# -lt 2 ]]; then
        echo "Usage: fs.mv <src> <dest>" >&2; return 1
    fi
    local src_r dest_r
    src_r="$(osroot_resolve "$1")" || return 1
    dest_r="$(osroot_resolve "$2")" || return 1
    mkdir -p "$(dirname "${dest_r}")"
    mv -- "${src_r}" "${dest_r}"
    echo "[fs] Moved ${1} -> ${2}"
}

aura_fs_find() {
    local target="${1:-.}"; shift || true
    local resolved
    resolved="$(osroot_resolve "${target}")" || return 1
    find "${resolved}" "$@"
}

register_command "fs.ls"    "aura_fs_ls"
register_command "fs.cat"   "aura_fs_cat"
register_command "fs.write" "aura_fs_write"
register_command "fs.mkdir" "aura_fs_mkdir"
register_command "fs.rm"    "aura_fs_rm"
register_command "fs.cp"    "aura_fs_cp"
register_command "fs.mv"    "aura_fs_mv"
register_command "fs.find"  "aura_fs_find"
