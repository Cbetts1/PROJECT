#!/usr/bin/env bash
# boot/bootloader.sh — AIOS visual boot sequence
# © 2026 Chris Betts | AIOSCPU Official
#
# Runs the full staged boot pipeline before handing off to bin/aios.
# Each stage is logged to var/log/aios.log and printed to stdout.
#
# Exit codes:
#   0 — boot succeeded, caller should exec bin/aios
#   1 — fatal boot failure

set -euo pipefail

AIOS_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export AIOS_ROOT

# Source core library (sets log(), OS_ROOT, etc.)
# shellcheck source=lib/aura-core.sh
. "${AIOS_ROOT}/lib/aura-core.sh"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
_BOOT_START=$(date +%s%N 2>/dev/null || printf '%s000000000' "$(date +%s)")

_ts()  { date -u +"%Y-%m-%dT%H:%M:%SZ"; }
_ms()  {
    local now
    now=$(date +%s%N 2>/dev/null || printf '%s000000000' "$(date +%s)")
    echo $(( (now - _BOOT_START) / 1000000 ))
}

_stage() {
    local n="$1"; local label="$2"
    printf '\n\033[1;36m[BOOT] Stage %d — %s\033[0m\n' "$n" "$label"
    log "BOOT" "Stage ${n}: ${label}"
}

_ok()   { printf '  \033[1;32m✓\033[0m %s\n' "$*"; }
_warn() { printf '  \033[1;33m⚠\033[0m %s\n' "$*"; }
_fail() { printf '  \033[1;31m✗\033[0m %s\n' "$*" >&2; }

_check() {
    local label="$1"; shift
    if "$@" &>/dev/null; then
        _ok "${label}"
        return 0
    else
        _warn "${label} (non-fatal)"
        return 0   # boot continues even when optional checks fail
    fi
}

# ---------------------------------------------------------------------------
# Banner
# ---------------------------------------------------------------------------
cat <<'BANNER'

  ╔══════════════════════════════════════════════════╗
  ║                                                  ║
  ║      ___  ___ ___  ___     _   ___               ║
  ║     / _ \|_ _/ _ \/ __|   /_\ |_ _|              ║
  ║    | (_) || || (_) \__ \  / _ \ | |               ║
  ║     \__,_|___\___/|___/ /_/ \_\___|              ║
  ║                                                  ║
  ║       AI Operating System — Aurora v1.0          ║
  ║       © 2026 Christopher Betts                   ║
  ╚══════════════════════════════════════════════════╝

BANNER

log "BOOT" "AIOS bootloader started. AIOS_ROOT=${AIOS_ROOT} OS_ROOT=${OS_ROOT}"

# ---------------------------------------------------------------------------
# Stage 0 — Environment Detection
# ---------------------------------------------------------------------------
_stage 0 "Environment Detection"

# Detect host type
if [[ -d /data/data/com.termux ]]; then
    HOST_ENV="termux"
elif [[ "$(uname -s)" == "Darwin" ]]; then
    HOST_ENV="macos"
elif [[ -f /etc/os-release ]]; then
    HOST_ENV="linux"
else
    HOST_ENV="posix"
fi
export HOST_ENV

_ok  "Host environment : ${HOST_ENV}"
_ok  "OS root jail     : ${OS_ROOT}"
_ok  "AIOS root        : ${AIOS_ROOT}"

# Bash version check
bash_major="${BASH_VERSINFO[0]:-0}"
if (( bash_major >= 4 )); then
    _ok  "Bash ${BASH_VERSION}"
else
    _warn "Bash ${BASH_VERSION} — version 4+ recommended (associative arrays)"
fi

# Python check
if command -v python3 &>/dev/null; then
    _ok  "Python $(python3 --version 2>&1 | cut -d' ' -f2)"
else
    _warn "python3 not found — AI backend will be unavailable"
fi

log "BOOT" "Stage 0 complete: HOST_ENV=${HOST_ENV} bash=${BASH_VERSION}"

# ---------------------------------------------------------------------------
# Stage 1 — Filesystem Initialisation
# ---------------------------------------------------------------------------
_stage 1 "Filesystem Initialisation"

# Create all required runtime directories
dirs=(
    "${OS_ROOT}/bin"
    "${OS_ROOT}/sbin"
    "${OS_ROOT}/etc"
    "${OS_ROOT}/etc/aura"
    "${OS_ROOT}/proc"
    "${OS_ROOT}/proc/aura/context"
    "${OS_ROOT}/proc/aura/memory"
    "${OS_ROOT}/proc/aura/semantic"
    "${OS_ROOT}/proc/os"
    "${OS_ROOT}/var/log"
    "${OS_ROOT}/var/service"
    "${OS_ROOT}/var/events"
    "${OS_ROOT}/var/pkg"
    "${OS_ROOT}/tmp"
    "${OS_ROOT}/dev"
    "${OS_ROOT}/home"
    "${AIOS_ROOT}/var/log"
    "${AIOS_ROOT}/var/run"
    "${AIOS_ROOT}/llama_model"
)

