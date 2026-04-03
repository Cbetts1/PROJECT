#!/usr/bin/env bash
# bootstrap-sd.sh — AIOS Portable SD-Card / External-Storage Bootstrap
# © 2026 Chris Betts | AIOSCPU Official | AI-generated, fully legal
#
# Prepares a target directory (SD card, USB drive, or any external storage)
# for running AIOS-Lite entirely self-contained.  After bootstrap, the device
# can boot AIOS on *any* Unix-like host without modifying the host system.
#
# Usage:
#   bash bootstrap-sd.sh [options]
#
# Options:
#   --target <path>        Root path of the SD card / external volume
#                          (default: /media/sdcard  or $AIOS_SD_TARGET)
#   --source <path>        AIOS repo root to copy from
#                          (default: directory containing this script)
#   --model <file>         Path to a .gguf LLaMA model to embed on device
#   --no-model             Skip model embedding (default if --model not given)
#   --autoboot             Write a boot entry (init.sh) that auto-starts AIOS
#   --dry-run              Show what would be done without writing anything
#   --help | -h            Show this help text
#
# The resulting layout on the target device:
#
#   <target>/
#   ├── AIOS/                   ← project root (all scripts, libs, configs)
#   │   ├── OS/                 ← OS_ROOT virtualised file system
#   │   ├── ai/                 ← AI Core (intent engine, router, bots)
#   │   ├── bin/                ← aios, aios-sys, aios-heartbeat
#   │   ├── lib/                ← aura shell modules
#   │   ├── config/             ← aios.conf, llama-settings.conf
#   │   ├── docs/               ← documentation
#   │   └── install.sh          ← on-device installer
#   ├── llama_model/            ← (optional) embedded .gguf model
#   └── init.sh                 ← (optional) auto-boot entry point

set -euo pipefail

# ---------------------------------------------------------------------------
# Defaults
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_ROOT="${AIOS_SD_SOURCE:-$SCRIPT_DIR}"
TARGET_ROOT="${AIOS_SD_TARGET:-/media/sdcard}"
MODEL_FILE=""
AUTOBOOT=0
DRY_RUN=0

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------
while [[ $# -gt 0 ]]; do
    case "$1" in
        --target)    TARGET_ROOT="$2"; shift 2 ;;
        --source)    SOURCE_ROOT="$2"; shift 2 ;;
        --model)     MODEL_FILE="$2";  shift 2 ;;
        --no-model)  MODEL_FILE="";    shift   ;;
        --autoboot)  AUTOBOOT=1;       shift   ;;
        --dry-run)   DRY_RUN=1;        shift   ;;
        --help|-h)
            sed -n '3,40p' "$0"
            exit 0
            ;;
        *) echo "Unknown option: $1" >&2; exit 1 ;;
    esac
done

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
info()    { echo "[bootstrap-sd] $*"; }
success() { echo "[bootstrap-sd] ✓ $*"; }
warn()    { echo "[bootstrap-sd] ⚠  $*" >&2; }
die()     { echo "[bootstrap-sd] ✗ $*" >&2; exit 1; }

run() {
    if [[ $DRY_RUN -eq 1 ]]; then
        echo "[DRY-RUN] $*"
    else
        "$@"
    fi
}

require_cmd() {
    command -v "$1" &>/dev/null || die "Required command not found: $1"
}

# ---------------------------------------------------------------------------
# Pre-flight checks
# ---------------------------------------------------------------------------
info "Source : $SOURCE_ROOT"
info "Target : $TARGET_ROOT"

[[ -d "$SOURCE_ROOT" ]] || die "Source directory not found: $SOURCE_ROOT"

if [[ $DRY_RUN -eq 0 ]]; then
    [[ -d "$TARGET_ROOT" ]] || die "Target directory not found: $TARGET_ROOT  (mount it first, or create it)"
fi

require_cmd rsync
require_cmd python3

# ---------------------------------------------------------------------------
# 1. Copy AIOS project tree to target
# ---------------------------------------------------------------------------
AIOS_TARGET="$TARGET_ROOT/AIOS"
info "Syncing AIOS tree → $AIOS_TARGET ..."

RSYNC_EXCLUDES=(
    --exclude='.git'
    --exclude='__pycache__'
    --exclude='*.pyc'
    --exclude='*.pyo'
    --exclude='.DS_Store'
    --exclude='OS/var/log/*.log'
    --exclude='OS/var/events/*.event'
    --exclude='OS/tmp/*'
    --exclude='var/log/*.log'
    --exclude='var/run/*'
    --exclude='llama_model/*.gguf'     # model added separately below
    --exclude='build/llama.cpp'        # large build artifact
)

run rsync -a --delete "${RSYNC_EXCLUDES[@]}" \
    "$SOURCE_ROOT/" "$AIOS_TARGET/"

success "AIOS tree synced."

# ---------------------------------------------------------------------------
# 2. Fix permissions
# ---------------------------------------------------------------------------
info "Setting executable bits ..."
run find "$AIOS_TARGET" \( \
    -name "*.sh"           -o \
    -name "os-*"           -o \
    -name "aios*"          -o \
    -name "init"           -o \
    -name "install.sh"     -o \
    -name "bootstrap-sd.sh"\
\) -exec chmod +x {} \;

success "Permissions set."

# ---------------------------------------------------------------------------
# 3. Initialise runtime directories (idempotent)
# ---------------------------------------------------------------------------
info "Initialising OS runtime directories ..."
OS_ROOT_ON_SD="$AIOS_TARGET/OS"

