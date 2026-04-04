# AI-OS

**The Official AI-Native Operating System**

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

## What Is AI-OS?

**AI-OS** is a complete, standalone, AI-native operating system. It is not a
wrapper, not a chatbot, and not a shell script. AI-OS is a full OS that uses
the host POSIX environment (Termux, Linux, macOS, Darwin) only as a hidden
firmware layer — the same way a real OS uses bare-metal firmware.

From the user's perspective, AI-OS owns the shell, the services, the filesystem,
the networking, and the identity. The host kernel is invisible.

### OS Identity

| Property | Value |
|---|---|
| **Name** | AI-OS |
| **Edition** | Aurora v1.0 |
| **Codename** | AIOSCPU |
| **Cognitive Layer** | AURA |
| **AI CPU** | LLaMA (llama.cpp) |
| **Host Requirement** | Any POSIX kernel (Termux, Linux, macOS, Darwin) |
| **Primary Target** | Android (Samsung Galaxy S21 FE via Termux) |
| **Author** | Christopher Betts |

---

## System Architecture

AI-OS is organized as six layers. Every layer is fully implemented and every
interface is defined. The host kernel is hidden behind the Bridge/Mirror layer.

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

Full architecture specification: [`docs/architecture.md`](docs/architecture.md)

---

## Quick Start

### Requirements

- Android (Termux), Linux (Debian/Ubuntu/Arch), macOS, or any POSIX system
- Python 3.8+
- `git`, `bash` or `sh`
- Optional: llama.cpp binary + model file for full AI CPU

### Install and Boot

```bash
# 1. Clone
git clone https://github.com/Cbetts1/PROJECT.git aios
cd aios

# 2. Permissions
chmod +x bin/* tools/* OS/bin/* OS/sbin/*

# 3. Verify
bash tools/health_check.sh

# 4. Boot AI-OS
./bin/aios
```

### Termux (Android)

```sh
pkg update && pkg upgrade
pkg install git python openssh android-tools

git clone https://github.com/Cbetts1/PROJECT.git aios
cd aios
chmod +x bin/* OS/bin/* OS/sbin/*
./bin/aios
```

See full install guide: [`docs/INSTALL.md`](docs/INSTALL.md)

---

## Key Features

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
    │  → HealthBot / LogBot / RepairBot / NetworkBot / FSBot / ...
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
| **Bots** | `ai/core/bots.py` | HealthBot, LogBot, RepairBot — specialized handlers |
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

# Natural language
aios> ask what services are running
aios> ask is my WiFi connected
aios> ask repair all broken services

# OS commands (dot notation)
aios> fs.ls /
aios> proc.list
aios> net.wifi.scan
aios> mem.set project "AI-OS v1"
aios> recall project

# Service management
aios> services
aios> service start aura-bridge
aios> health

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
