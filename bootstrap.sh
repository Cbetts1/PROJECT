#!/usr/bin/env sh
# bootstrap.sh — AIOS Portable Bootstrap
# © 2026 Chris Betts | AIOSCPU Official | AI-generated, fully legal
#
# Bootstraps AIOS on any Unix-like system: Linux, macOS, Android/Termux,
# Raspberry Pi, SD-card, USB drive, or external storage.
#
# Usage:
#   sh bootstrap.sh [options]
#
# Options:
#   --aios-home <path>     Override install root   (default: dir of this script)
#   --os-root   <path>     Override OS_ROOT        (default: AIOS_HOME/OS)
#   --no-llama             Skip llama.cpp build check
#   --start                Boot AIOS after setup
#   --help                 Show this help
#
# Designed to run from read-only media (SD-card, USB):
#   - Requires only POSIX sh + standard coreutils
#   - Zero network dependencies for the bootstrap itself
#   - Optional llama.cpp / model download when online

set -eu

# ---------------------------------------------------------------------------
# Resolve paths
# ---------------------------------------------------------------------------
_SELF_DIR="$(cd "$(dirname "$0")" 2>/dev/null && pwd)"
AIOS_HOME="${AIOS_HOME:-$_SELF_DIR}"
OS_ROOT="${OS_ROOT:-$AIOS_HOME/OS}"

START_AIOS=0
SKIP_LLAMA=0

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------
while [ $# -gt 0 ]; do
    case "$1" in
        --aios-home) AIOS_HOME="$2"; OS_ROOT="$AIOS_HOME/OS"; shift 2 ;;
        --os-root)   OS_ROOT="$2"; shift 2 ;;
        --no-llama)  SKIP_LLAMA=1; shift ;;
        --start)     START_AIOS=1; shift ;;
        --help|-h)
            sed -n '4,21p' "$0"
            exit 0
            ;;
        *) echo "Unknown option: $1" >&2; exit 1 ;;
    esac
done

export AIOS_HOME OS_ROOT

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
info()  { printf '[bootstrap] %s\n' "$*"; }
ok()    { printf '[bootstrap] \033[32m✓\033[0m %s\n' "$*"; }
warn()  { printf '[bootstrap] \033[33m⚠\033[0m %s\n' "$*" >&2; }
die()   { printf '[bootstrap] \033[31m✗\033[0m %s\n' "$*" >&2; exit 1; }

# Detect platform
detect_platform() {
    if [ -d "/data/data/com.termux" ] || [ -n "${TERMUX_VERSION:-}" ]; then
        echo "termux"
    elif uname -a 2>/dev/null | grep -qi "android"; then
        echo "android"
    elif [ "$(uname -s)" = "Darwin" ]; then
        echo "macos"
    elif [ -f "/etc/os-release" ]; then
        echo "linux"
    elif uname -a 2>/dev/null | grep -qi "raspberry"; then
        echo "rpi"
    else
        echo "posix"
    fi
}

# ---------------------------------------------------------------------------
# Banner
# ---------------------------------------------------------------------------
cat <<'BANNER'
╔══════════════════════════════════════════════╗
║      AIOS — AI-Native Operating System       ║
║      Portable Bootstrap v1.0                 ║
║      Device-Agnostic · Modular · Portable    ║
╚══════════════════════════════════════════════╝
BANNER

PLATFORM="$(detect_platform)"
info "Platform  : $PLATFORM"
info "AIOS_HOME : $AIOS_HOME"
info "OS_ROOT   : $OS_ROOT"
echo

# ---------------------------------------------------------------------------
# Verify required source files exist
# ---------------------------------------------------------------------------
info "Checking source tree..."
for required in \
    "$OS_ROOT/sbin/init" \
    "$OS_ROOT/bin/os-shell" \
    "$AIOS_HOME/bin/aios"
do
    if [ ! -f "$required" ]; then
        die "Required file missing: $required  (is AIOS_HOME correct?)"
    fi
done
ok "Source tree OK"

# ---------------------------------------------------------------------------
# Create runtime directory layout
# ---------------------------------------------------------------------------
info "Creating runtime directories..."
mkdir -p \
    "$OS_ROOT/var/log" \
    "$OS_ROOT/var/service" \
    "$OS_ROOT/var/events" \
    "$OS_ROOT/var/pkg" \
    "$OS_ROOT/proc/aura/context" \
    "$OS_ROOT/proc/aura/memory" \
    "$OS_ROOT/proc/aura/semantic" \
    "$OS_ROOT/proc/aura/bridge" \
    "$OS_ROOT/proc/aura/intent" \
    "$OS_ROOT/proc/aura/bots" \
    "$OS_ROOT/mirror/ios" \
    "$OS_ROOT/mirror/android" \
    "$OS_ROOT/mirror/linux" \
    "$OS_ROOT/tmp" \
    "$AIOS_HOME/var/log" \
    "$AIOS_HOME/var/run" \
    "$AIOS_HOME/llama_model"
ok "Directories created"

# ---------------------------------------------------------------------------
# Initialise runtime state files
# ---------------------------------------------------------------------------
info "Initialising runtime state..."

[ -f "$OS_ROOT/proc/aura/context/window" ]  || touch "$OS_ROOT/proc/aura/context/window"
[ -f "$OS_ROOT/proc/os.messages" ]           || touch "$OS_ROOT/proc/os.messages"
[ -f "$OS_ROOT/var/log/os.log" ]             || touch "$OS_ROOT/var/log/os.log"
[ -f "$OS_ROOT/var/log/aura.log" ]           || touch "$OS_ROOT/var/log/aura.log"
[ -f "$OS_ROOT/var/log/events.log" ]         || touch "$OS_ROOT/var/log/events.log"
[ -f "$OS_ROOT/var/log/bus.log" ]            || touch "$OS_ROOT/var/log/bus.log"
[ -f "$OS_ROOT/var/log/intent.log" ]         || touch "$OS_ROOT/var/log/intent.log"