run mkdir -p \
    "$OS_ROOT_ON_SD/var/log" \
    "$OS_ROOT_ON_SD/var/service" \
    "$OS_ROOT_ON_SD/var/events" \
    "$OS_ROOT_ON_SD/var/pkg" \
    "$OS_ROOT_ON_SD/proc/aura/context" \
    "$OS_ROOT_ON_SD/proc/aura/memory" \
    "$OS_ROOT_ON_SD/proc/aura/semantic" \
    "$OS_ROOT_ON_SD/proc/aura/bridge" \
    "$OS_ROOT_ON_SD/mirror/ios" \
    "$OS_ROOT_ON_SD/mirror/android" \
    "$OS_ROOT_ON_SD/mirror/linux" \
    "$OS_ROOT_ON_SD/tmp" \
    2>/dev/null || true

# Seed empty log files if absent
for logfile in os.log aura.log events.log; do
    if [[ ! -f "$OS_ROOT_ON_SD/var/log/$logfile" ]]; then
        run touch "$OS_ROOT_ON_SD/var/log/$logfile"
    fi
done

success "Runtime directories ready."

# ---------------------------------------------------------------------------
# 4. Embed LLaMA model (optional)
# ---------------------------------------------------------------------------
MODEL_DIR="$TARGET_ROOT/llama_model"
if [[ -n "$MODEL_FILE" ]]; then
    if [[ ! -f "$MODEL_FILE" ]]; then
        warn "Model file not found: $MODEL_FILE — skipping."
    else
        info "Embedding model: $(basename "$MODEL_FILE") ..."
        run mkdir -p "$MODEL_DIR"
        run cp "$MODEL_FILE" "$MODEL_DIR/"
        # Update config to reference the embedded model
        CONF="$AIOS_TARGET/config/aios.conf"
        if [[ -f "$CONF" ]]; then
            run sed -i \
                "s|^LLAMA_MODEL_PATH=.*|LLAMA_MODEL_PATH=\"$MODEL_DIR/$(basename "$MODEL_FILE")\"|" \
                "$CONF"
        fi
        success "Model embedded."
    fi
else
    info "No model specified (--model not given). Place a .gguf file in $MODEL_DIR/ manually."
    run mkdir -p "$MODEL_DIR"
fi

# ---------------------------------------------------------------------------
# 5. Write auto-boot entry point (optional)
# ---------------------------------------------------------------------------
INIT_SCRIPT="$TARGET_ROOT/init.sh"
if [[ $AUTOBOOT -eq 1 ]]; then
    info "Writing auto-boot script: $INIT_SCRIPT ..."
    if [[ $DRY_RUN -eq 0 ]]; then
        cat > "$INIT_SCRIPT" << 'BOOT_SCRIPT'
#!/usr/bin/env bash
# init.sh — AIOS auto-boot entry point for SD card / external storage
# Run this script from the root of the mounted device to start AIOS.
set -euo pipefail
DEVICE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AIOS_HOME="$DEVICE_ROOT/AIOS"
OS_ROOT="$AIOS_HOME/OS"
export AIOS_HOME OS_ROOT
export PATH="$OS_ROOT/bin:$OS_ROOT/sbin:$AIOS_HOME/bin:$PATH"
echo "[init.sh] Starting AIOS from: $AIOS_HOME"
exec sh "$OS_ROOT/sbin/init"
BOOT_SCRIPT
        chmod +x "$INIT_SCRIPT"
    else
        echo "[DRY-RUN] Would write $INIT_SCRIPT"
    fi
    success "Auto-boot script written."
fi

# ---------------------------------------------------------------------------
# 6. Verify Python environment
# ---------------------------------------------------------------------------
info "Verifying Python 3 availability ..."
if python3 -c "import sys; assert sys.version_info >= (3,9)" 2>/dev/null; then
    success "Python 3 available: $(python3 --version)"
else
    warn "Python 3.9+ not found on this host. The AI Core requires it at runtime."
fi

# ---------------------------------------------------------------------------
# 7. Self-test (smoke check) — only in live mode
# ---------------------------------------------------------------------------
if [[ $DRY_RUN -eq 0 ]]; then
    info "Running smoke test: filesystem.py ..."
    FS_PY="$OS_ROOT_ON_SD/lib/filesystem.py"
    if [[ -f "$FS_PY" ]]; then
        result=$(OS_ROOT="$OS_ROOT_ON_SD" python3 "$FS_PY" exists proc/aura 2>/dev/null || true)
        if [[ "$result" == "true" ]]; then
            success "filesystem.py smoke test passed."
        else
            warn "filesystem.py smoke test returned: $result (proc/aura may not exist yet — run init first)."
        fi
    else
        warn "filesystem.py not found — check rsync output above."
    fi
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo
echo "════════════════════════════════════════"
echo "  AIOS SD Bootstrap Complete"
echo "════════════════════════════════════════"
echo "  Device root : $TARGET_ROOT"
echo "  AIOS home   : $AIOS_TARGET"
echo "  OS root     : $OS_ROOT_ON_SD"
if [[ -n "$MODEL_FILE" && -f "$MODEL_DIR/$(basename "${MODEL_FILE:-x}")" ]]; then
    echo "  LLaMA model : $MODEL_DIR/$(basename "$MODEL_FILE")"
else
    echo "  LLaMA model : not embedded (add manually to $MODEL_DIR/)"
fi
echo
echo "To start AIOS on any Unix host:"
if [[ $AUTOBOOT -eq 1 ]]; then
    echo "  bash $INIT_SCRIPT"
else
    echo "  export OS_ROOT=$OS_ROOT_ON_SD"
    echo "  export AIOS_HOME=$AIOS_TARGET"
    echo "  export PATH=\"\$OS_ROOT/bin:\$OS_ROOT/sbin:\$PATH\""
    echo "  sh \$OS_ROOT/sbin/init"
fi
echo "════════════════════════════════════════"
