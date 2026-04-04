# Aura LLM Module - llama.cpp wrapper with rule-based fallback
# Source this file to get: llm_query, llm_available, llm_prompt_build

# Primary model directory; runtime code also searches AIOS_HOME/llama_model
# and AIOS_HOME/models as fallbacks (see llm_model() below).
LLM_MODEL_DIR="${LLM_MODEL_DIR:-${OS_ROOT}/llama_model}"
LLM_CONTEXT_FILE="${OS_ROOT}/proc/aura/context/window"
LLM_HISTORY_FILE="${OS_ROOT}/var/log/llm.history"
LLM_MAX_TOKENS="${LLM_MAX_TOKENS:-256}"

# Check if a LLaMA binary is available
llm_available() {
    # Standard PATH binaries (covers Termux pkg, brew, pip installs)
    for bin in llama-cli llama-server llama.cpp llama main; do
        if command -v "$bin" >/dev/null 2>&1; then
            echo "$bin"
            return 0
        fi
    done
    # Check OS_ROOT, AIOS_HOME, and build output dirs
    for bin in \
        "$OS_ROOT/bin/llama-cli" "$OS_ROOT/bin/llama" "$OS_ROOT/bin/llama.cpp" \
        "${AIOS_HOME:-}/bin/llama-cli" "${AIOS_HOME:-}/bin/llama" \
        "${AIOS_HOME:-}/build/bin/llama-cli" "${AIOS_HOME:-}/build/bin/main"
    do
        if [ -x "$bin" ]; then
            echo "$bin"
            return 0
        fi
    # Binaries installed inside OS_ROOT
    for bin in \
        "$OS_ROOT/bin/llama-cli" \
        "$OS_ROOT/bin/llama-server" \
        "$OS_ROOT/bin/llama" \
        "$OS_ROOT/bin/llama.cpp"
    do
        [ -x "$bin" ] && { echo "$bin"; return 0; }
    done
    # Build-tree locations (repo root relative to OS_ROOT)
    _aios_home="${AIOS_HOME:-$(cd "$OS_ROOT/.." 2>/dev/null && pwd)}"
    for bin in \
        "$_aios_home/build/llama.cpp/llama-cli" \
        "$_aios_home/build/llama.cpp/main" \
        "$_aios_home/build/bin/llama-cli" \
        "$_aios_home/build/bin/main"
    do
        [ -x "$bin" ] && { echo "$bin"; return 0; }
    done
    return 1
}

# Find first available model file — searches multiple standard locations
llm_model() {
    for d in \
        "${LLM_MODEL_DIR:-$OS_ROOT/llama_model}" \
        "${AIOS_HOME:-}/llama_model" \
        "${AIOS_HOME:-}/models"
    do
        [ -z "$d" ] && continue
        for ext in gguf bin; do
            m=$(find "$d" -maxdepth 2 -name "*.$ext" 2>/dev/null | head -1)
            [ -n "$m" ] && { echo "$m"; return 0; }
        done
    done
    return 1
}

# Build a context-aware prompt from hybrid memory + conversation history
llm_prompt_build() {
    user_input="$*"
    os_name=$(awk -F'"' '/OS_NAME/ {print $2}' "$OS_ROOT/proc/os.identity" 2>/dev/null)
    os_name="${os_name:-AIOS-Lite}"

    printf 'You are %s, an intelligent AI operating system. You help the user manage their system, answer questions, and bridge to other devices.\n\n' "$os_name"

    # Recent context window (last 10 lines)
    if [ -f "$LLM_CONTEXT_FILE" ]; then
        echo "Recent context:"
        tail -n 10 "$LLM_CONTEXT_FILE" | sed 's/^/  /'
        echo
    fi

    # Relevant symbolic memory
    if [ -f "$OS_ROOT/etc/aura/memory.index" ]; then
        matches=$(grep -i "$(echo "$user_input" | awk '{print $1}')" "$OS_ROOT/etc/aura/memory.index" 2>/dev/null | head -3)
        if [ -n "$matches" ]; then
            echo "Relevant memory:"
            echo "$matches" | sed 's/^/  /'
            echo
        fi
    fi

    echo "User: $user_input"
    echo "Assistant:"
}

