# AI-OS — Development Guide

> © 2026 Christopher Betts | AIOSCPU Official  
> *Created and developed by Christopher Betts. All code was generated or refined using AI tools under the creator's direction.*

---

## Table of Contents

1. [Development Philosophy](#1-development-philosophy)
2. [Repository Layout](#2-repository-layout)
3. [Development Environment Setup](#3-development-environment-setup)
4. [Building AI-OS](#4-building-ai-os)
5. [Running AI-OS Locally](#5-running-ai-os-locally)
6. [Testing](#6-testing)
7. [Adding OS Commands](#7-adding-os-commands)
8. [Adding Services](#8-adding-services)
9. [Extending AURA (New Bots and Intents)](#9-extending-aura-new-bots-and-intents)
10. [Writing Plugins (aura-mods)](#10-writing-plugins-aura-mods)
11. [Networking Module Development](#11-networking-module-development)
12. [Bridge Module Development](#12-bridge-module-development)
13. [AI Shell Development](#13-ai-shell-development)
14. [Coding Standards](#14-coding-standards)
15. [Debugging](#15-debugging)
16. [Building the AIOSCPU Disk Image](#16-building-the-aioscpu-disk-image)
17. [Contributing](#17-contributing)
18. [Versioning and Release Process](#18-versioning-and-release-process)

---

## 1. Development Philosophy

AI-OS is built on three principles:

1. **AI-First** — The OS is not a shell with AI bolted on. The AI is the CPU.
   Every design decision favors AI-native operation over legacy shell convention.

2. **POSIX-Portable** — AI-OS runs on any POSIX host without modification.
   Shell code uses `#!/bin/sh` (POSIX sh, not bash-only) except where bash
   features are explicitly required (the `bin/aios` shell uses `bash`).

3. **Layered and Auditable** — Every cross-layer call goes through a defined
   interface. No layer reaches around another. Every OS action is logged.

---

## 2. Repository Layout

```
PROJECT/
├── OS/                   AI-OS virtual root (OS_ROOT)
│   ├── sbin/init         PID-1 boot script
│   ├── bin/              OS commands (os-shell, os-bridge, os-ai, ...)
│   ├── lib/              AURA OS-level modules
│   ├── etc/              Configuration (init.d/, rc2.d/, perms.d/)
│   ├── proc/             Runtime state files
│   ├── dev/              Virtual devices
│   ├── mirror/           Connected device mount points
│   └── var/              Logs, events, service files
│
├── ai/core/              Python AI pipeline
│   ├── intent_engine.py  Intent classification
│   ├── router.py         Intent → handler routing
│   ├── bots.py           HealthBot, LogBot, RepairBot
│   ├── commands.py       Structured command dispatch
│   ├── llama_client.py   llama.cpp subprocess client
│   ├── fuzzy.py          Fuzzy command matching
│   └── ai_backend.py     Top-level pipeline
│
├── bin/                  Host-level entry points
│   ├── aios              AI shell (primary entry)
│   ├── aios-sys          Raw OS shell
│   └── aios-heartbeat    Background daemon
│
├── lib/                  AURA shell library (sourced by bin/aios)
│   ├── aura-core.sh      Core, include guards
│   ├── aura-ai.sh        AI dispatch
│   ├── aura-fs.sh        Filesystem operations
│   ├── aura-net.sh       Network operations
│   ├── aura-proc.sh      Process operations
│   ├── aura-llama.sh     LLM backend
│   ├── aura-security.sh  Permissions
│   └── aura-typo.sh      Typo correction
│
├── config/               Configuration files
├── aura/                 AURA agent (AIOSCPU variant)
├── aioscpu/              Bootable disk image builder
├── build/                llama.cpp build scripts
├── mirror/               Overlay manager
├── tools/                Operator scripts
├── tests/                Tests
├── docs/                 Documentation
└── branding/             Brand assets
```

---

## 3. Development Environment Setup

### Minimum Requirements

- `bash` 4.0+ (for `bin/aios`)
- `sh` (any POSIX shell for `OS/sbin/init`)
- Python 3.8+
- `git`

### Optional (for full features)

- `adb` (Android bridge)
- `libimobiledevice` + `ifuse` (iOS bridge)
- `sshfs` (SSH bridge)
- `nmcli` or `wpa_cli` (WiFi control on Linux)
- `bluetoothctl` (Bluetooth on Linux)
- llama.cpp binary + model (AI CPU)

### Setup on Debian/Ubuntu

```bash
sudo apt-get update
sudo apt-get install -y \
    git bash python3 python3-pip \
    android-tools-adb \
    libimobiledevice-utils ifuse fuse \
    sshfs \
    network-manager bluetooth bluez \
    build-essential cmake

# Clone
git clone https://github.com/Cbetts1/PROJECT.git
cd PROJECT

# Permissions
chmod +x bin/* tools/* OS/bin/* OS/sbin/*

# Python deps (minimal — stdlib only by default)
# If using semantic memory:
pip3 install numpy sqlite3
```

### Setup on Termux (Android)

```bash
pkg update && pkg upgrade -y
pkg install -y \
    git bash python openssh \
    android-tools \
    termux-api

# Clone
git clone https://github.com/Cbetts1/PROJECT.git
cd PROJECT
chmod +x bin/* OS/bin/* OS/sbin/*
```

### Setup on macOS

```bash
brew install git python3 libimobiledevice android-platform-tools \
             sshfs

git clone https://github.com/Cbetts1/PROJECT.git
cd PROJECT
chmod +x bin/* tools/* OS/bin/* OS/sbin/*
```

---

## 4. Building AI-OS

AI-OS is primarily interpreted (shell + Python) and does not need compilation
except for the optional llama.cpp AI CPU backend.

### Build llama.cpp (AI CPU Backend)

```bash
# Hosted / server build
bash build/build.sh --target hosted

# For Termux (Android ARM)
bash build/build.sh --target termux
```

This clones llama.cpp, compiles it for the current platform, and places the
binary at `llama_model/llama-cli` (or `llama_model/main`).

### Build AIOSCPU Disk Image

The AIOSCPU disk image is a bootable Debian-based ISO with AI-OS pre-installed.

```bash
cd aioscpu/build
make          # Requires: debootstrap, grub, xorriso, squashfs-tools
```

See `docs/BUILDING-IMAGE.md` for full instructions.

---

## 5. Running AI-OS Locally

### Start the AI Shell

```bash
./bin/aios
```

This is the standard way to run AI-OS. It:
1. Loads all `lib/aura-*.sh` modules
2. Boots the OS if not already booted (`OS/sbin/init` auto-ran)
3. Presents the `aios>` prompt

### Start the Raw OS Shell

```bash
./bin/aios-sys
```

Drops directly to the OS-level shell without the AI layer. Useful for
debugging OS commands independently.

### Boot the OS Manually

```bash
export AIOS_HOME=$(pwd)
export OS_ROOT=$(pwd)/OS
export PATH="$OS_ROOT/bin:$OS_ROOT/sbin:$PATH"
sh OS/sbin/init --no-shell
```

`--no-shell` boots all services but does not exec into a shell, letting you
inspect the state programmatically.

### Run Health Check

```bash
AIOS_HOME=$(pwd) OS_ROOT=$(pwd)/OS bash tools/health_check.sh
```

---

## 6. Testing

### Run All Tests

```bash
# Unit tests (shell + Python)
AIOS_HOME=$(pwd) OS_ROOT=$(pwd)/OS bash tests/unit-tests.sh

# Integration tests
AIOS_HOME=$(pwd) OS_ROOT=$(pwd)/OS bash tests/integration-tests.sh
```

### Run Python AI Core Tests Only

```bash
python3 tests/test_python_modules.py
```

### Test Structure

| File | Contents |
|---|---|
| `tests/unit-tests.sh` | Shell unit tests + calls `test_python_modules.py` |
| `tests/integration-tests.sh` | Full boot + service integration tests |
| `tests/test_python_modules.py` | Python tests for `ai/core/` modules |

### Writing Shell Tests

Shell tests follow this pattern:

```sh
# In tests/unit-tests.sh
test_os_log_write() {
    local out
    out=$(OS_ROOT="$OS_ROOT" "$OS_ROOT/bin/os-log" write INFO test "test message" 2>&1)
    assert_exit 0 $?
    assert_contains "$OS_ROOT/var/log/os.log" "test message"
}
```

### Writing Python Tests

Python tests use `unittest`:

```python
# In tests/test_python_modules.py
import unittest
from ai.core.intent_engine import IntentEngine

class TestIntentEngine(unittest.TestCase):
    def setUp(self):
        self.engine = IntentEngine()

    def test_health_intent(self):
        intent = self.engine.classify("what is my system health")
        self.assertEqual(intent, "system.health")
```

---

## 7. Adding OS Commands

OS commands live in `OS/bin/`. They follow a strict set of conventions.

### Command Template

```sh
#!/bin/sh
# OS/bin/os-mycommand — Short description
# © 2026 Christopher Betts

# Require OS_ROOT
: "${OS_ROOT:?OS_ROOT is not set}"

# Load common functions if needed
. "$OS_ROOT/../lib/aura-core.sh" 2>/dev/null || true

PROG="os-mycommand"

usage() {
    echo "Usage: $PROG <subcommand> [args]"
    echo "  subcommand1  - does thing 1"
    echo "  subcommand2  - does thing 2"
}

log() {
    echo "[$(date +%s)] INFO  $PROG: $*" >> "$OS_ROOT/var/log/os.log"
}

case "${1:-}" in
    subcommand1)
        log "doing thing 1"
        # ... implementation
        ;;
    subcommand2)
        log "doing thing 2"
        # ... implementation
        ;;
    *)
        usage
        exit 1
        ;;
esac
```

### Registration

Register your command by making it executable:

```bash
chmod +x OS/bin/os-mycommand
```

To expose it as a syscall, add an entry to `docs/SYSCALL-LIST.md` and
optionally add a dispatch entry in `ai/core/commands.py`.

---

## 8. Adding Services

Services are defined in `OS/etc/init.d/` and enabled in `OS/etc/rc2.d/`.

### Service Definition File

```sh
# OS/etc/init.d/my-service.service
SERVICE_NAME="my-service"
SERVICE_CMD="$OS_ROOT/bin/os-mycommand daemon"
SERVICE_DEPS="logging events"
SERVICE_CAPS="net.read"
SERVICE_HEALTH_CMD="os-mycommand status"
SERVICE_RESTART="on-failure"
SERVICE_USER="aios"
```

### Boot Script

```sh
# OS/etc/rc2.d/S11-my-service
#!/bin/sh
. "$OS_ROOT/etc/init.d/my-service.service"

start() {
    $SERVICE_CMD &
    echo $! > "$OS_ROOT/var/service/my-service.pid"
    echo "[$(date +%s)] INFO  init: my-service started" >> "$OS_ROOT/var/log/os.log"
}

stop() {
    local pid
    pid=$(cat "$OS_ROOT/var/service/my-service.pid" 2>/dev/null)
    [ -n "$pid" ] && kill "$pid" 2>/dev/null
    rm -f "$OS_ROOT/var/service/my-service.pid"
}

case "${1:-start}" in
    start) start ;;
    stop)  stop ;;
esac
```

Enable by making it executable and giving it the correct S## prefix.

---

## 9. Extending AURA (New Bots and Intents)

### Add a New Intent

In `ai/core/intent_engine.py`, add your intent pattern:

```python
INTENT_PATTERNS = {
    # ... existing patterns ...
    "myfeature.action": [
        r"\bmy keyword\b",
        r"\bmy other keyword\b",
    ],
}
```

### Add a New Bot

In `ai/core/bots.py`:

```python
class MyFeatureBot(BaseBot):
    """Handles myfeature.action intents."""

    INTENT = "myfeature.action"

    def handle(self, intent: str, context: dict) -> str:
        # Perform the action
        result = self._run_os_command(["os-mycommand", "subcommand1"])
        return f"Done: {result}"
```

### Register the Bot

In `ai/core/router.py`, register your bot:

```python
from .bots import HealthBot, LogBot, RepairBot, MyFeatureBot

BOTS = [
    HealthBot(),
    LogBot(),
    RepairBot(),
    MyFeatureBot(),   # ← add here
]
```

### Test

```python
# tests/test_python_modules.py
def test_myfeature_intent(self):
    intent = self.engine.classify("do my keyword thing")
    self.assertEqual(intent, "myfeature.action")
```

---

## 10. Writing Plugins (aura-mods)

The `OS/lib/aura-mods/` directory is AI-OS's plugin system. Any `.sh` file
dropped there is automatically sourced by `bin/aios` at startup.

### Plugin Template

```sh
# OS/lib/aura-mods/my-plugin.sh
# My Plugin — adds 'myplugin' command to the AI shell

# Guard against double-sourcing
[ -n "$__MYPLUGIN_LOADED" ] && return 0
__MYPLUGIN_LOADED=1

# Register command handler
aura_register_cmd "myplugin" "_myplugin_handler"

_myplugin_handler() {
    local subcmd="$1"; shift
    case "$subcmd" in
        hello)
            echo "Hello from my plugin!"
            ;;
        *)
            echo "Usage: myplugin hello"
            ;;
    esac
}
```

Plugins can use any of the `lib/aura-*.sh` functions since those modules are
loaded before `aura-mods/` is scanned.

---

## 11. Networking Module Development

Network operations are implemented in two places:

- `lib/aura-net.sh` — shell-level AURA network functions
- `OS/bin/os-netconf` — OS command for network configuration

### Adding a New Network Operation

1. Add the implementation to `lib/aura-net.sh`:

```sh
# lib/aura-net.sh

net_myop() {
    # Validate OS_ROOT
    : "${OS_ROOT:?}"
    
    # Platform dispatch
    if _is_termux; then
        termux-myop "$@"
    elif _is_macos; then
        networksetup -myop "$@"
    else
        # Linux default
        ip myop "$@"
    fi
}
```

2. Expose as a subcommand in `OS/bin/os-netconf`:

```sh
case "${1:-}" in
    myop)
        shift
        . "$AIOS_HOME/lib/aura-net.sh"
        net_myop "$@"
        ;;
    # ...
esac
```

3. Add intent pattern if natural language control is needed:

```python
# ai/core/intent_engine.py
"net.myop": [r"\bmy network operation\b"]
```

---

## 12. Bridge Module Development

Bridge modules connect AI-OS to external devices. They live in `OS/lib/aura-bridge/`.

### Bridge Module Structure

```sh
# OS/lib/aura-bridge/my-device.sh

bridge_mydevice_detect() {
    # Return 0 if device found, 1 if not
    mydevice-tool check >/dev/null 2>&1
}

bridge_mydevice_mount() {
    local mountpoint="$OS_ROOT/mirror/mydevice"
    mkdir -p "$mountpoint"
    mydevice-tool mount "$mountpoint"
    echo "[$(date +%s)] INFO  bridge: mydevice mounted at $mountpoint" \
        >> "$OS_ROOT/var/log/os.log"
}

bridge_mydevice_unmount() {
    local mountpoint="$OS_ROOT/mirror/mydevice"
    umount "$mountpoint" 2>/dev/null || fusermount -u "$mountpoint" 2>/dev/null
    rmdir "$mountpoint" 2>/dev/null
}

bridge_mydevice_status() {
    mountpoint -q "$OS_ROOT/mirror/mydevice" && echo "mounted" || echo "unmounted"
}
```

Register by adding detection and dispatch to `OS/bin/os-bridge`:

```sh
# OS/bin/os-bridge
case "${1:-}" in
    detect)
        # ... existing detects ...
        . "$OS_ROOT/lib/aura-bridge/my-device.sh"
        bridge_mydevice_detect && echo "mydevice: found"
        ;;
    mydevice)
        shift
        . "$OS_ROOT/lib/aura-bridge/my-device.sh"
        "bridge_mydevice_${1:-status}"
        ;;
esac
```

---

## 13. AI Shell Development

The AI shell (`bin/aios`) is the primary user-facing component. It must remain
fast, responsive, and AI-aware.

### Shell Loop Structure

```sh
# bin/aios (simplified)

while true; do
    # Read input
    read -r -p "aios> " INPUT || break
    [ -z "$INPUT" ] && continue

    # Step 1: Typo correction
    INPUT=$(aura_typo_correct "$INPUT")

    # Step 2: Command classification
    if aura_is_structured_cmd "$INPUT"; then
        # Dispatch to handler (fs.*, net.*, proc.*, ...)
        aura_dispatch_cmd "$INPUT"
    else
        # Natural language → AI pipeline
        aura_ai_query "$INPUT"
    fi
done
```

### Adding a New Shell Command

1. Add to the dispatch table in `lib/aura-core.sh`:

```sh
# lib/aura-core.sh
aura_dispatch_cmd() {
    local cmd="$1"; shift
    case "$cmd" in
        mycmd)         _mycmd_handler "$@" ;;
        # ... existing ...
    esac
}
```

2. Implement the handler (inline or in a new `lib/aura-mycmd.sh`).

3. Add typo variants in `lib/aura-typo.sh` if needed.

### Prompt Engineering for LLM Calls

LLM context is constructed in `lib/aura-ai.sh`. To add OS state to the
context window:

```sh
aura_build_context() {
    local state
    state=$(cat "$OS_ROOT/proc/os.state" 2>/dev/null | head -20)
    
    printf "System state:\n%s\n\n" "$state"
    printf "Running services:\n%s\n\n" \
        "$(ls "$OS_ROOT/var/service/"*.pid 2>/dev/null | xargs -I{} basename {} .pid)"
}
```

---

## 14. Coding Standards

### Shell Scripts

- Shebang: `#!/bin/sh` for OS commands; `#!/usr/bin/env bash` for `bin/aios`
- Error handling: always check return codes; use `set -e` in init scripts
- OS_ROOT: always validate with `: "${OS_ROOT:?OS_ROOT is not set}"`
- Logging: write to `$OS_ROOT/var/log/os.log` with `[timestamp] LEVEL component: message` format
- Include guards: all modules use `[ -n "$__MODULE_LOADED" ] && return 0`
- No bashisms in `OS/sbin/init` or `OS/bin/` scripts — POSIX sh only

### Python

- Python 3.8+ compatible
- Type hints on all public functions
- Docstrings on all classes and public methods
- No external dependencies beyond stdlib (unless explicitly approved)
- Tests for all new public functions in `tests/test_python_modules.py`

### File Permissions

```bash
chmod 755 OS/bin/*        # Executable OS commands
chmod 755 OS/sbin/init    # Boot script
chmod 755 bin/*           # Entry points
chmod 644 OS/etc/*        # Config files
chmod 644 lib/*.sh        # Shell libraries (sourced, not exec'd)
chmod 644 ai/core/*.py    # Python modules
```

### Commit Message Format

```
type(scope): short description

body (optional, wrap at 72 chars)
```

Types: `feat`, `fix`, `docs`, `test`, `refactor`, `chore`

Examples:
```
feat(ai): add NetworkBot for net.wifi.* intents
fix(bridge): handle ADB reconnect after USB disconnect
docs(arch): update boot pipeline diagram
```

---

## 15. Debugging

### Enable Debug Logging

```bash
export AIOS_LOG_LEVEL=DEBUG
./bin/aios
```

### Watch Live Log

```bash
tail -f OS/var/log/os.log
tail -f OS/var/log/aura.log
```

### Inspect OS State

```bash
cat OS/proc/os.state
OS/bin/os-state show
```

### Check Service Health

```bash
OS_ROOT=$(pwd)/OS OS/bin/os-service-health
```

### Test AI Pipeline Directly

```bash
# Test intent classification
python3 -c "
import sys; sys.path.insert(0, '.')
from ai.core.intent_engine import IntentEngine
e = IntentEngine()
print(e.classify('what is my system health'))
"

# Test full pipeline
python3 -c "
import sys; sys.path.insert(0, '.')
from ai.core.ai_backend import handle_input
print(handle_input('list running services'))
"
```

### Test LLM Backend

```bash
# Check if llama.cpp binary exists
ls llama_model/

# Run a test query
AIOS_HOME=$(pwd) OS_ROOT=$(pwd)/OS python3 -c "
from ai.core.llama_client import LlamaClient
c = LlamaClient()
print(c.query('hello'))
"
```

### Shell Debug Mode

```bash
bash -x bin/aios 2>&1 | head -50
sh -x OS/sbin/init --no-shell 2>&1 | head -100
```

---

## 16. Building the AIOSCPU Disk Image

The AIOSCPU disk image is a bootable Debian-based ISO with AI-OS pre-installed
and GRUB as the bootloader. It supports two boot modes: AI (AURA active) and
Shell (standard getty).

### Build Requirements

```bash
sudo apt-get install -y \
    debootstrap squashfs-tools xorriso \
    grub-pc-bin grub-efi-amd64-bin \
    mtools dosfstools
```

### Build

```bash
cd aioscpu/build
sudo make
```

Output: `aioscpu-aurora-1.0.iso`

### GRUB Configuration

```cfg
# aioscpu/build/grub.cfg
set timeout=5
set default=0

menuentry "AI-OS Aurora — AI Mode" {
    linux  /boot/vmlinuz quiet aioscpu_mode=ai
    initrd /boot/initrd.img
}

menuentry "AI-OS Aurora — Shell Mode" {
    linux  /boot/vmlinuz quiet aioscpu_mode=shell
    initrd /boot/initrd.img
}
```

### Rootfs Overlay

Files in `aioscpu/rootfs-overlay/` are copied into the image root. This is
where AIOS-specific system units and configuration are placed.

See `docs/BUILDING-IMAGE.md` for the full build walkthrough.

---

## 17. Contributing

1. Fork the repository
2. Create a feature branch: `git checkout -b feat/my-feature`
3. Make changes following the coding standards
4. Run the full test suite: `bash tests/unit-tests.sh && bash tests/integration-tests.sh`
5. Commit with a descriptive message
6. Open a pull request

Read `CONTRIBUTING.md` for the full contribution guide and `docs/GOVERNANCE.md`
for the project governance model.

---

## 18. Versioning and Release Process

AI-OS uses [Semantic Versioning](https://semver.org/) (`MAJOR.MINOR.PATCH`).

| Component | Triggers MAJOR | Triggers MINOR | Triggers PATCH |
|---|---|---|---|
| Public API (`os-*` commands) | Breaking changes | New commands | Bug fixes |
| AURA pipeline | Breaking intent changes | New bots/intents | Bug fixes |
| Service model | Service protocol changes | New services | Bug fixes |
| Documentation | — | New documents | Corrections |

### Release Checklist

1. `bash tests/unit-tests.sh` — all pass
2. `bash tests/integration-tests.sh` — all pass
3. Update `CHANGELOG.md`
4. Update `OS/etc/os-release` version
5. Tag: `git tag -a v1.0.0 -m "AI-OS Aurora 1.0"`
6. Push tag to trigger release workflow
7. Publish release notes in `docs/RELEASE-NOTES.md`

See `docs/RELEASE-ENGINEERING.md` for the full release engineering guide.