if [ ! -f "$OS_ROOT/proc/os.state" ]; then
    cat > "$OS_ROOT/proc/os.state" <<STATE
boot_time=$(date +%s)
kernel_pid=0
os_version=0.1
runlevel=2
last_heartbeat=$(date +%s)
STATE
fi
ok "State files initialised"

# ---------------------------------------------------------------------------
# Set executable permissions (works on FAT-formatted SD cards too)
# ---------------------------------------------------------------------------
info "Setting permissions on scripts..."
find "$OS_ROOT/bin" "$OS_ROOT/sbin" "$OS_ROOT/etc/init.d" \
     "$OS_ROOT/lib/aura-agents" "$OS_ROOT/init.d" \
     "$AIOS_HOME/bin" "$AIOS_HOME/build" \
     -type f 2>/dev/null | while read -r f; do
    head -c 2 "$f" 2>/dev/null | grep -q '^#!' && chmod +x "$f" 2>/dev/null || true
done
chmod +x "$OS_ROOT/lib/filesystem.py" 2>/dev/null || true
chmod +x "$AIOS_HOME/install.sh"      2>/dev/null || true
ok "Permissions set"

# ---------------------------------------------------------------------------
# Check Python 3
# ---------------------------------------------------------------------------
info "Checking Python 3..."
if command -v python3 >/dev/null 2>&1; then
    PY_VER="$(python3 --version 2>&1)"
    ok "Python: $PY_VER"
else
    warn "python3 not found — filesystem.py and AI backend will not work."
    case "$PLATFORM" in
        termux)  warn "Run: pkg install python" ;;
        linux)   warn "Run: apt install python3  OR  dnf install python3" ;;
        macos)   warn "Run: brew install python3" ;;
        rpi)     warn "Run: sudo apt install python3" ;;
    esac
fi

# ---------------------------------------------------------------------------
# Check llama.cpp / AI model
# ---------------------------------------------------------------------------
if [ "$SKIP_LLAMA" -eq 0 ]; then
    info "Checking LLM runtime..."
    LLAMA_FOUND=0
    for bin in llama-cli llama.cpp llama main; do
        if command -v "$bin" >/dev/null 2>&1; then
            ok "llama.cpp binary: $bin ($(command -v "$bin"))"
            LLAMA_FOUND=1
            break
        fi
    done
    if [ "$LLAMA_FOUND" -eq 0 ]; then
        warn "llama.cpp not found — AI will use rule-based fallback."
        warn "Build with:  bash $AIOS_HOME/build/build.sh --target $PLATFORM"
    fi

    MODEL_COUNT=$(find "$AIOS_HOME/llama_model" -maxdepth 2 \
                       -name "*.gguf" -o -name "*.bin" 2>/dev/null | wc -l | tr -d ' ')
    if [ "$MODEL_COUNT" -gt 0 ]; then
        ok "LLM model files found: $MODEL_COUNT"
    else
        warn "No model files in $AIOS_HOME/llama_model/"
        warn "Download a GGUF model (e.g. llama-3-8b.Q4_K_M.gguf) and place it there."
    fi
fi

# ---------------------------------------------------------------------------
# Platform-specific hints
# ---------------------------------------------------------------------------
echo
info "Platform notes for: $PLATFORM"
case "$PLATFORM" in
    termux)
        echo "  • Run AIOS from Termux: sh $AIOS_HOME/OS/sbin/init"
        echo "  • For full setup: pkg install python openssh"
        ;;
    rpi)
        echo "  • Add to /etc/rc.local: sh $AIOS_HOME/OS/sbin/init --no-shell &"
        echo "  • For autostart: copy aioscpu/rootfs-overlay/systemd/system/aura.service"
        ;;
    linux)
        echo "  • Autostart: copy aioscpu/rootfs-overlay/systemd/system/aura.service"
        echo "              to /etc/systemd/system/ and run: systemctl enable aura"
        ;;
    macos)
        echo "  • Autostart: create a launchd plist pointing to OS/sbin/init"
        ;;
    *)
        echo "  • Start manually: sh $AIOS_HOME/OS/sbin/init"
        ;;
esac

# ---------------------------------------------------------------------------
# Write a local env helper  (AIOS_HOME/env.sh)
# ---------------------------------------------------------------------------
ENV_FILE="$AIOS_HOME/env.sh"
if [ ! -f "$ENV_FILE" ]; then
    cat > "$ENV_FILE" <<ENVSH
#!/bin/sh
# Auto-generated by bootstrap.sh — source this to activate AIOS env
export AIOS_HOME="$AIOS_HOME"
export OS_ROOT="$OS_ROOT"
export PATH="\$OS_ROOT/bin:\$OS_ROOT/sbin:\$AIOS_HOME/bin:\$PATH"
ENVSH
    ok "Environment helper written: $ENV_FILE"
    ok "  source it with:  . $ENV_FILE"
fi

# ---------------------------------------------------------------------------
# Optionally boot AIOS
# ---------------------------------------------------------------------------
echo
ok "Bootstrap complete."

if [ "$START_AIOS" -eq 1 ]; then
    info "Starting AIOS..."
    # shellcheck source=/dev/null
    . "$ENV_FILE"
    exec sh "$OS_ROOT/sbin/init"
else
    echo
    echo "  To start AIOS:"
    echo "    . $AIOS_HOME/env.sh"
    echo "    sh \$OS_ROOT/sbin/init"
    echo
    echo "  Or with the AI shell directly:"
    echo "    . $AIOS_HOME/env.sh && bash \$AIOS_HOME/bin/aios"
fi
