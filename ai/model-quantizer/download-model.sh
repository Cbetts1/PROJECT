#!/bin/bash
# ai/model-quantizer/download-model.sh
# Downloads a quantized GGUF model from Hugging Face.
#
# Usage:
#   bash ai/model-quantizer/download-model.sh [--model NAME] [--quant TYPE]
#
# Examples:
#   bash ai/model-quantizer/download-model.sh --model llama-3.2-3b-instruct --quant Q4_K_M
#   bash ai/model-quantizer/download-model.sh --model llama-3.1-7b-instruct --quant Q4_K_M

set -euo pipefail

AIOS_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
MODEL_DIR="$AIOS_ROOT/llama_model"
CONFIG_FILE="$AIOS_ROOT/config/llama-settings.conf"

MODEL="llama-3.2-3b-instruct"
QUANT="Q4_K_M"

log()  { echo "[download-model] $*"; }
die()  { echo "[download-model] ERROR: $*" >&2; exit 1; }

while [[ $# -gt 0 ]]; do
    case "$1" in
        --model) MODEL="$2"; shift 2 ;;
        --quant) QUANT="$2"; shift 2 ;;
        *) die "Unknown argument: $1" ;;
    esac
done

mkdir -p "$MODEL_DIR"

# ── Resolve HuggingFace repo and filename ─────────────────────────────────────
case "$MODEL" in
    llama-3.2-1b-instruct)
        HF_REPO="bartowski/Llama-3.2-1B-Instruct-GGUF"
        FILENAME="Llama-3.2-1B-Instruct-${QUANT}.gguf"
        ;;
    llama-3.2-3b-instruct)
        HF_REPO="bartowski/Llama-3.2-3B-Instruct-GGUF"
        FILENAME="Llama-3.2-3B-Instruct-${QUANT}.gguf"
        ;;
    llama-3.1-7b-instruct)
        HF_REPO="bartowski/Meta-Llama-3.1-7B-Instruct-GGUF"
        FILENAME="Meta-Llama-3.1-7B-Instruct-${QUANT}.gguf"
        ;;
    llama-3.1-8b-instruct)
        HF_REPO="bartowski/Meta-Llama-3.1-8B-Instruct-GGUF"
        FILENAME="Meta-Llama-3.1-8B-Instruct-${QUANT}.gguf"
        ;;
    *)
        die "Unknown model: $MODEL. Supported: llama-3.2-1b-instruct, llama-3.2-3b-instruct, llama-3.1-7b-instruct, llama-3.1-8b-instruct"
        ;;
esac

OUTPUT="$MODEL_DIR/$FILENAME"
URL="https://huggingface.co/${HF_REPO}/resolve/main/${FILENAME}"

log "Model  : $MODEL ($QUANT)"
log "Source : $URL"
log "Output : $OUTPUT"

if [[ -f "$OUTPUT" ]]; then
    log "Model already downloaded: $OUTPUT"
else
    if command -v wget >/dev/null 2>&1; then
        wget -c --show-progress -O "$OUTPUT" "$URL"
    elif command -v curl >/dev/null 2>&1; then
        curl -L --progress-bar -o "$OUTPUT" -C - "$URL"
    else
        die "Neither wget nor curl is available."
    fi
    log "Download complete."
fi

# ── Update config ─────────────────────────────────────────────────────────────
if [[ -f "$CONFIG_FILE" ]]; then
    sed -i "s|^MODEL_PATH=.*|MODEL_PATH=$OUTPUT|" "$CONFIG_FILE"
    log "Updated MODEL_PATH in $CONFIG_FILE"
fi

log "Model ready: $OUTPUT ($(du -sh "$OUTPUT" | cut -f1))"
