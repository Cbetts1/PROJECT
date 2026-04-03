# AIOS-Lite — OS Architecture Reference

> © 2026 Christopher Betts | AIOSCPU Official
> *Created and developed by Christopher Betts. All code was generated or refined using AI tools under the creator's direction.*

---

## Table of Contents

1. [System Overview](#1-system-overview)
2. [Boot Sequence](#2-boot-sequence)
3. [Runlevels](#3-runlevels)
4. [Kernel / Pseudo-Kernel Boundary](#4-kernel--pseudo-kernel-boundary)
5. [Syscall List](#5-syscall-list)
6. [Process Model](#6-process-model)
7. [Scheduler](#7-scheduler)
8. [Resource Manager](#8-resource-manager)
9. [Permissions Model](#9-permissions-model)
10. [Service Registry](#10-service-registry)
11. [Networking Model](#11-networking-model)
12. [API Surface](#12-api-surface)

---

## 1. System Overview

AIOS-Lite is a layered, shell-native AI operating system. It runs on top of any POSIX host (Android/Termux, Linux, macOS) and installs as an isolated userspace environment rooted at `$OS_ROOT`. It does not replace the host kernel; instead it presents a consistent OS interface above the host, supplemented by an AI cognitive layer (AURA).

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
║                  PSEUDO-KERNEL LAYER (sbin/init)            ║
║   scheduler · resource-mgr · permissions · service-registry ║
╠══════════════════════════════════════════════════════════════╣
║                    BRIDGE / MIRROR LAYER                    ║
║          iOS bridge · Android bridge · SSH bridge           ║
╠══════════════════════════════════════════════════════════════╣
║                      HOST POSIX KERNEL                      ║
║          Linux / Android (Termux) / macOS / Darwin          ║
╚══════════════════════════════════════════════════════════════╝
```

---

## 2. Boot Sequence

The boot sequence is driven by `OS/sbin/init` and proceeds through five phases.

```
Phase 0 — Environment Bootstrap
  └─ Detect OS_ROOT (auto-derive from script location)
  └─ Export PATH="$OS_ROOT/bin:$OS_ROOT/sbin:$PATH"
  └─ Source lib/aura-core.sh (core primitives)
  └─ Write PID to $OS_ROOT/proc/os (process identity)

Phase 1 — Early Services (init.d/banner)
  └─ Print AIOS-Lite boot banner
  └─ Load $OS_ROOT/etc/os-release
  └─ Write $OS_ROOT/proc/os.identity
  └─ Set OS_STATE=booting in proc/os.state

Phase 2 — Subsystem Init (runlevel 1)
  └─ Start logging subsystem     (var/log/aios.log)
  └─ Start event subsystem       (var/events/)
  └─ Start message bus           (OS/proc/bus.sock)
  └─ Start service-health daemon (var/service/*.health)

Phase 3 — Kernel Services (runlevel 2 — rc2.d/)
  └─ os-kernelctl start          (pseudo-kernel daemon)
  └─ aura-bridge start           (cross-OS bridge detection)
  └─ aura-llm start              (llama.cpp wrapper if model present)
  └─ aura-memory / semantic / hybrid layers
  └─ aura-policy engine          (event-driven rules)
  └─ aura-agents start           (background intelligence agents)

Phase 4 — Shell Ready
  └─ OS_STATE=running written to proc/os.state
  └─ os-shell launched (or control returns to caller)

                        BOOT SEQUENCE ASCII DIAGRAM
┌───────────────────────────────────────────────────────┐
│  sbin/init                                            │
│    │                                                  │
│    ├── [Phase 0] Bootstrap env & aura-core.sh         │
│    │                                                  │
│    ├── [Phase 1] init.d/banner → os-release → state  │
│    │                                                  │
│    ├── [Phase 2] logging → events → bus → health     │
│    │                                                  │
│    ├── [Phase 3] rc2.d/* (kernel, bridge, llm, ai)   │
│    │                                                  │
│    └── [Phase 4] os-shell / interactive prompt       │
└───────────────────────────────────────────────────────┘
```

**Cold boot time target:** < 2 seconds on Android/Termux with no LLM model; < 8 seconds with model loading.

---

## 3. Runlevels

AIOS-Lite defines four runlevels modelled on classic SysV init.

| Runlevel | Name | Description |
|---|---|---|
| **0** | Halt | Shutdown / cleanup, flush logs, unmount mirrors |
| **1** | Single | Emergency / repair shell, no services started |
| **2** | Multi | Full OS with all services and AI layer (default) |
| **3** | Update | Maintenance mode — services paused, update in progress |

Runlevel scripts live in `OS/etc/rc2.d/` (symlinks to `init.d/` scripts).  
The active runlevel is stored in `OS/proc/os.state` under the key `OS_RUNLEVEL`.

Transitioning runlevels:
```sh
os-kernelctl runlevel <0|1|2|3>
```

Services that honour runlevels expose a `start` / `stop` interface and register themselves in the service registry (see §10).

---

## 4. Kernel / Pseudo-Kernel Boundary

AIOS-Lite does not ship or modify a real OS kernel. It defines a **pseudo-kernel** — a set of daemons and scripts that perform kernel-like coordination in userspace.

### Pseudo-Kernel Components

| Component | File | Responsibility |
|---|---|---|
| `os-kernelctl` | `OS/bin/os-kernelctl` | Lifecycle control, runlevel transitions |
| `os-sched` | `OS/bin/os-sched` | Cooperative task scheduler |
| `os-resource` | `OS/bin/os-resource` | CPU/memory/disk quotas per service |
| `os-perms` | `OS/bin/os-perms` | Permission enforcement |
| `os-syscall` | `OS/bin/os-syscall` | Unified syscall dispatcher |
| `os-state` | `OS/bin/os-state` | Global OS state store |
| `aura-core.sh` | `lib/aura-core.sh` | Core primitives (locks, paths, logging) |

### Boundary Rule

Any operation that **reads or writes outside `$OS_ROOT`** must go through the bridge layer (`OS/lib/aura-bridge/`). Operations inside `$OS_ROOT` use the filesystem abstraction in `OS/lib/filesystem.py`.

```
INSIDE OS_ROOT          │  OUTSIDE OS_ROOT
─────────────────────────┼──────────────────────────────
filesystem.py (Python)   │  aura-bridge modules (shell)
aura-core.sh primitives  │  Host syscalls (passthrough)
os-syscall dispatcher    │  Mirror layer (OS_ROOT/mirror/)
```

---

## 5. Syscall List

AIOS-Lite exposes its own syscall interface via `OS/bin/os-syscall`. Each syscall maps to a shell function or Python method.

### Filesystem Syscalls

| Syscall | Arguments | Description |
|---|---|---|
| `fs.read` | `<path>` | Read file inside OS_ROOT |
| `fs.write` | `<path> <data>` | Write/create file inside OS_ROOT |
| `fs.append` | `<path> <data>` | Append to file |
| `fs.list` | `<path>` | List directory contents |
| `fs.exists` | `<path>` | Test file existence |
| `fs.stat` | `<path>` | Return file metadata |
| `fs.delete` | `<path>` | Delete file |
| `fs.mkdir` | `<path>` | Create directory |

### Process Syscalls

| Syscall | Arguments | Description |
|---|---|---|
| `proc.spawn` | `<cmd> [args]` | Spawn a background process |
| `proc.kill` | `<pid>` | Send SIGTERM to a process |
| `proc.list` | — | List all tracked processes |
| `proc.wait` | `<pid>` | Wait for process to finish |
| `proc.status` | `<pid>` | Get process status |

### Service Syscalls

| Syscall | Arguments | Description |
|---|---|---|
| `svc.start` | `<name>` | Start a registered service |
| `svc.stop` | `<name>` | Stop a service |
| `svc.status` | `<name>` | Get service health |
| `svc.list` | — | List all services and states |
| `svc.register` | `<name> <script>` | Register a new service |

### Memory Syscalls

| Syscall | Arguments | Description |
|---|---|---|
| `mem.set` | `<key> <value>` | Write symbolic memory |
| `mem.get` | `<key>` | Read symbolic memory |
| `mem.delete` | `<key>` | Delete memory key |
| `sem.set` | `<key> <value>` | Write semantic embedding |
| `sem.search` | `<query>` | Fuzzy semantic search |
| `recall` | `<query>` | Hybrid memory recall |

### Event Syscalls

| Syscall | Arguments | Description |
|---|---|---|
| `event.fire` | `<name> [payload]` | Fire a system event |
| `event.listen` | `<name> <handler>` | Register event handler |
| `event.list` | — | List pending events |

### Network Syscalls

| Syscall | Arguments | Description |
|---|---|---|
| `net.status` | — | Current network state |
| `net.connect` | `<ssid> [pass]` | Connect to WiFi |
| `net.scan` | — | Scan available networks |
| `net.route` | — | Show routing table |
| `net.ping` | `<host>` | Ping a host |

---

## 6. Process Model

AIOS-Lite uses a **cooperative, non-preemptive process model**. All processes are POSIX shell jobs managed by the pseudo-kernel.

### Process Types

| Type | Lifecycle | Examples |
|---|---|---|
| **Daemon** | Long-running background | `os-kernelctl`, `aios-heartbeat`, `aura-agents` |
| **Service** | Start/stop via service registry | `aura-llm`, `aura-bridge`, `aura-policy` |
| **Command** | One-shot, returns immediately | `os-info`, `os-log`, `os-ps` |
| **Shell** | Interactive, foreground | `os-shell`, `bin/aios`, `bin/aios-sys` |

### Process Identity

Each running process writes its PID to `$OS_ROOT/var/run/<name>.pid`.  
State is tracked in `$OS_ROOT/proc/`:

```
proc/
├── os          # Main OS PID
├── os.state    # KEY=VALUE runtime state
├── os.identity # Name, version, vendor
├── os.manifest # Subsystem manifest
├── aura        # AURA agent PID
├── aura.memory # Memory index PID
└── sched.table # Scheduler job table
```

### Signal Handling

| Signal | Action |
|---|---|
| `SIGTERM` | Graceful shutdown — flush logs, stop services |
| `SIGINT` | Interrupt shell command, prompt user |
| `SIGHUP` | Reload configuration without restart |
| `SIGUSR1` | Trigger OS state dump to `var/log/` |

---

## 7. Scheduler

The AIOS-Lite scheduler (`OS/bin/os-sched`) is a **cooperative round-robin scheduler** with priority tiers. It does not preempt processes; instead, long-running tasks voluntarily yield using the `sched.yield` syscall.

### Priority Tiers

| Priority | Tier Name | Examples |
|---|---|---|
| 0 (highest) | **Critical** | `os-kernelctl`, heartbeat, permissions |
| 1 | **System** | `aura-bridge`, `aura-llm`, `aura-policy` |
| 2 | **Service** | `aura-agents`, `aura-tasks`, log rotation |
| 3 (lowest) | **Background** | Model pre-loading, mirror sync |

### Scheduler Table

The scheduler table is written to `$OS_ROOT/proc/sched.table` in `KEY=VALUE` format:

```
JOB_1_NAME=aura-heartbeat
JOB_1_PRIORITY=0
JOB_1_INTERVAL=30
JOB_1_LAST_RUN=1711123456
JOB_1_STATUS=running
```

### Scheduling Commands

```sh
os-sched list               # Show all scheduled jobs
os-sched add <name> <cmd>   # Add a job
os-sched remove <name>      # Remove a job
os-sched run <name>         # Run job immediately
```

---

## 8. Resource Manager

The resource manager (`OS/bin/os-resource`) tracks and enforces soft quotas on CPU time, memory, and disk I/O for each service.

### Tracked Resources

| Resource | Unit | Default Limit |
|---|---|---|
| CPU time | % of host CPU | 80% combined |
| RAM usage | MB | Configurable per service |
| Disk writes | KB/s | Unlimited (soft throttle) |
| Log size | Lines | 1000 lines per log file |
| LLM tokens | Tokens/request | 512 (configurable in `config/llama-settings.conf`) |

### Enforcement Mechanism

1. The resource manager polls `/proc/<pid>/status` (Linux) or `ps` output (macOS/Termux) every 30 seconds.
2. If a service exceeds its CPU quota for three consecutive polls, it is throttled via `nice +10`.
3. Log rotation is triggered automatically at 1000 lines.
4. LLM token limits are passed as `--n-predict` to `llama-cli`.

### Commands

```sh
os-resource status          # Show current usage
os-resource set <svc> <key> <val>  # Set quota
os-resource reset <svc>     # Reset to defaults
```

---

## 9. Permissions Model

AIOS-Lite uses a **capability-based permissions model** stored in `$OS_ROOT/etc/perms.d/`. Each service or command declares the capabilities it requires; the permissions engine checks at invocation time.

### Capability Categories

| Category | Capabilities |
|---|---|
| **Filesystem** | `fs.read`, `fs.write`, `fs.delete`, `fs.exec` |
| **Network** | `net.connect`, `net.listen`, `net.route` |
| **Process** | `proc.spawn`, `proc.kill`, `proc.list` |
| **Bridge** | `bridge.ios`, `bridge.android`, `bridge.ssh` |
| **AI / LLM** | `ai.query`, `ai.memory.write`, `ai.memory.read` |
| **Admin** | `admin.service`, `admin.runlevel`, `admin.config` |

### Permission File Format

Capability files live at `$OS_ROOT/etc/perms.d/<service>.perms`:

```ini
[service]
name = aura-bridge
capabilities = fs.read, fs.write, net.connect, bridge.ios, bridge.android
deny = admin.runlevel
```

### Enforcement

```sh
os-perms check <service> <capability>   # Returns 0 (allowed) or 1 (denied)
os-perms grant <service> <capability>   # Grant capability
os-perms revoke <service> <capability>  # Revoke capability
os-perms list <service>                 # List granted capabilities
```

Capabilities can also be granted interactively from the AI shell:
```sh
# Inside os-shell:
perms grant aura-bridge net.connect
```

---

## 10. Service Registry

All long-running services and daemons register with the service registry managed by `OS/bin/os-service`. The registry persists in `$OS_ROOT/var/service/`.

### Registry Entry Format

```
var/service/
├── <name>.pid      # Process ID
├── <name>.health   # last-check timestamp + status (ok|warn|fail)
└── <name>.conf     # Service configuration
```

### Service Lifecycle

```
  register
     │
     ▼
  REGISTERED ──start──▶ STARTING ──ready──▶ RUNNING
                                                │
                            ◀──restart─────── FAIL
                            ▼
                          STOPPING ──done──▶ STOPPED
```

### Core Registered Services

| Service Name | Script | Auto-start |
|---|---|---|
| `aura-heartbeat` | `bin/aios-heartbeat` | Yes |
| `os-kernel` | `etc/init.d/os-kernel` | Yes |
| `aura-bridge` | `etc/init.d/aura-bridge` | Yes |
| `aura-llm` | `OS/lib/aura-llm/` | If model present |
| `aura-policy` | `OS/lib/aura-policy/` | Yes |
| `aura-agents` | `OS/lib/aura-agents/` | Yes |
| `aura-tasks` | `OS/lib/aura-tasks/` | Yes |
| `os-httpd` | `OS/bin/os-httpd` | Optional |

### Commands

```sh
os-service list                    # All services + status
os-service start <name>            # Start service
os-service stop <name>             # Stop service
os-service restart <name>          # Restart service
os-service-health                  # Health summary
os-service-status                  # Detailed status table
```

---

## 11. Networking Model

AIOS-Lite abstracts networking through `lib/aura-net.sh` and `OS/bin/os-netconf`. On Android/Termux, WiFi and Bluetooth are accessed via Android API calls through the ADB bridge.

### Network Stack

```
┌─────────────────────────────────────────┐
│         Application Layer               │
│    os-shell / os-httpd / SSH tunnel     │
├─────────────────────────────────────────┤
│         AIOS Network Abstraction        │
│    aura-net.sh  ·  os-netconf           │
├─────────────────────────────────────────┤
│         Bridge Layer (optional)         │
│    ADB bridge  ·  SSH tunnel  ·  SSHFS  │
├─────────────────────────────────────────┤
│         Host Network Stack              │
│    WiFi  ·  Bluetooth  ·  TCP/IP        │
└─────────────────────────────────────────┘
```

### WiFi

AIOS-Lite controls WiFi via the host's `wpa_supplicant` / `nmcli` / Android WiFi API (through ADB):

```sh
os-netconf wifi scan                    # Scan SSIDs
os-netconf wifi connect <ssid> <pass>   # Connect
os-netconf wifi status                  # Current connection
os-netconf wifi disconnect              # Disconnect
```

On Termux/Android, WiFi commands delegate to `adb shell cmd wifi` through the ADB bridge module.

### Bluetooth

```sh
os-netconf bt scan                      # Discover devices
os-netconf bt pair <address>            # Pair device
os-netconf bt connect <address>         # Connect device
os-netconf bt list                      # List paired devices
```

On Android, Bluetooth is controlled via `adb shell am broadcast` or `adb shell settings`.

### IP / Routing

```sh
os-netconf ip show                      # Show IP addresses
os-netconf route show                   # Show routing table
os-netconf route add <net> <gw>         # Add route
os-netconf dns set <server>             # Set DNS server
```

### Networking Architecture (Hosted Mode)

```
Device (Android/Termux)
  │
  ├── WiFi (host WiFi chip)
  │     └── Android WiFi Service ──── ADB bridge ──── AIOS net layer
  │
  ├── Bluetooth (host BT chip)
  │     └── Android BT Service  ──── ADB bridge ──── AIOS net layer
  │
  └── TCP/IP (Linux kernel stack)
        └── Direct passthrough ──────────────────── AIOS net layer
              └── SSH tunnels, SSHFS mounts
```

### HTTP Server

`OS/bin/os-httpd` provides a minimal built-in HTTP server (POSIX netcat + shell handlers) for local API access:

- Default bind: `127.0.0.1:8080`
- Endpoint: `GET /status` → OS state JSON
- Endpoint: `POST /ai` → AI query passthrough
- Endpoint: `GET /services` → Service health JSON

---

## 12. API Surface

AIOS-Lite exposes four API surfaces.

### 12.1 System API (shell commands)

Available inside `os-shell` or from any POSIX shell with `$OS_ROOT/bin` in PATH.

| Command | Description |
|---|---|
| `os-info` | OS identity and version |
| `os-state` | Dump full OS state |
| `os-ps` | List tracked processes |
| `os-log <msg>` | Write to system log |
| `os-event fire <name>` | Fire a system event |
| `os-msg <topic> <msg>` | Send message bus message |
| `os-kernelctl <cmd>` | Control pseudo-kernel |
| `os-service <cmd>` | Service lifecycle |
| `os-resource <cmd>` | Resource management |
| `os-perms <cmd>` | Permissions management |
| `os-netconf <cmd>` | Network configuration |
| `os-recover` | Run repair/recovery |

### 12.2 Kernel API (os-syscall)

The unified syscall dispatcher:
```sh
os-syscall <domain> <call> [args...]
# Examples:
os-syscall fs read /etc/os-release
os-syscall proc list
os-syscall svc status aura-bridge
os-syscall mem get mykey
```

### 12.3 Automation / AI API (Python)

The AI Core in `ai/core/` exposes a Python API:

```python
from ai.core.ai_backend import AIBackend
from ai.core.intent_engine import IntentEngine
from ai.core.router import Router

backend = AIBackend()
response = backend.handle("what is my system status?")
```

**IntentEngine** classifies input into intent categories:
- `system_query`, `memory_op`, `bridge_op`, `service_op`, `network_op`, `general_chat`

**Router** dispatches to:
- `HealthBot`, `LogBot`, `RepairBot` (specialized bots)
- `commands.py` (OS command handlers)
- `llama_client.py` (LLM fallback)

### 12.4 Plugin API (loadable modules)

Plugins are shell scripts placed in `OS/lib/aura-mods/`. They are sourced at boot and can register commands, event handlers, and service endpoints.

**Plugin skeleton:**
```sh
#!/bin/sh
# Plugin: my-plugin
# Version: 1.0

PLUGIN_NAME="my-plugin"
PLUGIN_VERSION="1.0"

plugin_init() {
    # Called at boot — register commands and handlers
    os-event listen my_event my_plugin_handler
}

my_plugin_handler() {
    # Handle the event
    os-log "my-plugin: received event"
}

# Register with module loader
plugin_init
```

Plugins are auto-loaded from `OS/etc/aura/modules` (newline-separated list of module names).

---

*End of OS Architecture Reference*

> © 2026 Christopher Betts | AIOS-Lite v0.2 | AI-Augmented Portable Operating System
