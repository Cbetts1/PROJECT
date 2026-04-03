#!/usr/bin/env bash
# lib/aura-typo.sh — fuzzy command-name correction
[[ -n "${_AURA_TYPO_SH_LOADED:-}" ]] && return 0
_AURA_TYPO_SH_LOADED=1

# shellcheck source=lib/aura-core.sh
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/aura-core.sh"

# Print all known command names, one per line.
# Uses the dynamic AIOS_COMMANDS registry when available, supplemented by
# the static built-in list to ensure coverage even before modules are loaded.
aura_known_commands() {
    # Emit all commands registered via register_command (dynamic registry).
    if [[ -n "${AIOS_COMMANDS+x}" ]]; then
        printf "%s\n" "${!AIOS_COMMANDS[@]}"
    fi
    # Always include built-in shell commands that are not in the registry.
    printf "%s\n" "sys" "help" "exit" "quit"
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
