# AI-BRAIN — How the AI Model Becomes the OS Brain

> © 2026 Chris Betts | AIOSCPU Official

---

## Overview

AIOS is not an application running on an operating system.  
**AIOS is an operating system where the AI model is the core.**

Every decision the OS makes — from parsing a shell command to restarting a
dead service — flows through the AI Core.  The model does not sit on top of
the OS; it *is* the cognitive layer that drives the OS.

```
┌─────────────────────────────────────────────────────────────┐
│                       AIOS System                           │
│                                                             │
│   ┌─────────────────────────────────────────────────┐      │
│   │                  AI CORE (Brain)                │      │
│   │                                                 │      │
│   │   Intent Engine → Router → Subsystem Handlers   │      │
│   │   Bot System    → Autonomous background agents  │      │
│   │   LLaMA / Mock  → Language model inference      │      │
│   └──────────────────────┬──────────────────────────┘      │
│                          │ dispatches to                    │
│         ┌────────────────┼──────────────────┐              │
│         ▼                ▼                  ▼              │
│   ┌──────────┐    ┌──────────────┐   ┌───────────┐         │
│   │Filesystem│    │ Process/Svc  │   │  Network  │         │
│   │ OS/lib/  │    │ OS/bin/os-*  │   │ aura-net  │         │
│   └──────────┘    └──────────────┘   └───────────┘         │
│                                                             │
│   ┌───────────────────────────────────────────────┐        │
│   │             OS Body (Shell Layer)             │        │
│   │  OS/sbin/init → OS/bin/os-shell → bin/aios   │        │
│   └───────────────────────────────────────────────┘        │
└─────────────────────────────────────────────────────────────┘
```

---

## The Five-Layer Model

### Layer 1 — Hardware / Host (Physical body)

The host CPU, RAM, storage, and devices.  AIOS runs on any POSIX system:
Android (Termux), Linux, macOS, Raspberry Pi, or an SD card.  This layer is
device-agnostic.

### Layer 2 — OS Body (Nervous system)

The POSIX shell environment, kernel daemon, service manager, filesystem jail,
and process table.

| Component | Location | Role |
|---|---|---|
| Boot init | `OS/sbin/init` | Bootstraps the OS body |
| Kernel daemon | `OS/etc/init.d/os-kernel` | Heartbeat + service monitor |
| Service manager | `OS/bin/os-service` | Start / stop / restart services |
| Filesystem | `OS/lib/filesystem.py` | OS_ROOT-isolated file I/O |
| Shell | `OS/bin/os-shell` | Interactive POSIX shell |

### Layer 3 — Message Bus (Bloodstream)

The message bus (`OS/lib/aura-mods/bus.mod`) carries events between all layers.
Any subsystem can publish to a channel; any other subsystem can subscribe.

```sh
bus_publish "service" "os-kernel started pid=1234"
bus_subscribe "service"   # receive new messages
bus_broadcast "system up" # send to all channels
```

### Layer 4 — AI Core (Brain)

The AI Core is implemented in `ai/core/`.  It has four sub-components:

#### 4a. Intent Engine (`ai/core/intent_engine.py`)

Classifies every piece of natural language into a typed *Intent*:

| Intent Type | Example input | Sub-intent |
|---|---|---|
| `COMMAND` | "list files in /etc" | `fs.ls` |
| `QUERY` | "show service health" | `sys.health` |
| `ACTION` | "start nginx" | `svc.start` |
| `REPAIR` | "fix the broken service" | `repair.auto` |
| `WORKFLOW` | "deploy the app" | `workflow.run` |
| `CHAT` | "what is the weather?" | — |

Each Intent carries a **confidence score** (0–1) and extracted **entities**
(e.g. `{"path": "/etc"}`).

#### 4b. Router (`ai/core/router.py`)

The Router receives an Intent and dispatches it to the correct subsystem
handler.  Handlers can be overridden at runtime via `router.register()`.

```
                  ┌─────────────────────────────┐
User input ──▶   │  classify(input) → Intent    │
                  └──────────────┬──────────────┘
                                 │
                  ┌──────────────▼──────────────┐
                  │  Router.dispatch(intent)     │
                  └──┬──┬──┬──┬──┬──────────────┘
                     │  │  │  │  │
            COMMAND  │  │  │  │  │ CHAT
                     │  │  │  │  └──▶ LLaMA / mock model
            QUERY ───┘  │  │  └─────▶ RepairSubsystem
            ACTION ─────┘  └───────▶ WorkflowSubsystem
```

#### 4c. Bot System (`ai/core/bots.py`)

Autonomous agents that run on a schedule or in response to events.

| Bot | Purpose |
|---|---|
| `HealthBot` | Polls PID files; detects and logs dead services |
| `LogBot` | Rotates logs that exceed the line threshold |
| `RepairBot` | Scans audit log for errors; generates repair actions |

Custom bots are added by subclassing `BaseBot` and setting `name`.

```python
class MyBot(BaseBot):
    name = "mybot"
    description = "Does something useful."

    def run_once(self) -> BotResult:
        ...
        return BotResult(bot_name=self.name, success=True, message="done")
```

