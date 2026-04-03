# How the AI Model Becomes the OS Brain

> © 2026 Chris Betts | AIOSCPU Official | AI-generated, fully legal

---

## Overview

In a conventional operating system the kernel is a passive rule-follower: it
schedules processes, manages memory, and dispatches system calls — but it
never *understands* what is happening. AIOS inverts this. The AI model sits
at the core of every user interaction, every shell command, every service
decision, and every repair cycle. The OS provides the body; the AI is the
brain.

```
┌────────────────────────────────────────────────────────────┐
│                     User / Operator                        │
└───────────────────────────┬────────────────────────────────┘
                            │  natural language + commands
                            ▼
┌────────────────────────────────────────────────────────────┐
│                 AIOS Shell  (bin/aios)                     │
│  • accepts text input (commands or natural language)       │
│  • fuzzy-corrects typos (aura-typo)                        │
│  • dispatches to Intent Engine                             │
└───────────────────────────┬────────────────────────────────┘
                            │
                            ▼
┌────────────────────────────────────────────────────────────┐
│              Intent Engine  (aura-mods/intent.mod)         │
│  • classifies input: filesystem | process | network |      │
│    memory | bridge | system | chat                         │
│  • logs every classified intent to var/log/intent.log      │
│  • hands off to the Message Router                         │
└───────────────────────────┬────────────────────────────────┘
                            │
                            ▼
┌────────────────────────────────────────────────────────────┐
│              Message Router  (aura-mods/router.mod)        │
│  • routing table: dest → handler function                  │
│  • delivers message to the correct AURA module             │
│  • publishes to the Message Bus for other subscribers      │
└──────┬────────────────────┬────────────────────────────────┘
       │                    │
       ▼                    ▼
┌────────────┐   ┌──────────────────────────────────────────┐
│  OS Modules│   │          AI Core  (ai/core/)             │
│  aura-fs   │   │  ai_backend.py  → parse_natural_language │
│  aura-proc │   │  llama_client.py → LLaMA model (gguf)    │
│  aura-net  │   │  fallback: rule-based responses          │
│  aura-mem  │   └──────────────────────────────────────────┘
│  aura-llm  │
└────────────┘
```

---

## The Four Layers

### 1. Body — Init + Services (OS/sbin/init)

`sbin/init` is the first thing that runs. It builds the runtime directory
tree, fires every service in `etc/rc2.d/`, writes `proc/os.state`, and then
hands control to the shell. This is the "boot nervous system" — it ensures
the body is alive before the brain wakes up.

```
sbin/init
  ├─ mkdir  var/log, var/service, proc/aura/, mirror/*, tmp
  ├─ init   proc/os.state, proc/os.messages, var/log/aura.log
  ├─ source config/aios.conf
  ├─ start  rc2.d/S* services (banner, os-kernel, aura-bridge)
  └─ exec   bin/os-shell  (or bin/aios)
```

### 2. Nervous System — Message Bus (aura-mods/bus.mod)

Every component that needs to communicate appends a timestamped record to
`var/log/bus.log`. Any component that wants to listen maintains a cursor
file in `var/service/bus/`.  This gives AIOS a durable, append-only nervous
system that works even on constrained hardware with no IPC primitives.

```
bus_publish  "channel" "message"   → append to bus.log
bus_subscribe "channel"            → read new messages since last cursor
bus_broadcast "message"            → publish to the "broadcast" channel
```

### 3. Cognition — Intent Engine + Router

When the user types something:

1. **Intent Engine** (`intent.mod`) reads the text and classifies it into
   one of seven classes: `filesystem`, `process`, `network`, `memory`,
   `bridge`, `system`, or `chat`.

2. **Router** (`router.mod`) looks up the registered handler for that class
   and calls it. If a live handler function is registered in
   `proc/aura/router/`, it is invoked immediately; otherwise the message is
   queued.

3. For `chat`-classified inputs the Router calls the **LLM** module
   (`aura-llm/llm.mod`), which builds a context-aware prompt from:
   - The last 10 lines of `proc/aura/context/window` (session context)
   - Matching entries from the symbolic memory index
   - The user's input
   
   It then calls `llama-cli` with the `.gguf` model, or falls back to a
   rule-based response engine if no model is present.

### 4. Memory — Three Tiers

| Tier | Storage | Speed | Use |
|---|---|---|---|
| **Context Window** | `proc/aura/context/window` (rolling 50 lines) | instant | recent conversation |
| **Symbolic Memory** | `etc/aura/memory.index` (key-value) | fast | named facts (`mem.set`) |
| **Semantic Memory** | `proc/aura/semantic/` (embedding index) | moderate | similarity search (`sem.search`) |