# Query the LLM (uses llama.cpp if available, falls back to rule-based)
llm_query() {
    input="$*"
    mkdir -p "$(dirname "$LLM_HISTORY_FILE")"

    llm_bin=$(llm_available)
    model=$(llm_model)

    if [ -n "$llm_bin" ] && [ -n "$model" ]; then
        # Real LLM path
        prompt=$(llm_prompt_build "$input")
        response=$("$llm_bin" \
            -m "$model" \
            --n-predict "$LLM_MAX_TOKENS" \
            --temp 0.7 \
            --ctx-size 2048 \
            -p "$prompt" \
            2>>"$LLM_HISTORY_FILE" | tail -n +2 | head -30)
        [ -z "$response" ] && response=$(llm_fallback "$input")
    else
        response=$(llm_fallback "$input")
    fi

    # Log to history
    echo "$(date '+%Y-%m-%d %H:%M:%S') Q: $input" >> "$LLM_HISTORY_FILE"
    echo "$(date '+%Y-%m-%d %H:%M:%S') A: $response" >> "$LLM_HISTORY_FILE"

    echo "$response"
}

# Rule-based fallback when no LLM model is present
llm_fallback() {
    input="$*"
    input_lower=$(echo "$input" | tr '[:upper:]' '[:lower:]')

    # NOTE: case patterns below intentionally omit spaces (e.g. *how*you* instead of
    # *how are you*) because POSIX sh (dash) does not allow spaces in case patterns.
    case "$input_lower" in
        *hello*|*hi*|*hey*)
            echo "Hello! I am AIOS-Lite, your AI operating system. How can I assist you today?" ;;
        *status*|*how*you*|*health*)
            echo "System status: operational. All core services running. Type 'os-state' for full details." ;;
        *bridge*|*connect*|*device*|*phone*)
            echo "Bridge system ready. Use 'os-bridge detect' to scan for connected devices (iOS, Android, Linux). Use 'os-mirror' to mount a device filesystem." ;;
        *memory*|*remember*)
            echo "I have symbolic, semantic, and context memory available. Use 'mem.set', 'sem.set', or 'ctx.add' to store information." ;;
        *help*|*what*you*do*)
            echo "I can: manage your OS, bridge to other devices (iOS/Android/Linux), store and recall memories, monitor services, and answer questions. Type 'help' for command list." ;;
        *mirror*|*apple*|*ios*|*iphone*)
            echo "iOS bridging uses libimobiledevice. Run 'os-bridge detect' after connecting your iPhone via USB, then 'os-mirror mount ios' to access its filesystem." ;;
        *android*|*adb*)
            echo "Android bridging uses ADB. Ensure USB debugging is enabled on the target device, then run 'os-bridge detect' followed by 'os-mirror mount android'." ;;
        *reboot*|*restart*)
            echo "To restart the kernel daemon: 'os-kernelctl restart'. To reboot the full system: 'reboot'." ;;
        *time*|*date*)
            echo "Current time: $(date '+%Y-%m-%d %H:%M:%S')" ;;
        *version*|*who*you*)
            echo "AIOS-Lite v0.1 — AI-Augmented Operating System by Chris. Built for portability and cross-device bridging." ;;
        *)
            # Try symbolic memory search
            result=$(grep -i "$(echo "$input" | awk '{print $1}')" "$OS_ROOT/etc/aura/memory.index" 2>/dev/null | head -1)
            if [ -n "$result" ] && command -v mem_get >/dev/null 2>&1; then
                key=$(echo "$result" | awk -F'|' '{print $1}' | xargs)
                echo "From memory [$key]: $(mem_get "$key" 2>/dev/null)"
            else
                echo "I don't have a specific answer for that. Try 'help' for available commands, or store relevant info with 'mem.set <key> <value>'."
            fi
            ;;
    esac
}

# Stream the LLM response token-by-token to stdout (for interactive use)
# Falls back to llm_fallback when no model/binary is present.
llm_stream() {
    input="$*"
    llm_bin=$(llm_available)
    model=$(llm_model)

    if [ -n "$llm_bin" ] && [ -n "$model" ]; then
        prompt=$(llm_prompt_build "$input")
        # Use python3 streaming client if available; fall back to plain binary
        if command -v python3 >/dev/null 2>&1 && \
           [ -f "$(dirname "$(dirname "$(dirname "$0")")")/ai/core/llama_client.py" ]; then
            AIOS_PY="$(dirname "$(dirname "$(dirname "$0")")")/ai/core/llama_client.py"
            python3 "$AIOS_PY" \
                --backend llama \
                --model-path "$model" \
                --threads "${LLAMA_THREADS:-4}" \
                --ctx 2048 \
                --stream \
                --prompt "$prompt" 2>/dev/null
        else
            "$llm_bin" -m "$model" \
                --n-predict "${LLM_MAX_TOKENS:-256}" \
                --temp 0.7 \
                --ctx-size 2048 \
                -p "$prompt" 2>/dev/null
        fi
    else
        llm_fallback "$input"
    fi
}
