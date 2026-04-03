# AIOS — UX, Interaction Model & Interface Layer

> © 2026 Chris Betts | AIOSCPU Official | AI-generated, fully legal

---

## Table of Contents

1. [UX Philosophy](#1-ux-philosophy)
2. [Interaction Model](#2-interaction-model)
3. [Command-Line Interface (CLI)](#3-command-line-interface-cli)
4. [Text User Interface (TUI)](#4-text-user-interface-tui)
5. [Optional GUI Layer](#5-optional-gui-layer)
6. [Voice & Natural Language Interaction](#6-voice--natural-language-interaction)
7. [Automation & Workflow Layer](#7-automation--workflow-layer)
8. [Notification & Event System](#8-notification--event-system)
9. [Accessibility](#9-accessibility)
10. [Final Integration Notes](#10-final-integration-notes)

---

## 1. UX Philosophy

### 1.1 Core Principles

| Principle | Definition |
|-----------|------------|
| **Intent-First** | The OS works from what the user *means*, not just what they type. Natural language and structured commands are equally valid entry points. |
| **Progressive Disclosure** | Simple commands produce simple output. Detail is always available one step deeper — never forced on the user. |
| **Transparent Agency** | Every AI decision is explainable. The OS surfaces *why* it chose an action, not just *what* it did. |
| **Graceful Degradation** | When AI inference is unavailable (thermal throttle, low battery, no model loaded), the OS falls back to rule-based matching, then structured CLI — never silent failure. |
| **Minimal Surprise** | Destructive or irreversible operations always require explicit confirmation, regardless of how they were invoked. |

### 1.2 How the OS Should Feel

AIOS should feel like a **knowledgeable assistant that also hands you the wrench** when you want it.

- **Responsive**: Commands return output in under 200 ms for cached/rule-based responses; AI inference responses display a spinner with elapsed time.
- **Honest**: The system reports confidence levels on AI-generated responses and clearly labels mock/fallback output.
- **Consistent**: Command namespaces (`fs.*`, `proc.*`, `net.*`) follow the same grammar everywhere — in the CLI, in the TUI, and in automation YAML.
- **Quiet by default**: No banners, no unsolicited tips after the first run. The OS speaks when spoken to.

### 1.3 Balance Between Automation and Manual Control

```
Manual ◄──────────────────────────────────────────► Automated
  │                                                        │
  │  aios-sys          aios (AI shell)       on-event      │
  │  (raw shell)       (intent + commands)   (policy rules) │
  │                                                        │
  └──── Full user control ──── AI assistance ──── Autonomous ─┘
```

- **The AI shell (`bin/aios`) is the default entry point.** It interprets commands, corrects typos, and routes intent — but never acts autonomously on system state without user input.
- **The real OS shell (`bin/aios-sys`) is always one keystroke away** (`sys` from within `aios`). No hoops.
- **Automation rules (`on-event … do …`) are opt-in** and must be explicitly defined in `OS/etc/aura/policy.rules`. The OS does not create automations on its own.

### 1.4 Accessibility Expectations

- All interfaces are **screen-reader compatible**: no decoration-only ASCII art in functional output, no color-only information encoding.
- **Text scaling** is supported in the TUI via `AIOS_FONT_SCALE` environment variable.
- **High-contrast mode** is available via `AIOS_THEME=high-contrast`.
- All interactive prompts can be driven via **keyboard only** — no mouse required.
- Voice interaction provides a **complete alternative** to typed input for every operation.

---

## 2. Interaction Model

### 2.1 How Users Interact with the OS

AIOS offers four interaction surfaces, all sharing the same underlying command and permission model:

| Surface | Entry Point | Audience |
|---------|-------------|----------|
| AI Shell CLI | `bin/aios` | Primary — all users |
| Real OS Shell | `bin/aios-sys` | Operators, power users |
| TUI Dashboard | `aios --tui` | Visual monitoring, navigation |
| REST API | `OS/bin/os-httpd` | Remote clients, integrations |

Each surface maps to the same **principal model** (system / operator / aura / any) and the same capability checks (`os-perms`).

### 2.2 Command Model

AIOS uses a **hybrid command model**:

```
User input
    │
    ├─ Exact match? ──────────────────► Execute directly
    │
    ├─ Typo-corrected match? ─────────► Confirm + execute  (fuzzy.py)
    │
    ├─ Intent classified? ────────────► Route to bot/handler  (intent_engine.py → router.py)
    │
    └─ Unrecognised? ─────────────────► LLaMA inference (if available)
                                        └─ Mock/rule fallback (if not)
```

**Command namespaces** enforce discoverability:

| Namespace | Domain |
|-----------|--------|
| `fs.*` | Filesystem operations (confined to OS_ROOT) |
| `proc.*` | Process management |
| `net.*` | Network operations |
| `mem.*` | Symbolic memory (key-value) |
| `sem.*` | Semantic embedding memory |
| `os-*` | Kernel/system subsystems |
| (bare verbs) | Shell-level shortcuts (`ls`, `cat`, `ask`, `status`) |

### 2.3 How the AI Mediates Interactions

The AI pipeline has three layers:

1. **IntentEngine** (`ai/core/intent_engine.py`) — classifies input into a structured `Intent` (category, action, entities, confidence).
2. **Router** (`ai/core/router.py`) — dispatches the intent to the appropriate bot or handler.
3. **Bots** (`ai/core/bots.py`) — `HealthBot`, `LogBot`, `RepairBot` each own a domain. Custom bots can be registered.

The AI mediates by **translating intent to commands**, not by bypassing the permission model. Every AI-dispatched action is logged to `var/log/aura.log` identically to a manually typed command.

### 2.4 Handling Ambiguous Input

When input is ambiguous, the OS follows a **clarify-then-act** pattern:

```
aios> restart
[AIOS] 'restart' is ambiguous. Which service?
  1) os-kernel
  2) aura-agents
  3) os-httpd
  > _
```

Rules:
- If confidence < 0.7, always ask before acting.
- If confidence ≥ 0.7 on a **read-only** operation, proceed and show reasoning.
- If confidence ≥ 0.7 on a **write/destructive** operation, show the intended action and prompt `[y/N]`.
- If the user types `?` as input, the OS offers the most recent ambiguity resolution.

### 2.5 Error and Recovery Interactions

All errors follow a **three-part format**:

```
[ERROR] <what failed>
[REASON] <why it failed>
[SUGGEST] <how to fix it>
```

Example:

```
aios> fs.cat /etc/shadow
[ERROR] Permission denied: /etc/shadow
[REASON] Principal 'user' lacks capability 'fs.read.protected'
[SUGGEST] Run 'mode operator' to elevate, or ask an operator to grant fs.read.protected
```

**Self-repair**: The `RepairBot` monitors for known failure states and can suggest or execute repairs:

```
aios> os-recover repair
[REPAIR] Checking file integrity...
[REPAIR] Missing: OS/var/log/os.log — restoring from template
[REPAIR] All checks passed. (3 items repaired)
```

---

## 3. Command-Line Interface (CLI)

### 3.1 CLI Structure

The AIOS CLI is the **primary interaction surface**. It is a REPL (Read-Eval-Print Loop) launched by `bin/aios`.

```
bin/aios          AI REPL — jailed to OS_ROOT, intent-aware
bin/aios-sys      Real OS shell — unrestricted, operator-grade
bin/aios-heartbeat  Background daemon — not interactive
```

### 3.2 Command Syntax

```
<namespace>.<verb> [<positional>...] [--<flag> [<value>]]
```

Or bare verbs (shell shortcuts):

```
<verb> [<positional>...] [--<flag> [<value>]]
```

Rules:
- Namespaces are dot-separated: `fs.ls`, `net.ping`, `proc.kill`.
- Flags use GNU-style `--long-flag` or `-s` short form.
- Positional arguments come before flags.
- Values with spaces must be quoted: `fs.write /tmp/note "hello world"`.

### 3.3 Flags and Parameters

| Flag | Applies to | Meaning |
|------|-----------|---------|
| `--help` | all commands | Show usage for this command |
| `--json` | read commands | Output as JSON instead of plain text |
| `--quiet` / `-q` | all | Suppress decorative output (machine-friendly) |
| `--yes` / `-y` | write/destructive | Skip confirmation prompt |
| `--tail <n>` | log commands | Show last *n* lines (default 50) |
| `--follow` / `-f` | log commands | Stream output continuously |
| `--port <n>` | os-httpd | Bind port (default 8080) |
| `--tls` | os-httpd | Enable HTTPS |
| `--no-auth` | os-httpd | Disable token auth (dev only) |

### 3.4 Help System

Three levels of help:

| Command | Output |
|---------|--------|
| `help` | Full command listing (all namespaces) |
| `help <namespace>` | All commands in that namespace |
| `<command> --help` | Usage, flags, examples for that command |

The help system is always available, even in non-interactive (piped) mode.

### 3.5 Example Commands

```sh
# Filesystem
fs.ls /                          # List OS root
fs.ls /etc --json                # JSON output
fs.cat /etc/aios.conf            # Read file
fs.write /tmp/note "hello world" # Write file
fs.mkdir /var/myapp              # Create directory
fs.rm /tmp/note --yes            # Remove without prompt
fs.cp /etc/aios.conf /tmp/aios.conf.bak
fs.find /var/log --name "*.log"

# Process
proc.ps                          # List processes
proc.kill 1234                   # Terminate PID 1234

# Network
net.ping 8.8.8.8                 # ICMP ping
net.ping google.com --count 5
net.ifconfig                     # Show interfaces

# AI / Memory
ask "why is disk usage high?"    # Natural-language query
recall "last boot time"          # Hybrid memory recall
mem.set app.version 2.1          # Store symbolic key
mem.get app.version              # Retrieve symbolic key
sem.set ctx.note "deploy notes from Friday meeting"
sem.search "Friday deploy"       # Semantic search

# System
status                           # Full OS state
sysinfo                          # Hardware/kernel info
uptime                           # System uptime
disk                             # Disk usage
services                         # Service health overview
ps                               # Process list

# Service control
start aura-agents
stop  os-httpd
restart os-httpd

# Mode switching
mode operator                    # Full access
mode system                      # Diagnostic/system mode
mode talk                        # Conversational AI mode

# HTTP server
OS_ROOT=$(pwd)/OS python3 OS/bin/os-httpd --port 8080 --no-auth
OS_ROOT=$(pwd)/OS python3 OS/bin/os-httpd --port 8443 --tls

# Recovery
os-recover repair                # Self-repair
os-recover backup                # Backup OS state
os-recover restore               # Restore from backup
os-recover deps                  # Dependency audit

# Permissions
os-perms list operator           # List operator capabilities
os-perms grant operator fs.write.protected
os-perms audit 20                # Last 20 permission events
```

### 3.6 Example Sessions

#### Session 1 — First Boot Orientation

```
$ bin/aios

AIOS — AI Operating System Shell
OS jail : /home/runner/work/PROJECT/PROJECT/OS
AI mode : mock
Type 'help' for commands, 'exit' to quit.

aios> help
AIOS AI Shell — built-in commands
══════════════════════════════════════════════════════
Filesystem (confined to OS_ROOT):
  fs.ls   [path]           List directory (default: /)
  ...
══════════════════════════════════════════════════════

aios> status
OS version  : 0.1
Runlevel    : 3
Boot time   : 2026-04-03T10:00:00Z
Kernel PID  : 5216
Last heartbeat: 2026-04-03T10:05:00Z

aios> ask "what services are running?"
[AI] Querying HealthBot...
Services running: os-kernel ✓  aura-agents ✓  os-httpd ✗ (stopped)

aios> start os-httpd
Starting os-httpd... done.

aios> exit
Goodbye.
```

#### Session 2 — Operator Diagnostic Workflow

```
aios> mode operator
[AUTH] Operator mode activated. All capabilities granted.

aios> os-resource status
CPU:     12% (Cortex-A78 cores 1-3, 2.84 GHz)
Memory:  3.4 GB / 8 GB (42%)
Disk:    52 GB / 128 GB (40%)
Thermal: 41°C  [OK — limit 68°C]

aios> os-recover deps
[DEPS] Checking runtime dependencies...
  bash        ✓
  python3     ✓
  sqlite3     ✓
  openssl     ✓
  llama.cpp   ✓  (7B int4 model loaded)
All dependencies satisfied.

aios> fs.cat /var/log/os.log --tail 10
[2026-04-03T10:04:55Z] [kernel] heartbeat ok
[2026-04-03T10:05:00Z] [kernel] heartbeat ok
...

aios> sys
[AIOS] Entering OS shell. Type 'exit' to return.
$ ls /
... (real shell, unrestricted)
$ exit
[AIOS] Returned from OS shell.

aios> exit
Goodbye.
```

#### Session 3 — Natural Language & Typo Correction

```
aios> staus
[AIOS] Did you mean 'status'? [Y/n] y
OS version  : 0.1
...

aios> what's the disk usage?
[AI] → disk
Filesystem  Size  Used  Avail  Use%
/OS         128G   52G    76G   40%

aios> kill all chrome processes
[AI] Intent: proc.kill (target=chrome)
[WARN] This will send SIGTERM to all processes matching 'chrome'. Proceed? [y/N] y
Killed: PID 8821 (chrome), PID 8835 (chrome --renderer)
```

---

## 4. Text User Interface (TUI)

### 4.1 TUI Layout

The TUI is launched with `aios --tui`. It is a full-terminal dashboard divided into persistent panels.

```
┌─────────────────────────────────────────────────────────────────────┐
│ AIOS v0.1 ·  Operator  ·  2026-04-03 11:00:05  ·  Thermal: 41°C   │  ← Header bar
├──────────────────────┬──────────────────────────────────────────────┤
│ SERVICES         F2  │  SYSTEM METRICS                         F3   │
│ ─────────────────    │  ─────────────────────────────────────────   │
│ os-kernel      ✓     │  CPU   ██████░░░░░░░░░░  12%                 │
│ aura-agents    ✓     │  MEM   ████████░░░░░░░░  42%  3.4/8 GB       │
│ os-httpd       ✗     │  DISK  ████████░░░░░░░░  40%  52/128 GB      │
│ aura-tasks     ✓     │  TEMP  ████░░░░░░░░░░░░  41°C / 68°C        │
│                      │                                              │
│ [S]tart [X]Stop      │                                              │
│ [R]estart  [↑↓]Sel   │                                              │
├──────────────────────┴──────────────────────────────────────────────┤
│ LOG STREAM                                                     F4   │
│ ─────────────────────────────────────────────────────────────────   │
│ [10:59:58] [kernel] heartbeat ok                                    │
│ [11:00:00] [httpd ] GET /api/v1/health 200 0ms                      │
│ [11:00:03] [aura  ] intent classified: query.status (conf=0.98)     │
│ [11:00:05] [kernel] heartbeat ok                                    │
├─────────────────────────────────────────────────────────────────────┤
│ aios> _                                                        F5   │  ← Input bar
└─────────────────────────────────────────────────────────────────────┘
  F1:Help  F2:Services  F3:Metrics  F4:Logs  F5:Shell  F6:Memory  F10:Quit
```

### 4.2 Navigation Model

- **Keyboard-first**: all navigation uses arrow keys, Tab, and function keys.
- **Focus ring**: Tab cycles focus between panels; active panel is highlighted with a brighter border.
- **Input bar (F5)** is always accessible — pressing any printable character while focus is outside the input bar jumps focus there.
- **Vim-style bindings** are available inside panels: `j`/`k` scroll, `g`/`G` jump to top/bottom.

| Key | Action |
|-----|--------|
| `Tab` | Cycle panel focus |
| `F1` | Help overlay |
| `F2` | Jump to Services panel |
| `F3` | Jump to Metrics panel |
| `F4` | Jump to Log stream |
| `F5` | Jump to input bar |
| `F6` | Memory/context panel |
| `F10` / `q` | Quit TUI (return to shell) |
| `↑` / `↓` | Scroll within focused panel |
| `Enter` | Activate selection in Services panel |
| `s` | Start selected service |
| `x` | Stop selected service |
| `r` | Restart selected service |
| `/` | Incremental search within log stream |
| `Esc` | Cancel search / close overlay |

### 4.3 Panels, Menus, and Views

#### Services Panel (F2)

Lists all services from `OS/bin/os-service-status`. Status indicators:

| Symbol | Meaning |
|--------|---------|
| `✓` | Running |
| `✗` | Stopped |
| `?` | Unknown |
| `⚠` | Degraded |

Pressing `Enter` on a selected service opens a **Service Detail overlay**:

```
┌── Service: os-httpd ──────────────────────────────┐
│ Status   : stopped                                │
│ PID      : —                                      │
│ Health   : OS/proc/health/os-httpd                │
│ Last log : [11:00:01] httpd stopped               │
│                                                   │
│  [S] Start   [X] Stop   [R] Restart   [Esc] Close │
└───────────────────────────────────────────────────┘
```

#### Metrics Panel (F3)

Auto-refreshes every 2 seconds from `OS/bin/os-resource`. Bars are ASCII progress bars; values are absolute and percentage. Thermal bar turns yellow above 55°C and red above 65°C.

#### Log Stream Panel (F4)

Tails `OS/var/log/aura.log` in real time. Log lines are colour-coded by severity (info/warn/error) where the terminal supports colour; in monochrome mode, severity is shown as a text prefix `[I]`/`[W]`/`[E]`.

#### Memory/Context Panel (F6)

```
┌── AI Context & Memory ────────────────────────────┐
│ Session context (last 10 inputs):                 │
│  1. "status"                       11:00:01       │
│  2. "what's the disk usage?"       11:00:04       │
│  3. "restart os-httpd"             11:00:07       │
│                                                   │
│ Symbolic memory (user scope):                     │
│  app.version = 2.1                                │
│  last.deploy = 2026-04-01                         │
│                                                   │
│  [C] Clear context   [M] Memory search   [Esc]    │
└───────────────────────────────────────────────────┘
```

#### Help Overlay (F1)

Full-screen overlay listing all TUI keybindings and available commands. Dismissed with `Esc` or `F1`.

### 4.4 ASCII Mockups

#### Full TUI (80×24 terminal)

```
╔═══════════════════════════════════════════════════════════════════════════════╗
║ AIOS v0.1 · operator · 2026-04-03 11:00:05 · 41°C · AI: llama-7b-int4       ║
╠════════════════════════╦══════════════════════════════════════════════════════╣
║ SERVICES         [F2]  ║ METRICS                                      [F3]   ║
║ ──────────────────     ║ ──────────────────────────────────────────────────  ║
║ > os-kernel      [✓]   ║ CPU  [████████░░░░░░░░░░░░░░░░░░]  28%            ║
║   aura-agents    [✓]   ║ MEM  [████████████░░░░░░░░░░░░░░]  42%  3.4/8GB   ║
║   os-httpd       [✗]   ║ DISK [████████████░░░░░░░░░░░░░░]  40%  52/128GB  ║
║   aura-tasks     [✓]   ║ TEMP [████░░░░░░░░░░░░░░░░░░░░░░]  41°C           ║
║                        ║                                                    ║
║   [s]tart [x]stop [r]  ║                                                    ║
╠════════════════════════╩══════════════════════════════════════════════════════╣
║ LOG STREAM                                                           [F4]   ║
║ ──────────────────────────────────────────────────────────────────────────  ║
║ [11:00:01] [I] [kernel ] heartbeat ok                                       ║
║ [11:00:03] [I] [ai     ] intent: query.status confidence=0.98               ║
║ [11:00:05] [I] [kernel ] heartbeat ok                                       ║
╠═══════════════════════════════════════════════════════════════════════════════╣
║ aios> _                                                              [F5]   ║
╠═══════════════════════════════════════════════════════════════════════════════╣
║  F1:Help  F2:Svc  F3:Metrics  F4:Logs  F5:Shell  F6:Memory  F10:Quit       ║
╚═══════════════════════════════════════════════════════════════════════════════╝
```

#### Confirmation Dialog

```
┌─────────────────────────────────────────────────────┐
│  ⚠  CONFIRM DESTRUCTIVE ACTION                      │
│                                                     │
│  Command : fs.rm /var/log/os.log                    │
│  Effect  : Permanently delete /var/log/os.log       │
│  Logged  : Yes (var/log/aura.log)                   │
│                                                     │
│     [Y] Yes, proceed     [N] Cancel                 │
└─────────────────────────────────────────────────────┘
```

---

## 5. Optional GUI Layer

### 5.1 Conceptual GUI Layout

The GUI layer is an **optional overlay** rendered on top of the TUI model when a graphical environment is detected (Android UI, X11, or Wayland). It mirrors the TUI layout using native widgets but adds touch, gesture, and mouse support.

```
┌──────────────────────────────────────────────────────────────────┐
│ 🔵 AIOS        operator   ●41°C   11:00:05              ⚙  ✕    │  ← Title bar
├──────────────────┬───────────────────────────────────────────────┤
│                  │                                               │
│  📋 Services     │   System Metrics                              │
│  ─────────────   │   CPU  ▓▓▓▓▓▓░░░░░░░░░░  28%                 │
│  ✅ os-kernel    │   MEM  ▓▓▓▓▓▓▓▓░░░░░░░░  42%                 │
│  ✅ aura-agents  │   DSK  ▓▓▓▓▓▓▓▓░░░░░░░░  40%                 │
│  ❌ os-httpd     │   🌡   41°C / 68°C                            │
│  ✅ aura-tasks   │                                               │
│                  │                                               │
├──────────────────┴───────────────────────────────────────────────┤
│  📜 Live Log                                                     │
│  [11:00:05] [kernel] heartbeat ok                                │
│  [11:00:03] [ai] intent: query.status  conf=0.98                 │
├──────────────────────────────────────────────────────────────────┤
│  🔍  Type a command or ask a question…                    ▶      │
└──────────────────────────────────────────────────────────────────┘
```

### 5.2 Window / Panel Structure

| Panel | Type | Resizable | Collapsible |
|-------|------|-----------|-------------|
| Title bar | Fixed | No | No |
| Services | Left sidebar | Yes (drag) | Yes |
| Metrics | Main top | Yes | Yes |
| Log stream | Main bottom | Yes | Yes |
| Input bar | Fixed bottom | No | No |
| Notification tray | Overlay (top-right) | No | Auto-dismiss |

### 5.3 Interaction Patterns

- **Touch / tap**: Tap a service to select; double-tap to open detail.
- **Long-press**: Opens context menu (Start / Stop / Restart / View logs).
- **Swipe left on log entry**: Copy to clipboard.
- **Pull-to-refresh**: Force-refresh metrics and service status.
- **Pinch-to-zoom**: Resize log text.
- **Input bar**: Full software keyboard support with command autocomplete chips.

### 5.4 Notifications and Alerts

| Alert Level | Visual | Dismissal |
|-------------|--------|-----------|
| `INFO` | Blue toast, bottom of screen | Auto (3 s) |
| `WARN` | Yellow banner, top of screen | Manual or auto (10 s) |
| `ERROR` | Red modal with action buttons | Manual |
| `CRITICAL` | Full-screen alert with vibration | Manual + confirmation |

All GUI notifications map 1:1 to events on the OS event bus (`os-event`), ensuring that dismissed GUI alerts are still captured in `OS/var/log/events.log`.

---

## 6. Voice & Natural Language Interaction

### 6.1 Voice Command Model

Voice input is an alternative entry point to the AI shell. Audio is transcribed locally (on-device STT), then the transcript is passed through the same IntentEngine pipeline as typed input.

```
Microphone input
      │
      ▼
On-device STT (whisper.cpp or Android SpeechRecognizer)
      │
      ▼
Transcript string
      │
      ▼
IntentEngine.classify(transcript)
      │
      ▼
Router.dispatch(intent)
      │
      ▼
Text-to-Speech output  +  Screen display
```

Voice is activated with:
- **Wake word**: `"Hey AIOS"` (configurable in `etc/aios.conf` → `VOICE_WAKE_WORD`)
- **Push-to-talk**: Long-press hardware volume-down button (Android integration)
- **CLI flag**: `aios --voice` for continuous listen mode

### 6.2 Fallback Behavior

| Condition | Fallback |
|-----------|----------|
| STT unavailable | Prompt user to type; display `[VOICE UNAVAILABLE]` |
| Transcript confidence < 0.6 | Read back transcript and ask "Did you mean: …?" |
| Intent confidence < 0.7 | Ask clarifying question before any action |
| LLaMA unavailable | Route to rule-based mock; label response `[Rule-based]` |
| Complete audio failure | Silent — show notification to check microphone |

### 6.3 Confirmation Rules

Voice commands follow stricter confirmation rules than typed commands because mis-transcription is possible:

| Action type | Confirmation required |
|-------------|----------------------|
| Read-only query | None (result spoken + displayed) |
| Service start/stop | Read back service name + "Confirm?" |
| File delete | Read back path + "This will permanently delete. Say YES to confirm." |
| Mode switch | Read back new mode + "Confirm?" |
| Any command while thermal > 65°C | Always confirm (safety interlock) |

The user must say **"yes"** (or type `y`) within 10 seconds or the action is cancelled.

### 6.4 Safety Boundaries

Voice commands are subject to the same capability model as typed commands. Additional voice-specific safety rules:

- **No destructive commands from voice in unattended mode** (`VOICE_UNATTENDED_SAFE=true` in `etc/aios.conf`). In unattended mode, commands that modify system state are queued and require manual confirmation.
- **No privilege escalation by voice**: `mode operator` via voice always requires a PIN or biometric confirmation.
- **No voice commands in recovery mode**: voice is disabled during `os-recover` operations to prevent accidental interruption.
- **All voice-originated commands** are tagged `[voice]` in `var/log/aura.log`.

---

## 7. Automation & Workflow Layer

### 7.1 How Users Create Automations

Automations are defined as **policy rules** in `OS/etc/aura/policy.rules`. The format is a simple DSL; more complex workflows can be defined as YAML files loaded by the `aura-tasks` daemon.

Three ways to create automations:

| Method | How |
|--------|-----|
| Direct file edit | Edit `OS/etc/aura/policy.rules` |
| CLI helper | `aios workflow add` (interactive wizard) |
| REST API | `POST /api/v1/command` with workflow YAML payload |

### 7.2 Triggers, Actions, Conditions

**Triggers** — what starts a workflow:

| Trigger | Description |
|---------|-------------|
| `on-event <name>` | OS event bus event |
| `on-schedule <cron>` | Time-based (cron syntax) |
| `on-metric <metric> <op> <value>` | Resource threshold breach |
| `on-boot` | System startup |
| `on-service-fail <name>` | Service enters failed state |
| `on-voice <phrase>` | Voice wake phrase |

**Conditions** — optional guards:

| Condition | Example |
|-----------|---------|
| `if thermal < 65` | Only act if temperature is safe |
| `if mem_pct < 80` | Only act if memory is available |
| `if principal == operator` | Only for elevated sessions |
| `if time between 02:00 and 04:00` | Maintenance window |

**Actions** — what the workflow does:

| Action | Example |
|--------|---------|
| `run <command>` | Execute any AIOS command |
| `notify <level> <message>` | Fire a notification |
| `log <message>` | Append to aura.log |
| `restart <service>` | Restart a service |
| `email <to> <subject>` | Send email (requires SMTP config) |
| `webhook <url> <payload>` | POST to a URL |

### 7.3 Workflow Syntax

#### Simple Policy Rules (DSL — `OS/etc/aura/policy.rules`)

```
# One-liner: event → action
on-event thermal-warning   do restart aura-agents
on-event disk-full         do log "Disk full detected; manual cleanup required"
on-event service-fail      do restart os-httpd
on-boot                    do start os-httpd
```

#### Full Workflow YAML (`OS/etc/aura/workflows/*.yaml`)

```yaml
# OS/etc/aura/workflows/auto-repair.yaml
name: auto-repair
description: "Restart failed services and notify operator"
version: "1.0"

trigger:
  type: on-event
  event: service-fail

conditions:
  - metric: thermal
    operator: "<"
    value: 65
  - principal: system

actions:
  - type: log
    message: "Auto-repair triggered by service-fail event"
  - type: restart
    service: "{{ event.service_name }}"
  - type: notify
    level: warn
    message: "Service {{ event.service_name }} was restarted automatically"
  - type: run
    command: "os-recover repair"
    on_failure:
      - type: notify
        level: error
        message: "Auto-repair failed — manual intervention required"
```

#### Scheduled Maintenance YAML

```yaml
# OS/etc/aura/workflows/nightly-backup.yaml
name: nightly-backup
description: "Nightly OS state backup during maintenance window"

trigger:
  type: on-schedule
  cron: "0 3 * * *"     # 03:00 daily

conditions:
  - time_between: ["02:00", "05:00"]
  - metric: mem_pct
    operator: "<"
    value: 70

actions:
  - type: run
    command: "os-recover backup"
  - type: log
    message: "Nightly backup completed"
  - type: notify
    level: info
    message: "Backup done. See var/log/recover.log for details"
```

#### Threshold-Based Workflow YAML

```yaml
# OS/etc/aura/workflows/thermal-throttle.yaml
name: thermal-throttle
description: "Reduce AI inference load when temperature approaches limit"

trigger:
  type: on-metric
  metric: thermal
  operator: ">="
  value: 60

actions:
  - type: run
    command: "mem.set system.ai_mode conservative"
  - type: notify
    level: warn
    message: "Thermal throttle active ({{ metric.value }}°C). AI load reduced."
  - type: log
    message: "Thermal throttle engaged at {{ metric.value }}°C"
```

### 7.4 Workflow CLI Examples

```sh
# List all loaded workflows
aios workflow list

# Validate a workflow file without applying it
aios workflow validate OS/etc/aura/workflows/auto-repair.yaml

# Load / reload a workflow
aios workflow load OS/etc/aura/workflows/nightly-backup.yaml

# Unload a workflow
aios workflow unload nightly-backup

# Fire a test event to exercise a workflow
os-event service-fail '{"service_name":"os-httpd"}'

# View workflow execution history
aios workflow history --tail 20
```

---

## 8. Notification & Event System

### 8.1 Event Types

Events are fired via `OS/bin/os-event` and persisted in `OS/var/events/`.

| Event Name | Source | Payload |
|------------|--------|---------|
| `boot` | `OS/sbin/init` | `{ "runlevel": 3 }` |
| `shutdown` | `OS/sbin/init` | `{ "reason": "user" }` |
| `service-start` | `os-service` | `{ "service_name": "…" }` |
| `service-stop` | `os-service` | `{ "service_name": "…" }` |
| `service-fail` | `os-service` | `{ "service_name": "…" }` |
| `thermal-warning` | `os-resource` | `{ "temp_c": 60 }` |
| `thermal-critical` | `os-resource` | `{ "temp_c": 65 }` |
| `disk-warning` | `os-resource` | `{ "disk_pct": 80 }` |
| `disk-full` | `os-resource` | `{ "disk_pct": 95 }` |
| `mem-warning` | `os-resource` | `{ "mem_pct": 80 }` |
| `repair-start` | `os-recover` | `{}` |
| `repair-complete` | `os-recover` | `{ "items_repaired": 3 }` |
| `permission-deny` | `os-perms` | `{ "principal": "…", "cap": "…" }` |
| `intent-classified` | `intent_engine` | `{ "action": "…", "conf": 0.98 }` |
| `voice-command` | voice subsystem | `{ "transcript": "…" }` |
| `user-event` | user / automation | arbitrary |

Custom events are fired with:

```sh
os-event my-event '{"key":"value"}'
```

### 8.2 Notification Rules

Notifications are generated from events via the policy engine. Default notification rules:

| Trigger | Level | Channel |
|---------|-------|---------|
| `service-fail` | `WARN` | TUI banner, log |
| `thermal-warning` | `WARN` | TUI banner, log |
| `thermal-critical` | `ERROR` | TUI modal, log |
| `disk-full` | `ERROR` | TUI modal, log |
| `permission-deny` | `WARN` | Log only |
| `repair-complete` | `INFO` | TUI toast, log |
| `boot` | `INFO` | Log only |

Users can add custom notification rules in `OS/etc/aura/policy.rules`:

```
on-event my-event do notify warn "Custom event fired: {{ event.key }}"
```

### 8.3 Escalation Logic

If a notification is not acknowledged within its escalation window, it escalates to the next level:

```
INFO  (auto-dismiss 3s)
  │
  └─ if not acknowledged within 30s → WARN (manual dismiss required)
           │
           └─ if not acknowledged within 5m → ERROR (modal + sound)
                    │
                    └─ if service still failed after 10m → CRITICAL
                               (full-screen alert + write to var/log/escalation.log)
```

Escalation is implemented in `aura-tasks` via the policy engine. The window durations are configurable in `etc/aios.conf`:

```ini
NOTIFY_ESCALATE_INFO_S=30
NOTIFY_ESCALATE_WARN_S=300
NOTIFY_ESCALATE_ERROR_S=600
```

### 8.4 Logging and History

All events and notifications are persisted across two locations:

| Log | Contents | Rotation |
|-----|----------|----------|
| `OS/var/log/events.log` | All fired events, timestamped | Daily, keep 7 days |
| `OS/var/log/aura.log` | AI decisions, permissions, repairs | Daily, keep 30 days |
| `OS/var/log/os.log` | General OS operation | Daily, keep 14 days |
| `OS/var/log/escalation.log` | Escalated critical alerts | Keep all (no rotation) |
| `OS/var/events/<ts>.event` | Individual event files | Purged after 24 h |

**Query event history from the CLI:**

```sh
# Last 20 events of any type
aios events --tail 20

# Filter by event name
aios events --filter service-fail

# Events in a time range
aios events --since "2026-04-03T10:00:00Z" --until "2026-04-03T12:00:00Z"

# Real-time event stream
aios events --follow
```

---

## 9. Accessibility

### 9.1 Accessibility Requirements

AIOS targets **WCAG 2.1 AA equivalence** for terminal and GUI interfaces, adapted for OS shell contexts.

| Requirement | Implementation |
|-------------|----------------|
| No color-only information | All status indicators include text labels (`✓` + `running`, not just green) |
| Screen reader compatible | All TUI elements have ARIA-equivalent text descriptions when rendered in GUI mode |
| Keyboard-only operation | Every action reachable without a mouse or touch |
| Sufficient contrast | Default theme meets 4.5:1 contrast ratio for normal text, 3:1 for large text |
| No time-limited content | No content disappears without user action (except INFO toasts, which can be disabled) |
| Voice alternative | Full voice command coverage for all CLI operations |

### 9.2 Text Scaling Rules

Text size in the TUI and GUI is controlled by the `AIOS_FONT_SCALE` environment variable:

| Value | Effect |
|-------|--------|
| `1.0` (default) | Standard terminal font size |
| `1.5` | 150% — large text mode |
| `2.0` | 200% — extra-large text mode |
| `0.75` | 75% — compact mode for small screens |

In GUI mode, font size maps directly to the system font scale preference.

TUI column widths reflow automatically based on terminal dimensions. Minimum supported terminal width is **60 columns**; at widths below 80 columns, secondary panels collapse automatically.

### 9.3 Color Contrast Rules

| Theme | Background | Foreground | Contrast ratio |
|-------|-----------|------------|----------------|
| Default (dark) | `#1a1a2e` | `#e0e0e0` | 11.5:1 |
| High-contrast | `#000000` | `#ffffff` | 21:1 |
| Light | `#f5f5f5` | `#1a1a1a` | 14.7:1 |
| Solarized-dark | `#002b36` | `#839496` | 4.6:1 |

Set theme with `AIOS_THEME=high-contrast` (or `light`, `solarized-dark`) in `etc/aios.conf` or at runtime:

```sh
mem.set system.theme high-contrast
```

Status colors also follow the **WCAG non-text contrast** rule (3:1 minimum against adjacent colors):

| Status | Default | High-contrast |
|--------|---------|---------------|
| Running (OK) | Green `#00cc66` | Bright green `#00ff00` |
| Warning | Yellow `#ffcc00` | Bright yellow `#ffff00` |
| Error | Red `#ff4444` | Bright red `#ff0000` |
| Unknown | Grey `#888888` | White `#ffffff` |

### 9.4 Alternative Interaction Modes

| Mode | Activation | Description |
|------|-----------|-------------|
| **Voice-only** | `aios --voice-only` | Disables keyboard input; all interaction via voice |
| **Screen-reader** | `AIOS_SCREEN_READER=1` | Outputs plain-text descriptions of all UI state changes |
| **Reduced-motion** | `AIOS_REDUCED_MOTION=1` | Disables spinner animations, blinking cursors |
| **High-contrast** | `AIOS_THEME=high-contrast` | Maximum contrast color scheme |
| **Monochrome** | `AIOS_THEME=mono` | No color output; severity via text prefix `[I]`/`[W]`/`[E]` |
| **Large-text** | `AIOS_FONT_SCALE=2.0` | Doubles all text size in GUI/TUI |
| **No-TUI** | `aios --no-tui` | Pure CLI; no panel layout |
| **Braille-ready** | `AIOS_SCREEN_READER=1 AIOS_THEME=mono` | Combines screen-reader + monochrome for braille display compatibility |

All accessibility settings can be persisted to the user's symbolic memory:

```sh
mem.set user.theme high-contrast
mem.set user.font_scale 1.5
mem.set user.reduced_motion true
```

They are applied automatically on the next session start.

---

## 10. Final Integration Notes

### Document Status

| Section | Status |
|---------|--------|
| UX Philosophy | ✅ Complete |
| Interaction Model | ✅ Complete |
| CLI | ✅ Complete |
| TUI | ✅ Complete |
| GUI Layer | ✅ Complete |
| Voice & NLI | ✅ Complete |
| Automation & Workflow | ✅ Complete |
| Notification & Events | ✅ Complete |
| Accessibility | ✅ Complete |

### Integration Points in the Codebase

| Section | Implemented in |
|---------|---------------|
| CLI entry point | `bin/aios`, `bin/aios-sys` |
| Command namespaces | `lib/aura-fs.sh`, `lib/aura-proc.sh`, `lib/aura-net.sh` |
| AI pipeline | `ai/core/intent_engine.py`, `ai/core/router.py`, `ai/core/bots.py` |
| Memory system | `OS/bin/os-shell` (mem.set/get, sem.set/search, recall) |
| Notification/event bus | `OS/bin/os-event`, `OS/bin/os-msg` |
| Policy / automation | `OS/etc/aura/policy.rules`, `aura-tasks` daemon |
| Permissions | `OS/bin/os-perms` |
| HTTP REST API | `OS/bin/os-httpd` |
| Logging | `OS/var/log/aura.log`, `OS/var/log/os.log`, `OS/var/log/events.log` |
| Configuration | `etc/aios.conf`, `config/aios.conf` |

### Related Documents

- [`docs/ARCHITECTURE.md`](ARCHITECTURE.md) — System architecture and hardware specs
- [`docs/API-REFERENCE.md`](API-REFERENCE.md) — Complete API reference
- [`docs/AURA-API.md`](AURA-API.md) — AURA line protocol reference
- [`docs/CAPABILITIES.md`](CAPABILITIES.md) — Capability implementation matrix
- [`docs/SECURITY.md`](SECURITY.md) — Security model and threat mitigations

---

*Last updated: 2026-04-03*
