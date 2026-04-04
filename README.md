# AIOS — AI Operating System Shell

**An AI-native interactive OS shell for Linux, macOS, and Termux (Android)**

```
   ___  ___ ___  ___ ___ ___  _   _
  / _ \|_ _/ _ \/ __/ __| _ \| | | |
 | (_) || || (_) \__ \__ \  _/ |_| |
  \__,_|___\___/|___/___/_|  \___/

   ___  ___
  / _ \/ __|
 | (_) \__ \
  \___/|___/

    _   ___ ___
   /_\ |_ _/ _ \  ___
  / _ \ | | (_) |/ __|
 /_/ \_\___\___/ \___|
```

> *"Not an app. Not a shell script. An operating system."*

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Platform: Termux · Linux · macOS · Darwin](https://img.shields.io/badge/platform-Termux%20%7C%20Linux%20%7C%20macOS%20%7C%20Darwin-lightgrey)](docs/INSTALL.md)
[![AI: LLaMA / llama.cpp](https://img.shields.io/badge/AI-LLaMA%20%2F%20llama.cpp-orange)](docs/AI_MODEL_SETUP.md)
[![AI-OS Version](https://img.shields.io/badge/AI--OS-v1.0--Aurora-blueviolet)](docs/RELEASE-NOTES.md)

---

## What Is AIOS?

**AIOS** (AI Operating System) is a portable, AI-augmented interactive shell
environment. It runs on any POSIX host (Linux, macOS, Android via Termux) and
provides:

- A **confined virtual filesystem** (`fs.*` commands) rooted at `OS/`
- A **natural-language AI backend** — type plain English and AIOS interprets it
- A **fuzzy typo-correction** engine for command names
- **Process and network utilities** (`proc.*`, `net.*`)
- An **escape hatch** (`sys`) to the real host shell when needed
- Optional **LLaMA LLM integration** via [llama.cpp](https://github.com/ggerganov/llama.cpp)

### OS Identity

| Property | Value |
|---|---|
| **Name** | AIOS (AI Operating System) |
| **Edition** | Aurora v1.0 |
| **Codename** | AIOSCPU |
| **Cognitive Layer** | AURA |
| **AI CPU** | LLaMA (llama.cpp) |
| **Host Requirement** | Any POSIX kernel (Termux, Linux, macOS, Darwin) |
| **Primary Target** | Android (Samsung Galaxy S21 FE via Termux) |
| **Author** | Christopher Betts |

---

## Requirements

| Requirement | Notes |
|---|---|
| **Bash 4.0+** | Required for associative arrays. macOS ships Bash 3 — install via Homebrew: `brew install bash` and run `bash bin/aios` explicitly |
| **Python 3.9+** | Required for AI backend and filesystem module |
| **Git** | Required to clone the repository |
| **cmake + make** | Optional — only needed to build llama.cpp for LLM support |
| **A `.gguf` model file** | Optional — enables full LLM responses (see [AI Model Setup](docs/AI_MODEL_SETUP.md)) |

**Termux (Android):** install dependencies with:
```sh
pkg install bash python git
```

---

## Installation

```sh
# 1. Clone the repository
git clone https://github.com/Cbetts1/PROJECT.git
cd PROJECT

# 2. Run the installer (sets permissions, creates runtime dirs)
bash install.sh
```

That's it. The installer is non-destructive and safe to re-run.

### Optional: Enable Full AI (LLM)

1. Download a `.gguf` model file (e.g. [Llama-3.2-3B-Instruct-GGUF](https://huggingface.co/bartowski/Llama-3.2-3B-Instruct-GGUF)) and place it in `llama_model/`
2. Build llama.cpp: `bash build/build.sh --target hosted`
3. Edit `etc/aios.conf`:
   ```sh
   AI_BACKEND=llama
   LLAMA_MODEL_PATH=/path/to/your/model.gguf
   ```

Without a model, AIOS uses its built-in rule-based AI backend, which handles
common commands and natural-language questions.

---

## How to Run

```sh
# Option 1: full boot sequence + AI shell (recommended)
./run.sh

# Option 2: skip boot animation
./run.sh --no-boot

# Option 3: direct shell
./bin/aios

# Option 4: explicit bash
bash bin/aios

# Option 5: boot AIOS-Lite virtual OS (init + rc2.d services + shell)
./run-os.sh

# Option 6: boot services only, no interactive shell (CI / automation)
./run-os.sh --no-shell
```

### Boot Sequence

`./run.sh` runs the full six-stage boot pipeline before opening the shell:

```
[BOOT] Stage 0 — Environment Detection
  ✓ Host environment : linux
  ✓ Bash 5.2 / Python 3.12

[BOOT] Stage 1 — Filesystem Initialisation
  ✓ Runtime directories ready

[BOOT] Stage 2 — Permission Check
  ✓ Executable permissions set

[BOOT] Stage 3 — Service Health Pre-Check
  ✓ Python AI backend importable
  ⚠ No llama binary — AI uses built-in rule-based backend

[BOOT] Stage 4 — Kernel State Write
  ✓ Kernel state written (OS/proc/os.state)

[BOOT] Stage 5 — Boot Complete
  AIOS boot completed in ~230 ms — launching AI shell
```

### Updating

```sh
./update.sh               # pull latest + re-install
./update.sh --check       # check for updates without applying
./update.sh --self-test   # update + run full test suite
```

### Example Session

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  AIOS — AI Operating System Shell
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  OS jail  : /path/to/PROJECT/OS
  AI mode  : built-in (rule-based) — no LLM loaded
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Type 'help' for commands, 'exit' to quit.

aios> fs.ls /
bin  dev  etc  proc  sbin  tmp  var

aios> fs.mkdir /home/mydir
aios> fs.write /home/mydir/hello.txt Hello from AIOS!
aios> fs.cat /home/mydir/hello.txt
Hello from AIOS!

aios> proc.ps
...

aios> sys
[AIOS] Entering OS shell. Type 'exit' to return.
$ exit
[AIOS] Returned from OS shell.

aios> exit
Goodbye.
```

---

## Available Commands

| Command | Description |
|---|---|
| `fs.ls [path]` | List directory (confined to `OS/`) |
| `fs.cat <path>` | Show file contents |
| `fs.write <path> <text>` | Write text to file |
| `fs.mkdir <path>` | Create directory |
| `fs.rm <path>` | Remove path |
| `fs.cp <src> <dest>` | Copy file or directory |
| `fs.mv <src> <dest>` | Move/rename |
| `fs.find [path] [args]` | Find files |
| `proc.ps` | List running processes |
| `proc.kill <pid>` | Kill process by PID |
| `net.ping [host]` | Ping a host |
| `net.ifconfig` | Show network interfaces |
| `status` | Live system status (uptime, backend, PIDs) |
| `sysinfo` | Host OS, memory, disk, Bash/Python versions |
| `version` | Print AIOS version and paths |
| `log.tail [n]` | Show last N lines of `var/log/aios.log` |
| `clear` | Clear terminal screen |
| `sys` | Enter real host shell |
| `sys -- <cmd>` | Run one host command |
| `help` | Show command reference |
| `exit` / `quit` | Exit AIOS |
| *(anything else)* | Routed to AI backend (natural language) |

---

## System Architecture

```
╔══════════════════════════════════════════════════════════════╗
║                    USER / AI SHELL LAYER                    ║
║          os-shell  ·  os-ai  ·  bin/aios  ·  bin/aios-sys   ║
╠══════════════════════════════════════════════════════════════╣
║                      AURA COGNITIVE LAYER                   ║
║   IntentEngine → Router → Bots/Handlers → LLM (llama.cpp)   ║
╠══════════════════════════════════════════════════════════════╣
║                    OS SERVICES LAYER                        ║
║  logging · events · message-bus · service-health · state    ║
╠══════════════════════════════════════════════════════════════╣
║                  PSEUDO-KERNEL (sbin/init)                  ║
║   scheduler · resource-mgr · permissions · service-registry ║
╠══════════════════════════════════════════════════════════════╣
║                    BRIDGE / MIRROR LAYER                    ║
║   Android bridge · iOS bridge · SSH bridge · network stack  ║
╠══════════════════════════════════════════════════════════════╣
║                      HOST POSIX KERNEL                      ║
║          Linux / Android (Termux) / macOS / Darwin          ║
╚══════════════════════════════════════════════════════════════╝
```

| Feature | Description |
|---|---|
| 🤖 **AI-OS CPU** | LLaMA-powered cognitive processor: intent classification, reasoning, action selection |
| 🧠 **AURA** | AI cognitive layer with hybrid memory (context + symbolic + semantic) |
| 🐚 **AI Shell** | Natural language OS control — ask questions, issue commands, manage services |
| ⚙️ **Pseudo-Kernel** | `sbin/init` with scheduler, resource manager, permissions, and service registry |
| 🌉 **Cross-OS Bridge** | Connect to iOS, Android, Linux, macOS, and SSH hosts |
| 🪞 **Filesystem Mirror** | Browse any connected device under `$OS_ROOT/mirror/` |
| 📡 **Networking** | WiFi scan/connect, Bluetooth pair/scan, IP stack, network health service |
| 📋 **Service Registry** | Start/stop/monitor named services with health checks and events |
| 🔒 **Permissions** | Capability-based access control; no service bypasses the gate |
| 🔧 **Self-Repair** | `os-recover` detects and repairs broken subsystems autonomously |
| 📦 **Plugin System** | Drop shell scripts into `OS/lib/aura-mods/` to extend the OS at runtime |
| 📡 **HTTP API** | Built-in `os-httpd` REST API for programmatic access |

---

## Boot Pipeline

AI-OS boots itself through a six-stage pipeline. The host POSIX kernel is
treated as silent firmware beneath Stage 0.

```
[HOST FIRMWARE]
     │
     ▼  Stage 0 — Bootloader (bin/aios bootstrap)
     │  • Detect POSIX host; validate firmware environment
     │  • Set AIOS_HOME, OS_ROOT, PATH
     │
     ▼  Stage 1 — Bootstrap (OS/sbin/init env resolution)
     │  • Create all required directories (bin/ sbin/ etc/ proc/ var/ tmp/ dev/ mirror/)
     │  • Touch required runtime files
     │
     ▼  Stage 2 — Init (OS/sbin/init rc2.d scripts)
     │  • Run OS/etc/rc2.d/S01-logging → S02-events → S03-msgbus → S04-state
     │
     ▼  Stage 3 — Services (OS/etc/rc2.d/S05-S10)
     │  • Start scheduler, resource-mgr, bridge, network, health monitor
     │
     ▼  Stage 4 — AI-OS CPU (AURA + LLaMA)
     │  • Load IntentEngine, Router, Bots; connect LLM backend
     │
     ▼  Stage 5 — AI Shell
        • Present interactive os-shell / bin/aios prompt
```

---

## AI-OS CPU

The AI-OS CPU is the cognitive processing unit of AI-OS. It replaces the
traditional instruction-fetch-execute cycle with an intent-classify-act cycle.

```
User Input
    │
    ▼  IntentEngine.classify(input)
    │  → intent tag (e.g. "system.health", "fs.read", "net.wifi.scan")
    │
    ▼  Router.dispatch(intent)
    │  → HealthBot / LogBot / RepairBot / UpgradeBot
    │
    ▼  Handler executes action
    │  → os-service, os-netconf, os-resource, os-log, os-event, ...
    │
    ▼  State updated + Event emitted
    │  → proc/os.state, var/log/os.log, var/events/
    │
    ▼  Response returned to AI Shell
```

---

## AURA Cognitive Layer

AURA is the AI cognitive layer that gives AI-OS its intelligence. It sits
between the OS Services Layer and the AI Shell.

| Component | File | Role |
|---|---|---|
| **IntentEngine** | `ai/core/intent_engine.py` | Classify natural language into intent tags |
| **Router** | `ai/core/router.py` | Dispatch intents to subsystem handlers |
| **Bots** | `ai/core/bots.py` | HealthBot, LogBot, RepairBot, UpgradeBot — specialized handlers |
| **LLM Client** | `ai/core/llama_client.py` | Interface to llama.cpp for free-form reasoning |
| **AI Backend** | `ai/core/ai_backend.py` | Top-level pipeline wiring |
| **Memory** | `OS/lib/aura-memory/` | Hybrid context + symbolic + semantic memory |
| **Policy** | `OS/lib/aura-policy/` | Event-driven rule engine for autonomous action |

---

## Networking

AI-OS owns the network through the bridge layer. All operations go through
`OS/bin/os-netconf`.

| Operation | Command |
|---|---|
| Scan WiFi networks | `net.wifi.scan` |
| Connect to WiFi | `net.wifi.connect <SSID>` |
| Disconnect WiFi | `net.wifi.disconnect` |
| Scan Bluetooth | `net.bt.scan` |
| Pair Bluetooth | `net.bt.pair <addr>` |
| Show IP address | `net.ip` |
| Ping host | `net.ping <host>` |
| Network health | `os-service-health net` |

---

## Bridge / Mirror Layer

The Bridge layer is what makes AI-OS a true multi-device OS. Connected devices
are mounted as mirrored filesystems inside AI-OS.

```sh
# Detect all connected devices
bridge.detect

# Mount iOS filesystem (requires libimobiledevice)
os-bridge ios pair
os-mirror mount ios
ls $OS_ROOT/mirror/ios/

# Android via ADB (USB debugging on)
os-mirror mount android
ls $OS_ROOT/mirror/android/

# Remote Linux via SSH
os-mirror mount ssh admin@10.0.0.5
ls $OS_ROOT/mirror/linux/ssh_10.0.0.5/
```

---

## AI Shell Usage

```sh
# Start AI-OS
./bin/aios

# Natural language (routed to AI backend)
aios> what services are running?
aios> repair all broken services

# Filesystem commands (confined to OS_ROOT)
aios> fs.ls /
aios> fs.mkdir /home/mydir
aios> fs.write /home/mydir/hello.txt Hello from AIOS!
aios> fs.cat /home/mydir/hello.txt

# Process and network
aios> proc.ps
aios> net.ping 8.8.8.8
aios> net.ifconfig

# System info and status
aios> status
aios> sysinfo
aios> version
aios> log.tail 20

# Drop to raw OS shell
aios> sys
```

---

## File Tree

```
PROJECT/
├── README.md                     ← This file (official AI-OS README)
├── LICENSE
├── INSTALL.md
├── CHANGELOG.md
│
├── OS/                           ← AI-OS root ($OS_ROOT)
│   ├── sbin/
│   │   └── init                  ← PID-1 boot script
│   ├── bin/                      ← OS commands
│   │   ├── os-shell              ← Interactive OS shell
│   │   ├── os-ai                 ← AI query interface
│   │   ├── os-bridge             ← Bridge controller
│   │   ├── os-netconf            ← Network configuration
│   │   ├── os-service            ← Service lifecycle manager
│   │   ├── os-service-health     ← Service health monitor
│   │   ├── os-log                ← Logging interface
│   │   ├── os-event              ← Event bus interface
│   │   ├── os-state              ← State inspector
│   │   ├── os-perms              ← Permissions gate
│   │   ├── os-sched              ← Scheduler
│   │   ├── os-resource           ← Resource manager
│   │   ├── os-recover            ← Self-repair agent
│   │   ├── os-mirror             ← Filesystem mirror
│   │   ├── os-kernelctl          ← Pseudo-kernel control
│   │   ├── os-syscall            ← Syscall gate
│   │   ├── os-httpd              ← HTTP API daemon
│   │   └── os-info               ← OS identity / version
│   ├── lib/
│   │   ├── filesystem.py         ← OS_ROOT-isolated file I/O
│   │   ├── aura-agents/          ← AURA agent definitions
│   │   ├── aura-bridge/          ← Bridge protocol modules
│   │   ├── aura-hybrid/          ← Hybrid memory integration
│   │   ├── aura-llm/             ← LLM interface
│   │   ├── aura-memory/          ← Memory subsystem
│   │   ├── aura-mods/            ← Plugin drop directory
│   │   ├── aura-policy/          ← Policy rule engine
│   │   ├── aura-semantic/        ← Semantic embedding
│   │   └── aura-tasks/           ← Task queue
│   ├── etc/
│   │   ├── os-release            ← OS identity file
│   │   ├── init.d/               ← Service definitions
│   │   ├── rc2.d/                ← Boot runlevel scripts
│   │   ├── perms.d/              ← Permission policy files
│   │   ├── aura/                 ← AURA runtime config
│   │   ├── boot.target           ← Boot target spec
│   │   └── security.conf         ← Security policy
│   ├── proc/
│   │   ├── os.state              ← Live OS state
│   │   ├── os.identity           ← OS identity manifest
│   │   ├── os.manifest           ← Service manifest
│   │   ├── sched.table           ← Scheduler table
│   │   └── aura/                 ← AURA process state
│   ├── dev/
│   │   ├── null                  ← Null device
│   │   ├── zero                  ← Zero device
│   │   ├── tty                   ← TTY device
│   │   └── random                ← Random device
│   ├── mirror/                   ← Connected device mounts
│   │   └── linux/                ← Linux mirror namespace
│   ├── var/
│   │   ├── log/                  ← os.log, aura.log
│   │   ├── events/               ← Event queue files
│   │   └── service/              ← Service PID and health files
│   └── tmp/                      ← Ephemeral runtime files
│
├── ai/
│   └── core/                     ← Python AI Core (AURA pipeline)
│       ├── intent_engine.py      ← IntentEngine: classify user input
│       ├── router.py             ← Router: dispatch intents to handlers
│       ├── bots.py               ← HealthBot / LogBot / RepairBot
│       ├── commands.py           ← Legacy command dispatch
│       ├── llama_client.py       ← llama.cpp interface
│       ├── fuzzy.py              ← Fuzzy command matching
│       └── ai_backend.py         ← Top-level AI pipeline
│
├── bin/                          ← Host-side launchers
│   ├── aios                      ← Primary AI shell entry point
│   ├── aios-sys                  ← Raw OS shell entry point
│   └── aios-heartbeat            ← Background heartbeat daemon
│
├── lib/                          ← AURA shell module library
│   ├── aura-core.sh              ← Core functions, include guard
│   ├── aura-ai.sh                ← AI dispatch
│   ├── aura-fs.sh                ← Filesystem operations
│   ├── aura-net.sh               ← Network operations
│   ├── aura-proc.sh              ← Process operations
│   ├── aura-llama.sh             ← llama.cpp wrapper
│   ├── aura-security.sh          ← Security and permissions
│   └── aura-typo.sh              ← Typo correction
│
├── config/                       ← Runtime configuration
│   ├── aios.conf                 ← Main OS config
│   ├── llama-settings.conf       ← LLM parameters
│   ├── network.conf              ← Network defaults
│   ├── services.conf             ← Service definitions
│   ├── system-manifest.conf      ← OS manifest
│   └── device-profiles/          ← Per-device tuning
│       ├── termux.conf
│       ├── samsung-s21fe.conf
│       └── generic-linux.conf
│
├── aura/
│   ├── aura-agent.py             ← AURA agent (systemd/AIOSCPU variant)
│   ├── aura-config.json          ← AURA agent configuration
│   └── schema-memory.sql         ← Memory DB schema
│
├── aioscpu/                      ← AIOSCPU bootable disk image builder
│   ├── build/
│   │   ├── Makefile
│   │   ├── build-image.sh        ← Build the AIOSCPU ISO
│   │   └── grub.cfg              ← GRUB bootloader configuration
│   └── rootfs-overlay/           ← Root filesystem overlay
│       ├── etc/
│       ├── sudoers.d/
│       ├── systemd/
│       └── usr/
│
├── build/
│   └── build.sh                  ← llama.cpp build helper
│
├── mirror/
│   └── overlay-manager.sh        ← Mirror overlay orchestrator
│
├── tools/                        ← Operator tools
│   ├── health_check.sh
│   ├── service-ctl.sh
│   ├── event-bus.sh
│   ├── log-viewer.sh
│   ├── security-audit.sh
│   └── (more...)
│
├── tests/
│   ├── unit-tests.sh
│   ├── integration-tests.sh
│   └── test_python_modules.py
│
├── docs/                         ← Full documentation library
│   ├── architecture.md           ← Master architecture blueprint
│   ├── development.md            ← Development guide
│   ├── ROADMAP.md                ← Implementation roadmap
│   ├── BOOT-SEQUENCE.md
│   ├── OS-ARCHITECTURE.md
│   ├── HAL-DESIGN.md
│   ├── AIOSCPU-ARCHITECTURE.md
│   ├── NETWORKING-MODEL.md
│   ├── AURA-API.md
│   ├── API-REFERENCE.md
│   ├── OPERATOR-RUNBOOK.md
│   └── (more...)
│
└── branding/
    ├── BRANDING.md
    ├── BRAND-IDENTITY.md
    ├── LOGO_ASCII.txt
    └── WATERMARK.txt
```

---

## Troubleshooting

### `./bin/aios` exits immediately with no output

**Cause:** A configuration file references an unbound variable while `set -o nounset` is active.

**Fix:** Run the installer first to ensure the environment is initialized:
```sh
bash install.sh
```
If the problem persists, check that `etc/aios.conf` exists and that `AIOS_ROOT` can be derived from the script location.

### `Permission denied` when running `./bin/aios` or `./run.sh`

```sh
chmod +x bin/aios bin/aios-sys bin/aios-heartbeat run.sh install.sh
```

### Python not found / AI backend fails

Install Python 3.9+ and verify it is on your PATH:
```sh
python3 --version
```
On Termux: `pkg install python`  
On Debian/Ubuntu: `sudo apt install python3`

### macOS: `bash: syntax error` or old Bash

macOS ships Bash 3. Install Bash 4+ via Homebrew:
```sh
brew install bash
/usr/local/bin/bash bin/aios
```

### LLM / AI responses are basic or rule-based

AIOS works without a model, but uses rule-based responses. To enable full AI:
1. Download a `.gguf` model to `llama_model/`
2. Build llama.cpp: `bash build/build.sh --target hosted`
3. Set `AI_BACKEND=llama` in `etc/aios.conf`

### Logs

All boot and session events are logged to `var/log/aios.log`:
```sh
tail -f var/log/aios.log
```

---

## Running Tests

```bash
# Unit tests (shell + Python)
AIOS_HOME=$(pwd) OS_ROOT=$(pwd)/OS bash tests/unit-tests.sh

# Integration tests
AIOS_HOME=$(pwd) OS_ROOT=$(pwd)/OS bash tests/integration-tests.sh

# Python AI core tests only
python3 tests/test_python_modules.py
```

---

## Documentation Index

| Document | Description |
|---|---|
| [`docs/architecture.md`](docs/architecture.md) | **Master architecture blueprint** |
| [`docs/development.md`](docs/development.md) | **Development guide** |
| [`docs/ROADMAP.md`](docs/ROADMAP.md) | Implementation roadmap |
| [`docs/OS-ARCHITECTURE.md`](docs/OS-ARCHITECTURE.md) | OS architecture reference |
| [`docs/BOOT-SEQUENCE.md`](docs/BOOT-SEQUENCE.md) | Boot sequence specification |
| [`docs/HAL-DESIGN.md`](docs/HAL-DESIGN.md) | Hardware abstraction layer design |
| [`docs/AIOSCPU-ARCHITECTURE.md`](docs/AIOSCPU-ARCHITECTURE.md) | AIOSCPU disk-image architecture |
| [`docs/NETWORKING-MODEL.md`](docs/NETWORKING-MODEL.md) | Networking model |
| [`docs/AURA-API.md`](docs/AURA-API.md) | AURA cognitive API reference |
| [`docs/API-REFERENCE.md`](docs/API-REFERENCE.md) | Full OS API reference |
| [`docs/OPERATOR-RUNBOOK.md`](docs/OPERATOR-RUNBOOK.md) | Operator runbook |
| [`docs/INSTALL.md`](docs/INSTALL.md) | Detailed installation guide |
| [`docs/AI_MODEL_SETUP.md`](docs/AI_MODEL_SETUP.md) | LLM model configuration |
| [`docs/SECURITY-FRAMEWORK.md`](docs/SECURITY-FRAMEWORK.md) | Security framework |
| [`docs/MANUAL.md`](docs/MANUAL.md) | User manual |
| [`CONTRIBUTING.md`](CONTRIBUTING.md) | Contribution guide |
| [`docs/LEGAL.md`](docs/LEGAL.md) | Legal and compliance |

---

## License

MIT — see [`LICENSE`](LICENSE)

---

## Legal & Attribution

© 2026 Christopher Betts. All rights reserved.

*Created and developed by Christopher Betts. All code was generated or refined
using AI tools under the creator's direction.*

This project contains AI-generated code. See [`docs/AI-DISCLOSURE.md`](docs/AI-DISCLOSURE.md)
and [`docs/LEGAL.md`](docs/LEGAL.md) for full legal notices, privacy information,
terms of use, and AI-generated code disclosure.
