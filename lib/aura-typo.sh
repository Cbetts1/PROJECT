#!/usr/bin/env bash
# lib/aura-typo.sh — fuzzy command-name correction
[[ -n "${_AURA_TYPO_SH_LOADED:-}" ]] && return 0
_AURA_TYPO_SH_LOADED=1

# shellcheck source=lib/aura-core.sh
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/aura-core.sh"

# Print all known command names, one per line.
aura_known_commands() {
    printf "%s\n" \
        "fs.ls" "fs.cat" "fs.write" "fs.mkdir" "fs.rm" "fs.cp" "fs.mv" "fs.find" \
        "proc.ps" "proc.kill" \
        "net.ping" "net.ifconfig" \
        "sys" "help" "exit" "quit"
}

# Print the best fuzzy suggestion for INPUT, or nothing if no close match.
aura_typo_suggest() {
    local input="$1"
    local candidates
    candidates="$(aura_known_commands | tr '\n' ',')"
    # Strip trailing comma
    candidates="${candidates%,}"
    python3 "${AIOS_ROOT}/ai/core/fuzzy.py" \
        --input "${input}" \
        --candidates "${candidates}"
}
