# AIOS-Lite — AI Core Architecture & Cognitive Integration Model

> © 2026 Chris Betts | AIOSCPU Official | AI-generated, fully legal

---

## Contents

1. [AI Core Architecture](#1-ai-core-architecture)
2. [Cognitive Layer](#2-cognitive-layer)
3. [AI–System Interaction Model](#3-aisystem-interaction-model)
4. [Bot & Module Integration](#4-bot--module-integration)
5. [Safety & Control Layer](#5-safety--control-layer)
6. [Cognitive Personality & Behavior](#6-cognitive-personality--behavior)
7. [AI Update & Evolution Model](#7-ai-update--evolution-model)

---

## 1. AI Core Architecture

### 1.1 Role of the AI Core

The AI Core is the central intelligence layer of AIOS-Lite. It sits between the user-facing shell (`bin/aios`) and the system execution layer (`bin/aios-sys` / `OS/bin/`). Its responsibilities are:

| Responsibility | Description |
|---|---|
| **Intent Understanding** | Translate free-form user input into structured, actionable intents |
| **Task Routing** | Dispatch intents to the appropriate bot or system module |
| **Memory Coordination** | Maintain context, symbolic, and semantic memory across sessions |
| **Identity Persistence** | Load and preserve the OS personality and operating state |
| **Safety Enforcement** | Apply guardrails and permission checks before any action executes |
| **Fallback Reasoning** | Respond gracefully when no structured handler can process a request |

The AI Core does **not** execute system calls directly. It only produces responses or issues requests to system modules through defined interfaces.

---

### 1.2 Initialization & Identity Persistence

**Boot sequence:**

```
OS/sbin/init
  └── rc2.d services start
        └── aura-agents (lib/aura-ai.sh)
              └── ai/core/ai_backend.py (Python AI layer loaded on first query)
```

**Identity files:**

| File | Purpose |
|---|---|
| `OS/proc/os.identity` | Persistent OS personality: name, version, boot epoch |
| `OS/proc/os.state` | Runtime state: runlevel, last heartbeat, kernel PID |
| `OS/proc/os.manifest` | Module inventory used to verify OS integrity |
| `OS/proc/aura/memory/` | Scoped key-value and semantic memory stores |
| `OS/proc/aura/context/window` | Rolling 50-line conversation context |

**Initialization steps:**

1. `sbin/init` creates required directory tree under `OS_ROOT`.
2. `os.identity` is read; if absent, `os-recover repair` regenerates it.
3. `os.state` is updated with current boot time and PID.
4. The AI memory subsystem loads the last known context window from `proc/aura/context/window`.
5. `IntentEngine` and `Router` are instantiated lazily on the first user query.

Identity persists across reboots through the files above. The AI Core never discards identity unless an explicit `os-recover wipe` is performed by an `operator`-role principal.

---

### 1.3 Memory Boundaries

| Memory Region | AI Can Read | AI Can Write | Notes |
|---|---|---|---|
| `OS/proc/aura/context/` | ✅ | ✅ | Conversation window, session state |
| `OS/proc/aura/memory/` | ✅ | ✅ | Scoped key-value memory |
| `OS/proc/aura/semantic/` | ✅ | ✅ | Embedding search index |
| `OS/proc/os.state` | ✅ | ✅ (via syscall) | System state (kernel writes) |
| `OS/proc/os.identity` | ✅ | ❌ | Read-only; modified only by `system` principal |
| `OS/var/log/` | ✅ | ✅ (append only) | Append-only audit and operation logs |
| `OS/etc/` | ✅ | ❌ | Configuration is read-only at runtime |
| `OS/bin/`, `OS/sbin/` | ❌ | ❌ | Executable files are off-limits to AI write |
| Host filesystem (`/`) | ❌ | ❌ | Blocked by `OS_ROOT` jail (filesystem.py) |
| `OS/mirror/` | ✅ | ✅ | Bridge-mirrored external devices |

The `OS_ROOT` jail in `OS/lib/filesystem.py` performs `os.path.realpath()` verification on every path operation, blocking all traversal attempts (`../`, symlink escapes, absolute paths outside `OS_ROOT`).

---

### 1.4 AI Core ↔ System Module Communication

The AI Core communicates with system modules through two interfaces:

**1. Shell subprocess (primary)**

```
ai_backend.py --input "<text>" --os-root <path> --aios-root <path>
  → invokes bin/aios-sys -- <command> [args]
  → aios-sys sources lib/aura-*.sh modules
  → returns stdout/stderr as string
```

**2. OS syscall interface (structured)**

```
OS/bin/os-syscall <call> [args...]
  → validates principal + capability
  → audits to var/log/syscall.log and var/log/aura.log
  → executes operation inside OS_ROOT
```

**3. Event bus (async)**

```
OS/bin/os-event <event-name> [data]
  → writes OS/var/events/<timestamp>.event
  → appends OS/var/log/events.log
  → triggers policy engine (aura-tasks daemon)
```

The AI Core never calls kernel internals, device drivers, or the host operating system directly.

---

### 1.5 Safety & Isolation Rules

| Rule | Enforcement Point |
|---|---|
| AI is confined to `OS_ROOT` | `OS/lib/filesystem.py` path jail |
| No direct host filesystem access | `OS_ROOT` prefix applied to all paths |
| Destructive syscalls require `operator` capability | `OS/bin/os-perms check` before execution |
| All AI-initiated syscalls are audited | `OS/bin/os-syscall` appends to `syscall.log` |
| Subprocess spawning is whitelist-only | `OS/bin/os-syscall spawn` + `aioscpu-secure-run` denylist |
| AI cannot modify its own binary or config | `OS/bin/`, `OS/etc/` are write-protected from AI principals |
| LLaMA model runs with `LLAMA_CPU_AFFINITY` and thermal cap | `config/llama-settings.conf` (68 °C limit) |

---

## 2. Cognitive Layer

### 2.1 Intent-Processing Pipeline

```
User Input (text)
  │
  ▼
IntentEngine.classify(text)          ← ai/core/intent_engine.py
  │  Returns: Intent(category, action, entities, raw, confidence)
  │
  ▼
Router.dispatch(intent)              ← ai/core/router.py
  │  Iterates registered bots in priority order
  │  First bot where can_handle(intent) == True handles the request
  │
  ├─ Bot matched → bot.handle(intent) → response string
  │
  └─ No bot matched
       │
       ▼
     parse_natural_language(text)    ← ai/core/commands.py
       │  Structured command plan (command + args)
       │
       ├─ plan.command != "chat" → run_system_command(plan) via bin/aios-sys
       │
       └─ plan.command == "chat"
            │
            ▼
          run_mock(text) / llama_client.py  ← LLaMA or rule-based response
```

**Pipeline guarantees:**
- Every input produces exactly one response.
- Every step is synchronous and single-threaded per request.
- No step modifies OS state without going through `os-syscall`.

---

### 2.2 User Command Interpretation

The `IntentEngine` applies a priority-ordered rule table (`_RULES` in `intent_engine.py`) using prefix/keyword matching:

| Match type | Example | Confidence |
|---|---|---|
| Exact prefix match (`"ping "`) | `ping 8.8.8.8` → `net.ping` | 0.95 |
| Keyword match (`"status"`) | `status` → `health.status` | 0.95 |
| Fuzzy match (`fuzzy.py`) | `chekc helth` → `health.check` | 0.7–0.9 |
| Chat fallback | `tell me a joke` → `chat.ask` | 0.5 |

Entities are extracted positionally: the remainder of the input after the trigger prefix becomes the entity value for the declared slot (e.g., `host`, `path`, `message`, `query`).

---

### 2.3 Task Routing to System Modules

| Intent Category | Primary Handler | Fallback |
|---|---|---|
| `health`, `system` | `HealthBot` | `commands.py` → `aios-sys` |
| `log` | `LogBot` | `commands.py` → `aios-sys` |
| `repair` | `RepairBot` | `commands.py` → `aios-sys` |
| `command` (fs, proc, net) | `commands.py` → `aios-sys` | `run_mock()` |
| `memory` | `commands.py` → `aios-sys` (mem.set/get) | `run_mock()` |
| `ai`, `chat` | `run_mock()` / `llama_client.py` | Echo + error message |

Routing is resolved at runtime. New bots can be registered via `Router.register_bot()` and are given the highest priority (prepended to the list).

---

### 2.4 Reasoning Boundaries

The AI Core reasons at the **intent** level, not at the code execution level.

| In scope | Out of scope |
|---|---|
| Classifying what the user wants | Deciding *how* to implement a new feature |
| Selecting the right bot or command | Modifying bot source code at runtime |
| Extracting entities from natural language | Parsing binary data or compiled executables |
| Generating natural-language responses | Accessing network endpoints directly |
| Reading log files for diagnostics | Writing to `OS/etc/` or `OS/bin/` |

The AI Core does not have a planning loop, multi-step chain-of-thought, or autonomous goal-pursuit capability in the current implementation. Every response is produced in a single synchronous pass.

---

### 2.5 Fallback Behavior

If the AI cannot handle a request at any pipeline stage:

| Stage | Fallback action |
|---|---|
| `IntentEngine` cannot classify | Returns `chat.ask` intent with `confidence=0.5` |
| No bot can handle the intent | Falls through to `commands.py` |
| `commands.py` produces `chat` plan | Routes to `run_mock()` / LLaMA |
| LLaMA binary absent or times out | `run_mock()` returns a canned rule-based reply |
| All paths produce an error | Returns `[ERROR] <description>` string to the shell |

No stage silently swallows errors. Every failure path produces an explicit human-readable response.

---

## 3. AI–System Interaction Model

### 3.1 Message Formats

**AI → System (command invocation):**

```
bin/aios-sys -- <command> [arg1] [arg2] ...
```

- `command` is a registered shell command name (e.g., `uptime`, `mem.set`, `ping`).
- Args are positional, space-separated, validated against the command's expected schema.
- Output is plain UTF-8 text returned on stdout.
- Error output is on stdout prefixed with `[ERROR]`.

**AI → System (syscall):**

```
OS_ROOT=<path> OS/bin/os-syscall <call> [args...]
```

All syscall invocations append a structured entry to `var/log/syscall.log`:

```
[YYYY-MM-DDTHH:MM:SSZ] [<principal>] <call> <args> → <result>
```

**System → AI (event):**

```
OS/var/events/<ISO8601-timestamp>.event
```

Event files contain:
```
event=<name>
data=<payload>
timestamp=<epoch>
```

**AI → AI (context):**

```
OS/proc/aura/context/window   (rolling 50-line plaintext)
```

---

### 3.2 System Call Wrappers for AI

The AI Core uses the following wrapper hierarchy rather than calling OS functions directly:

| Layer | Interface | Purpose |
|---|---|---|
| `ai_backend.py` | `run_system_command(plan, aios_root)` | Subprocess call to `bin/aios-sys` |
| `bin/aios-sys` | Shell script | Sources `lib/aura-*.sh`, runs command |
| `OS/bin/os-syscall` | Shell script | Permission check + audit + execution |
| `OS/lib/filesystem.py` | Python module | Path jail enforcement for file I/O |

The AI never invokes `os.system()`, `subprocess.run()`, or Python file I/O directly on paths outside `OS_ROOT`. All file access is routed through `OS/lib/filesystem.py`.

---

### 3.3 AI-Triggered Automation

The AI Core triggers automation through two mechanisms:

**1. Direct command dispatch** (synchronous, immediate):
```
ai_backend.py → aios-sys → lib/aura-*.sh → effect
```

**2. Event bus** (asynchronous, policy-driven):
```
os-event <event-name> [data]
  → writes var/events/<ts>.event
  → aura-tasks daemon polls at each heartbeat cycle
  → evaluates OS/etc/aura/policy.rules
  → executes matched action
```

Policy rule format:
```
on-event <event-name> do <action-command>
```

Automation rules are static at runtime. The AI Core does not modify `policy.rules` without explicit `operator` permission.

---

### 3.4 AI Receives System Events

System events are surfaced to the AI through:

| Source | Delivery mechanism | AI access |
|---|---|---|
| Kernel heartbeat | `OS/var/log/events.log` append | LogBot reads on demand |
| Service status change | `os-event service.<name>.<status>` | Policy engine + LogBot |
| Repair triggers | `os-event repair.needed` | RepairBot handles automatically |
| Boot completion | `os-event boot.complete` | Initializes context window |
| User commands | `bin/aios` stdin | Passed directly to `ai_backend.py` |
| HTTP API commands | `POST /api/v1/command` | Routed to `os-shell` → AI pipeline |

The `bin/aios-heartbeat` daemon publishes a heartbeat event every cycle, allowing the AI to detect OS health degradation passively.

---

### 3.5 AI Action Logging

Every AI action is recorded at multiple levels:

| Log file | What is recorded |
|---|---|
| `var/log/os.log` | General AI responses and shell interactions |
| `var/log/aura.log` | Permission grants/denials, boot events, repair |
| `var/log/syscall.log` | Every syscall the AI triggers (principal + call + result) |
| `var/log/events.log` | All OS events published to the event bus |
| `var/log/recover.log` | RepairBot actions and recovery sequences |

Log format:
```
[YYYY-MM-DDTHH:MM:SSZ] [<component>] <message>
```

Logs are append-only. The AI has no mechanism to delete or overwrite log entries.

---

## 4. Bot & Module Integration

### 4.1 Bot Registration

All bots extend `BaseBot` defined in `ai/core/bots.py`. Registration happens in `Router._init_bots()` at startup:

```python
# ai/core/router.py
def _init_bots(self) -> List[BaseBot]:
    return [
        RepairBot(os_root=self.os_root),   # Priority 1
        HealthBot(os_root=self.os_root),   # Priority 2
        LogBot(os_root=self.os_root),      # Priority 3
    ]
```

**To register a new bot at startup**, add it to the list in `_init_bots()`.

**To register a bot dynamically**, call:
```python
router.register_bot(MyBot(os_root=os_root))
# Prepends to list → highest dispatch priority
```

**Bot contract (`BaseBot` interface):**

```python
class BaseBot:
    name: str                              # Human-readable identifier

    def can_handle(self, intent: Intent) -> bool:
        # Return True if this bot owns the given intent
        ...

    def handle(self, intent: Intent) -> str:
        # Process the intent; return a plain-text response string
        # Must not raise exceptions — catch and return error string
        ...
```

---

### 4.2 AI Delegates Tasks to Bots

Delegation is performed by `Router.dispatch(intent)`:

```
intent.category = "health"
  → Router iterates [RepairBot, HealthBot, LogBot]
  → RepairBot.can_handle(intent) → False  (category != "repair")
  → HealthBot.can_handle(intent) → True   (category in {"health", "system"})
  → HealthBot.handle(intent) → response
  → Router returns response
```

The router stops at the first matching bot. Bots are independent — they do not call each other. If cross-bot coordination is needed, it must be modelled as separate intents processed sequentially at the shell level.

---

### 4.3 Bots Return Results

All bots return a single plain-text `str` from `handle()`. Conventions:

| Condition | Return format |
|---|---|
| Success | Human-readable result string |
| Partial success | Result with inline `[WARNING] ...` notes |
| Command not found | `[<BotName>] File not found: <path>` |
| Subprocess failure | `[<BotName>] Command failed: <exc>` |
| Write failure | `[<BotName>] Write failed: <exc>` |
| Unimplemented action | `[<BotName>] <action> not implemented` |

Bots never raise exceptions to the caller. All exceptions are caught in `BaseBot._run()` and `BaseBot._read_file()` and converted to descriptive strings.

---

### 4.4 Error Handling & Recovery

| Error scenario | Behavior |
|---|---|
| Bot `handle()` raises unexpectedly | `Router.dispatch()` should catch and return `[ERROR] <exc>` |
| Subprocess times out (> 10 s default) | `BaseBot._run()` catches `TimeoutExpired`, returns error string |
| Required file missing | `BaseBot._read_file()` returns `"File not found: <path>"` |
| `aios-sys` binary not found | `run_system_command()` returns `[ERROR] bin/aios-sys not found` |
| LLaMA binary absent | `run_mock()` returns a rule-based canned response |
| Repair needed | `RepairBot._self_repair()` recreates missing dirs and files automatically |
| Bot list empty | Router returns `None`; pipeline falls through to `commands.py` |

The repair recovery path (`RepairBot`) is self-contained: it scans required directories and files, recreates any that are missing, and reports exactly what was repaired.

---

## 5. Safety & Control Layer

### 5.1 Guardrails for AI Actions

| Guardrail | Mechanism |
|---|---|
| Filesystem jail | `OS/lib/filesystem.py` realpath check blocks all `../` traversal |
| Syscall whitelist | `OS/bin/os-syscall spawn` only allows whitelisted binaries |
| Denylist enforcement | `aioscpu-secure-run` rejects destructive patterns (`rm -rf /`, etc.) |
| No self-modification | AI cannot write to `OS/bin/`, `OS/sbin/`, `OS/etc/`, or AI source files |
| No credential access | AI cannot read `OS/etc/api.token` or `OS/etc/shadow` |
| Thermal cap | `config/llama-settings.conf` sets `THERMAL_LIMIT=68` °C; inference halts above threshold |
| CPU affinity | LLaMA pinned to big cores (`LLAMA_CPU_AFFINITY=1-3`) to prevent thermal runaway |

---

### 5.2 Permission Checks

All capability checks are performed by `OS/bin/os-perms`:

```sh
os-perms check <principal> <capability>
# exit 0 = allowed
# exit 1 = denied
# Appends result to var/log/aura.log
```

**Principal hierarchy:**

| Principal | Access level |
|---|---|
| `system` | Full OS access; reserved for kernel and boot scripts |
| `operator` | Administrative commands (repair, network, services) |
| `aura` | AI agent scope: memory read/write, log append, event publish |
| `any` | Read-only status and health queries |

The AI Core runs as the `aura` principal. Capabilities granted to `aura` by default:

- `memory.*` — full memory read/write
- `log.read`, `log.append` — log access (no delete)
- `health.*` — health and status queries
- `event.publish` — publish events to the event bus
- `repair.self` — self-repair of missing dirs/files

Capabilities **not** granted to `aura`:

- `syscall.spawn` — process spawning (requires `operator`)
- `network.*` — network reconfiguration (requires `operator`)
- `fs.rm` — file deletion (requires `operator`)
- `system.*` — kernel control (requires `system`)

---

### 5.3 Escalation Rules

When the AI needs a capability it does not hold:

1. The requested action is **blocked** at `os-perms check`.
2. The AI returns a response explaining the limitation:
   ```
   [AURA] This action requires operator permission. Please run in operator mode.
   ```
3. The denial is logged to `var/log/aura.log`.
4. The user may escalate by switching to operator mode in the shell:
   ```sh
   mode operator
   ```
5. In operator mode, commands execute with `operator` principal capabilities.
6. Escalation events are audited:
   ```
   [YYYY-MM-DDTHH:MM:SSZ] [os-perms] ESCALATE principal=aura→operator initiated by user
   ```

The AI Core cannot self-escalate. Escalation requires explicit user action.

---

### 5.4 User Override Rules

| Override | How to invoke | Effect |
|---|---|---|
| Operator mode | `mode operator` in shell | Grants `operator` capabilities for session |
| System mode | `mode system` (diagnostic) | Enables kernel-level diagnostics |
| Talk mode | `mode talk` | Restricts to conversational AI only; no system commands |
| Force repair | `os-recover repair` | Bypasses AI; runs repair directly |
| Force wipe | `os-recover wipe` | Destroys all AI memory and state (irreversible) |
| Disable AI | Set `AI_ENABLED=false` in `etc/aios.conf` | AI pipeline is bypassed; shell operates in pure command mode |

User overrides always take precedence over AI decisions. The AI cannot prevent, delay, or modify the effect of a user override.

---

### 5.5 Safe Failure Modes

| Failure | Safe behavior |
|---|---|
| AI pipeline crash | Shell continues in pure command mode (non-AI fallback) |
| LLaMA OOM / crash | `run_mock()` takes over; user is notified |
| Syscall denied | Error string returned; no partial execution |
| File write fails | Error string returned; state unchanged |
| Bot exception | Error string returned; other bots remain available |
| Thermal limit exceeded | LLaMA inference suspended; `[THERMAL] limit reached` logged |
| Heartbeat timeout | `os-recover repair` triggered automatically by kernel daemon |
| Event bus full | Oldest events are rotated out; no crash |

The OS kernel daemon (`OS/etc/init.d/os-kernel`) monitors the heartbeat independently of the AI Core and can trigger repair without AI involvement.

---

## 6. Cognitive Personality & Behavior

### 6.1 Communication Style

AURA communicates using the following principles:

| Principle | Expression |
|---|---|
| **Concise** | Responses are the shortest accurate answer; no padding or repetition |
| **Informative** | Includes relevant data (uptime values, file paths, error codes) not just status words |
| **Transparent** | Explains what it is doing and why, especially before any system action |
| **Honest about limits** | Explicitly states when it cannot help or needs escalation |
| **Consistent** | Uses the same terminology and format regardless of query type |

Response prefixes:

| Prefix | Meaning |
|---|---|
| `[HealthBot]` | Response from the health subsystem |
| `[LogBot]` | Response from the log subsystem |
| `[RepairBot]` | Response from the repair subsystem |
| `[AURA]` | General AI response or status message |
| `[ERROR]` | Unrecoverable error; action was not taken |
| `[WARNING]` | Partial success; action taken with caveats |
| `[REPAIR]` | Self-repair action was performed |

---

### 6.2 Responses to System Events

| Event | AI Behavior |
|---|---|
| `boot.complete` | Loads context window; logs `[AURA] System ready` |
| `repair.needed` | RepairBot activates; logs repair summary |
| `service.<name>.down` | HealthBot queried; status returned; event logged |
| `thermal.warning` | LLaMA suspended; user notified via next shell response |
| `heartbeat.timeout` | Kernel daemon triggers repair; AI logs `[WARNING] missed heartbeat` |
| `user.escalate` | Permissions updated; confirmation logged and returned to user |
| `update.available` | AI notifies user on next interaction; does not auto-apply |

---

### 6.3 How the AI Explains Actions

Before any system-modifying action, the AI prefixes its response with what it will do:

```
[RepairBot] Starting self-repair ...
  [REPAIR] Recreated missing dir: var/log
  [REPAIR] Recreated missing file: proc/os.messages
  [REPAIR] Repaired 2 item(s).
[RepairBot] Self-repair complete.
```

For read-only queries, the AI returns data without preamble.

For ambiguous inputs, the AI returns what it interpreted and the result:
```
[AURA] Interpreted as: health status check
=== HealthBot Status ===
 12:34:56 up 1 min, 1 user ...
```

---

### 6.4 Consistency Model

The AI maintains consistency through:

| Mechanism | Description |
|---|---|
| **Context window** | Last 50 lines of conversation stored in `proc/aura/context/window` |
| **Symbolic memory** | `mem.set` / `mem.get` — persistent key-value facts (e.g., `user/name=Alice`) |
| **Semantic memory** | `sem.set` / `sem.search` — embedding-based fuzzy recall |
| **Hybrid recall** | `recall <query>` searches context + symbolic + semantic and returns best match |
| **os.identity** | Personality file ensures the AI has the same name, version, and role on every boot |
| **Deterministic routing** | Same input always produces the same intent classification and routing |

If a conflict exists between context window content and a direct user instruction, the direct instruction takes precedence.

---

## 7. AI Update & Evolution Model

### 7.1 How the AI Core Is Updated

The AI Core components are updated through the standard AIOS update mechanism:

```sh
# Full system update and repair
os-recover repair

# Reinstall a specific module
os-recover reinstall ai

# Re-run full install
sh install.sh --repair ai
```

**Component-level update paths:**

| Component | Update method |
|---|---|
| `ai/core/*.py` | Replace files; no compilation required |
| `llama_model/` | Replace GGUF model file; update `config/llama-settings.conf` |
| `lib/aura-ai.sh` | Replace file; sourced fresh on each `aios` invocation |
| `OS/etc/aura/policy.rules` | Edit directly; reloaded by `aura-tasks` at next heartbeat |
| Bot plugins | Add Python file + register in `router.py`; no restart needed |

---

### 7.2 Compatibility Rules

| Rule | Details |
|---|---|
| **Intent rule backward compatibility** | New rules are appended to `_RULES`; existing rules are never removed without a deprecation cycle |
| **Bot interface stability** | `BaseBot.can_handle()` and `BaseBot.handle()` signatures are frozen; breaking changes require a major version bump |
| **Syscall API stability** | `os-syscall` call names and argument order are frozen per major version |
| **Memory format stability** | Key-value and semantic memory schemas are append-only; no fields are removed |
| **LLaMA model format** | Only GGUF format is supported; model quantization level must match `config/llama-settings.conf` |
| **Python version** | Python 3.8+ required; no dependencies outside the standard library for `ai/core/` |

---

### 7.3 Rollback Behavior

If an update introduces a regression:

```sh
# Restore OS from last backup
os-recover restore

# Repair to last known good state
os-recover repair
```

**AI model rollback:**

1. Stop the AI shell: `exit` from `bin/aios`.
2. Replace `llama_model/model.gguf` with the previous version.
3. Update `config/llama-settings.conf` to match.
4. Restart: `bin/aios`.

The `OS/proc/os.manifest` records a hash of all key files at last known good state. `os-recover repair` uses this manifest to detect and restore corrupted or missing files.

**Rollback does not affect:**
- User memory (`proc/aura/memory/`) — preserved across rollbacks unless `--wipe` is specified.
- Log files — never rolled back; they accumulate.
- `os.identity` — preserved; represents the persistent OS identity.

---

### 7.4 AI Model Versioning

| Field | Location | Format |
|---|---|---|
| OS version | `OS/proc/os.identity` | `version=<major.minor>` |
| AI model name | `config/llama-settings.conf` | `LLAMA_MODEL=<filename>` |
| AI model quantization | `config/llama-settings.conf` | `LLAMA_QUANT=int4` |
| AI Core module version | `ai/core/__init__.py` (if present) | Semantic versioning |
| AIOS build version | `OS/etc/aioscpu-release` | `AIOSCPU_VERSION=<tag>` |

Model selection by device variant:

| RAM | Model |
|---|---|
| 8 GB | 7B int4 quantised GGUF |
| 6 GB | 3B int4 quantised GGUF |

If the model file is absent or corrupt, `llama_client.py` falls back to `run_mock()` automatically. No crash. No user action required.

---

### 7.5 Long-Term Evolution Strategy

The AIOS-Lite AI Core is designed to evolve in stages:

**Stage 1 — Rule-based (current)**
- Rule-table intent classification in `intent_engine.py`
- Fixed bot registry (HealthBot, LogBot, RepairBot)
- Mock or local LLaMA chat fallback
- All state in flat files under `OS/proc/`

**Stage 2 — Context-aware routing**
- Extend `IntentEngine` with fuzzy-match scoring across all rules
- Add a `PlannerBot` that chains multi-step intents (e.g., "check health then repair")
- Introduce a rolling conversation history beyond the 50-line context window

**Stage 3 — Autonomous task execution**
- Add a task queue in `OS/proc/aura/tasks/`
- Allow the AI to propose multi-step plans and request user approval before execution
- Policy engine (`policy.rules`) extended with AI-authored rules (gated by `operator` permission)

**Stage 4 — Adaptive personalisation**
- Semantic memory used to adapt communication style per user preferences
- Long-term user preference profiles stored in `proc/aura/memory/user/`
- Model fine-tuning pipeline using on-device interaction logs (opt-in, privacy-gated)

**Design invariants that will not change:**
- `OS_ROOT` filesystem jail
- `os-perms` capability model
- Audit log append-only guarantee
- User override always wins
- No network egress without explicit `operator` permission

---

## Appendix A — Quick Reference: AI Core Files

| File | Role |
|---|---|
| `ai/core/intent_engine.py` | Intent classification (text → Intent) |
| `ai/core/router.py` | Bot dispatch (Intent → bot → response) |
| `ai/core/bots.py` | HealthBot, LogBot, RepairBot |
| `ai/core/commands.py` | Legacy natural-language command parser |
| `ai/core/llama_client.py` | LLaMA inference client + `run_mock()` fallback |
| `ai/core/fuzzy.py` | Fuzzy command matching |
| `ai/core/ai_backend.py` | Entry point: full pipeline orchestration |
| `lib/aura-ai.sh` | Shell wrapper that calls `ai_backend.py` |
| `OS/lib/filesystem.py` | OS_ROOT-jailed file I/O |
| `OS/bin/os-perms` | Capability permission checks |
| `OS/bin/os-syscall` | Audited system call interface |
| `OS/bin/os-event` | Event bus publisher |
| `OS/proc/os.identity` | Persistent OS identity |
| `OS/proc/aura/context/window` | Rolling conversation context |
| `OS/proc/aura/memory/` | Symbolic and semantic memory stores |
| `config/llama-settings.conf` | LLaMA model and hardware config |
| `OS/etc/aura/policy.rules` | Automation policy rules |

---

## Appendix B — Quick Reference: Permission Matrix

| Action | `any` | `aura` | `operator` | `system` |
|---|---|---|---|---|
| Read health / status | ✅ | ✅ | ✅ | ✅ |
| Read logs | ✅ | ✅ | ✅ | ✅ |
| Write logs (append) | ❌ | ✅ | ✅ | ✅ |
| Memory read/write | ❌ | ✅ | ✅ | ✅ |
| Publish events | ❌ | ✅ | ✅ | ✅ |
| Self-repair (dirs/files) | ❌ | ✅ | ✅ | ✅ |
| Spawn processes | ❌ | ❌ | ✅ | ✅ |
| Network reconfiguration | ❌ | ❌ | ✅ | ✅ |
| File deletion | ❌ | ❌ | ✅ | ✅ |
| Service start/stop | ❌ | ❌ | ✅ | ✅ |
| Kernel control | ❌ | ❌ | ❌ | ✅ |
| Modify `os.identity` | ❌ | ❌ | ❌ | ✅ |
| Modify `OS/bin/` | ❌ | ❌ | ❌ | ✅ |

---

*Last updated: 2026-04-03*
