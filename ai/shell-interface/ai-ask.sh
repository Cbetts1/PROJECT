#!/bin/bash
# ai/shell-interface/ai-ask.sh
# Send a single prompt to the Llama inference daemon and print the response.
#
# Usage:
#   bash ai/shell-interface/ai-ask.sh "What is the capital of France?"
#   echo "Tell me a joke" | bash ai/shell-interface/ai-ask.sh

set -euo pipefail

AIOS_ROOT="${AIOS_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)}"
CONFIG="$AIOS_ROOT/config/llama-settings.conf"
SOCKET="$AIOS_ROOT/OS/var/run/llama.sock"
LLAMA_CLI="$AIOS_ROOT/ai/llama-integration/bin/llama-cli"

log() { echo "[ai-ask] $*" >&2; }
die() { echo "[ai-ask] ERROR: $*" >&2; exit 1; }

# ── Load config ───────────────────────────────────────────────────────────────
MODEL_PATH=""
CONTEXT_SIZE=2048
THREADS=3
TEMP=0.7
TOP_P=0.9
REPEAT_PENALTY=1.1
LLAMA_CPU_AFFINITY=""

[[ -f "$CONFIG" ]] && . "$CONFIG"

[[ -z "$MODEL_PATH" ]] && die "MODEL_PATH not set in $CONFIG. Run: bash ai/model-quantizer/download-model.sh"
[[ -f "$MODEL_PATH" ]] || die "Model not found: $MODEL_PATH"

# ── Read prompt ───────────────────────────────────────────────────────────────
if [[ $# -gt 0 ]]; then
    PROMPT="$*"
elif [[ ! -t 0 ]]; then
    PROMPT=$(cat)
else
    die "Provide a prompt as argument or via stdin."
fi

# ── Build llama-cli command ───────────────────────────────────────────────────
LLAMA_ARGS=(
    --model "$MODEL_PATH"
    --n-predict 512
    --ctx-size "$CONTEXT_SIZE"
    --threads "$THREADS"
    --temp "$TEMP"
    --top-p "$TOP_P"
    --repeat-penalty "$REPEAT_PENALTY"
    --no-display-prompt
    --log-disable
    -p "$PROMPT"
)

# ── Apply CPU affinity if configured ─────────────────────────────────────────
if [[ -n "$LLAMA_CPU_AFFINITY" ]] && command -v taskset >/dev/null 2>&1; then
    exec taskset -c "$LLAMA_CPU_AFFINITY" "$LLAMA_CLI" "${LLAMA_ARGS[@]}"
else
    exec "$LLAMA_CLI" "${LLAMA_ARGS[@]}"
fi
