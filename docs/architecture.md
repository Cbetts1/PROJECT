# AI-OS — Master Architecture Blueprint

> © 2026 Christopher Betts | AIOSCPU Official  
> *Created and developed by Christopher Betts. All code was generated or refined using AI tools under the creator's direction.*

---

## Table of Contents

1. [System Identity](#1-system-identity)
2. [Layer Architecture](#2-layer-architecture)
3. [Layer 0 — Host POSIX Kernel (Firmware)](#3-layer-0--host-posix-kernel-firmware)
4. [Layer 1 — Bridge / Mirror Layer](#4-layer-1--bridge--mirror-layer)
5. [Layer 2 — Pseudo-Kernel (AIOS Hardware Abstraction)](#5-layer-2--pseudo-kernel-aios-hardware-abstraction)
6. [Layer 3 — OS Services Layer](#6-layer-3--os-services-layer)
7. [Layer 4 — AURA Cognitive Layer](#7-layer-4--aura-cognitive-layer)
8. [Layer 5 — User / AI Shell Layer](#8-layer-5--user--ai-shell-layer)
9. [AI-OS CPU Design](#9-ai-os-cpu-design)
10. [Boot Pipeline](#10-boot-pipeline)
11. [Bootloader Design](#11-bootloader-design)
12. [Bootstrap Design](#12-bootstrap-design)
13. [Init System](#13-init-system)
14. [Service Model](#14-service-model)
15. [Networking Model](#15-networking-model)
16. [Bridge / Mirror Model](#16-bridge--mirror-model)
17. [AI Shell Design](#17-ai-shell-design)
18. [Filesystem Hierarchy](#18-filesystem-hierarchy)
19. [Branding & Identity](#19-branding--identity)
20. [Implementation Roadmap](#20-implementation-roadmap)
21. [Prototype Specification](#21-prototype-specification)

---

## 1. System Identity

AI-OS is a fully original AI-native operating system. It is designed from the
ground up to be AI-first: the AI is not a feature added on top of the OS, it
is the CPU, the shell, and the policy engine of the OS itself.

| Property | Value |
|---|---|
| **Full Name** | AI-OS |
| **Edition** | Aurora |
| **Version** | 1.0 |
| **Codename** | AIOSCPU |
| **Cognitive Engine** | AURA |
| **AI CPU Backend** | LLaMA (llama.cpp) |
| **Kernel Model** | Pseudo-kernel over POSIX host |
| **Host Layer** | Firmware (hidden) |
| **Primary Language** | POSIX Shell + Python 3 |
| **Author** | Christopher Betts |

### Terminology

| Term | Meaning |
|---|---|
| **AI-OS** | The operating system (the whole stack) |
| **AIOS** | The virtual hardware layer / HAL |
| **AURA** | The cognitive layer (intent, memory, policy) |
| **LLaMA** | The CPU intelligence core (llama.cpp) |
| **AIOSCPU** | The bootable Debian-based disk image variant |

---

## 2. Layer Architecture

AI-OS is organized as six strictly-ordered layers. Each layer communicates
only with its immediate neighbors through defined interfaces.

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

### Layer Responsibilities

| Layer | Owner | Responsibility |
|---|---|---|
| Host POSIX Kernel | Hidden firmware | Process execution, file I/O, raw sockets |
| Bridge / Mirror | `OS/bin/os-bridge`, `OS/bin/os-mirror` | Device connectivity, network stack |
| Pseudo-Kernel | `OS/sbin/init` | Boot, scheduling, permissions, service registry |
| OS Services | `OS/etc/rc2.d/` | Logging, events, message-bus, health, state |
| AURA Cognitive | `ai/core/`, `OS/lib/aura-*` | Intent, reasoning, memory, policy |
| AI Shell | `bin/aios`, `OS/bin/os-shell` | User interface, command execution |

---

## 3. Layer 0 — Host POSIX Kernel (Firmware)

The host kernel is never visible to the AI-OS user. It is treated as firmware
— a substrate that provides raw execution capability.

### What AI-OS Uses from the Host

| Host Capability | AI-OS Abstraction |
|---|---|
| Process fork/exec | AIOS process model (`os-sched`, `os-ps`) |
| File I/O | AIOS filesystem (`OS/lib/filesystem.py`, `aura-fs.sh`) |
| Network sockets | AIOS networking (`os-netconf`, `aura-net.sh`) |
| TTY | AI-OS shell (`bin/aios`, `OS/bin/os-shell`) |
| Signals | AIOS event bus (`os-event`, `os-emit`) |

### Host Support Matrix

| Host | Supported | Notes |
|---|---|---|
| Android / Termux | ✅ Primary | Samsung Galaxy S21 FE is primary target |
| Debian / Ubuntu | ✅ | Full feature parity |
| macOS / Darwin | ✅ | Bridge uses `libimobiledevice` |
| Raspberry Pi | ✅ | Use generic-linux profile |
| WSL (Windows) | 🔄 | Planned v1.1 |

---

## 4. Layer 1 — Bridge / Mirror Layer

The Bridge layer is the interface between AI-OS and the outside world. It
connects to external devices and exposes them as mirrored filesystems inside
AI-OS's virtual filesystem.

### Architecture

```
┌──────────────────────────────────────────────────────────────────────┐
│                         BRIDGE LAYER                                  │
│                                                                       │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌────────────┐  │
│  │   Android   │  │     iOS     │  │     SSH     │  │  Network   │  │
│  │   Bridge    │  │   Bridge    │  │   Bridge    │  │   Stack    │  │
│  │ (os-bridge) │  │ (os-bridge) │  │ (os-mirror) │  │(os-netconf)│  │
│  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘  └─────┬──────┘  │
│         │                │                │               │          │
│  ┌──────▼────────────────▼────────────────▼───────────────▼──────┐  │
│  │                    Mirror Filesystem                            │  │
│  │           $OS_ROOT/mirror/{android,ios,linux,ssh_*}/           │  │
│  └────────────────────────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────────────────────────┘
```

### Bridge Modules

| Module | File | Function |
|---|---|---|
| Android Bridge | `OS/bin/os-bridge`, `OS/lib/aura-bridge/` | ADB-based device connection |
| iOS Bridge | `OS/bin/os-bridge` (ios subcommand) | libimobiledevice pairing + ifuse mount |
| SSH Bridge | `OS/bin/os-mirror` (ssh subcommand) | sshfs remote filesystem mount |
| Linux Mirror | `OS/mirror/linux/` | Local Linux overlay namespace |
| Network Stack | `OS/bin/os-netconf`, `lib/aura-net.sh` | WiFi, Bluetooth, IP management |
| Overlay Manager | `mirror/overlay-manager.sh` | Manages multiple simultaneous mounts |

### Bridge Protocol

1. **Detect** — `bridge.detect` scans for connected devices via ADB, USB PID lookup, mDNS
2. **Authenticate** — ADB authorization, iOS pairing PIN, SSH key exchange
3. **Mount** — Device root mounted into `$OS_ROOT/mirror/<type>/`
4. **Index** — Directory listing written to mirror index file
5. **Monitor** — Health daemon polls mount every 60 s; auto-remounts on disconnect

---

## 5. Layer 2 — Pseudo-Kernel (AIOS Hardware Abstraction)

The pseudo-kernel is AI-OS's kernel. It is not a Linux kernel — it is a
POSIX-shell and Python process that manages all OS resources, enforces
permissions, runs the scheduler, and owns the service registry.

PID 1 of the AI-OS process tree is `OS/sbin/init`.

### Pseudo-Kernel Subsystems

#### Scheduler (`OS/bin/os-sched`)

- Cooperative round-robin scheduler
- Three priority tiers: `critical`, `normal`, `background`
- Scheduler table: `OS/proc/sched.table`
- Context switch implemented as process yield + signal

#### Resource Manager (`OS/bin/os-resource`)

- Tracks CPU affinity assignments, memory budgets, I/O limits per service
- Enforces limits via advisory checks (not hard quotas — see HAL design)
- Reads limits from `config/aios.conf` and `config/device-profiles/`

#### Permissions (`OS/bin/os-perms`)

- Capability-based model: each service declares required capabilities
- Permission definitions in `OS/etc/perms.d/*.conf`
- Every cross-service call gated by `os-perms check <principal> <capability>`
- No service may bypass the gate; violations are logged and rejected

#### Service Registry (`OS/bin/os-service`, `OS/bin/os-svc`)

- Named services defined in `OS/etc/init.d/*.service`
- Lifecycle: `start` → `running` → `stop` → `stopped` | `failed` → `recover`
- PID files: `OS/var/service/<name>.pid`
- Health files: `OS/var/service/<name>.health`

#### Syscall Gate (`OS/bin/os-syscall`)

- All inter-layer calls go through the syscall gate
- Syscall table documented in `docs/SYSCALL-LIST.md`
- Provides audit trail for all OS operations

---

## 6. Layer 3 — OS Services Layer

The OS Services layer provides the core runtime services that all higher layers
depend on. These start during `rc2.d` boot and run for the lifetime of AI-OS.

### Core Services

| Service | Script | Function |
|---|---|---|
| **Logging** | `rc2.d/S01-logging` | Structured log sink → `OS/var/log/os.log` |
| **Events** | `rc2.d/S02-events` | Event queue in `OS/var/events/` |
| **Message Bus** | `rc2.d/S03-msgbus` | IPC between services via `os-msg`, `os-emit` |
| **State Manager** | `rc2.d/S04-state` | Live OS state in `OS/proc/os.state` |
| **Checkpoint** | `OS/bin/os-checkpoint` | Periodic state snapshots for recovery |
| **Service Health** | `OS/bin/os-service-health` | Polls all services; emits health events |
| **HTTP API** | `OS/bin/os-httpd` | REST interface for external integrations |

### Logging Architecture

```
os-log write <level> <component> <message>
         │
         ▼
  OS/var/log/os.log      (main OS log)
  OS/var/log/aura.log    (AURA cognitive log)
  OS/var/events/         (event queue files)
```

Log levels: `DEBUG`, `INFO`, `WARN`, `ERROR`, `FATAL`

### Event System

Events are the primary IPC mechanism between services:

```sh
# Emit an event
os-emit service.started aura-bridge

# Subscribe (polling)
os-event tail --filter service

# Event format
{
  "ts": 1712189422,
  "type": "service.started",
  "source": "os-service",
  "payload": {"name": "aura-bridge"}
}
```

---

## 7. Layer 4 — AURA Cognitive Layer

AURA (Autonomous Understanding and Reasoning Architecture) is the cognitive
layer of AI-OS. It converts the OS into a reasoning system.

### Pipeline Architecture

```
User Input (natural language or command)
         │
         ▼
  IntentEngine.classify(input)                  [ai/core/intent_engine.py]
         │  → intent tag + confidence score
         ▼
  Router.dispatch(intent, context)              [ai/core/router.py]
         │  → subsystem handler selection
         ▼
  Handler (Bot or direct command)               [ai/core/bots.py / commands.py]
         │  → HealthBot / LogBot / RepairBot / NetworkBot / FSBot / LLMBot
         ▼
  Action Execution                              [OS/bin/os-* commands]
         │  → os-service, os-netconf, os-log, os-event, ...
         ▼
  State Update + Event Emission                 [OS/proc/os.state, OS/var/events/]
         │
         ▼
  LLM Synthesis (optional)                      [ai/core/llama_client.py]
         │  → free-form reasoning if bot cannot handle
         ▼
  Response rendered to AI Shell
```

### AURA Components

| Component | File | Description |
|---|---|---|
| **IntentEngine** | `ai/core/intent_engine.py` | Classifies input into intent tags via keyword + heuristic matching |
| **Router** | `ai/core/router.py` | Maps intent tags to handler objects |
| **HealthBot** | `ai/core/bots.py` | Handles `system.health` intents |
| **LogBot** | `ai/core/bots.py` | Handles `system.log` intents |
| **RepairBot** | `ai/core/bots.py` | Handles `system.repair` intents |
| **Commands** | `ai/core/commands.py` | Legacy direct-command dispatch table |
| **LLM Client** | `ai/core/llama_client.py` | Subprocess interface to llama.cpp binary |
| **AI Backend** | `ai/core/ai_backend.py` | Top-level pipeline wiring and fallback |
| **Fuzzy Matcher** | `ai/core/fuzzy.py` | Fuzzy command matching for typos |

### AURA Memory Architecture

AURA uses a three-tier hybrid memory:

| Tier | Storage | Use |
|---|---|---|
| **Context window** | In-process list | Current conversation turns |
| **Symbolic (key-value)** | `OS/proc/aura.memory` | `mem.set` / `recall` |
| **Semantic** | SQLite + embeddings (`aura/schema-memory.sql`) | Long-term knowledge retrieval |

### AURA Shell Library

Shell-level AURA interface via `lib/aura-*.sh`:

| Module | Function |
|---|---|
| `lib/aura-core.sh` | Core functions, include guards, logging |
| `lib/aura-ai.sh` | AI dispatch from shell |
| `lib/aura-fs.sh` | Filesystem operations with OS_ROOT jail |
| `lib/aura-net.sh` | Network operations (WiFi, BT, IP) |
| `lib/aura-proc.sh` | Process management |
| `lib/aura-llama.sh` | llama.cpp subprocess management |
| `lib/aura-security.sh` | Security checks and capability gates |
| `lib/aura-typo.sh` | Typo correction for commands |

### LLM Backend (AI CPU Core)

The LLM is the intelligence core of the AI-OS CPU. It provides free-form
reasoning when structured handlers are insufficient.

- **Binary**: `llama.cpp` (compiled from source, see `build/build.sh`)
- **Model**: 7B int4 (8 GB devices) or 3B int4 (6 GB devices) — see device profiles
- **CPU Affinity**: `LLAMA_CPU_AFFINITY=1-3` (Cortex-A78 big cores on S21 FE)
- **Thermal Limit**: 68°C — LLM is suspended above threshold
- **Interface**: `ai/core/llama_client.py` spawns subprocess, manages I/O

---

## 8. Layer 5 — User / AI Shell Layer

The AI Shell is the primary interface to AI-OS. It accepts both natural
language and structured dot-notation commands.

### Entry Points

| Binary | Function |
|---|---|
| `bin/aios` | Primary AI shell (AURA + LLM) |
| `bin/aios-sys` | Raw OS shell (no AI mediation) |
| `OS/bin/os-shell` | Low-level OS interactive shell |
| `OS/bin/os-ai` | Non-interactive AI query |

### Shell Architecture

```
bin/aios
  │
  ├── Load lib/aura-core.sh       ← OS_ROOT resolution, PATH setup
  ├── Load lib/aura-security.sh   ← Permissions check
  ├── Load lib/aura-fs.sh         ← fs.* commands
  ├── Load lib/aura-proc.sh       ← proc.* commands
  ├── Load lib/aura-net.sh        ← net.* commands
  ├── Load lib/aura-typo.sh       ← Typo correction
  ├── Load lib/aura-llama.sh      ← LLM backend
  ├── Load lib/aura-ai.sh         ← AI dispatch
  │
  └── REPL loop
        │
        ├── Read input
        ├── Typo-correct
        ├── Classify: structured command vs. natural language
        ├── If structured → dispatch to aura-* handler
        ├── If natural language → IntentEngine → Router → Bot/LLM
        └── Print response
```

### Command Namespaces

| Namespace | Commands | Handler |
|---|---|---|
| `fs.*` | `fs.ls`, `fs.read`, `fs.write`, `fs.rm` | `lib/aura-fs.sh` |
| `proc.*` | `proc.list`, `proc.kill`, `proc.info` | `lib/aura-proc.sh` |
| `net.*` | `net.wifi.scan`, `net.wifi.connect`, `net.bt.scan`, `net.ip` | `lib/aura-net.sh` |
| `mem.*` | `mem.set`, `mem.get`, `mem.list` | `lib/aura-core.sh` |
| `bridge.*` | `bridge.detect`, `bridge.mount`, `bridge.unmount` | `OS/bin/os-bridge` |
| `mirror.*` | `mirror.mount`, `mirror.ls`, `mirror.unmount` | `OS/bin/os-mirror` |
| `service.*` | `service.start`, `service.stop`, `service.list` | `OS/bin/os-service` |
| `ask` | Natural language query | AURA → LLM |
| `recall` | Memory lookup | `lib/aura-core.sh` |
| `health` | System health dashboard | `OS/bin/os-service-health` |
| `sys` | Drop to raw OS shell | `bin/aios-sys` |

### Self-Explanation

The AI shell can explain any command or OS component:

```
aios> explain net.wifi.scan
AURA: net.wifi.scan calls os-netconf wifi scan which invokes the host WiFi
      scanner (nmcli, wpa_cli, or Termux's wifi API depending on platform).
      Results are written to proc/os.state under net.wifi.networks.

aios> explain how does booting work
AURA: AI-OS boots in 6 stages: firmware detection → bootstrap → init →
      services → AI CPU → AI shell. See docs/BOOT-SEQUENCE.md for full spec.
```

### Prompt Engineering

The AI shell maintains a system-aware context for LLM calls:

```
System: You are AURA, the cognitive core of AI-OS. You have access to:
        - OS state: {proc/os.state}
        - Running services: {var/service/*.pid}
        - Recent events: {var/events/}
        - User memory: {proc/aura.memory}
        Answer as an OS operator. Be precise and actionable.
User: {input}
```

---

## 9. AI-OS CPU Design

The AI-OS CPU replaces the traditional silicon CPU's instruction execution
cycle with an intent-classify-act cognitive cycle.

### CPU Architecture

```
┌──────────────────────────────────────────────────────────────────────────┐
│                             AI-OS CPU                                     │
│                                                                           │
│  ┌─────────────────┐                                                      │
│  │  Event Intake   │  ← AI Shell input, OS events, scheduled tasks       │
│  └────────┬────────┘                                                      │
│           │                                                               │
│  ┌────────▼────────┐                                                      │
│  │ Intent Classify │  ← IntentEngine.classify()                          │
│  └────────┬────────┘                                                      │
│           │                                                               │
│  ┌────────▼────────┐                                                      │
│  │ System Reasoning│  ← Context window + symbolic memory + LLM           │
│  └────────┬────────┘                                                      │
│           │                                                               │
│  ┌────────▼────────┐                                                      │
│  │ Action Selection│  ← Router.dispatch() → Bot selection                │
│  └────────┬────────┘                                                      │
│           │                                                               │
│  ┌────────▼────────┐                                                      │
│  │ Service Control │  ← os-service, os-netconf, os-resource, ...         │
│  └────────┬────────┘                                                      │
│           │                                                               │
│  ┌────────▼────────┐                                                      │
│  │  State Updates  │  ← proc/os.state, proc/aura.memory                  │
│  └────────┬────────┘                                                      │
│           │                                                               │
│  ┌────────▼────────┐                                                      │
│  │    Logging      │  ← var/log/os.log, var/log/aura.log                 │
│  └─────────────────┘                                                      │
└──────────────────────────────────────────────────────────────────────────┘
```

### CPU Cycle (Intent-Classify-Act)

```
1. INTAKE
   Input arrives from: AI shell, scheduled event, health alarm, bridge event

2. CLASSIFY
   IntentEngine scans input tokens against intent taxonomy:
   - system.health   → HealthBot
   - system.log      → LogBot
   - system.repair   → RepairBot
   - net.wifi.*      → NetworkBot
   - fs.*            → FSBot
   - service.*       → ServiceBot
   - memory.*        → MemoryBot
   - <unmatched>     → LLM fallback

3. REASON
   Selected handler loads context:
   - Reads proc/os.state
   - Reads recent var/events/
   - Loads symbolic memory (proc/aura.memory)
   - Constructs prompt if LLM is needed

4. SELECT
   Router returns action:
   - Direct OS command execution
   - Service lifecycle call
   - Network operation
   - LLM-generated plan

5. EXECUTE
   Action runs through syscall gate (os-syscall)

6. UPDATE
   Result written to proc/os.state
   Event emitted to var/events/

7. LOG
   Entry written to var/log/os.log + var/log/aura.log
```

### AI-OS CPU vs Traditional CPU

| Traditional CPU | AI-OS CPU |
|---|---|
| Instruction fetch | Event intake |
| Decode | Intent classification |
| Execute | Reasoning + action selection |
| Write-back | State update |
| Interrupt | OS event / health alarm |
| Cache | AURA memory (context + symbolic + semantic) |
| Clock | Scheduler tick (`os-sched`) |

---

## 10. Boot Pipeline

The complete boot pipeline from firmware to AI shell:

```
┌─────────────────────────────────────────────────────────────────┐
│  HOST POSIX FIRMWARE (hidden)                                    │
│  Android/Termux boots → sh or bash process starts              │
└──────────────────────────────┬──────────────────────────────────┘
                               │
┌──────────────────────────────▼──────────────────────────────────┐
│  STAGE 0: BOOTLOADER (bin/aios)                                  │
│  • Detect POSIX host type (Termux / Linux / macOS)              │
│  • Validate firmware environment                                 │
│  • Set AIOS_HOME (repo root), OS_ROOT ($AIOS_HOME/OS)           │
│  • Update PATH: OS/bin:OS/sbin:bin:$PATH                        │
│  • Load config/aios.conf                                         │
│  • Exec OS/sbin/init                                             │
└──────────────────────────────┬──────────────────────────────────┘
                               │
┌──────────────────────────────▼──────────────────────────────────┐
│  STAGE 1: BOOTSTRAP (OS/sbin/init — env resolution)             │
│  • Resolve OS_ROOT from script location                         │
│  • Create directory tree: bin/ sbin/ etc/ lib/ proc/ var/ tmp/  │
│                            dev/ mirror/ var/log/ var/service/   │
│  • Touch required runtime files (os.state, os.identity, ...)   │
│  • Write boot timestamp to var/log/os.log                       │
└──────────────────────────────┬──────────────────────────────────┘
                               │
┌──────────────────────────────▼──────────────────────────────────┐
│  STAGE 2: INIT (OS/sbin/init — rc2.d runlevel)                  │
│  • Run etc/rc2.d/S01-logging   → start logging service          │
│  • Run etc/rc2.d/S02-events    → start event queue              │
│  • Run etc/rc2.d/S03-msgbus    → start message bus              │
│  • Run etc/rc2.d/S04-state     → initialize OS state            │
└──────────────────────────────┬──────────────────────────────────┘
                               │
┌──────────────────────────────▼──────────────────────────────────┐
│  STAGE 3: SERVICES (OS/etc/rc2.d S05–S10)                       │
│  • S05-scheduler   → start os-sched                             │
│  • S06-resource    → start os-resource                          │
│  • S07-network     → start os-netconf health service            │
│  • S08-bridge      → start os-bridge auto-detect                │
│  • S09-health      → start os-service-health daemon             │
│  • S10-httpd       → start os-httpd (optional)                  │
└──────────────────────────────┬──────────────────────────────────┘
                               │
┌──────────────────────────────▼──────────────────────────────────┐
│  STAGE 4: AI-OS CPU (AURA + LLaMA)                              │
│  • Load ai/core/intent_engine.py                                │
│  • Load ai/core/router.py + bots.py                             │
│  • Connect llama.cpp backend (if model present)                 │
│  • Initialize hybrid memory (context + symbolic + semantic)     │
│  • Emit system.started event                                    │
└──────────────────────────────┬──────────────────────────────────┘
                               │
┌──────────────────────────────▼──────────────────────────────────┐
│  STAGE 5: AI SHELL                                               │
│  • Source all lib/aura-*.sh modules                             │
│  • Print AIOS ASCII banner                                      │
│  • Present interactive prompt: "aios> "                         │
└─────────────────────────────────────────────────────────────────┘
```

---

## 11. Bootloader Design

**File:** `bin/aios` (acts as bootloader when invoked fresh)

The bootloader is the first AI-OS code that runs. Its responsibilities:

### Bootloader Tasks

1. **Host Detection**
   - Check for `TERMUX_VERSION` → Android/Termux mode
   - Check `uname -s` → Linux, Darwin
   - Load matching device profile from `config/device-profiles/`

2. **Environment Setup**
   - Resolve `AIOS_HOME` (repo root, relative to `bin/aios`)
   - Set `OS_ROOT="$AIOS_HOME/OS"`
   - Prepend `OS/bin:OS/sbin:bin` to `PATH`
   - Source `config/aios.conf`

3. **Pre-flight Checks**
   - Verify `OS/sbin/init` exists and is executable
   - Verify Python 3 is available
   - Verify `OS/etc/os-release` exists

4. **Hand-off**
   - `exec sh "$OS_ROOT/sbin/init" "$@"`

### Bootloader Error Handling

| Error | Action |
|---|---|
| `OS/sbin/init` not found | Print error; drop to host shell |
| Python 3 missing | Print warning; boot continues (AI features disabled) |
| Config not found | Use compiled-in defaults |

---

## 12. Bootstrap Design

**File:** `OS/sbin/init` (first 60 lines — env resolution phase)

The bootstrap is responsible for making the AI-OS environment ready before any
service starts.

### Bootstrap Tasks

1. **OS_ROOT Resolution** — derive from script location if not set
2. **Directory Creation** — idempotent `mkdir -p` for all required paths
3. **File Initialization** — `touch` all required runtime files
4. **Config Load** — source `$AIOS_HOME/config/aios.conf`
5. **Identity Write** — write OS version to `OS/etc/os-release` and `OS/proc/os.identity`
6. **Log Open** — write first boot line to `OS/var/log/os.log`

### Directory Tree Created by Bootstrap

```
OS/
├── bin/            (already exists; added to PATH)
├── sbin/           (already exists)
├── etc/init.d/     (service definitions)
├── etc/rc2.d/      (runlevel boot scripts)
├── etc/perms.d/    (permission files)
├── etc/aura/       (AURA config)
├── lib/            (AURA modules)
├── proc/           (runtime state)
├── dev/            (virtual devices)
├── mirror/         (device mounts)
├── var/log/        (log files)
├── var/events/     (event queue)
├── var/service/    (service PID/health)
└── tmp/            (ephemeral)
```

---

## 13. Init System

**File:** `OS/sbin/init`

AI-OS uses a SysV-style init system implemented in POSIX shell.

### Runlevels

| Runlevel | Name | Description |
|---|---|---|
| 0 | halt | System halting |
| 1 | single | Single-user (recovery) mode |
| 2 | multi | Normal multi-service mode (default boot target) |
| 3 | ai | AI-OS full mode (includes AURA + LLM) |
| 6 | reboot | System rebooting |

Default boot target: `runlevel 2` with AURA enabled (effectively level 3).

### rc2.d Boot Scripts

Scripts in `OS/etc/rc2.d/` are run in lexicographic order. Each script:
- Has a `start()` and `stop()` function
- Logs its result to `OS/var/log/os.log`
- Is idempotent (safe to run twice)
- Returns 0 on success, non-zero on failure

```sh
# Example: OS/etc/rc2.d/S01-logging
start() {
    mkdir -p "$OS_ROOT/var/log"
    touch "$OS_ROOT/var/log/os.log"
    echo "[$(date +%s)] INFO  logging: service started" >> "$OS_ROOT/var/log/os.log"
}
```

### Init Shutdown

```sh
OS/bin/shutdown      # Graceful shutdown (runs stop() in reverse order)
OS/bin/reboot        # Shutdown + restart
```

---

## 14. Service Model

Services are the building blocks of AI-OS. Everything that runs persistently
is a service.

### Service Definition

Each service is defined in `OS/etc/init.d/<name>.service`:

```sh
# OS/etc/init.d/aura-bridge.service
SERVICE_NAME="aura-bridge"
SERVICE_CMD="$OS_ROOT/bin/os-bridge daemon"
SERVICE_DEPS="logging events"
SERVICE_CAPS="net.read net.write bridge.control"
SERVICE_HEALTH_CMD="os-bridge status"
SERVICE_RESTART="on-failure"
```

### Service Lifecycle

```
          start
    ┌──────────────┐
    │   stopped    │ ←──────── stop
    └──────┬───────┘
           │ start
    ┌──────▼───────┐
    │  starting    │
    └──────┬───────┘
           │ ready signal
    ┌──────▼───────┐
    │   running    │ ←──── health checks poll here
    └──────┬───────┘
           │ failure
    ┌──────▼───────┐
    │    failed    │
    └──────┬───────┘
           │ os-recover
    ┌──────▼───────┐
    │  recovering  │
    └──────┬───────┘
           │ success
    back to running
```

### Service Commands

```sh
os-service list               # List all services and status
os-service start <name>       # Start a service
os-service stop <name>        # Stop a service
os-service restart <name>     # Restart a service
os-service status <name>      # Show service status
os-service-health             # Full health dashboard
```

---

## 15. Networking Model

AI-OS owns the network through the Bridge layer. All network operations are
issued through `OS/bin/os-netconf` and exposed as AURA commands via
`lib/aura-net.sh`.

### Network Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                     AI-OS Network Stack                          │
│                                                                 │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │                    AI Shell Layer                          │  │
│  │  net.wifi.scan  net.wifi.connect  net.bt.scan  net.ip     │  │
│  └────────────────────────────┬──────────────────────────────┘  │
│                               │                                 │
│  ┌────────────────────────────▼──────────────────────────────┐  │
│  │              AI-OS Network API (os-netconf)                │  │
│  │  wifi.scan  wifi.connect  wifi.disconnect  wifi.status    │  │
│  │  bt.scan    bt.pair       bt.connect       bt.status      │  │
│  │  ip.addr    ip.route      net.ping         net.dns        │  │
│  └────────────────────────────┬──────────────────────────────┘  │
│                               │                                 │
│  ┌────────────────────────────▼──────────────────────────────┐  │
│  │              Bridge Network Layer                          │  │
│  │  lib/aura-net.sh  →  host OS network tools                │  │
│  │  nmcli / wpa_cli / iwlist  (Linux)                        │  │
│  │  networksetup / airport    (macOS)                        │  │
│  │  termux-wifi-scaninfo      (Termux/Android)               │  │
│  │  bluetoothctl / hcitools   (Linux Bluetooth)              │  │
│  └────────────────────────────┬──────────────────────────────┘  │
│                               │                                 │
│  ┌────────────────────────────▼──────────────────────────────┐  │
│  │              Host OS Network Stack (firmware)              │  │
│  │  Wi-Fi driver · Bluetooth stack · IP/TCP/UDP kernel       │  │
│  └─────────────────────────────────────────────────────────  ┘  │
└─────────────────────────────────────────────────────────────────┘
```

### WiFi Operations

| Operation | Command | Implementation |
|---|---|---|
| Scan networks | `net.wifi.scan` | `nmcli dev wifi list` / `termux-wifi-scaninfo` |
| Connect | `net.wifi.connect <SSID> [pass]` | `nmcli dev wifi connect` / `wpa_supplicant` |
| Disconnect | `net.wifi.disconnect` | `nmcli dev disconnect` |
| Status | `net.wifi.status` | `nmcli dev show` / `termux-wifi-connectioninfo` |
| IP address | `net.ip` | `ip addr show` / `ifconfig` |

### Bluetooth Operations

| Operation | Command | Implementation |
|---|---|---|
| Scan devices | `net.bt.scan` | `bluetoothctl scan on` / `hcitool scan` |
| Pair device | `net.bt.pair <addr>` | `bluetoothctl pair <addr>` |
| Connect | `net.bt.connect <addr>` | `bluetoothctl connect <addr>` |
| List paired | `net.bt.list` | `bluetoothctl paired-devices` |
| Status | `net.bt.status` | `bluetoothctl show` |

### Network Health Service

The network health service (`rc2.d/S07-network`) runs continuously and:
- Pings the default gateway every 30 s
- Writes network status to `OS/proc/os.state` under `net.status`
- Emits `net.connected` / `net.disconnected` events
- Logs all transitions to `OS/var/log/os.log`

---

## 16. Bridge / Mirror Model

See also Layer 1 summary above.

### Android Bridge (ADB)

```
AI-OS → os-bridge android detect
      → adb devices
      → Device found: <serial>
      → adb shell ls /sdcard  (index)
      → os-mirror mount android
      → mount point: $OS_ROOT/mirror/android/
```

Requirements: `adb` in PATH; USB debugging enabled on device.

### iOS Bridge (libimobiledevice)

```
AI-OS → os-bridge ios detect
      → ideviceinfo  (detect connected device)
      → idevicepair  (pair if not already paired)
      → ifuse $OS_ROOT/mirror/ios  (mount AFC filesystem)
      → mount point: $OS_ROOT/mirror/ios/
```

Requirements: `libimobiledevice`, `ifuse`, `fuse`.

### SSH Bridge

```
AI-OS → os-mirror mount ssh user@host
      → sshfs user@host:/ $OS_ROOT/mirror/linux/ssh_user_host/
      → mount point: $OS_ROOT/mirror/linux/ssh_user_host/
```

Requirements: `sshfs`, SSH key access to remote host.

### Mirror Namespace

All connected devices appear under `$OS_ROOT/mirror/`:

```
OS/mirror/
├── android/           ← Android device (ADB)
│   └── _sdcard.listing
├── ios/               ← iOS device (AFC)
│   └── DCIM/
├── linux/
│   └── ssh_admin_10.0.0.5/   ← SSH-mounted Linux host
└── overlay/           ← Overlay manager metadata
```

---

## 17. AI Shell Design

See Layer 5 for architecture details.

### Complete Command Reference

#### Filesystem
```
fs.ls [path]          List directory
fs.read <path>        Read file content
fs.write <path> <data> Write to file
fs.rm <path>          Remove file
fs.stat <path>        File info
```

#### Process
```
proc.list             List all tracked processes
proc.kill <pid>       Send SIGTERM to process
proc.info <pid>       Show process info
```

#### Network
```
net.wifi.scan         Scan for WiFi networks
net.wifi.connect <ssid> [pass]  Connect to WiFi
net.wifi.disconnect   Disconnect WiFi
net.bt.scan           Scan for Bluetooth devices
net.bt.pair <addr>    Pair Bluetooth device
net.ip                Show IP addresses
net.ping <host>       Ping a host
```

#### Memory
```
mem.set <key> <value> Store a value
mem.get <key>         Get a value
mem.list              List all stored keys
recall <key>          AI-formatted recall
```

#### Bridge
```
bridge.detect         Auto-detect connected devices
bridge.mount <type>   Mount a device bridge
bridge.unmount <type> Unmount a device bridge
bridge.list           List all mounted bridges
mirror.ls <type> [path]  List mirrored files
```

#### Services
```
services              List all services
service start <name>  Start service
service stop <name>   Stop service
service restart <name> Restart service
health                Full health dashboard
```

#### AI
```
ask <question>        Natural language AI query
explain <topic>       Self-explain any command or component
sys                   Drop to raw OS shell (bin/aios-sys)
```

---

## 18. Filesystem Hierarchy

The official AI-OS filesystem is rooted at `$OS_ROOT` (typically `PROJECT/OS/`).

```
$OS_ROOT/                     AI-OS virtual root
├── bin/                      User-executable OS commands
│   ├── os-shell              Interactive shell
│   ├── os-ai                 AI query CLI
│   ├── os-bridge             Bridge controller
│   ├── os-mirror             Mirror filesystem manager
│   ├── os-netconf            Network configurator
│   ├── os-service            Service manager
│   ├── os-service-health     Health monitor
│   ├── os-log                Log interface
│   ├── os-event              Event bus
│   ├── os-emit               Event emitter
│   ├── os-msg                Message bus
│   ├── os-state              State inspector
│   ├── os-perms              Permissions gate
│   ├── os-sched              Scheduler
│   ├── os-resource           Resource manager
│   ├── os-recover            Self-repair agent
│   ├── os-kernelctl          Pseudo-kernel control
│   ├── os-syscall            Syscall gate
│   ├── os-httpd              HTTP API daemon
│   ├── os-info               OS identity
│   ├── os-ps                 Process lister
│   ├── os-check              Health check runner
│   ├── os-checkpoint         State checkpoint
│   ├── os-login              Login gate
│   ├── os-install            Component installer
│   ├── os-selftest           Self-test runner
│   ├── os-svc                Service control alias
│   ├── os-real-shell         Passthrough to host shell
│   └── (busybox aliases: ls, cat, echo, mkdir, ps, sh, sleep, uname, reboot, shutdown)
│
├── sbin/
│   └── init                  PID-1 boot script
│
├── lib/
│   ├── filesystem.py         OS_ROOT-isolated file I/O
│   ├── aura-agents/          AURA agent modules
│   ├── aura-bridge/          Bridge protocol modules
│   ├── aura-hybrid/          Hybrid memory integration
│   ├── aura-llm/             LLM interface modules
│   ├── aura-memory/          Memory subsystem
│   ├── aura-mods/            Plugin drop directory
│   ├── aura-policy/          Policy rule engine
│   ├── aura-semantic/        Semantic embedding
│   └── aura-tasks/           Task queue
│
├── etc/
│   ├── os-release            OS identification
│   ├── passwd                User table
│   ├── security.conf         Security policy
│   ├── boot.target           Boot target
│   ├── init.d/               Service definitions
│   ├── rc2.d/                Runlevel 2 boot scripts
│   ├── perms.d/              Permission policy files
│   └── aura/                 AURA configuration
│
├── proc/
│   ├── os.state              Live OS state (key=value)
│   ├── os.identity           OS identity manifest
│   ├── os.manifest           Registered services
│   ├── sched.table           Scheduler run table
│   └── aura/                 AURA process state
│       └── aura.memory       Symbolic memory store
│
├── dev/
│   ├── null                  Null device
│   ├── zero                  Zero device
│   ├── tty                   TTY device
│   └── random                Random source
│
├── mirror/                   Connected device mounts
│   ├── android/
│   ├── ios/
│   └── linux/
│
├── var/
│   ├── log/
│   │   ├── os.log            Main system log
│   │   └── aura.log          AURA cognitive log
│   ├── events/               Event queue files
│   ├── service/              Service runtime files
│   │   ├── <name>.pid        Service PID
│   │   └── <name>.health     Service health status
│   └── run/                  Ephemeral run files
│
├── init.d/
│   └── startup.sh            Legacy startup shim
│
└── tmp/                      Ephemeral working directory
```

---

## 19. Branding & Identity

### Official Names

| Context | Name |
|---|---|
| Operating system | **AI-OS** |
| Full product name | **AI-OS Aurora** |
| Codename (internal) | **AIOSCPU** |
| Cognitive layer | **AURA** |
| Disk image variant | **AIOSCPU** |
| Author | **Christopher Betts** |
| Copyright | © 2026 Christopher Betts |

### OS Identity File (`OS/etc/os-release`)

```sh
NAME="AI-OS"
PRETTY_NAME="AI-OS Aurora 1.0"
VERSION="1.0"
VERSION_ID="1.0"
ID=aios
ID_LIKE=posix
HOME_URL="https://github.com/Cbetts1/PROJECT"
AURA_VERSION="1.0"
LLAMA_BACKEND="llama.cpp"
BUILD_DATE="2026-04-04"
AUTHOR="Christopher Betts"
```

### Taglines

- Primary: *"Not an app. Not a shell script. An operating system."*
- Secondary: *"Plug your OS into any device — and your AI comes with it."*
- Technical: *"POSIX is our firmware. Intelligence is our kernel."*

---

## 20. Implementation Roadmap

### Phase 0 — Prototype (Complete)

- [x] `OS/sbin/init` boot script
- [x] `bin/aios` AI shell
- [x] `bin/aios-sys` OS shell
- [x] `ai/core/intent_engine.py` + router + bots
- [x] `lib/aura-*.sh` module library
- [x] `OS/bin/os-service`, `os-log`, `os-event`, `os-netconf`
- [x] `OS/bin/os-bridge`, `os-mirror`
- [x] `OS/bin/os-recover`
- [x] `OS/lib/filesystem.py`
- [x] Unit tests + integration tests
- [x] Full documentation library

### Phase 1 — Stability (v0.x → v1.0)

- [ ] Persistent SQLite memory backend (replace flat `aura.memory` file)
- [ ] LLM backend: Ollama + OpenAI-compatible endpoint support
- [ ] Network health service as proper rc2.d daemon
- [ ] Intent engine v2: confidence scoring, multi-label classification
- [ ] AI shell: tab completion, command history search
- [ ] iOS bridge: stable pairing and reconnect on macOS
- [ ] Security audit: capability gate coverage >95%
- [ ] `v1.0` stable release + SemVer

### Phase 2 — Platform (v1.x)

- [ ] Web UI dashboard (`os-httpd` serving React SPA)
- [ ] Docker / container image
- [ ] WSL (Windows) support
- [ ] Plugin marketplace index
- [ ] Multi-user sessions with per-user memory namespaces
- [ ] Encrypted memory store (AES-256 at rest)
- [ ] AURA policy engine v2 (autonomous repair rules)

### Phase 3 — Ecosystem (v2.x)

- [ ] AIOSCPU disk image (Debian-based, bootable ISO) — `aioscpu/build/`
- [ ] Mobile app companion (Android/iOS remote shell)
- [ ] Over-the-air update system
- [ ] AURA plugin API (third-party bot development)
- [ ] Distributed bridge (multi-device mesh)

---

## 21. Prototype Specification

The current prototype (v0.x) satisfies the following specification:

### Required Capabilities

| Capability | Status | Files |
|---|---|---|
| Boot from `sbin/init` | ✅ | `OS/sbin/init` |
| AI shell with NL input | ✅ | `bin/aios`, `OS/bin/os-shell` |
| Intent classification | ✅ | `ai/core/intent_engine.py` |
| Intent routing | ✅ | `ai/core/router.py` |
| HealthBot / LogBot / RepairBot | ✅ | `ai/core/bots.py` |
| LLM integration (llama.cpp) | ✅ | `ai/core/llama_client.py` |
| Service registry | ✅ | `OS/bin/os-service`, `OS/etc/init.d/` |
| Service health monitor | ✅ | `OS/bin/os-service-health` |
| Logging | ✅ | `OS/bin/os-log`, `OS/var/log/` |
| Event bus | ✅ | `OS/bin/os-event`, `OS/bin/os-emit` |
| Permissions gate | ✅ | `OS/bin/os-perms`, `OS/etc/perms.d/` |
| Scheduler | ✅ | `OS/bin/os-sched`, `OS/proc/sched.table` |
| Resource manager | ✅ | `OS/bin/os-resource` |
| WiFi operations | ✅ | `OS/bin/os-netconf`, `lib/aura-net.sh` |
| Bluetooth operations | ✅ | `OS/bin/os-netconf`, `lib/aura-net.sh` |
| Android bridge (ADB) | ✅ | `OS/bin/os-bridge` |
| iOS bridge (libimobiledevice) | ✅ | `OS/bin/os-bridge` |
| SSH bridge (sshfs) | ✅ | `OS/bin/os-mirror` |
| Filesystem mirror | ✅ | `OS/mirror/`, `OS/bin/os-mirror` |
| Hybrid memory | ✅ | `OS/lib/aura-memory/`, `proc/aura.memory` |
| Self-repair | ✅ | `OS/bin/os-recover` |
| Plugin system | ✅ | `OS/lib/aura-mods/` |
| HTTP API | ✅ | `OS/bin/os-httpd` |
| Unit tests | ✅ | `tests/unit-tests.sh`, `tests/test_python_modules.py` |
| Integration tests | ✅ | `tests/integration-tests.sh` |
| Full documentation | ✅ | `docs/` |

### Prototype Constraints

- No hard memory quotas (advisory only) — enforced at Phase 1
- LLM requires manual model download (see `docs/AI_MODEL_SETUP.md`)
- iOS bridge requires USB + trust dialog on iOS device
- ADB bridge requires USB debugging enabled
- SQLite memory not yet persistent across reboots (Phase 1)

### Running the Prototype

```bash
# Clone and set up
git clone https://github.com/Cbetts1/PROJECT.git aios
cd aios
chmod +x bin/* tools/* OS/bin/* OS/sbin/*

# Verify environment
AIOS_HOME=$(pwd) OS_ROOT=$(pwd)/OS bash tools/health_check.sh

# Run tests
AIOS_HOME=$(pwd) OS_ROOT=$(pwd)/OS bash tests/unit-tests.sh
AIOS_HOME=$(pwd) OS_ROOT=$(pwd)/OS bash tests/integration-tests.sh

# Boot AI-OS
./bin/aios
```
