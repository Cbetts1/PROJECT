#!/usr/bin/env bash
# lib/aura-ai.sh — natural-language AI query dispatch
[[ -n "${_AURA_AI_SH_LOADED:-}" ]] && return 0
_AURA_AI_SH_LOADED=1

# shellcheck source=lib/aura-core.sh
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/aura-core.sh"

# Route the user's natural-language input through the Python AI backend.
# The backend may translate it into a command or return a chat response.
aura_ai_query() {
    local user_input="$*"
    if ! command -v python3 &>/dev/null; then
        echo "[AURA] python3 not found — AI backend unavailable." >&2
        echo "[AURA] Install python3 (>=3.10) and re-run install.sh." >&2
        return 1
    fi
    python3 "${AIOS_ROOT}/ai/core/ai_backend.py" \
        --input   "${user_input}" \
        --os-root "${OS_ROOT}" \
        --aios-root "${AIOS_ROOT}"
}