#### 4d. Language Model (`ai/core/llama_client.py`)

When a `.gguf` model file is present and `llama-cli` is on PATH, the AI Core
uses it for `CHAT` intent responses and open-ended reasoning.  Without a
model, a rule-based mock responds to common queries.

```
AI_BACKEND=llama                # in config/aios.conf
LLAMA_MODEL_PATH=/path/to/model.gguf
```

### Layer 5 — Shell (Mouth / Hands)

The AI shell is the interface between the user and the AI Core.

```
User types: "fix the nginx service"
                │
                ▼
    os-shell / bin/aios
                │
                ▼
    lib/aura-ai.sh → ai_backend.py
                │
                ▼
    IntentEngine → Intent(type=REPAIR, sub_intent="repair.auto")
                │
                ▼
    Router → RepairSubsystem → analyses logs + suggests restart
                │
                ▼
    Shell prints repair report
```

---

## Boot Sequence

```
Power on / shell launch
        │
        ▼
OS/sbin/init
   ├─ Resolve OS_ROOT and AIOS_HOME
   ├─ Load config/aios.conf
   ├─ Create runtime directories (var/log, proc/, mirror/)
   ├─ Start rc2.d services (banner, devices, os-kernel, aura-bridge)
   └─ exec os-shell (AI shell, hands control to AI Core)
        │
        ▼
os-shell / bin/aios
   ├─ Source aura modules (memory, semantic, bridge, LLM, policy)
   ├─ Display AIOS banner
   └─ Enter REPL (read → classify → route → respond)
```

---

## How the AI Model Evolves the OS

The AI Core is not static.  It can:

1. **Inspect itself** — read any file in `OS/` via the filesystem module.
2. **Modify configuration** — write to `OS/etc/` or `config/` to change behaviour.
3. **Restart services** — call `OS/bin/os-service restart <name>`.
4. **Load new modules** — source new `.mod` files from `OS/lib/aura-mods/`.
5. **Register new commands** — call `register_command` in `bin/aios`.
6. **Schedule new bots** — add subclasses of `BaseBot` to `ai/core/bots.py`.
7. **Update itself** — clone new code into `OS/` via the bridge layer.

This creates a feedback loop:

```
User need → AI Intent → OS action → observation → updated AI behaviour
```

---

## Security Boundaries

| Boundary | Mechanism |
|---|---|
| Filesystem jail | `OS/lib/filesystem.py` rejects paths outside `OS_ROOT` |
| Shell mode | `operator` / `system` / `talk` modes limit command exposure |
| Audit log | Every AI decision is logged to `OS/var/log/aura.log` |
| No direct root | All AIOS commands run in user space; no kernel modifications |
| SD isolation | `bootstrap-sd.sh` creates a self-contained tree; the host FS is untouched |

---

## Quick Reference

```sh
# Boot AIOS
sh OS/sbin/init

# Launch AI shell
OS_ROOT=$(pwd)/OS bin/aios

# Classify a natural-language input
python3 ai/core/intent_engine.py --input "list files in /etc" --json

# Route an input through the full AI Core pipeline
python3 ai/core/router.py --input "fix broken service" --os-root $(pwd)/OS --aios-root $(pwd)

# Run the health bot
python3 ai/core/bots.py --run health

# Run all bots
python3 ai/core/bots.py --run-all

# Bootstrap to SD card
bash bootstrap-sd.sh --target /media/sdcard --autoboot

# Run unit tests
AIOS_HOME=$(pwd) OS_ROOT=$(pwd)/OS bash tests/unit-tests.sh
```

---

## File Map

```
ai/core/
├── intent_engine.py   ← classifies input into typed intents
├── router.py          ← dispatches intents to OS subsystems
├── bots.py            ← autonomous bot framework (HealthBot, LogBot, RepairBot)
├── ai_backend.py      ← shell ↔ AI Core bridge (called by lib/aura-ai.sh)
├── commands.py        ← legacy NL → command mapper (still used as fallback)
├── llama_client.py    ← LLaMA / mock inference client
└── fuzzy.py           ← fuzzy command-name matching

OS/
├── sbin/init          ← boot init (activates OS body, hands off to AI Core)
├── bin/os-shell       ← interactive POSIX AI shell
├── lib/
│   ├── aura-mods/bus.mod   ← message bus
│   ├── aura-mods/core.mod  ← core utilities
│   ├── aura-mods/sysinfo.mod
│   ├── aura-memory/        ← symbolic key-value memory
│   ├── aura-semantic/      ← embedding-based semantic memory
│   ├── aura-hybrid/        ← hybrid recall (symbolic + semantic)
│   ├── aura-policy/        ← event-driven policy engine
│   ├── aura-agents/        ← background shell agents
│   └── aura-llm/           ← LLM shell wrapper
└── lib/filesystem.py  ← OS_ROOT-isolated file I/O

bin/
├── aios               ← top-level AI shell (uses router + intent engine)
├── aios-sys           ← OS system shell (runs registered commands)
└── aios-heartbeat     ← daemon heartbeat process

bootstrap-sd.sh        ← SD card / external storage bootstrap
install.sh             ← in-place installer (hosted environment)
```
