#!/usr/bin/env bash
# lib/aura-llama.sh — LLaMA inference wrapper
[[ -n "${_AURA_LLAMA_SH_LOADED:-}" ]] && return 0
_AURA_LLAMA_SH_LOADED=1

# shellcheck source=lib/aura-core.sh
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/aura-core.sh"

# Query the AI model.  Backend is selected by AI_BACKEND from aios.conf.
# Falls back to mock when no model/binary is present.
aura_llama_query() {
    local prompt="$1"
    python3 "${AIOS_ROOT}/ai/core/llama_client.py" \
        --backend  "${AI_BACKEND:-mock}" \
        --model-path "${LLAMA_MODEL_PATH:-}" \
        --ctx      "${LLAMA_CTX:-4096}" \
        --threads  "${LLAMA_THREADS:-4}" \
        --prompt   "${prompt}"
}
