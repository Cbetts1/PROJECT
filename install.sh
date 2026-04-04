#!/usr/bin/env bash
# install.sh — AIOS-Lite Installer
# © 2026 Chris Betts | AIOSCPU Official | AI-generated, fully legal
#
# Sets up AIOS-Lite in the current directory:
#   - Makes all scripts executable
#   - Creates required runtime directories
#   - Initialises proc/os.state and var/log/os.log
#   - Optionally builds llama.cpp (--build-llama)
#   - Optionally starts the AIOS kernel (--start)
#
# Usage:
#   bash install.sh [options]
#
# Options:
#   --build-llama          Build llama.cpp (requires cmake + git)
#   --start                Start AIOS kernel after install
#   --self-test            Run full self-test suite and exit (no install)
#   --os-root <path>       Override OS_ROOT (default: ./OS)
#   --help                 Show this help

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OS_ROOT="${OS_ROOT:-$REPO_ROOT/OS}"

BUILD_LLAMA=0
START_AFTER=0
SELF_TEST=0

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------
while [[ $# -gt 0 ]]; do
    case "$1" in
        --build-llama) BUILD_LLAMA=1; shift ;;
        --start)       START_AFTER=1; shift ;;
        --self-test)   SELF_TEST=1; shift ;;
        --os-root)     OS_ROOT="$2"; shift 2 ;;
        --help|-h)
            sed -n '3,20p' "$0"
            exit 0
            ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

info()    { echo "[install] $*"; }
success() { echo "[install] ✓ $*"; }
warn()    { echo "[install] ⚠ $*" >&2; }

# ---------------------------------------------------------------------------
# Check Python 3.13+
# ---------------------------------------------------------------------------
check_python() {
    if ! command -v python3 &>/dev/null; then
        warn "python3 not found — filesystem.py will not work."
        warn "Install python3 (>=3.9 required, 3.13+ recommended)."
        return
    fi
    py_ver=$(python3 -c "import sys; print(sys.version_info[:2])")
    info "Python: $(python3 --version) ($py_ver)"
}

# ---------------------------------------------------------------------------
# Make executables
# ---------------------------------------------------------------------------
make_executables() {
    info "Setting executable permissions on scripts..."

    find "$OS_ROOT/bin" "$OS_ROOT/sbin" "$OS_ROOT/etc/init.d" \
         "$OS_ROOT/lib/aura-agents" \
         "$OS_ROOT/init.d" \
         "$REPO_ROOT/build" \
         -type f 2>/dev/null | while read -r f; do
        head -c 2 "$f" 2>/dev/null | grep -q '^#!' && chmod +x "$f"
    done

    chmod +x "$OS_ROOT/lib/filesystem.py" 2>/dev/null || true

    # Root-level scripts
    for f in "$REPO_ROOT/install.sh"; do
        [ -f "$f" ] && chmod +x "$f"
    done

    success "Permissions set."
}

# ---------------------------------------------------------------------------
# Create runtime directories
# ---------------------------------------------------------------------------
create_dirs() {
    info "Creating runtime directories..."
    mkdir -p \
        "$OS_ROOT/var/log" \
        "$OS_ROOT/var/service" \
        "$OS_ROOT/var/events" \
        "$OS_ROOT/var/pkg" \
        "$OS_ROOT/proc" \
        "$OS_ROOT/proc/aura/context" \
        "$OS_ROOT/proc/aura/memory" \
        "$OS_ROOT/proc/aura/semantic" \
        "$OS_ROOT/proc/aura/bridge" \
        "$OS_ROOT/mirror/ios" \
        "$OS_ROOT/mirror/android" \
        "$OS_ROOT/mirror/linux" \
        "$OS_ROOT/tmp" \
        "$OS_ROOT/usr/pkg" \
        "$REPO_ROOT/llama_model"

    success "Directories created."
}

# ---------------------------------------------------------------------------
# Initialise runtime files
# ---------------------------------------------------------------------------
init_files() {
    info "Initialising runtime files..."

    # Context window
    [ -f "$OS_ROOT/proc/aura/context/window" ] || touch "$OS_ROOT/proc/aura/context/window"

    # Logs
    for log in os.log aura.log events.log messages.log bridge.log; do
        [ -f "$OS_ROOT/var/log/$log" ] || touch "$OS_ROOT/var/log/$log"
    done

    # Proc state
    if [ ! -f "$OS_ROOT/proc/os.state" ]; then
        cat > "$OS_ROOT/proc/os.state" << 'EOF'
boot_time=0
kernel_pid=0
os_version=0.1
runlevel=2
last_heartbeat=0
EOF
        info "Created proc/os.state"
    fi

    # Message bus
    [ -f "$OS_ROOT/proc/os.messages" ] || touch "$OS_ROOT/proc/os.messages"

    # Memory/semantic indices
    [ -f "$OS_ROOT/etc/aura/memory.index" ]   || touch "$OS_ROOT/etc/aura/memory.index"
    [ -f "$OS_ROOT/etc/aura/semantic.index" ] || touch "$OS_ROOT/etc/aura/semantic.index"
    [ -f "$OS_ROOT/etc/aura/agents.list" ]    || printf 'heartbeat\nlistener\nautosys\nbridge\n' > "$OS_ROOT/etc/aura/agents.list"

    success "Runtime files initialised."
}

