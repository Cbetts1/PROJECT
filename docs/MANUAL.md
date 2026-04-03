# AIOS-Lite — Full Instruction Manual

**Version:** 0.1-alpha
**Author:** Christopher Betts
**Repository:** <https://github.com/Cbetts1/PROJECT>

> © 2026 Christopher Betts. All rights reserved.

---

## Table of Contents

1. [What Is AIOS-Lite?](#1-what-is-aios-lite)
2. [How It Works](#2-how-it-works)
3. [Architecture](#3-architecture)
4. [Installation](#4-installation)
5. [Operation](#5-operation)
6. [Updating](#6-updating)
7. [Repairing](#7-repairing)
8. [Extending](#8-extending)
9. [Troubleshooting](#9-troubleshooting)
10. [Glossary](#10-glossary)

---

## 1. What Is AIOS-Lite?

**AIOS-Lite** (Artificial Intelligence Operating System, Lite edition) is a portable, AI-augmented operating system implemented in POSIX shell script and Python. It provides a unified, natural-language-capable shell environment that can run on any Unix-like system and optionally connect to and mirror the filesystems of iOS devices, Android devices, and remote Linux/macOS servers.

### Key Properties

- **Portable** — The entire OS is a directory tree that can be copied to a USB drive, phone, or server and run from there.
- **AI-Powered** — User commands pass through a Python-based intent classification pipeline before being dispatched to specialist handlers. An optional local LLM (llama.cpp) provides free-form conversational responses.
- **Cross-OS** — Bridge modules enable connection to iOS, Android, and remote Linux/macOS hosts. Connected device filesystems are accessible through the `mirror/` namespace.
- **Self-contained** — The OS kernel requires only POSIX sh, awk, grep, sed, and cksum. No compiled binaries, no root access, no system-wide installation required.

### Primary Use Cases

- Personal AI assistant shell running on an Android phone (Termux)
- Portable development and administration environment on a USB drive
- Unified access point that bridges your phone, laptop, and remote server into a single shell
- Embedded automation agent on a Raspberry Pi or similar device

---

## 2. How It Works

When you launch `bin/aios`, the following sequence takes place:

```
1. Shell Initialization
   └─ bin/aios sources all lib/aura-*.sh modules
   └─ Configures OS_ROOT jail path
   └─ Starts REPL loop

2. User Input
   └─ Raw text entered at the prompt

3. Built-in Command Check
   └─ aios REPL checks for known built-in commands (ask, recall, mem.set, etc.)
   └─ If matched: executes directly in shell

4. AI Dispatch (for "ask" and unrecognised input)
   └─ lib/aura-ai.sh calls the Python AI backend
   └─ ai/core/ai_backend.py is invoked

5. Intent Classification
   └─ IntentEngine.classify(raw_input) in intent_engine.py
   └─ Returns Intent(category, action, entities, confidence)

6. Intent Routing
   └─ Router.dispatch(intent) in router.py
   └─ Iterates registered Bots; first bot whose can_handle() returns True handles it

7. Handler Execution
   └─ Bot.handle(intent) produces a response string
   └─ Fallback 1: commands.parse_natural_language()
   └─ Fallback 2: llama_client.chat() if LLM is available

8. Response Output
   └─ Response printed to terminal
   └─ Context window updated
```

The heartbeat daemon (`bin/aios-heartbeat`) runs independently in the background, checking configured targets at a set interval and logging results.

---

## 3. Architecture

### Layer Diagram

```
+=========================================================+
|                    USER INTERFACE                        |
|  bin/aios            bin/aios-sys      bin/aios-heartbeat|
|  (AI interactive)    (OS dispatcher)   (health monitor)  |
+==========================+==============================+
                           |
+==========================v==============================+
|                    AI CORE (Python)                      |
|                                                          |
|  ai/core/intent_engine.py                                |
|      classify(input) -> Intent                           |
|           |                                              |
|  ai/core/router.py                                       |
|      dispatch(intent) -> response                        |
|           |                                              |
|      +----+----+----+----+                               |
|      |    |    |    |    |                               |
|  Health Log Repair cmds  LLM                             |
|  Bot  Bot  Bot  .py  client.py                           |
+==========================+==============================+
                           |
+==========================v==============================+
|                AURA FRAMEWORK (Shell)                    |
|                                                          |
|  lib/aura-core.sh    (OS_ROOT jail, path rewriting)      |
|  lib/aura-fs.sh      (filesystem operations)             |
|  lib/aura-proc.sh    (process management)                |
|  lib/aura-net.sh     (network utilities)                 |
|  lib/aura-llm.sh     (LLM invocation wrapper)            |
|  lib/aura-ai.sh      (AI session management)             |
|  lib/aura-typo.sh    (typo correction)                   |
+==========================+==============================+
                           |
+==========================v==============================+
|              OS VIRTUAL ENVIRONMENT (OS/)                |
|                                                          |
|  OS/sbin/init         Boot init, rc2.d service start    |
|  OS/bin/os-shell      Interactive AI shell (inner)       |
|  OS/bin/os-bridge     Bridge detection and control       |
|  OS/bin/os-mirror     Device filesystem mounting         |
|  OS/lib/aura-bridge/  iOS, Android, SSH bridge modules  |
|  OS/lib/aura-memory/  Symbolic key-value memory store   |
|  OS/lib/aura-semantic/Semantic embedding index          |
|  OS/lib/aura-hybrid/  Hybrid recall engine              |
|  OS/lib/aura-policy/  Event-driven policy engine        |
|  OS/lib/aura-agents/  Background automation agents      |
|  OS/lib/aura-tasks/   Scheduled task runner             |
|  OS/etc/init.d/       Service scripts                    |
|  OS/etc/rc2.d/        Runlevel 2 symlinks                |
|  OS/proc/             Runtime state (PID, bridge status) |
|  OS/mirror/           Mounted device filesystems         |
|  OS/var/log/          System logs (auto-rotated 1000L)   |
+=========================================================+
```

### AI Intent Pipeline (Detail)

```
User: "show me the disk usage"
         |
         v
IntentEngine.classify()
  - Tokenises input
  - Checks rule table for trigger keywords
  - "disk", "usage" -> category="command", action="fs.df"
  - Returns Intent(category="command", action="fs.df",
                   entities=None, confidence=0.9)
         |
         v
Router.dispatch(intent)
  - Iterates [HealthBot, LogBot, RepairBot]
  - HealthBot.can_handle(intent): category=="health"? No
  - LogBot.can_handle(intent): category=="log"? No
  - RepairBot.can_handle(intent): category=="repair"? No
  - Fallback: commands.parse_natural_language(intent)
         |
         v
commands.parse_natural_language()
  - action "fs.df" -> executes df command via aios-sys
  - Returns formatted disk usage output
         |
         v
Response printed to terminal
```

### Cross-OS Bridge Architecture

```
+------------------------------------------+
|        AIOS-Lite Shell (bin/aios)        |
+------------------+-----------------------+
                   |
        bridge detection & dispatch
                   |
     +-------------+-------------+
     |             |             |
     v             v             v
+----------+ +-----------+ +----------+
| iOS      | | Android   | | Linux/   |
| Bridge   | | Bridge    | | SSH      |
| (libimob | | (ADB)     | | Bridge   |
|  ifuse)  | |           | | (SSHFS)  |
+----+-----+ +-----+-----+ +----+-----+
     |               |            |
     v               v            v
  iPhone/iPad    Android      Remote host
  filesystem     sdcard       filesystem
     |               |            |
     v               v            v
OS/mirror/ios/  OS/mirror/   OS/mirror/
                android/     linux/
```

---

## 4. Installation

### 4.1 Prerequisites

| Requirement | Minimum | Notes |
|---|---|---|
| Shell | POSIX sh | bash 4+ recommended |
| Python | 3.8 | For AI Core |
| Git | Any | For cloning and updating |

Optional (enable specific features):

```
libimobiledevice, ifuse    -> iOS bridge
adb (Android Debug Bridge) -> Android bridge
openssh, sshfs             -> SSH/Linux bridge
llama-cli (llama.cpp)      -> LLM natural language
```

### 4.2 Standard Installation

```sh
# 1. Clone the repository
git clone https://github.com/Cbetts1/PROJECT.git
cd PROJECT

# 2. Run the installer
bash install.sh

# 3. Launch the AI shell
bash bin/aios
```

### 4.3 Termux (Android)

```sh
# Install dependencies
pkg update
pkg install git python libimobiledevice ifuse android-tools openssh sshfs

# Clone and install
git clone https://github.com/Cbetts1/PROJECT.git
cd PROJECT
bash install.sh

# Launch
bash bin/aios
```

### 4.4 Debian / Ubuntu / Raspberry Pi

```sh
# Install dependencies
sudo apt update
sudo apt install git python3 libimobiledevice-utils ifuse adb openssh-client sshfs

# Clone and install
git clone https://github.com/Cbetts1/PROJECT.git
cd PROJECT
bash install.sh

# Launch
bash bin/aios
```

### 4.5 macOS

```sh
# Install dependencies via Homebrew
brew install libimobiledevice ifuse android-platform-tools openssh

# Clone and install
git clone https://github.com/Cbetts1/PROJECT.git
cd PROJECT
bash install.sh

# Launch
bash bin/aios
```

### 4.6 LLM Model Setup (Optional)

To enable full natural-language AI responses:

```sh
# 1. Build llama.cpp
bash build/build.sh --target hosted

# 2. Download a GGUF model
mkdir -p OS/llama_model
# 8 GB RAM: Mistral-7B-Instruct-v0.3-Q4_K_M.gguf (~4.4 GB)
# 6 GB RAM: Llama-3.2-3B-Instruct-Q4_K_M.gguf (~2.0 GB)
# wget -O OS/llama_model/model.gguf <model-download-url>

# 3. Configure the model path (if not auto-detected)
# Edit config/aios.conf:
# LLAMA_MODEL_PATH="OS/llama_model/model.gguf"
```

See [`docs/AI_MODEL_SETUP.md`](AI_MODEL_SETUP.md) for detailed LLM configuration.

### 4.7 Manual Boot (Without Installer)

```sh
cd PROJECT/OS
export OS_ROOT="$(pwd)"
export AIOS_HOME="$(dirname $(pwd))"
export PATH="$OS_ROOT/bin:$OS_ROOT/sbin:$PATH"
sh sbin/init
```

---

## 5. Operation

### 5.1 Starting the System

**Standard launch:**
```sh
bash bin/aios
```

**Launch with explicit configuration:**
```sh
AIOS_HOME=/path/to/PROJECT OS_ROOT=/path/to/PROJECT/OS bash bin/aios
```

**Launch heartbeat daemon (background):**
```sh
bash bin/aios-heartbeat &
```

**OS command dispatcher (non-interactive):**
```sh
bash bin/aios-sys -- df -h
bash bin/aios-sys -- ls OS/var/log/
```

### 5.2 Shell Modes

AIOS-Lite has three operating modes, switchable with the `mode` command:

| Mode | Description |
|---|---|
| `operator` | Default. Structured command mode. AI classifies and routes commands. |
| `system` | Low-level OS access. Commands pass directly to the OS shell. |
| `talk` | Conversational mode. All input goes to the LLM for free-form response. |

```sh
mode operator   # structured commands (default)
mode system     # direct OS access
mode talk       # conversational AI
```

### 5.3 Core Commands Reference

**AI and Memory**

```sh
ask "what is the system status?"      # Natural language query to AI
recall "phone I connected last week"  # Hybrid memory search
mem.set project "AIOS-Lite"           # Store a named fact
mem.get project                       # Retrieve a named fact
sem.set note "disk is 80 percent full" # Store semantic memory
sem.search "disk space issue"          # Semantic similarity search
```

**Device Bridging**

```sh
bridge.detect                         # Detect all connected devices
bridge.detect ios                     # Check for iOS devices specifically
mirror.mount ios                      # Mount iPhone filesystem
mirror.mount android                  # Mount Android sdcard
mirror.mount ssh user@192.168.1.10    # Mount remote Linux via SSH
mirror.mount auto                     # Mount best available device
mirror.ls ios                         # List mirrored iOS files
mirror.ls android
mirror.ls linux
```

**System Status**

```sh
status                                # Full OS state dump
services                              # Service health overview
help                                  # Complete command reference
sys df -h                             # Pass command to OS shell
```

### 5.4 Service Management

Services are defined in `OS/etc/init.d/` and started at boot via `OS/etc/rc2.d/` symlinks.

```sh
services                              # View all service statuses
os-service-status                     # Detailed service health report
os-kernelctl status                   # Kernel daemon status
os-event <event-name>                 # Fire a system event
```

PID files and health status files are stored in `OS/var/service/`.

### 5.5 Logging

All system logs are written to `OS/var/log/`. Logs are auto-rotated at 1000 lines.

```sh
# View system log
cat OS/var/log/system.log

# View AURA agent audit log
cat OS/var/log/aura.log

# View heartbeat log
cat OS/var/log/heartbeat.log

# Write to system log
os-log "Custom log entry"
```

---

## 6. Updating

### 6.1 Update via Git

```sh
cd PROJECT

# Fetch latest changes
git pull origin main

# Re-run the installer to apply any new configuration
bash install.sh
```

### 6.2 Update LLM Model

To replace the LLM model with a newer version:

```sh
# Remove old model
rm OS/llama_model/*.gguf

# Download and place new model
# wget -O OS/llama_model/model.gguf <new-model-url>
```

### 6.3 Update llama.cpp

```sh
# Rebuild from source
bash build/build.sh --target hosted
```

### 6.4 Preserve User Data During Updates

User memory, logs, and runtime state are stored under `OS/var/` and `OS/proc/`. These directories are **not** overwritten by `git pull` or `install.sh`. No special action is needed to preserve user data across updates.

---

## 7. Repairing

### 7.1 Reset to Clean State

To clear all runtime state without losing user memory:

```sh
# Clear process state
rm -f OS/proc/*.pid OS/proc/*.state

# Restart init
bash OS/sbin/init
```

### 7.2 Clear Logs

```sh
# Truncate all logs (does not delete memory or configuration)
find OS/var/log/ -name "*.log" -exec truncate -s 0 {} \;
```

### 7.3 Rebuild Configuration

If configuration files are corrupted or missing:

```sh
# Re-run installer (does not overwrite OS/var/ data)
bash install.sh
```

### 7.4 Re-Pair iOS Device

If the iOS bridge stops responding:

```sh
# Unpair and re-pair
idevicepair unpair
idevicepair pair
idevicepair validate
mirror.mount ios
```

### 7.5 Fix ADB Android Bridge

```sh
# Kill and restart ADB server
adb kill-server
adb start-server
adb devices
mirror.mount android
```

### 7.6 Diagnose AI Core Failures

```sh
# Test Python AI Core directly
python3 tests/test_python_modules.py

# Test with a specific input
python3 -c "
from ai.core.intent_engine import IntentEngine
ie = IntentEngine()
print(ie.classify('show disk usage'))
"
```

### 7.7 Diagnose Shell Module Failures

```sh
# Source a module manually and test
source lib/aura-core.sh
source lib/aura-fs.sh
# Then call functions directly
```

---

## 8. Extending

### 8.1 Adding a New Shell Command

Shell commands are registered in `lib/aura-ai.sh` and the main REPL in `bin/aios`.

1. Add your command logic as a function in the appropriate `lib/aura-*.sh` module (or a new file).
2. Register it in the `bin/aios` REPL command dispatcher.
3. Add help text to the `help` output section.
4. Add unit tests in `tests/unit-tests.sh`.

### 8.2 Adding a New AI Bot

Bots live in `ai/core/bots.py` and extend `BaseBot`.

```python
from ai.core.bots import BaseBot
from ai.core.intent_engine import Intent

class MyBot(BaseBot):
    def can_handle(self, intent: Intent) -> bool:
        return intent.category == "mycat"

    def handle(self, intent: Intent) -> str:
        return f"Handled by MyBot: {intent.action}"
```

Register your bot in `ai/core/router.py` by adding it to the bot list in `Router.__init__`.

### 8.3 Adding a New Bridge Module

Bridge modules are located in `OS/lib/aura-bridge/`. Each module is a shell script that implements:

- `bridge_detect()` — check if the device type is present
- `bridge_connect()` — establish the connection
- `bridge_mount()` — mount the filesystem into `OS/mirror/<type>/`
- `bridge_disconnect()` — cleanly unmount and disconnect

Source your new module in `OS/bin/os-bridge`.

### 8.4 Adding a New Service

1. Create a service script in `OS/etc/init.d/my-service` following the existing service script pattern.
2. Create a symlink in `OS/etc/rc2.d/`:
   ```sh
   ln -s ../init.d/my-service OS/etc/rc2.d/S50my-service
   ```
3. The service will start automatically on next boot.

### 8.5 Adding AURA Agents

Background automation agents are configured in `OS/etc/aura/agents.conf`. Each agent specifies:

- A trigger condition (event name or schedule)
- A shell command or script to run

See `OS/lib/aura-agents/` for implementation details.

### 8.6 Adding Scheduled Tasks

Tasks are configured in `OS/etc/aura/tasks.conf`. Format:

```
<interval_seconds> <command>
```

Example:
```
300 os-log "5-minute heartbeat checkpoint"
```

---

## 9. Troubleshooting

### 9.1 `bash bin/aios` exits immediately with no output

**Cause:** Missing dependency or configuration error.

**Fix:**
```sh
# Check for syntax errors in AURA modules
bash -n lib/aura-core.sh
bash -n lib/aura-ai.sh
bash -n bin/aios

# Ensure AIOS_HOME and OS_ROOT are set
export AIOS_HOME=$(pwd)
export OS_ROOT=$(pwd)/OS
bash bin/aios
```

---

### 9.2 `ask` command returns no response

**Cause 1:** Python AI Core is not starting correctly.
```sh
python3 ai/core/ai_backend.py "test"
```

**Cause 2:** AI_BACKEND is set to "mock" — mock backend returns empty.
Check `etc/aios.conf`: `AI_BACKEND="llama"` or `AI_BACKEND="mock"`.

---

### 9.3 LLM returns no response / hangs

**Cause 1:** No model file present.
```sh
ls OS/llama_model/
# Should contain at least one .gguf file
```

**Cause 2:** `llama-cli` is not installed or not in PATH.
```sh
which llama-cli
# If not found: bash build/build.sh --target hosted
```

**Cause 3:** Insufficient memory. Check `config/aios.conf` for `DEVICE_RAM_GB` and use a smaller model.

---

### 9.4 iOS bridge fails (`mirror.mount ios` has no output)

**Step 1:** Check libimobiledevice is installed.
```sh
ideviceinfo -s
```

**Step 2:** Pair the device.
```sh
idevicepair pair
idevicepair validate
```

**Step 3:** Check ifuse is installed.
```sh
which ifuse
```

**Step 4:** Ensure the device is trusted (accept the "Trust this computer?" prompt on the device).

---

### 9.5 Android bridge shows no devices

```sh
# Verify ADB sees the device
adb devices
# If empty: enable USB debugging on the Android device
# Settings -> Developer Options -> USB Debugging -> On
# Accept the "Allow USB debugging?" dialog on the device

# Restart ADB server
adb kill-server && adb start-server
adb devices
```

---

### 9.6 SSH/SSHFS bridge fails

```sh
# Test SSH connectivity first
ssh user@192.168.1.100 "echo OK"

# Check sshfs is installed
which sshfs

# Try mounting manually
sshfs user@192.168.1.100:/ OS/mirror/linux/test/ -o reconnect
```

---

### 9.7 Heartbeat daemon crashes on start

```sh
# Check environment variables
echo "HEARTBEAT_TARGETS: $HEARTBEAT_TARGETS"

# Run manually with debug output
bash -x bin/aios-heartbeat
```

---

### 9.8 Logs grow too large

Logs are auto-rotated at 1000 lines. If a log file is unexpectedly large:

```sh
# Manually truncate
truncate -s 0 OS/var/log/system.log
```

---

### 9.9 Running Tests

```sh
# Full unit test suite
AIOS_HOME=$(pwd) OS_ROOT=$(pwd)/OS bash tests/unit-tests.sh

# Full integration test suite
AIOS_HOME=$(pwd) OS_ROOT=$(pwd)/OS bash tests/integration-tests.sh

# Python AI Core tests only
python3 tests/test_python_modules.py
```

---

## 10. Glossary

| Term | Definition |
|---|---|
| **AIOS-Lite** | AI-Augmented Portable Operating System, Lite edition |
| **AURA** | Autonomous Unified Resource Agent — the AIOS-Lite automation and memory framework |
| **OS_ROOT** | The root directory of the virtual OS environment. All OS file operations are sandboxed to this path. |
| **AIOS_HOME** | The root of the AIOS-Lite project repository. |
| **Intent** | A structured representation of user intent produced by the IntentEngine: `{category, action, entities, confidence}`. |
| **IntentEngine** | Python NLP classifier (`ai/core/intent_engine.py`) that converts raw text into an Intent object. |
| **Router** | Python dispatcher (`ai/core/router.py`) that routes an Intent to the appropriate Bot or fallback handler. |
| **Bot** | A Python class extending BaseBot that handles a specific category of intents (HealthBot, LogBot, RepairBot). |
| **LLM** | Large Language Model — a neural network for natural language understanding and generation. AIOS-Lite uses llama.cpp for local inference. |
| **GGUF** | A binary model format used by llama.cpp. Model files end in `.gguf`. |
| **llama.cpp** | An open-source LLM inference engine optimised for CPU/mobile hardware. Used as AIOS-Lite's optional LLM backend. |
| **Bridge** | A subsystem that connects AIOS-Lite to an external device or host (iOS, Android, SSH). |
| **Mirror** | The `OS/mirror/` directory namespace where bridged device filesystems are mounted. |
| **ADB** | Android Debug Bridge — a command-line tool for communicating with Android devices. |
| **libimobiledevice** | An open-source library for communicating with iOS devices. |
| **ifuse** | A FUSE-based tool for mounting iOS device filesystems. |
| **SSHFS** | SSH Filesystem — mounts remote filesystems over SSH. |
| **Hybrid Memory** | AIOS-Lite's three-layer memory system: context window + symbolic store + semantic index. |
| **Context Window** | A rolling log of recent commands and conversation turns, used as short-term AI memory. |
| **Symbolic Memory** | A key-value store for named facts, accessible with `mem.set` / `mem.get`. |
| **Semantic Memory** | An embedding-based index for similarity search, accessible with `sem.set` / `sem.search`. |
| **Heartbeat** | A periodic health check performed by `bin/aios-heartbeat` to verify that monitored targets are alive. |
| **POSIX** | Portable Operating System Interface — a family of standards for Unix-like operating systems. |
| **rc2.d** | A SysV-style runlevel directory. Symlinks here point to service scripts that are started automatically at boot. |
| **init** | The first process executed by the OS (`OS/sbin/init`). Starts all rc2.d services. |
| **Q4_K_M** | A quantisation format for GGUF models (4-bit, K-means, medium quality). Balances quality and memory footprint. |

---

*AIOS-Lite Instruction Manual — © 2026 Christopher Betts. All rights reserved.*
