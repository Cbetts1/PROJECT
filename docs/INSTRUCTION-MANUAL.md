# AIOS-Lite / AIOSCPU — Complete Instruction Manual

> © 2026 Christopher Betts | AIOSCPU Official | AI-generated, fully legal

*Version 1.4.0 — Last updated: 2026-04-03*

---

## Table of Contents

1. [Overview](#1-overview)
2. [Installation](#2-installation)
3. [Operation](#3-operation)
4. [Updating](#4-updating)
5. [Repairing](#5-repairing)
6. [Extending](#6-extending)
7. [Troubleshooting](#7-troubleshooting)
8. [Glossary](#8-glossary)

---

## 1. Overview

### 1.1 What Is AIOS-Lite?

AIOS-Lite is a lightweight, AI-powered operating system built entirely in
POSIX shell script and Python 3. It runs on any Unix-like environment —
Android (Termux), Linux, or macOS — and provides:

- **A pseudo-kernel** with syscalls, scheduling, permissions, and resource
  management, all running in user-space
- **An AI shell** powered by a local LLaMA language model (or rule-based
  fallback) with three-layer memory (context, symbolic, semantic)
- **A cross-OS bridge** that connects to iOS, Android, Linux, and remote
  SSH hosts, mirroring their filesystems into a unified namespace
- **A service registry** and event bus for managing background processes
- **A REST/WebSocket API** for programmatic access

### 1.2 AIOSCPU

AIOSCPU is the native x86-64 / ARM64 bootable build of AIOS-Lite — a
Buildroot-based Linux system with AIOS pre-installed, bootable from a USB
drive or as a virtual machine image.

### 1.3 System Architecture

```
┌───────────────────────────────────────────────────────────────┐
│                     User / AI Shell Layer                      │
│         os-shell  |  os-real-shell  |  bin/aios               │
└────────────────────────────┬──────────────────────────────────┘
                             │ os-syscall
┌────────────────────────────▼──────────────────────────────────┐
│                    AIOS Pseudo-Kernel                          │
│  os-kernelctl | os-syscall | os-sched | os-perms              │
│  os-resource  | os-recover | os-service | os-event            │
└────────────────────────────┬──────────────────────────────────┘
                             │ OS_ROOT filesystem jail
┌────────────────────────────▼──────────────────────────────────┐
│              OS_ROOT Virtual Filesystem (OS/)                  │
│  bin/  sbin/  etc/  lib/  proc/  var/  mirror/  tmp/          │
└────────────────────────────┬──────────────────────────────────┘
                             │ host OS boundary
┌────────────────────────────▼──────────────────────────────────┐
│          Host OS (Android/Linux/macOS) + Bridge Layer          │
│   iOS (libimobiledevice)  |  Android (ADB)  |  Linux (SSH)    │
└───────────────────────────────────────────────────────────────┘
```

### 1.4 Key Concepts

| Concept | Description |
|---------|-------------|
| `OS_ROOT` | Virtual filesystem root — all AIOS file I/O stays inside |
| `AIOS_HOME` | Repository root directory |
| Principal | A named permission role: `operator`, `aura`, `service` |
| Capability | A namespaced permission token: e.g. `fs.read`, `proc.kill` |
| Syscall | A kernel operation invoked via `os-syscall <name> [args]` |
| AURA | The AI agent (Autonomous Unified Resource Agent) |
| Bridge | Connection to an external device or remote system |
| Mirror | Device filesystem exposed under `OS_ROOT/mirror/` |

---

## 2. Installation

### 2.1 System Requirements

**Minimum (no LLM):**

```
POSIX sh, Python 3.9+, awk, grep, sed, cksum, 32 MB RAM, 20 MB disk
```

**Recommended (with LLaMA):**

```
Python 3.11+, 4–8 GB RAM, 5 GB disk, 4+ CPU cores
```

### 2.2 Quick Install

```sh
git clone https://github.com/Cbetts1/PROJECT.git
cd PROJECT
sh install.sh
```

### 2.3 Manual Install

```sh
# 1. Clone
git clone https://github.com/Cbetts1/PROJECT.git ~/aios
cd ~/aios

# 2. Set environment (add to ~/.bashrc or ~/.zshrc)
export AIOS_HOME="$HOME/aios"
export OS_ROOT="$AIOS_HOME/OS"
export PATH="$OS_ROOT/bin:$OS_ROOT/sbin:$AIOS_HOME/bin:$PATH"

# 3. Boot the OS tree
sh OS/sbin/init

# 4. Launch the AI shell
os-shell
```

### 2.4 Platform-Specific

**Android / Termux:**
```sh
pkg update && pkg install git python python-pip libimobiledevice ifuse android-tools openssh sshfs
git clone https://github.com/Cbetts1/PROJECT.git ~/aios && cd ~/aios && sh install.sh
```

**Debian / Ubuntu:**
```sh
sudo apt install git python3 python3-pip libimobiledevice-utils ifuse adb openssh-client sshfs
git clone https://github.com/Cbetts1/PROJECT.git ~/aios && cd ~/aios && sh install.sh
```

**macOS:**
```sh
brew install git python3 libimobiledevice android-platform-tools
git clone https://github.com/Cbetts1/PROJECT.git ~/aios && cd ~/aios && sh install.sh
```

### 2.5 AI Model Setup (Optional)

```sh
# Create model directory
mkdir -p "$AIOS_HOME/llama_model"

# Download a GGUF model from Hugging Face (example)
# For 8 GB RAM: llama-3.2-7B-Instruct-Q4_K_M.gguf
# For 6 GB RAM: llama-3.2-3B-Instruct-Q4_K_M.gguf

# Build llama.cpp
bash build/build.sh --target hosted

# Configure (edit config/aios.conf)
LLAMA_MODEL="$AIOS_HOME/llama_model/your-model.gguf"
LLAMA_BINARY="$AIOS_HOME/build/llama.cpp/build/bin/llama-cli"
```

### 2.6 Verification

```sh
# Check OS state
os-info

# Run full test suite
AIOS_HOME=$(pwd) OS_ROOT=$(pwd)/OS bash tests/unit-tests.sh
AIOS_HOME=$(pwd) OS_ROOT=$(pwd)/OS bash tests/integration-tests.sh

# Check service health
os-service-status
```

---

## 3. Operation

### 3.1 Starting AIOS

```sh
# Load environment (if not already in ~/.bashrc)
export AIOS_HOME="/path/to/PROJECT"
export OS_ROOT="$AIOS_HOME/OS"
export PATH="$OS_ROOT/bin:$OS_ROOT/sbin:$AIOS_HOME/bin:$PATH"

# Boot the OS
sh OS/sbin/init

# Launch AI shell
os-shell
```

### 3.2 The AI Shell

The AI shell presents an `aios>` prompt. Type commands or natural language:

```
aios> ask how much memory is available
RAM: 5.2 GB available of 8.0 GB (65% free)

aios> mem.set my_phone "Samsung Galaxy S21 FE"
Stored: my_phone = Samsung Galaxy S21 FE

aios> recall what phone do I use
my_phone: Samsung Galaxy S21 FE (from symbolic memory)

aios> services
SERVICE         STATUS    PID    UPTIME
kernel          RUNNING   12345  2h 14m
aura-agent      RUNNING   12400  2h 13m
health-monitor  RUNNING   12450  2h 13m

aios> exit
```

### 3.3 Shell Modes

```sh
aios> mode operator    # Full system access (default)
aios> mode system      # OS admin commands only
aios> mode talk        # Pure AI conversation
```

### 3.4 Key Commands

```sh
# System info
status          # Full OS state
sysinfo         # Hardware info
os-info         # Friendly system display
os-state        # Raw state dump

# AI memory
mem.set key value           # Store named fact
mem.get key                 # Retrieve fact
recall "what was my query"  # Hybrid recall

# Services
services                    # Service health
os-service start <name>     # Start service
os-service stop  <name>     # Stop service

# Bridge
bridge.detect               # Detect connected devices
mirror.mount ios            # Mount iPhone
mirror.mount android        # Mount Android
mirror.ls android           # Browse Android files
mirror.unmount ios          # Unmount iPhone

# AI
ask <question>              # Ask AURA a question
```

### 3.5 Cross-OS Bridge

```
ASCII Bridge Diagram

┌─────────────────────────────────────┐
│        AIOS-Lite Shell              │
└─────────────────┬───────────────────┘
                  │ bridge layer (OS/lib/aura-bridge/)
       ┌──────────┼───────────┐
       ▼          ▼           ▼
  iOS Bridge  Android Bridge  Linux Bridge
  (ifuse/     (ADB/TCP)       (SSH/SSHFS)
  libimob)
       │          │           │
       ▼          ▼           ▼
   iPhone      Android     Linux/macOS
   iPad        Device      Remote Server
       │          │           │
       └──────────┴───────────┘
                  │
            OS_ROOT/mirror/
            ├── ios/
            ├── android/
            ├── linux/
            └── custom/
```

```sh
# iOS
os-bridge ios pair
os-mirror mount ios
ls $OS_ROOT/mirror/ios/

# Android (USB debugging required)
os-bridge android devices
os-mirror mount android
cat $OS_ROOT/mirror/android/_sdcard.listing

# Remote Linux via SSH
os-mirror mount ssh user@192.168.1.100
ls $OS_ROOT/mirror/linux/ssh_192.168.1.100/
```

### 3.6 Memory System

```
Three-Layer Memory Architecture

┌────────────────────────────────────────┐
│            Hybrid Recall               │
│         (recall "query")               │
└────────┬───────────┬───────────────────┘
         │           │           │
         ▼           ▼           ▼
┌──────────────┐ ┌──────────────┐ ┌──────────────┐
│   Context    │ │  Symbolic    │ │  Semantic    │
│   Window     │ │  Memory      │ │  Memory      │
│ (last 50     │ │ (key-value   │ │ (embedding   │
│  lines)      │ │  index)      │ │  search)     │
│ proc/aura/   │ │ proc/aura.   │ │ lib/aura-    │
│ context/     │ │ memory       │ │ semantic/    │
└──────────────┘ └──────────────┘ └──────────────┘
```

```sh
mem.set name "Christopher Betts"        # Store fact
sem.set device_info "Samsung S21 FE"    # Store semantic entry
recall "who am I"                        # Search all three layers
```

### 3.7 HTTP API

Enable in `config/aios.conf`:

```sh
HTTPD_ENABLED=true
HTTPD_PORT=8080
HTTPD_TOKEN=your-secret-token
```

Start the server:

```sh
os-service start os-httpd
```

Query examples:

```sh
# Health check (unauthenticated)
curl http://localhost:8080/health

# OS state (authenticated)
curl -H "Authorization: Bearer your-secret-token" \
     http://localhost:8080/api/v1/state

# Ask the AI
curl -X POST -H "Authorization: Bearer your-secret-token" \
     -H "Content-Type: application/json" \
     -d '{"message":"how much disk space?"}' \
     http://localhost:8080/api/v1/ai/ask
```

Full endpoint reference: `config/api-endpoints.conf` and
`docs/API-REFERENCE.md`.

---

## 4. Updating

### 4.1 Update AIOS-Lite

```sh
cd "$AIOS_HOME"

# Stop running services
os-kernelctl stop

# Pull latest changes
git pull origin main

# Re-run boot init (recreates any new directories/files)
sh OS/sbin/init

# Restart services
os-kernelctl start
```

### 4.2 Update the AI Model

```sh
# Place new model in llama_model/
cp ~/downloads/new-model.Q4_K_M.gguf "$AIOS_HOME/llama_model/"

# Update config/aios.conf
LLAMA_MODEL="$AIOS_HOME/llama_model/new-model.Q4_K_M.gguf"

# Restart AURA agent
os-service restart aura-agent
```

### 4.3 Update llama.cpp

```sh
cd "$AIOS_HOME"
git submodule update --remote build/llama.cpp 2>/dev/null || \
    git -C build/llama.cpp pull origin master
bash build/build.sh --target hosted
```

### 4.4 Backup Before Updating

```sh
OS_ROOT=$AIOS_HOME/OS sh OS/bin/os-recover backup
# Backup stored in OS/var/backup/
```

---

## 5. Repairing

### 5.1 Integrity Check (No Changes)

```sh
OS_ROOT=$AIOS_HOME/OS sh OS/bin/os-recover check
```

Output includes:
- Missing directories
- Missing required files
- Stale PID files
- Oversized log files
- Missing host binaries

### 5.2 Full Repair

```sh
OS_ROOT=$AIOS_HOME/OS sh OS/bin/os-recover repair
```

Five recovery stages:

```
Stage 1 — Directory/File Repair
  ✓ Recreate missing OS_ROOT directories
  ✓ Touch missing required files

Stage 2 — State File Repair
  ✓ Restore proc/os.state from defaults if corrupt/missing
  ✓ Restore proc/os.identity

Stage 3 — Service Cleanup
  ✓ Remove stale .pid files for dead processes
  ✓ Reset .health files to "stopped" for dead services

Stage 4 — Log Rotation
  ✓ Trim any log file over 1000 lines to 500 lines

Stage 5 — Dependency Audit
  ✓ Verify sh, python3, awk, grep, sed, cksum are available
  ⚠ Warn about optional missing tools (adb, ideviceinfo, etc.)
```

### 5.3 Recovery Mode Boot

If the OS fails to boot, use recovery mode:

```sh
# Edit OS/etc/boot.target
echo "recovery" > "$AIOS_HOME/OS/etc/boot.target"

# Boot — will run os-recover repair instead of normal init
sh OS/sbin/init
```

Reset to normal boot after repair:

```sh
echo "default" > "$AIOS_HOME/OS/etc/boot.target"
```

### 5.4 Common Repair Scenarios

**Corrupt OS state:**
```sh
rm -f "$OS_ROOT/proc/os.state"
OS_ROOT=$AIOS_HOME/OS sh OS/bin/os-recover repair
```

**Stale service PIDs preventing startup:**
```sh
rm -f "$OS_ROOT/var/service/"*.pid
os-kernelctl start
```

**Full reset (WARNING: deletes all memory):**
```sh
os-kernelctl stop
rm -f "$OS_ROOT/var/log/"*
rm -f "$OS_ROOT/proc/os.state" "$OS_ROOT/proc/aura.memory"
rm -rf "$OS_ROOT/proc/aura/"
OS_ROOT=$AIOS_HOME/OS sh OS/bin/os-recover repair
os-kernelctl start
```

---

## 6. Extending

### 6.1 Adding a New AI Bot

Create a new bot in `ai/core/bots.py`:

```python
from ai.core.bots import BaseBot

class WeatherBot(BaseBot):
    name = "weather"
    intents = ["weather", "temperature", "forecast"]

    def handle(self, intent, context):
        location = context.get("location", "unknown")
        # Implement your weather query here
        return f"Weather for {location}: sunny, 22°C"
```

Register it in `ai/core/router.py`:

```python
from ai.core.bots import HealthBot, LogBot, RepairBot, WeatherBot

BOTS = [HealthBot(), LogBot(), RepairBot(), WeatherBot()]
```

### 6.2 Adding a New Shell Command

Add to `OS/bin/os-shell` (or create a new binary in `OS/bin/`):

```sh
# In os-shell command dispatch section:
mycommand)
    echo "My custom command output"
    ;;
```

Or create a standalone script:

```sh
#!/bin/sh
# OS/bin/os-mycommand
# Description: My custom command
. "$OS_ROOT/lib/aura-core.sh"
echo "Hello from my command"
```

Make it executable:

```sh
chmod +x "$OS_ROOT/bin/os-mycommand"
```

### 6.3 Adding a New Service

1. Create the init.d script:

```sh
#!/bin/sh
# OS/etc/init.d/my-service
SERVICE_NAME="my-service"
SERVICE_CMD="sh $OS_ROOT/bin/my-service-daemon"
SERVICE_PID="$OS_ROOT/var/service/my-service.pid"

start() {
    $SERVICE_CMD &
    echo $! > "$SERVICE_PID"
    echo "my-service started"
}
stop() {
    kill "$(cat $SERVICE_PID 2>/dev/null)" 2>/dev/null
    rm -f "$SERVICE_PID"
}
case "$1" in
    start) start ;;
    stop)  stop  ;;
    restart) stop; start ;;
    *) echo "Usage: $0 {start|stop|restart}" ;;
esac
```

2. Register it:

```sh
os-service register my-service "sh $OS_ROOT/etc/init.d/my-service start"
```

3. Enable at boot by adding to `config/services.conf`:

```ini
[my-service]
cmd=sh $OS_ROOT/etc/init.d/my-service start
restart=on-failure
priority=10
deps=kernel
enabled=true
log=my-service.log
```

### 6.4 Adding a New Bridge Module

Create `OS/lib/aura-bridge/mydevice.mod`:

```sh
#!/bin/sh
# Bridge module for MyDevice
# Required functions: start, stop, status, detect

BRIDGE_NAME="mydevice"
BRIDGE_MOUNT="$OS_ROOT/mirror/custom/mydevice"

detect() {
    # Return 0 if device is connected, 1 if not
    command -v mydevice-tool >/dev/null 2>&1 && mydevice-tool list | grep -q "."
}

start() {
    mkdir -p "$BRIDGE_MOUNT"
    mydevice-tool mount "$BRIDGE_MOUNT" && echo "Mounted mydevice at $BRIDGE_MOUNT"
}

stop() {
    umount "$BRIDGE_MOUNT" 2>/dev/null || true
    echo "Unmounted mydevice"
}

status() {
    mountpoint -q "$BRIDGE_MOUNT" && echo "MOUNTED" || echo "UNMOUNTED"
}
```

### 6.5 Adding a Loadable Module

Place your module in `OS/lib/aura-mods/`:

```sh
# OS/lib/aura-mods/my-mod.sh
AURA_MOD_NAME="my-mod"
AURA_MOD_VERSION="1.0"

aura_mod_init() {
    echo "[my-mod] Initialised"
}

aura_mod_cmd_myaction() {
    echo "[my-mod] Executing myaction"
}
```

Load it at runtime:

```sh
. "$OS_ROOT/lib/aura-mods/my-mod.sh"
aura_mod_init
aura_mod_cmd_myaction
```

### 6.6 Adding a New Scheduled Task

Create `OS/etc/aura/tasks/my-task.task`:

```sh
TASK_NAME="my-task"
TASK_CMD="sh $OS_ROOT/bin/my-periodic-script"
TASK_INTERVAL=3600    # every hour
TASK_PRIORITY=15
TASK_ENABLED=true
```

The task will be picked up automatically on next boot or:

```sh
os-service restart aura-tasks
```

### 6.7 Extending the Permissions Model

Add a new principal:

```sh
# OS/etc/perms.d/myplugin.caps
fs.read
fs.list
log.read
memory.read
ai.ask
```

Check permissions in your code:

```sh
os-perms check myplugin fs.write   # exit 1 — denied
os-perms check myplugin fs.read    # exit 0 — granted
```

---

## 7. Troubleshooting

### 7.1 Diagnostic Commands

```sh
os-info                          # System info
os-state                         # OS runtime state
os-kernelctl status              # Kernel daemon health
os-service-status                # All service statuses
os-resource status               # CPU/memory/disk/thermal
OS_ROOT=$AIOS_HOME/OS sh OS/bin/os-recover check   # Integrity check
```

### 7.2 Common Problems and Solutions

#### `os-shell: command not found`

```sh
# Cause: $OS_ROOT/bin not in PATH
export PATH="$OS_ROOT/bin:$OS_ROOT/sbin:$AIOS_HOME/bin:$PATH"
```

#### `OS_ROOT is not set`

```sh
# Cause: Environment not loaded
export AIOS_HOME="/path/to/PROJECT"
export OS_ROOT="$AIOS_HOME/OS"
sh OS/sbin/init
```

#### AI returns "mock response" / "rule-based fallback"

```
Cause: No GGUF model found or llama-cli not installed.
Solution:
  1. Place a .gguf model in llama_model/
  2. Install llama.cpp (bash build/build.sh --target hosted)
  3. Set LLAMA_MODEL and LLAMA_BINARY in config/aios.conf
```

#### iOS bridge: "No iOS device found"

```sh
# Step 1: Install libimobiledevice
sudo apt install libimobiledevice-utils ifuse   # Debian
pkg install libimobiledevice ifuse               # Termux

# Step 2: Pair the device
idevicepair pair
# Accept the trust dialog on the iPhone

# Step 3: Verify
ideviceinfo | head -5

# Step 4: Mount
os-bridge ios pair
os-mirror mount ios
```

#### Android bridge: "no devices found"

```sh
# Step 1: Enable USB Debugging on Android
# (Settings → Developer Options → USB Debugging)

# Step 2: Verify USB connection
adb devices
# Accept the "Allow USB debugging" dialog on the phone

# Step 3: Mount
os-bridge android devices
os-mirror mount android
```

#### SSH bridge: "connection refused"

```sh
# Verify SSH server is running on remote host
ssh user@host -p 22 "echo ok"

# If key auth fails, set up SSH keys
ssh-keygen -t ed25519
ssh-copy-id user@host
```

#### Kernel heartbeat crash loop

```sh
# Stop the loop
os-kernelctl stop

# Remove stale PIDs
rm -f "$OS_ROOT/var/service/"*.pid

# Run recovery
OS_ROOT=$AIOS_HOME/OS sh OS/bin/os-recover repair

# Restart
os-kernelctl start
```

#### Log file too large / disk space warning

```sh
# Rotate immediately
OS_ROOT=$AIOS_HOME/OS sh OS/bin/os-recover log_rotate

# Or manually truncate
tail -500 "$OS_ROOT/var/log/os.log" > /tmp/os.log.tmp
mv /tmp/os.log.tmp "$OS_ROOT/var/log/os.log"
```

#### Permission denied on os-perms check

```sh
# Check what capabilities your principal has
os-perms list operator
os-perms list aura

# Temporarily grant capability (not persistent)
os-perms grant aura fs.write

# Or edit the capability file
echo "fs.write" >> "$OS_ROOT/etc/perms.d/aura.caps"
```

### 7.3 Log Locations

| Log file | Contents |
|----------|---------|
| `OS/var/log/os.log` | Main system log |
| `OS/var/log/aura.log` | AURA AI agent log |
| `OS/var/log/syscall.log` | System call audit log |
| `OS/var/log/bridge.log` | Cross-OS bridge log |
| `OS/var/log/perms.log` | Permission check audit log |
| `OS/var/log/os-httpd.log` | HTTP server log |
| `OS/var/log/health.log` | Health monitoring log |
| `OS/var/log/tasks.log` | Scheduled task log |

### 7.4 Running the Tests

```sh
# Unit tests (57 total: 17 shell + 40 Python)
AIOS_HOME=$(pwd) OS_ROOT=$(pwd)/OS bash tests/unit-tests.sh

# Integration tests (87 total)
AIOS_HOME=$(pwd) OS_ROOT=$(pwd)/OS bash tests/integration-tests.sh

# Python modules only
python3 tests/test_python_modules.py

# Verbose Python test output
python3 -m pytest tests/test_python_modules.py -v
```

---

## 8. Glossary

| Term | Definition |
|------|-----------|
| **AIOS** | AI-augmented Operating System |
| **AIOS-Lite** | The portable, user-space implementation of AIOS |
| **AIOSCPU** | Native bootable build of AIOS-Lite |
| **AURA** | Autonomous Unified Resource Agent — the AI daemon |
| **OS_ROOT** | Virtual filesystem root; all AIOS file I/O is jailed here |
| **AIOS_HOME** | Repository root directory |
| **Pseudo-kernel** | User-space kernel abstraction (no hardware privilege rings) |
| **Principal** | A named permission role: `operator`, `aura`, `service` |
| **Capability** | A namespaced permission token: e.g. `fs.read` |
| **Syscall** | A kernel operation invoked via `os-syscall` |
| **Bridge** | A connection to an external device (iOS, Android, Linux) |
| **Mirror** | A device filesystem exposed under `OS_ROOT/mirror/` |
| **Intent** | A classified user query type (health, log, repair, etc.) |
| **Bot** | A specialist AI handler (HealthBot, LogBot, RepairBot) |
| **GGUF** | AI model file format used by llama.cpp |
| **rc2.d** | Runlevel-2 service scripts, named S##-<service> |
| **Heartbeat** | Periodic kernel poll to check service health |
| **Hybrid recall** | Combined context + symbolic + semantic memory search |
| **Semantic memory** | Embedding-based similarity search memory |
| **Symbolic memory** | Named key-value fact store |
| **Context window** | Rolling 50-line recent interaction history |
| **SSHFS** | SSH Filesystem — mount remote directories over SSH |
| **ADB** | Android Debug Bridge — USB/TCP tool for Android devices |
| **libimobiledevice** | Open-source iOS device communication library |
| **ifuse** | Mount iOS filesystem via FUSE |
| **llama.cpp** | High-performance C++ LLaMA inference engine |
| **Runlevel** | System operation mode (2 = normal, 0 = halt, 6 = reboot) |
| **init.d** | Service script directory (one script per service) |
| **PID** | Process ID — numeric identifier for a running process |
| **nice** | POSIX process priority value (-20 to +19) |
| **SIGTERM** | Graceful shutdown signal |
| **SIGKILL** | Force-kill signal (immediate, no cleanup) |
| **SIGHUP** | Reload configuration signal |

---

*© 2026 Christopher Betts | AIOSCPU Official | AI-generated, fully legal*  
*Repository: <https://github.com/Cbetts1/PROJECT>*