# ---------------------------------------------------------------------------
# Verify AURA modules
# ---------------------------------------------------------------------------
verify_modules() {
    info "Verifying AURA modules..."
    missing=0
    for mod in \
        lib/aura-memory/engine.mod \
        lib/aura-semantic/embed.mod \
        lib/aura-semantic/engine.mod \
        lib/aura-hybrid/engine.mod \
        lib/aura-llm/llm.mod \
        lib/aura-policy/engine.mod \
        lib/aura-policy/actions.mod \
        lib/aura-bridge/detect.mod \
        lib/aura-bridge/ios.mod \
        lib/aura-bridge/android.mod \
        lib/aura-bridge/linux.mod \
        lib/aura-bridge/mirror.mod \
        lib/aura-mods/core.mod \
        lib/aura-mods/bus.mod \
        lib/filesystem.py; do
        if [ -f "$OS_ROOT/$mod" ]; then
            printf '  %-40s OK\n' "$mod"
        else
            printf '  %-40s MISSING\n' "$mod" >&2
            missing=$((missing+1))
        fi
    done
    if [ "$missing" -gt 0 ]; then
        warn "$missing module(s) missing. Run from the repo root."
    else
        success "All AURA modules present."
    fi
}

# ---------------------------------------------------------------------------
# Detect optional dependencies
# ---------------------------------------------------------------------------
detect_deps() {
    info "Detecting optional dependencies..."
    for tool in python3 adb ideviceinfo ifuse sshfs nmcli bluetoothctl; do
        if command -v "$tool" &>/dev/null; then
            printf '  %-20s found\n' "$tool"
        else
            printf '  %-20s not found (optional)\n' "$tool"
        fi
    done

    # Termux-specific tools
    if [[ -n "${TERMUX_VERSION:-}" ]] || [[ -d "/data/data/com.termux" ]]; then
        for tool in termux-notification termux-vibrate termux-clipboard-get termux-battery-status termux-wake-lock; do
            if command -v "$tool" &>/dev/null; then
                printf '  %-30s found\n' "$tool"
            else
                printf '  %-30s not found — install: pkg install termux-api\n' "$tool"
            fi
        done
    fi

    # LLM binary
    llm_found=0
    for bin in llama-cli llama.cpp llama main; do
        if command -v "$bin" &>/dev/null || [ -x "$OS_ROOT/bin/$bin" ]; then
            printf '  %-20s found\n' "$bin"
            llm_found=1
            break
        fi
    done
    [ "$llm_found" -eq 0 ] && printf '  %-20s not found — run: bash build/build.sh\n' "llama-cli"
}

# ---------------------------------------------------------------------------
# Termux boot.d integration (optional, only on Termux)
# ---------------------------------------------------------------------------
setup_termux_boot() {
    if [[ -z "${TERMUX_VERSION:-}" ]] && [[ ! -d "/data/data/com.termux" ]]; then
        return 0   # not on Termux
    fi

    local boot_dir="${HOME}/.termux/boot"
    local boot_script="${boot_dir}/aios-boot.sh"
    local src="$OS_ROOT/init.d/termux-boot.sh"

    if [[ ! -f "$src" ]]; then
        warn "termux-boot.sh not found at $src — skipping Termux boot.d setup."
        return 0
    fi

    info "Setting up Termux boot.d integration..."
    mkdir -p "$boot_dir"
    # Write a launcher that calls back to this repo's termux-boot.sh
    cat > "$boot_script" << TERMUX_BOOT
#!/data/data/com.termux/files/usr/bin/bash
# Auto-generated by AIOS install.sh — launches AIOS on Termux boot.
export AIOS_HOME="$REPO_ROOT"
export OS_ROOT="$OS_ROOT"
exec bash "$src" --no-shell
TERMUX_BOOT
    chmod +x "$boot_script"
    success "Termux boot script installed: $boot_script"
    info "  Install Termux:Boot add-on from F-Droid to run automatically on device boot."
}

# ---------------------------------------------------------------------------
# Run unit tests
# ---------------------------------------------------------------------------
run_tests() {
    info "Running unit tests..."
    if AIOS_HOME="$REPO_ROOT" OS_ROOT="$OS_ROOT" bash "$REPO_ROOT/tests/unit-tests.sh" 2>&1; then
        success "All unit tests passed."
    else
        warn "Some unit tests failed. See output above."
    fi
}

