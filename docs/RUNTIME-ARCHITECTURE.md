# AIOS Runtime Architecture & System Services

> © 2026 Chris Betts | AIOSCPU Official | AI-generated, fully legal

---

## Contents

1. [Runtime Architecture](#1-runtime-architecture)
2. [Core System Services](#2-core-system-services)
3. [Service Lifecycle Model](#3-service-lifecycle-model)
4. [Module & Plugin Runtime](#4-module--plugin-runtime)
5. [Event & Notification System](#5-event--notification-system)
6. [Scheduler & Task Execution](#6-scheduler--task-execution)
7. [Resource Management](#7-resource-management)
8. [System Orchestration](#8-system-orchestration)
9. [Developer Hooks](#9-developer-hooks)

---

## 1. Runtime Architecture

### 1.1 Runtime Environment

AIOS runs a **user-space pseudo-kernel** implemented entirely in POSIX shell and
Python 3.  There is no hardware privilege ring requirement; all isolation is
achieved through:

- **OS_ROOT filesystem jail** — every file path is resolved and validated inside
  `$OS_ROOT` before any I/O is allowed (see `OS/lib/filesystem.py`).
- **Capability-based permissions** — every cross-service call is gated by
  `os-perms check <principal> <capability>`.
- **Process registry** — every running component writes a PID file to
  `OS/var/service/<name>.pid` and is periodically audited.

```
┌─────────────────────────────────────────────────────────────────┐
│                     User / AI Shell Layer                        │
│   os-shell  |  os-real-shell  |  aios  |  aios-sys             │
└──────────────────────────┬──────────────────────────────────────┘
                           │  os-syscall (system call gate)
┌──────────────────────────▼──────────────────────────────────────┐
│                     AIOS Runtime Core                            │
│  os-event (message bus)  |  os-sched (scheduler)               │
│  os-service (lifecycle)  |  os-perms (capabilities)            │
│  os-resource (limits)    |  os-recover (self-repair)           │
└──────────────────────────┬──────────────────────────────────────┘
                           │  OS_ROOT filesystem jail
┌──────────────────────────▼──────────────────────────────────────┐
│               OS_ROOT Virtual Filesystem                         │
│  OS/bin/  OS/sbin/  OS/etc/  OS/proc/  OS/var/  OS/mirror/     │
└──────────────────────────┬──────────────────────────────────────┘
                           │  host OS boundary
┌──────────────────────────▼──────────────────────────────────────┐
│               Host OS (Android/Termux · Linux · macOS)          │
└─────────────────────────────────────────────────────────────────┘
```

### 1.2 System Event Loop

The runtime event loop is driven by `bin/aios-heartbeat`.  It runs as a
background daemon and performs one iteration every `KERNEL_HEARTBEAT_INTERVAL`
seconds (default: 5 s).

```
┌──────────────────────────────────────────────────────────────┐
│                   Heartbeat Tick (5 s)                        │
│                                                              │
│  1. Poll service PID files  →  detect dead services          │
│  2. Read health files       →  detect degraded services      │
│  3. Emit HEALTH_CHECK event →  notify ai-core & monitors     │
│  4. Check resource limits   →  emit RESOURCE_WARN if needed  │
│  5. Drain event queue       →  dispatch pending events       │
│  6. Invoke os-sched tick    →  prune dead PIDs, renice tasks  │
│  7. Sleep until next tick   →  KERNEL_HEARTBEAT_INTERVAL     │
└──────────────────────────────────────────────────────────────┘
```

### 1.3 Message Bus Architecture

`OS/bin/os-event` implements a **file-backed, append-only message bus**.

- **Queue file**: `OS/var/event/queue`
- **History file**: `OS/var/event/history` (append-only audit log)
- Each event is a single JSON line:

```json
{ "id": "evt-0042", "ts": 1743696000, "type": "SERVICE_FAILED",
  "source": "aura-heartbeat", "priority": "HIGH",
  "payload": { "service": "aura-agents", "pid": 4821 } }
```

Consumers poll or tail the queue file.  The AI Core (`ai/core/ai_backend.py`)
subscribes to events via `os-event subscribe <type>`, which blocks on a named
pipe until a matching event arrives.

### 1.4 Service Communication

Services communicate through three channels, in order of preference:

| Channel | Mechanism | Use Case |
|---------|-----------|----------|
| **Event bus** | `os-event emit / subscribe` | Asynchronous notifications |
| **Syscall gate** | `os-syscall <call> [args]` | Synchronous filesystem / process ops |
| **Shared state files** | `OS/proc/*.state`, `OS/var/service/*.health` | Status polling |

Direct inter-service shell invocation is **prohibited**; all cross-service
calls must go through the syscall gate or event bus to maintain audit coverage.

### 1.5 Concurrency and Scheduling Rules

| Rule | Detail |
|------|--------|
| **Cooperative by default** | Services yield at I/O boundaries; no forced preemption in user space |
| **Priority range** | 0 (highest) → 19 (lowest), mapped to POSIX `nice` values |
| **AI inference** | Runs at priority 5 on big cores (CPU affinity: `LLAMA_CPU_AFFINITY=1-3`) |
| **Background daemons** | Run at priority 15–19 |
| **Interactive shell** | Runs at priority 0 |
| **Thermal throttle** | If temperature ≥ 68 °C, all non-critical tasks are demoted to priority 19 |
| **Maximum parallel tasks** | 8 concurrent tasks; additional tasks are queued |

---

## 2. Core System Services

### 2.1 Service Catalog

| Service | Binary | Language | Role |
|---------|--------|----------|------|
| **init** | `OS/sbin/init` | POSIX sh | PID 1 — boot orchestrator |
| **aios-heartbeat** | `bin/aios-heartbeat` | Bash | Kernel heartbeat daemon |
| **os-kernelctl** | `OS/bin/os-kernelctl` | POSIX sh | Kernel state control |
| **os-syscall** | `OS/bin/os-syscall` | POSIX sh | System call gate |
| **os-sched** | `OS/bin/os-sched` | POSIX sh | Process scheduler |
| **os-perms** | `OS/bin/os-perms` | POSIX sh | Capability enforcement |
| **os-resource** | `OS/bin/os-resource` | POSIX sh | Resource monitor |
| **os-event** | `OS/bin/os-event` | POSIX sh | Event bus |
| **os-service** | `OS/bin/os-service` | POSIX sh | Service lifecycle manager |
| **os-recover** | `OS/bin/os-recover` | POSIX sh | Self-repair engine |
| **os-httpd** | `OS/bin/os-httpd` | Python 3 | REST / WebSocket server |
| **os-netconf** | `OS/bin/os-netconf` | POSIX sh | Network configuration |
| **aura-agents** | `OS/etc/rc2.d/S60-aura-agents` | Bash | AI background agents |
| **aura-tasks** | `OS/etc/rc2.d/S70-aura-tasks` | Bash | Task scheduler |

### 2.2 Service Responsibilities

**init**
- Resolves `OS_ROOT`, sources `config/aios.conf`
- Creates required runtime directories and state files
- Executes all `OS/etc/rc2.d/S*` scripts in lexicographic order
- Launches interactive shell on completion

**aios-heartbeat**
- Runs permanently in the background
- Polls PID files and health files every 5 s
- Emits `HEALTH_CHECK`, `SERVICE_FAILED`, `RESOURCE_WARN` events
- Triggers `os-recover` on repeated service failure

**os-event**
- Accepts `emit`, `subscribe`, `drain`, `history` sub-commands
- Appends all events to `OS/var/event/history` for audit
- Delivers matching events to subscribers via named pipes

**os-recover**
- Five-stage recovery: directory repair → state repair → service cleanup →
  log rotation → dependency audit
- Can be run in `check` (read-only) or `repair` (write) mode

**os-httpd**
- Listens on `127.0.0.1:8080` (configurable via `etc/aios.conf`)
- Exposes REST endpoints for all syscalls and service control
- WebSocket stream for real-time event subscription

### 2.3 Startup Order and Dependencies

```
Stage 0 — Pre-flight
  S10-banner      (no deps)

Stage 1 — Hardware / Network
  S20-devices     (requires: OS_ROOT mounted)
  S30-aura-bridge (requires: S20-devices)

Stage 2 — Kernel Services
  S40-os-kernel   (requires: OS_ROOT, aios-heartbeat binary)
    └─ starts: aios-heartbeat

Stage 3 — Application Services
  S50-os-httpd    (requires: S40-os-kernel)
  S60-aura-agents (requires: S40-os-kernel, ai/core/*.py)
  S70-aura-tasks  (requires: S60-aura-agents)

Stage 4 — Shell
  exec os-shell   (requires: all S* scripts succeeded)
```

### 2.4 Failure and Recovery Behavior

| Condition | Detection | Action |
|-----------|-----------|--------|
| Service PID gone | Heartbeat poll | Emit `SERVICE_FAILED`, attempt restart (max 3×) |
| Health file stale (> 30 s) | Heartbeat poll | Emit `SERVICE_DEGRADED`, log warning |
| Repeated failure (≥ 3 restarts) | os-recover | Enter recovery mode, alert AI Core |
| Resource limit exceeded | os-resource | Emit `RESOURCE_WARN`, demote priority |
| Thermal limit exceeded | os-resource | Emit `THERMAL_CRITICAL`, pause inference |

### 2.5 Service Lifecycle Diagram

```
                  ┌─────────┐
                  │ INACTIVE │
                  └────┬────┘
                       │ start
                  ┌────▼────┐
                  │STARTING │◄──────────────────┐
                  └────┬────┘                   │
              success  │  timeout / error        │ restart
                  ┌────▼────┐        ┌──────────┴──────┐
                  │ RUNNING │───────►│    DEGRADED      │
                  └────┬────┘ health │ (heartbeat miss) │
                       │     warn   └──────────┬────────┘
                  stop │                 3× fail│
                  ┌────▼────┐        ┌──────────▼──────┐
                  │STOPPING │        │     FAILED       │
                  └────┬────┘        └──────────┬───────┘
                       │                        │ os-recover
                  ┌────▼────┐        ┌──────────▼──────┐
                  │ STOPPED │        │  RECOVERY MODE   │
                  └─────────┘        └─────────────────┘
```

---

## 3. Service Lifecycle Model

### 3.1 Service States

| State | Description |
|-------|-------------|
| `INACTIVE` | Service is defined but not started |
| `STARTING` | Service process has been spawned; awaiting PID file registration |
| `RUNNING` | PID file present; health file updated within the last 30 s |
| `DEGRADED` | PID alive but health file stale, or non-fatal errors reported |
| `STOPPING` | SIGTERM sent; awaiting process exit |
| `STOPPED` | Process exited cleanly |
| `FAILED` | Process exited unexpectedly or failed to start |

State is persisted in `OS/var/service/<name>.state` and updated by both the
service itself and the heartbeat daemon.

### 3.2 State Transitions

```
INACTIVE  ──start──►  STARTING  ──registered──►  RUNNING
RUNNING   ──stop───►  STOPPING  ──exited──────►  STOPPED
RUNNING   ──health miss──►  DEGRADED  ──recovered──►  RUNNING
RUNNING   ──crash──►  FAILED
DEGRADED  ──3×fail──►  FAILED
STARTING  ──timeout──►  FAILED
FAILED    ──restart (≤3)──►  STARTING
FAILED    ──restart (>3)──►  os-recover invoked
```

### 3.3 Restart Policies

| Policy | Behavior |
|--------|----------|
| `always` | Restart on any exit (clean or unclean), indefinitely |
| `on-failure` | Restart only on non-zero exit; default for all daemons |
| `never` | Do not restart; used for one-shot init scripts |
| `on-watchdog` | Restart when heartbeat misses; used for the AI Core |

Restart back-off: 1 s → 2 s → 4 s (exponential, capped at 30 s).

Restart policies are declared in `OS/etc/services.d/<name>.service`:

```ini
[Service]
RestartPolicy = on-failure
RestartMaxAttempts = 3
RestartBackoffBase = 1
```

### 3.4 Health Checks and Heartbeats

Every service must update its health file at least once per
`SERVICE_HEARTBEAT_INTERVAL` (default: 15 s):

```sh
# From within a service
echo "ok $(date +%s)" > "$OS_ROOT/var/service/${SERVICE_NAME}.health"
```

The heartbeat daemon treats a health file older than
`SERVICE_HEARTBEAT_TIMEOUT` (default: 30 s) as a degraded signal.

Health file format:

```
ok 1743696000
```

or, for degraded status:

```
degraded high-memory 1743696000
```

---

## 4. Module & Plugin Runtime

### 4.1 How Modules Are Loaded

Modules are discovered at boot by `OS/sbin/init` scanning two directories:

| Directory | Type | Load time |
|-----------|------|-----------|
| `OS/etc/modules.d/` | Core system modules (shell) | Boot (Stage 0–2) |
| `OS/etc/plugins.d/` | Optional user plugins | Boot (Stage 3) or hot-reload |

Each entry is a descriptor file (`<name>.mod`) containing:

```ini
[Module]
Name        = my-module
Version     = 1.0.0
Entrypoint  = OS/bin/my-module
Capabilities = fs.read, log.write
RestartPolicy = on-failure
Sandbox     = true
```

The loader validates the descriptor, checks that `Entrypoint` exists and is
executable, verifies declared capabilities against the permissions database,
and then spawns the service.

### 4.2 Module Registration

On startup, a module must register itself with the runtime:

```sh
os-syscall spawn os-service register my-module "$$"
```

Registration writes:

- `OS/var/service/my-module.pid` — process ID
- `OS/var/service/my-module.state` — initial state `STARTING`
- `OS/var/service/my-module.caps` — granted capabilities (from descriptor)

### 4.3 Hot-Reload Behavior

Plugins in `OS/etc/plugins.d/` support hot-reload without system restart:

```sh
# Operator command
os-service reload my-plugin
```

Hot-reload sequence:

```
1. Emit PLUGIN_RELOAD_START event
2. Send SIGHUP to the plugin process
3. Plugin re-reads its config and reinitializes
4. If plugin does not acknowledge within 10 s → full restart
5. Emit PLUGIN_RELOAD_DONE event
```

Modules in `OS/etc/modules.d/` (core) require a system restart to reload.

### 4.4 Sandboxing and Isolation

| Rule | Enforcement |
|------|-------------|
| Filesystem access | All I/O via `OS/lib/filesystem.py`; OS_ROOT jail enforced |
| Process spawning | Only whitelisted binaries via `os-syscall spawn` |
| Capability enforcement | `os-perms check` before every privileged operation |
| Network access | Only `net.ping` and `net.http` capabilities; raw sockets denied |
| Plugin scope | Plugins may not call `os-recover` or modify `OS/etc/` |
| Audit | Every operation appended to `OS/var/log/aura.log` |

Plugins that request capabilities beyond their descriptor are denied at
registration time and will not start.

---

## 5. Event & Notification System

### 5.1 Event Types

| Event Type | Source | Priority | Description |
|------------|--------|----------|-------------|
| `BOOT_COMPLETE` | init | NORMAL | All rc2.d scripts finished |
| `SERVICE_STARTED` | os-service | NORMAL | Service entered RUNNING state |
| `SERVICE_STOPPED` | os-service | NORMAL | Service entered STOPPED state |
| `SERVICE_FAILED` | aios-heartbeat | HIGH | Service process died unexpectedly |
| `SERVICE_DEGRADED` | aios-heartbeat | MEDIUM | Service heartbeat stale |
| `HEALTH_CHECK` | aios-heartbeat | LOW | Routine heartbeat tick |
| `RESOURCE_WARN` | os-resource | HIGH | Resource threshold crossed |
| `THERMAL_CRITICAL` | os-resource | CRITICAL | Temperature ≥ 68 °C |
| `PLUGIN_RELOAD_START` | os-service | NORMAL | Hot-reload initiated |
| `PLUGIN_RELOAD_DONE` | os-service | NORMAL | Hot-reload completed |
| `TASK_QUEUED` | os-sched | LOW | New task added to scheduler |
| `TASK_COMPLETED` | os-sched | LOW | Task finished successfully |
| `TASK_FAILED` | os-sched | MEDIUM | Task exited with error |
| `SYSCALL_DENIED` | os-syscall | HIGH | Capability check failed |
| `RECOVERY_START` | os-recover | CRITICAL | Recovery mode entered |
| `RECOVERY_DONE` | os-recover | HIGH | Recovery completed |
| `AI_QUERY` | ai-core | NORMAL | Incoming AI inference request |
| `AI_RESPONSE` | ai-core | NORMAL | AI inference result ready |
| `USER_INPUT` | os-shell | NORMAL | User entered a command |

### 5.2 Event Routing

```
Producer
  │
  │  os-event emit <type> <priority> <json-payload>
  ▼
┌──────────────────────────────────────────────────────┐
│                    Event Bus                          │
│  OS/var/event/queue   (active FIFO)                  │
│  OS/var/event/history (append-only audit)            │
└──────────┬──────────────────────────┬────────────────┘
           │                          │
    CRITICAL/HIGH              NORMAL/LOW/MEDIUM
    immediate delivery          batch drain (5 s tick)
           │                          │
    ┌──────▼──────┐          ┌────────▼────────┐
    │  AI Core    │          │  Subscribers     │
    │ ai_backend  │          │  (named pipes)   │
    └─────────────┘          └─────────────────┘
```

Subscribers register with:

```sh
os-event subscribe SERVICE_FAILED HIGH   # blocks until matching event
os-event subscribe "*" "*"               # receive all events
```

### 5.3 Priority Levels

| Priority | Value | Delivery Guarantee |
|----------|-------|--------------------|
| `CRITICAL` | 0 | Delivered immediately; bypasses queue |
| `HIGH` | 1 | Delivered on next heartbeat tick |
| `MEDIUM` | 2 | Delivered within 2 ticks (10 s) |
| `NORMAL` | 3 | Delivered within 4 ticks (20 s) |
| `LOW` | 4 | Delivered within 10 ticks (50 s) |

### 5.4 AI Core Event Integration

The AI Core subscribes to events at startup:

```python
# ai/core/ai_backend.py
router.subscribe_events(["SERVICE_FAILED", "RESOURCE_WARN",
                          "THERMAL_CRITICAL", "RECOVERY_START"])
```

On receipt of a `SERVICE_FAILED` or `RECOVERY_START` event, the
`RepairBot` intent handler is activated automatically, generating a
repair plan without requiring user input.

On receipt of a `THERMAL_CRITICAL` event, inference is suspended and
a cooldown advisory is emitted to the user shell.

### 5.5 Logging and Audit Trails

| Log File | Content | Rotation |
|----------|---------|----------|
| `OS/var/log/aura.log` | All AURA operations (primary audit log) | > 1000 lines → truncate to 500 |
| `OS/var/log/syscall.log` | Every syscall invocation with result | > 1000 lines → truncate to 500 |
| `OS/var/log/os.log` | Boot, service, and recovery events | > 1000 lines → truncate to 500 |
| `OS/var/event/history` | All events (append-only, never rotated) | Archive to `history.1` when > 10 MB |

Every log entry follows the format:

```
[2026-04-03T16:00:00Z] [LEVEL] [source] message
```

---

## 6. Scheduler & Task Execution

### 6.1 Task Scheduling Model

`OS/bin/os-sched` implements **priority round-robin** scheduling.  Tasks are
classified at submission and placed in one of five priority queues.

```sh
# Submit a task
os-sched submit --priority 5 --type short -- my-command --arg value

# List scheduled tasks
os-sched list

# Cancel a task
os-sched cancel <task-id>
```

### 6.2 Priority Queues

| Queue | Priority | Purpose | Max Runtime |
|-------|----------|---------|-------------|
| `Q0` — critical | 0–1 | Recovery, thermal response | Unlimited |
| `Q1` — interactive | 2–4 | User shell commands, AI responses | 30 s |
| `Q2` — standard | 5–9 | AI inference, health checks | 120 s |
| `Q3` — background | 10–14 | Log rotation, plugin reload | 300 s |
| `Q4` — idle | 15–19 | Telemetry, cleanup | 600 s |

Tasks that exceed their queue's `Max Runtime` receive SIGTERM followed
by SIGKILL after a 5 s grace period, and emit a `TASK_FAILED` event.

### 6.3 Long-Running vs. Short-Running Tasks

| Attribute | Short-Running (< 30 s) | Long-Running (> 30 s) |
|-----------|------------------------|----------------------|
| Heartbeat required | No | Yes (every 15 s) |
| Cancellation | Immediate SIGTERM | Graceful shutdown hook |
| Resource limit enforcement | On submission | Continuous monitoring |
| CPU affinity | Inherited | Explicitly pinned by os-sched |
| Result storage | Return value in queue entry | Written to `OS/var/tasks/<id>.result` |

Long-running tasks must call:

```sh
os-sched heartbeat <task-id>   # every 15 s
os-sched progress <task-id> 42 # optional: report % complete
```

### 6.4 Cooperative vs. Preemptive Behavior

AIOS is **cooperative** in user space.  Tasks yield at:

- Every `os-syscall` invocation
- Every `os-event emit` call
- Explicit `os-sched yield` call
- End of I/O operations

The scheduler cannot forcibly preempt a running task mid-computation.
However, the heartbeat daemon **will** send SIGTERM to tasks that:

- Exceed their queue's `Max Runtime`
- Miss two consecutive heartbeat updates (long-running tasks only)
- Are in queue `Q3`/`Q4` when a `THERMAL_CRITICAL` event is active

### 6.5 Example Scheduling Diagrams

**Example A — AI Query (priority 5, standard queue)**

```
t=0s   User types "what is the weather?"
t=0s   os-shell emits USER_INPUT event (NORMAL)
t=0s   ai_backend receives event → IntentEngine.classify()
t=0s   Router dispatches to LlamaClient (task submitted Q2, priority 5)
t=0s   os-sched assigns CPU affinity cores 1-3, nice -5
t=3s   LlamaClient returns response
t=3s   ai_backend emits AI_RESPONSE event
t=3s   os-shell prints response to user
t=3s   Task removed from Q2
```

**Example B — Service Failure Recovery (priority 0, critical queue)**

```
t=0s   aura-agents PID disappears
t=5s   Heartbeat tick detects dead PID
t=5s   Emits SERVICE_FAILED (HIGH) → delivered immediately to AI Core
t=5s   RepairBot activated; submits recovery task to Q0
t=5s   os-recover starts (stage 1–5)
t=8s   Services restarted; health files updated
t=8s   Emits RECOVERY_DONE (HIGH)
t=8s   AI Core logs recovery; notifies user shell
```

**Example C — Background Log Rotation (priority 18, idle queue)**

```
t=0s   Idle scheduler detects no Q0–Q2 tasks pending
t=0s   Q4 task "log-rotate" dequeued (priority 18, nice +18)
t=2s   Log files trimmed to 500 lines each
t=2s   Emits TASK_COMPLETED (LOW)
t=2s   Task removed from Q4; scheduler idles until next tick
```

---

## 7. Resource Management

### 7.1 CPU Allocation Rules

| Principal | Priority | CPU Affinity | Rationale |
|-----------|----------|--------------|-----------|
| AI inference (llama) | 5 | Cores 1–3 (big, Cortex-A78) | Maximum throughput |
| Interactive shell | 0 | All cores | Responsive UX |
| Heartbeat daemon | 10 | Any | Low overhead |
| Background services | 15–19 | Cores 0 (LITTLE) | Efficiency |
| Recovery tasks | 0 | All cores | Safety priority |

CPU affinity is configured via `LLAMA_CPU_AFFINITY` in `config/llama-settings.conf`.

Thermal throttling automatically demotes all `Q2`–`Q4` tasks to priority 19
when `THERMAL_CRITICAL` is active:

```sh
# Triggered by os-resource when temp >= 68°C
os-sched demote-all --min-priority 2 --to-priority 19
```

### 7.2 Memory Allocation Rules

| Tier | Allocation | Owner |
|------|-----------|-------|
| Model weights (llama 7B int4) | ≤ 4 GB | llama_client.py |
| AI Core working memory | ≤ 512 MB | ai_backend.py, router.py |
| Service processes | ≤ 64 MB each | All daemons |
| Event bus queue | ≤ 16 MB | os-event |
| Log buffers | ≤ 8 MB total | All log files |

Memory limits are soft limits declared in `OS/etc/resource.limits`:

```ini
[memory]
llama_max_mb     = 4096
ai_core_max_mb   = 512
service_max_mb   = 64
event_queue_mb   = 16
```

When a service exceeds its limit, `os-resource` emits `RESOURCE_WARN`
and notifies `os-sched` to lower the offending task's priority.  If usage
exceeds 110% of the limit, SIGTERM is sent.

### 7.3 I/O Throttling

All file I/O is serialized through `OS/lib/filesystem.py`.  The following
rate limits are enforced:

| Operation | Limit | Action on breach |
|-----------|-------|-----------------|
| Log writes | 1000 lines/min per service | Drop excess writes, emit warning |
| Event emissions | 100 events/min per service | Queue overflow → drop LOW/NORMAL |
| Syscall invocations | 500 calls/min per process | Throttle with 100 ms back-off |
| Filesystem reads | Unrestricted (OS_ROOT jail only) | N/A |

### 7.4 Safe Failure Modes

| Failure | Immediate Action | Recovery |
|---------|-----------------|----------|
| AI inference crash | Suspend inference, emit RESOURCE_WARN | RepairBot restarts llama_client |
| Heartbeat daemon crash | Host OS restart via `aios-heartbeat` watchdog | Re-launch aios-heartbeat |
| Disk full (> 95%) | Log rotation, delete oldest archive | Alert operator; pause non-critical writes |
| Memory exhaustion | SIGTERM to lowest-priority process | Retry after 10 s |
| Thermal critical | Pause all inference; fan alert | Resume when temp < 60 °C |
| Syscall gate crash | All services report DEGRADED | init restarts os-syscall |

### 7.5 Resource Monitoring

`OS/bin/os-resource` publishes a snapshot to `OS/proc/resources.json` on
every heartbeat tick:

```json
{
  "ts": 1743696000,
  "cpu_pct": 42,
  "mem_pct": 61,
  "disk_pct": 34,
  "thermal_c": 54,
  "llama_mem_mb": 3821,
  "event_queue_depth": 3,
  "active_tasks": 2
}
```

Operators and the AI Core can read this file at any time for live metrics.

Thresholds (configurable in `OS/etc/resource.limits`):

| Resource | Warn | Critical |
|----------|------|---------|
| CPU usage | 80% | 95% |
| Memory usage | 85% | 95% |
| Disk usage | 90% | 95% |
| Temperature | 60 °C | 68 °C |

---

## 8. System Orchestration

### 8.1 How the OS Coordinates Services

The orchestrator is `OS/bin/os-service`, a thin wrapper that:

1. Reads service descriptors from `OS/etc/services.d/`
2. Resolves the dependency graph (topological sort)
3. Spawns services in order, waiting for each to reach `RUNNING` state
4. Monitors the event bus for `SERVICE_FAILED` events
5. Delegates restart decisions to the restart policy engine

```sh
os-service start   <name>   # start a single service
os-service stop    <name>   # graceful stop (SIGTERM + 5 s grace)
os-service restart <name>   # stop + start
os-service status  <name>   # print state and last health timestamp
os-service list             # all services with their current states
```

### 8.2 Dependency Resolution

Service descriptors declare their dependencies:

```ini
[Service]
Name     = aura-agents
Requires = os-kernel, os-event
After    = os-httpd
```

`os-service` builds a directed acyclic graph (DAG) and runs a topological
sort before each start sequence.  Circular dependencies are rejected at
load time with a `DEPENDENCY_CYCLE` error.

```
init
 └─► os-kernel (os-syscall, os-sched, os-perms, os-resource)
       └─► os-event
             └─► os-httpd
                   └─► aura-agents
                         └─► aura-tasks
```

### 8.3 Startup / Shutdown Sequences

**Startup**

```
1. init resolves OS_ROOT and loads config
2. Pre-flight checks (directories, state files, required binaries)
3. Execute S10 → S40 rc2.d scripts (core kernel services)
4. Execute S50 → S70 rc2.d scripts (application services)
5. Emit BOOT_COMPLETE event
6. Launch interactive shell
```

**Shutdown**

```
1. Operator issues: os-service shutdown  (or system halt)
2. Emit SHUTDOWN_INITIATED event (CRITICAL)
3. Stop services in reverse dependency order:
   aura-tasks → aura-agents → os-httpd → os-event → os-kernel
4. Flush all log buffers and event history
5. Write OS/proc/os.state: runlevel=0, shutdown_time=<ts>
6. Exit with code 0
```

### 8.4 Maintenance Mode

Maintenance mode suspends all non-essential services and grants the operator
unrestricted access to the system:

```sh
os-service maintenance enter   # enter maintenance mode
os-service maintenance leave   # return to normal operation
```

**On entry:**

1. Emit `MAINTENANCE_START` (CRITICAL)
2. Stop `aura-tasks`, `aura-agents`, `os-httpd` (in order)
3. Set `OS/proc/os.state`: `runlevel=1`
4. Grant operator `*.*` capabilities (temporarily override perms)
5. Launch `os-real-shell` with full access

**On exit:**

1. Restore capability database from `OS/etc/perms.d/`
2. Restart stopped services in dependency order
3. Emit `MAINTENANCE_END` (HIGH)
4. Set `OS/proc/os.state`: `runlevel=2`

### 8.5 Recovery Mode

Recovery mode is activated automatically by the heartbeat daemon after
3 consecutive service restart failures, or manually:

```sh
OS_ROOT=/path/to/OS sh OS/bin/os-recover repair
```

**Recovery stages (os-recover):**

```
Stage 1 — Directory Repair
  Recreate missing OS_ROOT directories (bin, sbin, etc, proc, var/*)

Stage 2 — State File Repair
  Restore OS/proc/os.state from defaults if corrupt or missing

Stage 3 — Service Cleanup
  Remove stale PID files for dead services
  Reset state files to INACTIVE

Stage 4 — Log Rotation
  Truncate all log files > 1000 lines to 500 lines

Stage 5 — Dependency Audit
  Verify all required binaries (sh, python3, awk, grep, sed, …)
  Report any missing binaries to OS/var/log/os.log
```

After successful recovery, `RECOVERY_DONE` is emitted and normal boot
resumes from Stage 2 (kernel services).

---

## 9. Developer Hooks

### 9.1 Extension Points

| Hook | Location | Trigger | Purpose |
|------|----------|---------|---------|
| `pre-boot` | `OS/etc/hooks.d/pre-boot.d/` | Before rc2.d scripts | Custom initialization |
| `post-boot` | `OS/etc/hooks.d/post-boot.d/` | After BOOT_COMPLETE | Post-boot setup |
| `pre-shutdown` | `OS/etc/hooks.d/pre-shutdown.d/` | Before shutdown sequence | Cleanup / export |
| `on-event` | `OS/etc/hooks.d/on-event.d/` | Any event emission | Custom event handlers |
| `on-recover` | `OS/etc/hooks.d/on-recover.d/` | After RECOVERY_DONE | Post-recovery actions |

Hook scripts receive the triggering event as `$1` (JSON string) and must
exit within 5 s or be killed.

### 9.2 Service Templates

**Minimal daemon template** (`OS/etc/services.d/my-daemon.service`):

```ini
[Service]
Name          = my-daemon
Version       = 1.0.0
Entrypoint    = OS/bin/my-daemon
Requires      = os-kernel
RestartPolicy = on-failure
RestartMax    = 3
Sandbox       = true
Capabilities  = fs.read, log.write, health.status
```

**One-shot task template** (`OS/etc/services.d/my-task.service`):

```ini
[Service]
Name          = my-task
Version       = 1.0.0
Entrypoint    = OS/bin/my-task
Type          = oneshot
RestartPolicy = never
Sandbox       = true
Capabilities  = fs.read, fs.write
```

**Plugin template** (`OS/etc/plugins.d/my-plugin.mod`):

```ini
[Module]
Name          = my-plugin
Version       = 1.0.0
Entrypoint    = OS/bin/plugins/my-plugin
HotReload     = true
Sandbox       = true
Capabilities  = fs.read, log.write
```

### 9.3 Runtime APIs

**Shell API** (available in any service or hook script):

```sh
# Emit an event
os-event emit MY_EVENT NORMAL '{"key":"value"}'

# Subscribe (blocking)
os-event subscribe MY_EVENT NORMAL

# File I/O (OS_ROOT-jailed)
os-syscall read  var/myservice/data.txt
os-syscall write var/myservice/data.txt "hello"

# Health reporting
echo "ok $(date +%s)" > "$OS_ROOT/var/service/${SERVICE_NAME}.health"

# Log a message
os-syscall log "[my-service] started successfully"

# Schedule a task
os-sched submit --priority 10 --type short -- my-command --arg value

# Check a capability
os-perms check my-service fs.write   # exit 0 = allowed
```

**Python API** (available via `OS/lib/filesystem.py`):

```python
import sys, os
sys.path.insert(0, os.environ["OS_ROOT"] + "/lib")
from filesystem import FileSystem

fs = FileSystem(os.environ["OS_ROOT"])

fs.write("var/myservice/data.txt", "hello world")
content = fs.read("var/myservice/data.txt")
fs.log("[my-service] wrote data")
```

### 9.4 Example Service Definition

The following is a complete example for a hypothetical `weather-agent` plugin
that queries an external API and caches results locally.

**Descriptor** (`OS/etc/plugins.d/weather-agent.mod`):

```ini
[Module]
Name          = weather-agent
Version       = 1.2.0
Entrypoint    = OS/bin/plugins/weather-agent
HotReload     = true
Sandbox       = true
Capabilities  = fs.read, fs.write, log.write, net.http, health.status
```

**Entrypoint** (`OS/bin/plugins/weather-agent`):

```sh
#!/bin/sh
# weather-agent — fetches weather data and caches it
SERVICE_NAME="weather-agent"
CACHE="var/plugins/weather-agent/cache.json"

while true; do
    # Update health heartbeat
    echo "ok $(date +%s)" > "$OS_ROOT/var/service/${SERVICE_NAME}.health"

    # Fetch and cache data (capability: net.http required)
    os-perms check "$SERVICE_NAME" net.http || {
        os-syscall log "[weather-agent] net.http denied, skipping fetch"
        sleep 300
        continue
    }
    DATA=$(curl -sf "https://api.example.com/weather?q=local")
    os-syscall write "$CACHE" "$DATA"
    os-event emit WEATHER_UPDATED NORMAL "{\"cache\":\"$CACHE\"}"

    sleep 300
done
```

**Consuming the event** (from the AI Core or another plugin):

```sh
os-event subscribe WEATHER_UPDATED NORMAL
# Blocks until a WEATHER_UPDATED event arrives; prints the JSON payload
```

---

*Last updated: 2026-04-03*
