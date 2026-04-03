# Aura LLM Module - llama.cpp wrapper with rule-based fallback
# Source this file to get: llm_query, llm_available, llm_prompt_build,
#                           llm_model, llm_thermal_ok
#
# Honours config/aios.conf and config/llama-settings.conf when present.

# Apply llama-settings.conf if it lives alongside the repo root
_AIOS_ROOT="${AIOS_HOME:-$(cd "$OS_ROOT/.." 2>/dev/null && pwd)}"
[ -f "$_AIOS_ROOT/config/llama-settings.conf" ] && \
    . "$_AIOS_ROOT/config/llama-settings.conf" 2>/dev/null

LLM_MODEL_DIR="${LLM_MODEL_DIR:-${OS_ROOT}/llama_model}"
LLM_CONTEXT_FILE="${OS_ROOT}/proc/aura/context/window"
LLM_HISTORY_FILE="${OS_ROOT}/var/log/llm.history"
LLM_MAX_TOKENS="${LLAMA_N_PREDICT:-${LLM_MAX_TOKENS:-256}}"
LLM_TEMPERATURE="${LLAMA_TEMP:-${LLM_TEMPERATURE:-0.7}}"
LLM_CTX_SIZE="${LLAMA_CTX_SIZE:-2048}"
LLM_THREADS="${LLAMA_THREADS:-3}"
LLAMA_CPU_AFFINITY="${LLAMA_CPU_AFFINITY:-}"
LLAMA_THERMAL_LIMIT="${LLAMA_THERMAL_LIMIT:-68}"
LLAMA_THERMAL_SENSOR="${LLAMA_THERMAL_SENSOR:-/sys/class/thermal/thermal_zone0/temp}"
DEVICE_RAM_VARIANT="${DEVICE_RAM_VARIANT:-}"
LLM_MODEL_8GB="${LLM_MODEL_8GB:-llama-3-8b-instruct.Q4_K_M.gguf}"
LLM_MODEL_6GB="${LLM_MODEL_6GB:-llama-3-3b-instruct.Q4_K_M.gguf}"

# ---------------------------------------------------------------------------
# llm_available — locate a working llama binary
# ---------------------------------------------------------------------------
llm_available() {
    for bin in llama-cli llama.cpp llama main; do
        if command -v "$bin" >/dev/null 2>&1; then
            echo "$bin"
            return 0
        fi
    done
    for bin in "$OS_ROOT/bin/llama-cli" "$OS_ROOT/bin/llama" "$OS_ROOT/bin/llama.cpp"; do
        if [ -x "$bin" ]; then
            echo "$bin"
            return 0
        fi
    done
    return 1
}

# ---------------------------------------------------------------------------
# llm_detect_ram — auto-detect device RAM variant ("6GB" or "8GB")
# ---------------------------------------------------------------------------
llm_detect_ram() {
    if [ -n "$DEVICE_RAM_VARIANT" ]; then
        echo "$DEVICE_RAM_VARIANT"
        return 0
    fi
    if [ -f /proc/meminfo ]; then
        total_kb=$(awk '/^MemTotal:/ {print $2}' /proc/meminfo 2>/dev/null)
        # > 7 GB in kB → 8 GB device
        if [ -n "$total_kb" ] && [ "$total_kb" -gt 7000000 ] 2>/dev/null; then
            echo "8GB"
        else
            echo "6GB"
        fi
    else
        echo "6GB"
    fi
}

# ---------------------------------------------------------------------------
# llm_model — find the best available model file
# ---------------------------------------------------------------------------
llm_model() {
    # 1. Try RAM-appropriate preferred model
    ram=$(llm_detect_ram)
    if [ "$ram" = "8GB" ]; then
        preferred="$LLM_MODEL_8GB"
    else
        preferred="$LLM_MODEL_6GB"
    fi

    if [ -f "$LLM_MODEL_DIR/$preferred" ]; then
        echo "$LLM_MODEL_DIR/$preferred"
        return 0
    fi

    # 2. Fall back to any .gguf or .bin in model dir
    for ext in gguf bin; do
        model=$(find "$LLM_MODEL_DIR" -maxdepth 2 -name "*.$ext" 2>/dev/null | head -1)
        [ -n "$model" ] && { echo "$model"; return 0; }
    done
    return 1
}

# ---------------------------------------------------------------------------
# llm_thermal_ok — return 0 if device temperature is within safe limits
# ---------------------------------------------------------------------------
llm_thermal_ok() {
    sensor="$LLAMA_THERMAL_SENSOR"
    limit="$LLAMA_THERMAL_LIMIT"
    [ -f "$sensor" ] || return 0      # no sensor = assume safe
    raw=$(cat "$sensor" 2>/dev/null)
    [ -z "$raw" ] && return 0
    # Most Linux thermal zones report milli-Celsius; convert to °C
    temp_c=$((raw / 1000))
    if [ "$temp_c" -ge "$limit" ] 2>/dev/null; then
        echo "[llm] WARNING: device temperature ${temp_c}°C ≥ limit ${limit}°C — pausing inference" >&2
        return 1
    fi
    return 0
}