# ---------------------------------------------------------------------------
# Self-test: run all tests + verify core binary presence
# ---------------------------------------------------------------------------
self_test() {
    local failed=0
    echo "════════════════════════════════════════"
    echo "  AIOS Self-Test"
    echo "════════════════════════════════════════"

    check_python
    verify_modules
    detect_deps

    info "Running unit tests..."
    if AIOS_HOME="$REPO_ROOT" OS_ROOT="$OS_ROOT" bash "$REPO_ROOT/tests/unit-tests.sh" 2>&1; then
        success "Unit tests: PASS"
    else
        warn "Unit tests: FAIL"
        failed=$(( failed + 1 ))
    fi

    if [[ -f "$REPO_ROOT/tests/integration-tests.sh" ]]; then
        info "Running integration tests..."
        if AIOS_HOME="$REPO_ROOT" OS_ROOT="$OS_ROOT" bash "$REPO_ROOT/tests/integration-tests.sh" 2>&1; then
            success "Integration tests: PASS"
        else
            warn "Integration tests: FAIL"
            failed=$(( failed + 1 ))
        fi
    fi

    # Verify core executables are present and executable
    for f in \
        "$OS_ROOT/bin/os-shell" \
        "$OS_ROOT/bin/os-real-shell" \
        "$OS_ROOT/sbin/init" \
        "$OS_ROOT/bin/os-kernelctl" \
        "$OS_ROOT/bin/os-service" \
        "$OS_ROOT/bin/os-bridge" \
        "$OS_ROOT/bin/os-mirror"; do
        if [[ -x "$f" ]]; then
            printf '  %-45s OK\n' "$(basename "$f")"
        else
            printf '  %-45s MISSING or not executable\n' "$f" >&2
            failed=$(( failed + 1 ))
        fi
    done

    echo ""
    if [[ "$failed" -eq 0 ]]; then
        success "All self-tests passed."
    else
        warn "$failed test(s) failed."
    fi
    echo "════════════════════════════════════════"
    return "$failed"
}

# ---------------------------------------------------------------------------
# Build llama.cpp (optional)
# ---------------------------------------------------------------------------
build_llama() {
    info "Building llama.cpp..."
    if bash "$REPO_ROOT/build/build.sh" --target hosted; then
        success "llama.cpp built successfully."
    else
        warn "llama.cpp build failed. AI will use rule-based fallback."
    fi
}

# ---------------------------------------------------------------------------
# Start AIOS
# ---------------------------------------------------------------------------
start_aios() {
    info "Starting AIOS kernel..."
    export OS_ROOT
    sh "$OS_ROOT/etc/init.d/os-kernel" start
    sleep 1
    sh "$OS_ROOT/etc/init.d/aura-bridge" start
    sh "$OS_ROOT/etc/init.d/aura-agents" start
    sh "$OS_ROOT/etc/init.d/aura-tasks" start
    success "AIOS services started."
    info ""
    info "Launch the AI shell:      bash $REPO_ROOT/bin/aios"
    info "Launch the real shell:    OS_ROOT=$OS_ROOT bash $OS_ROOT/bin/os-real-shell"
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
echo "════════════════════════════════════════"
echo "  AIOS-Lite Installer"
echo "  Repo root : $REPO_ROOT"
echo "  OS_ROOT   : $OS_ROOT"
echo "════════════════════════════════════════"
echo ""

# --self-test: only run tests, no install
if [[ "$SELF_TEST" -eq 1 ]]; then
    make_executables
    create_dirs
    init_files
    self_test
    exit $?
fi

check_python
make_executables
create_dirs
init_files
verify_modules
detect_deps
setup_termux_boot
run_tests

if [[ "$BUILD_LLAMA" -eq 1 ]]; then
    build_llama
fi

if [[ "$START_AFTER" -eq 1 ]]; then
    start_aios
fi

echo ""
echo "════════════════════════════════════════"
success "Installation complete!"
echo ""
echo "Next steps:"
echo "  1. Launch the AI shell:   bash bin/aios"
echo "  2. Or start all services: bash install.sh --start"
echo ""

# Termux-specific guidance
if [[ -n "${TERMUX_VERSION:-}" ]] || [[ -d "/data/data/com.termux" ]]; then
    echo "Termux quick-start:"
    echo "  3. Start AIOS now:        bash OS/init.d/termux-boot.sh"
    echo "  4. Boot on device start:  install Termux:Boot (F-Droid), then:"
    echo "       bash install.sh  (run once — auto-configures ~/.termux/boot/)"
    echo "  5. Termux API commands:   pkg install termux-api"
    echo "       Then in os-shell: termux.notify | termux.battery | termux.clipboard"
    echo ""
fi

echo "To enable full AI (optional):"
echo "  3. Download a .gguf model to llama_model/"
echo "       https://huggingface.co/bartowski/Llama-3.2-3B-Instruct-GGUF"
echo "  4. Build llama.cpp:       bash build/build.sh --target hosted"
echo "  5. Edit etc/aios.conf:    AI_BACKEND=llama"
echo "       LLAMA_MODEL_PATH=<path-to>.gguf"
echo ""
echo "  Run tests at any time:"
echo "    AIOS_HOME=$(pwd) OS_ROOT=$OS_ROOT bash tests/unit-tests.sh"
echo "    bash install.sh --self-test    (full self-test suite)"
echo "    bash tests/integration-tests.sh  (if available)"
echo ""
echo "  Full documentation:  INSTALL.md  |  docs/AI_MODEL_SETUP.md  |  README.md"
echo "════════════════════════════════════════"
