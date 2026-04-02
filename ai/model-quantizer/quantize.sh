#!/bin/bash
# ai/model-quantizer/quantize.sh
# Converts a full-precision model to GGUF quantized format using llama.cpp tools.
#
# Usage:
#   bash ai/model-quantizer/quantize.sh \
#     --input  /path/to/model/ \
#     --output llama_model/model.Q4_K_M.gguf \
#     --type   Q4_K_M

set -euo pipefail

AIOS_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
LLAMA_DIR="$AIOS_ROOT/ai/llama-integration/llama.cpp"

INPUT=""
OUTPUT=""
QUANT_TYPE="Q4_K_M"

log() { echo "[quantize] $*"; }
die() { echo "[quantize] ERROR: $*" >&2; exit 1; }

while [[ $# -gt 0 ]]; do
    case "$1" in
        --input)  INPUT="$2";      shift 2 ;;
        --output) OUTPUT="$2";     shift 2 ;;
        --type)   QUANT_TYPE="$2"; shift 2 ;;
        *) die "Unknown argument: $1" ;;
    esac
done

[[ -z "$INPUT" ]]  && die "--input is required"
[[ -z "$OUTPUT" ]] && die "--output is required"

CONVERT_SCRIPT="$LLAMA_DIR/convert_hf_to_gguf.py"
QUANTIZE_BIN="$LLAMA_DIR/build/bin/llama-quantize"

[[ -f "$CONVERT_SCRIPT" ]] || die "llama.cpp not built. Run: bash ai/llama-integration/build.sh"
[[ -f "$QUANTIZE_BIN" ]]   || die "llama-quantize not found. Run: bash ai/llama-integration/build.sh"

# ── Step 1: Convert to f16 GGUF ───────────────────────────────────────────────
F16_OUT="${OUTPUT%.gguf}-f16.gguf"
log "Converting to F16 GGUF: $F16_OUT"
python3 "$CONVERT_SCRIPT" "$INPUT" --outfile "$F16_OUT" --outtype f16

# ── Step 2: Quantize ──────────────────────────────────────────────────────────
log "Quantizing to $QUANT_TYPE: $OUTPUT"
"$QUANTIZE_BIN" "$F16_OUT" "$OUTPUT" "$QUANT_TYPE"

log "Cleaning up F16 intermediate..."
rm -f "$F16_OUT"

SIZE=$(du -sh "$OUTPUT" | cut -f1)
log "Done: $OUTPUT ($SIZE)"
