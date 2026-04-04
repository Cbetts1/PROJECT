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
    local model_path="${LLAMA_MODEL_PATH:-}"
    local backend="${AI_BACKEND:-mock}"

    # Autodetect: look for *.gguf in $OS_ROOT/llama_model/ when no valid
    # explicit model path is configured.
    if [[ -z "${model_path}" || ! -f "${model_path}" ]]; then
        local detected=""
        if [[ -d "${OS_ROOT}/llama_model" ]]; then
            while IFS= read -r -d '' f; do
                detected="${f}"
                break
            done < <(find "${OS_ROOT}/llama_model" -maxdepth 1 -name "*.gguf" -print0 2>/dev/null | sort -z)
        fi
        if [[ -n "${detected}" ]]; then
            model_path="${detected}"
            backend="llama"
        else
            echo "AI offline, fallback mode"
            backend="mock"
            model_path=""
        fi
    fi

    python3 "${AIOS_ROOT}/ai/core/llama_client.py" \
        --backend  "${backend}" \
        --model-path "${model_path}" \
        --ctx      "${LLAMA_CTX:-4096}" \
        --threads  "${LLAMA_THREADS:-4}" \
        --prompt   "${prompt}"
}
