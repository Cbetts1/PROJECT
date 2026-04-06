#!/usr/bin/env bash
# lib/aura-ai.sh — natural-language AI query dispatch
[[ -n "${_AURA_AI_SH_LOADED:-}" ]] && return 0
_AURA_AI_SH_LOADED=1

# shellcheck source=lib/aura-core.sh
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/aura-core.sh"

# Route the user's natural-language input through the Python AI backend.
# The backend may translate it into a command or return a chat response.
# When AI_BACKEND=llama, tokens are streamed as they arrive.
aura_ai_query() {
    local user_input="$*"
    local stream_flag=""
    if [[ "${AI_BACKEND:-mock}" == "llama" ]]; then
        stream_flag="--stream"
    fi
    python3 "${AIOS_ROOT}/ai/core/ai_backend.py" \
        --input   "${user_input}" \
        --os-root "${OS_ROOT}" \
        --aios-root "${AIOS_ROOT}" \
        ${stream_flag}
}
