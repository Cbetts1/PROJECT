# Process Model — AIOS-Lite

> © 2026 Christopher Betts | AIOSCPU Official | AI-generated, fully legal

---

## Overview

AIOS-Lite implements a **flat, cooperative process model** in user-space.
There are no hardware privilege rings or true preemptive scheduling.
"Processes" are shell scripts and Python modules that cooperate via a shared
virtual filesystem (`OS_ROOT`) and an event bus.

---

## Process Types

| Type | Description | Registered? | Scheduled? |
|------|-------------|-------------|-----------|
| `init` | PID 1, boots the OS | No | No |
| `kernel` | Kernel daemon (heartbeat) | Yes | No |
| `service` | Named background service | Yes | Optional |
| `agent` | AURA background agent | Yes | Optional |
| `task` | Periodic scheduled task | Yes | Yes |
| `shell` | Interactive AI or OS shell | No | No |
| `syscall` | Short-lived syscall invocation | No | No |

---

## Process Lifecycle

```
         ┌──────────────────────────────────────┐
         │            SPAWN                     │
         │  • Write PID to var/service/<n>.pid  │
         │  • Write health: "starting"          │
         │  • Optionally register with os-sched │
         └─────────────────┬────────────────────┘
                           │
                           ▼
         ┌──────────────────────────────────────┐
         │            RUNNING                   │
         │  • Process executes its main loop    │
         │  • Heartbeat polls pidfile every 30s │
         │  • Health file updated periodically  │
         └──┬───────────────┬───────────────────┘
            │               │
     Normal │         Crash │
      exit  │               │
            ▼               ▼
  ┌──────────────┐  ┌───────────────────────────┐
  │   STOPPING   │  │        CRASHED            │
  │  • SIGTERM   │  │  • Heartbeat detects dead │
  │  • Remove    │  │    PID in pidfile         │
  │    pidfile   │  │  • Log crash event        │
  │  • Health:   │  │  • Fire repair signal     │
  │    "stopped" │  │  • RepairBot may restart  │
  └──────────────┘  └───────────────────────────┘
```

---

## PID Registry

Each process registers itself by:

1. Writing its numeric PID to `$OS_ROOT/var/service/<name>.pid`
2. Writing a health descriptor to `$OS_ROOT/var/service/<name>.health`

### Health descriptor format

```
status=running
started=1743695424
pid=12345
cmd=os-kernelctl daemon
restarts=0
```

### Kernel heartbeat polling

The kernel daemon (`OS/etc/init.d/os-kernel`) polls all `*.pid` files in
`var/service/` every `KERNEL_HEARTBEAT_INTERVAL` seconds (default: 30 s):

```sh
for pidfile in "$OS_ROOT/var/service/"*.pid; do
    pid=$(cat "$pidfile")
    if ! kill -0 "$pid" 2>/dev/null; then
        # process is dead
        log_event "crash" "$(basename $pidfile .pid)" "$pid"
        rm -f "$pidfile"
        fire_event "service.crashed" "$(basename $pidfile .pid)"
    fi
done
```

---

## Scheduler Integration

Processes may optionally register with `os-sched` for priority management:

```sh
# Register a process with priority 5
os-sched register <name> <pid> <priority>

# Update priority
os-sched renice <name> <priority>

# Remove from scheduler
os-sched deregister <name>
```

The scheduler table is stored in `OS/proc/sched.table`:

```
# name        pid    priority  started
kernel        12345  0         1743695424
aura-agent    12400  5         1743695430
health-check  12450  10        1743695435
```

Background scan every 5 seconds prunes entries for dead PIDs.

---

## Inter-Process Communication

AIOS-Lite provides two IPC mechanisms:

### 1. Event Bus (files)

Events are written to `$OS_ROOT/var/events/<name>`:

```sh
# Sender
os-event fire service.crashed kernel

# Receiver (polling loop)
while true; do
    for ev in "$OS_ROOT/var/events/"*; do
        handle_event "$(basename $ev)" "$(cat $ev)"
        rm -f "$ev"
    done
    sleep 1
done
```

### 2. Shared State Files

Processes communicate via agreed-upon files in `$OS_ROOT/proc/`:

| File | Written by | Read by | Purpose |
|------|-----------|---------|---------|
| `proc/os.state` | init, kernel | all | OS runlevel, boot time, version |
| `proc/os.identity` | init | all | Hostname, OS_ROOT, personality |
| `proc/os.manifest` | init | kernel | Registered components |
| `proc/sched.table` | os-sched | kernel | Process priority table |
| `proc/aura.memory` | AURA | AURA | Pointer to memory DB |
| `proc/aura` | AURA agent | os-health | AURA agent state |

---

## Process Priorities

| Priority | Nice value | Use case |
|----------|-----------|---------|
| 0 | -10 | Kernel daemon — highest priority |
| 5 | -5 | Critical services |
| 10 | 0 | Normal services (default) |
| 15 | +5 | Background agents |
| 19 | +9 | Idle tasks |

Priority maps to POSIX `nice` values via:

```
nice_value = (priority - 10)
```

`os-sched` calls `renice -n <nice_value> -p <pid>` which delegates to the
host OS for actual CPU time allocation.

---

## Process Limits (Resource Manager)

`os-resource` enforces soft limits per-process:

| Resource | Per-process limit | Global warn threshold |
|----------|------------------|----------------------|
| CPU | — | 80% total |
| Memory RSS | — | 85% total |
| Open files | 256 | — |
| Log file size | — | 1000 lines (rotate) |
| Thermal | — | 68°C (S21 FE limit) |

When a global threshold is crossed, `os-resource` logs a warning and fires
a `resource.warning` event. Services may hook this event to throttle.

---

## Signal Handling

AIOS-Lite uses standard POSIX signals:

| Signal | Meaning in AIOS |
|--------|----------------|
| `SIGTERM` | Graceful shutdown request |
| `SIGKILL` | Force-kill (requires `proc.kill` cap) |
| `SIGHUP` | Reload configuration |
| `SIGUSR1` | Custom: trigger health check |
| `SIGUSR2` | Custom: dump state to log |

Services should install trap handlers:

```sh
trap 'cleanup; exit 0' TERM
trap 'reload_config' HUP
trap 'dump_state' USR2
```

---

*Last updated: 2026-04-03*