The **Hybrid Recall Engine** (`aura-hybrid/engine.mod`) queries all three
tiers simultaneously and merges the results, ensuring the AI always has the
best available context when formulating a response.

---

## How the AI Model Plugs In

### With a GGUF model installed

```
llama_model/
  └── llama-3-8b.Q4_K_M.gguf   ← place any GGUF here

lib/aura-llm/llm.mod
  llm_available()  → finds llama-cli binary
  llm_model()      → finds first *.gguf file
  llm_prompt_build() → assembles context-aware prompt
  llm_query()      → calls: llama-cli -m <model> --n-predict 256 ...
```

The model receives a prompt that looks like:

```
You are AIOS, an intelligent AI operating system. You help the user manage
their system, answer questions, and bridge to other devices.

Recent context:
  [user] ls /etc
  [sys]  aura  boot.target  init.d  os-release  passwd  rc2.d

Relevant memory:
  phone_model = Samsung Galaxy S21 FE

User: how much memory is free?
Assistant:
```

The model's response is written directly to the shell's stdout, making it
indistinguishable from a built-in command output.

### Without a model (rule-based fallback)

`ai/core/llama_client.py:run_mock()` handles common OS questions with
pattern-matched responses. This ensures the shell remains usable on devices
without enough RAM for a model.

---

## The Boot-to-Brain Sequence

```
Power on / sh bootstrap.sh
    │
    ▼
OS/sbin/init
    │  mkdir runtime dirs, write os.state
    │  start rc2.d services
    ▼
bin/aios (or OS/bin/os-shell)
    │  source aura-core, aura-fs, aura-proc, aura-net
    │  source aura-typo, aura-llama, aura-ai
    ▼
REPL loop
    │  read user input
    ├─ built-in command? → run directly
    ├─ typo? → suggest correction
    ├─ AURA command? → run_command() dispatch
    └─ fallback → aura_ai_query()
                     │
                     ▼
               ai/core/ai_backend.py
                     │
                     ├─ parse_natural_language() → CommandPlan
                     │      command? → bin/aios-sys -- <cmd>
                     │      chat?   → run_mock() or llama-cli
                     │
                     └─ stdout → back to shell
```

---

## Autonomous Behavior — Bot System

The bot system (`OS/lib/aura-agents/bot.agent`) runs three lightweight bots
in a background loop:

| Bot | Role |
|---|---|
| **sysmon** | Reads CPU load, free memory, disk %; triggers bus alerts when thresholds exceeded |
| **advisor** | Checks for missing model files, oversized logs, stale configs; surfaces tips |
| **doctor** | Scans `aura.log` for ERROR entries; auto-repairs missing runtime dirs; reports issues |

Bots publish findings to the message bus, which the shell can subscribe to
and surface as notifications. The bot daemon is started by the `aura-agents`
service at boot.

---

## Design Principles

| Principle | Implementation |
|---|---|
| AI is the OS | Every user interaction routes through the intent engine and may invoke the LLM |
| AI lives in the system | Model file in `llama_model/`, context in `proc/aura/`, memory in `etc/aura/` |
| AI can modify itself | `fs.*` commands are jailed to `OS_ROOT` but give full read/write access within it |
| AI understands errors | Doctor bot + `aura.log` + intent classification of error messages |
| OS is the body | `sbin/init`, `rc2.d` services, `kernelctl`, `os-service` — all exist to keep the body running |
| Portability | POSIX sh throughout; zero hard dependencies except Python 3 for the AI backend |

---

## Quick Reference: Key Files

| File | Role |
|---|---|
| `OS/sbin/init` | Boot — brings the body online |
| `bin/aios` | AI shell — the primary interface |
| `OS/bin/os-shell` | Classic AI shell (POSIX sh) |
| `OS/lib/aura-mods/intent.mod` | Intent classifier |
| `OS/lib/aura-mods/router.mod` | Message router |
| `OS/lib/aura-mods/bus.mod` | Message bus |
| `OS/lib/aura-llm/llm.mod` | LLM wrapper (llama.cpp) |
| `ai/core/ai_backend.py` | Python AI dispatch |
| `ai/core/commands.py` | NL → command planner |
| `ai/core/llama_client.py` | LLaMA client + mock |
| `OS/lib/aura-agents/bot.agent` | Autonomous bot system |
| `OS/lib/aura-hybrid/engine.mod` | Hybrid memory recall |
| `bootstrap.sh` | Portable SD-card/USB bootstrap |