# ---------------------------------------------------------------------------
# llm_prompt_build — construct a context-aware prompt
# ---------------------------------------------------------------------------
llm_prompt_build() {
    user_input="$*"
    os_name=$(awk -F'"' '/OS_NAME/ {print $2}' "$OS_ROOT/proc/os.identity" 2>/dev/null)
    os_name="${os_name:-AIOS-Lite}"

    printf 'You are %s, an intelligent AI operating system. You help the user manage their system, answer questions, and bridge to other devices.\n\n' "$os_name"

    if [ -f "$LLM_CONTEXT_FILE" ] && [ -s "$LLM_CONTEXT_FILE" ]; then
        echo "Recent context:"
        tail -n 10 "$LLM_CONTEXT_FILE" | sed 's/^/  /'
        echo
    fi

    if [ -f "$OS_ROOT/etc/aura/memory.index" ]; then
        matches=$(grep -i "$(echo "$user_input" | awk '{print $1}')" \
                  "$OS_ROOT/etc/aura/memory.index" 2>/dev/null | head -3)
        if [ -n "$matches" ]; then
            echo "Relevant memory:"
            echo "$matches" | sed 's/^/  /'
            echo
        fi
    fi

    echo "User: $user_input"
    echo "Assistant:"
}

# ---------------------------------------------------------------------------
# llm_query — run inference or fall back to rule-based response
# ---------------------------------------------------------------------------
llm_query() {
    input="$*"
    mkdir -p "$(dirname "$LLM_HISTORY_FILE")"

    llm_bin=$(llm_available)
    model=$(llm_model)

    if [ -n "$llm_bin" ] && [ -n "$model" ]; then
        # Check thermal limit before inference
        if ! llm_thermal_ok; then
            echo "[llm] Inference paused: device too hot. Try again shortly."
            return
        fi

        prompt=$(llm_prompt_build "$input")

        # Build command — with optional CPU affinity
        if [ -n "$LLAMA_CPU_AFFINITY" ] && command -v taskset >/dev/null 2>&1; then
            _prefix="taskset -c $LLAMA_CPU_AFFINITY"
        else
            _prefix=""
        fi

        response=$(${_prefix} "$llm_bin" \
            -m "$model" \
            --n-predict "$LLM_MAX_TOKENS" \
            --temp "$LLM_TEMPERATURE" \
            --ctx-size "$LLM_CTX_SIZE" \
            --threads "$LLM_THREADS" \
            -p "$prompt" \
            2>>"$LLM_HISTORY_FILE" | tail -n +2 | head -30)

        [ -z "$response" ] && response=$(llm_fallback "$input")
    else
        response=$(llm_fallback "$input")
    fi

    echo "$(date '+%Y-%m-%d %H:%M:%S') Q: $input" >> "$LLM_HISTORY_FILE"
    echo "$(date '+%Y-%m-%d %H:%M:%S') A: $response" >> "$LLM_HISTORY_FILE"

    echo "$response"
}

# ---------------------------------------------------------------------------
# llm_fallback — rule-based responses when no model is available
# ---------------------------------------------------------------------------
llm_fallback() {
    input="$*"
    input_lower=$(echo "$input" | tr '[:upper:]' '[:lower:]')

    case "$input_lower" in
        *hello*|*hi*|*hey*)
            echo "Hello! I am AIOS-Lite, your AI operating system. How can I assist you today?" ;;
        *status*|*how*you*|*health*)
            echo "System status: operational. All core services running. Type 'os-state' for full details." ;;
        *bridge*|*connect*|*device*|*phone*)
            echo "Bridge system ready. Use 'bridge.detect' to scan for connected devices (iOS, Android, Linux). Use 'mirror.mount auto' to mount a device filesystem." ;;
        *memory*|*remember*)
            echo "I have symbolic, semantic, and context memory available. Use 'mem.set', 'sem.set', or 'ctx.add' to store information." ;;
        *help*|*what*you*do*)
            echo "I can: manage your OS, bridge to other devices (iOS/Android/Linux), store and recall memories, monitor services, and answer questions. Type 'help' for command list." ;;
        *mirror*|*apple*|*ios*|*iphone*)
            echo "iOS bridging uses libimobiledevice. Run 'bridge.detect' after connecting your iPhone via USB, then 'mirror.mount ios' to access its filesystem." ;;
        *android*|*adb*)
            echo "Android bridging uses ADB. Ensure USB debugging is enabled on the target device, then run 'bridge.detect' followed by 'mirror.mount android'." ;;
        *reboot*|*restart*)
            echo "To restart the kernel daemon: 'restart os-kernel'. To reboot the full system: 'reboot'." ;;
        *time*|*date*)
            echo "Current time: $(date '+%Y-%m-%d %H:%M:%S')" ;;
        *version*|*who*you*)
            echo "AIOS-Lite v0.1 — AI-Augmented Operating System by Chris. Built for portability and cross-device bridging." ;;
        *temp*|*thermal*|*hot*)
            if [ -f "$LLAMA_THERMAL_SENSOR" ]; then
                raw=$(cat "$LLAMA_THERMAL_SENSOR" 2>/dev/null)
                temp_c=$((raw / 1000))
                echo "Device temperature: ${temp_c}°C (limit: ${LLAMA_THERMAL_LIMIT}°C)"
            else
                echo "No thermal sensor found at $LLAMA_THERMAL_SENSOR"
            fi ;;
        *model*|*llm*|*llama*)
            echo "LLM model directory: $LLM_MODEL_DIR. Place a .gguf file there and install llama-cli to enable full AI inference." ;;
        *)
            result=$(grep -i "$(echo "$input" | awk '{print $1}')" \
                     "$OS_ROOT/etc/aura/memory.index" 2>/dev/null | head -1)
            if [ -n "$result" ] && command -v mem_get >/dev/null 2>&1; then
                key=$(echo "$result" | awk -F'|' '{print $1}' | xargs)
                echo "From memory [$key]: $(mem_get "$key" 2>/dev/null)"
            else
                echo "I don't have a specific answer for that. Try 'help' for available commands, or store relevant info with 'mem.set <key> <value>'."
            fi
            ;;
    esac
}