created=0
for d in "${dirs[@]}"; do
    if [[ ! -d "${d}" ]]; then
        mkdir -p "${d}" && (( created++ )) || true
    fi
done
_ok "Runtime directories ready (${created} created)"

# Initialise essential runtime files
_init_file() {
    local path="$1"; local content="$2"
    [[ -f "${path}" ]] || printf '%s\n' "${content}" > "${path}"
}

_init_file "${OS_ROOT}/proc/os.state"    "boot_time=$(date +%s)
kernel_pid=0
os_version=1.0
runlevel=2
last_heartbeat=$(date +%s)"

_init_file "${OS_ROOT}/proc/aura/context/window" ""
_init_file "${OS_ROOT}/proc/os.messages"          ""
_init_file "${OS_ROOT}/var/log/os.log"            ""
_init_file "${OS_ROOT}/var/log/aura.log"          ""
_init_file "${OS_ROOT}/var/log/events.log"        ""
_init_file "${AIOS_ROOT}/var/log/aios.log"        ""

_ok "Runtime files initialised"
log "BOOT" "Stage 1 complete: filesystem ready"

# ---------------------------------------------------------------------------
# Stage 2 — Permission Check
# ---------------------------------------------------------------------------
_stage 2 "Permission Check"

perm_fixed=0
for f in \
    "${AIOS_ROOT}/bin/aios" \
    "${AIOS_ROOT}/bin/aios-sys" \
    "${AIOS_ROOT}/bin/aios-heartbeat" \
    "${AIOS_ROOT}/install.sh" \
    "${AIOS_ROOT}/run.sh"; do
    if [[ -f "${f}" && ! -x "${f}" ]]; then
        chmod +x "${f}" && (( perm_fixed++ )) || true
    fi
done

# Fix all shell scripts in OS/bin and OS/sbin
while IFS= read -r -d '' f; do
    head -c 2 "${f}" 2>/dev/null | grep -q '^#!' && chmod +x "${f}" 2>/dev/null || true
done < <(find "${OS_ROOT}/bin" "${OS_ROOT}/sbin" -type f -print0 2>/dev/null)

_ok "Executable permissions set (${perm_fixed} fixed)"
log "BOOT" "Stage 2 complete: permissions OK"

# ---------------------------------------------------------------------------
# Stage 3 — Service Health Pre-Check
# ---------------------------------------------------------------------------
_stage 3 "Service Health Pre-Check"

_check "Python AI backend importable" \
    python3 -c "import sys; sys.path.insert(0,'${AIOS_ROOT}/ai/core'); from ai_backend import main"

_check "Aura core module loadable" \
    bash -c "AIOS_ROOT='${AIOS_ROOT}' . '${AIOS_ROOT}/lib/aura-core.sh'"

# LLM check (non-fatal)
llm_ready=0
for _b in llama-cli llama llama.cpp main; do
    if command -v "${_b}" &>/dev/null || \
       [[ -x "${AIOS_ROOT}/build/llama.cpp/build/bin/${_b}" ]]; then
        llm_ready=1
        _ok "LLM binary found: ${_b}"
        break
    fi
done
model_ready=0
while IFS= read -r -d '' f; do
    model_ready=1
    _ok "Model file: $(basename "${f}")"
    break
done < <(find "${AIOS_ROOT}/llama_model" -name "*.gguf" -print0 2>/dev/null)

if (( llm_ready == 0 )); then
    _warn "No llama binary — AI will use built-in rule-based backend"
fi
if (( model_ready == 0 )); then
    _warn "No .gguf model found in llama_model/ — see docs/AI_MODEL_SETUP.md"
fi

log "BOOT" "Stage 3 complete: service checks done"

# ---------------------------------------------------------------------------
# Stage 4 — Kernel State Write
# ---------------------------------------------------------------------------
_stage 4 "Kernel State Write"

BOOT_TS=$(date +%s)
cat > "${OS_ROOT}/proc/os.state" <<EOF
# AIOS Kernel State — written at boot by boot/bootloader.sh
OS_NAME="AIOS"
OS_VERSION="1.0"
HOST_ENV="${HOST_ENV}"
boot_time=${BOOT_TS}
kernel_pid=$$
os_root="${OS_ROOT}"
aios_root="${AIOS_ROOT}"
runlevel=2
last_heartbeat=${BOOT_TS}
ai_backend="${AI_BACKEND:-mock}"
EOF

_ok "Kernel state written (PID=$$)"

# Write boot log entry
printf '[%s] [BOOT] boot_time=%s kernel_pid=%s runlevel=2 host_env=%s\n' \
    "$(_ts)" "${BOOT_TS}" "$$" "${HOST_ENV}" >> "${OS_ROOT}/var/log/aura.log"

log "BOOT" "Stage 4 complete: kernel state written"

# ---------------------------------------------------------------------------
# Stage 5 — Boot Complete
# ---------------------------------------------------------------------------
_boot_ms=$(_ms)
_stage 5 "Boot Complete"
printf '\n\033[1;32m  AIOS boot completed in %d ms — launching AI shell\033[0m\n\n' "${_boot_ms}"
log "BOOT" "Boot complete in ${_boot_ms}ms. Handing off to bin/aios"
