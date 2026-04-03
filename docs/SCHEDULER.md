# Scheduler Description — AIOS-Lite

> © 2026 Christopher Betts | AIOSCPU Official | AI-generated, fully legal

---

## Overview

`OS/bin/os-sched` implements a **priority-based round-robin scheduler** for
AIOS-Lite processes. Because AIOS runs entirely in user-space, the scheduler
is an advisory layer — it tracks registered processes and delegates actual
CPU time allocation to the host OS via POSIX `renice`.

---

## Scheduler Architecture

```
┌──────────────────────────────────────────────────────────┐
│                     os-sched                              │
│                                                          │
│  ┌─────────────────────────────────────────────────┐    │
│  │               Scheduler Table                    │    │
│  │  (OS/proc/sched.table)                          │    │
│  │  name | pid | priority | started | cpu_nice     │    │
│  └──────────────────────┬──────────────────────────┘    │
│                         │                               │
│  ┌──────────────────────▼──────────────────────────┐    │
│  │           Background Scan (every 5 s)            │    │
│  │  • Read all entries                              │    │
│  │  • kill -0 each PID                             │    │
│  │  • Remove dead entries                          │    │
│  │  • Emit service.pruned event if removed         │    │
│  └──────────────────────┬──────────────────────────┘    │
│                         │                               │
│  ┌──────────────────────▼──────────────────────────┐    │
│  │         Host OS Delegation (renice)              │    │
│  │  renice -n <nice> -p <pid>                      │    │
│  └─────────────────────────────────────────────────┘    │
└──────────────────────────────────────────────────────────┘
```

---

## Scheduler Table Format

File: `OS/proc/sched.table`

```
# AIOS Scheduler Table
# Format: name  pid  priority  started  restarts
kernel        12345  0   1743695424  0
aura-agent    12400  5   1743695430  0
bridge-ios    12410  8   1743695432  0
health-poll   12450  10  1743695435  0
log-rotate    12460  15  1743695436  0
idle-cleanup  12470  19  1743695437  0
```

---

## Priority Levels

| Priority | POSIX nice | Label | Typical users |
|----------|-----------|-------|--------------|
| 0 | -10 | `realtime` | Kernel daemon |
| 1–4 | -5 to -9 | `high` | Critical services (bridge, auth) |
| 5–9 | -1 to -5 | `above_normal` | Standard services |
| 10 | 0 | `normal` | Default priority |
| 11–15 | +1 to +5 | `below_normal` | Background agents |
| 16–19 | +6 to +9 | `idle` | Idle/cleanup tasks |

Priority 10 maps to nice 0 (no priority change). Formula:

```
nice_value = (priority - 10)
```

---

## Scheduling Algorithm

AIOS-Lite uses **static-priority round-robin**:

1. All registered processes are sorted by priority (ascending = higher priority)
2. The scheduler does not preempt — it relies on the host kernel for time slices
3. Every 5 seconds the background scan verifies liveness and cleans dead PIDs
4. On a priority change (`os-sched renice`), `renice` is called immediately

### Round-robin within same priority

Multiple processes at the same priority share CPU time equally (host OS
round-robins them at their shared nice value).

---

## Scheduler Commands

```sh
# Register a process
os-sched register <name> <pid> [priority]   # default priority: 10

# Update priority
os-sched renice <name> <priority>

# Remove a process
os-sched deregister <name>

# List all scheduled processes
os-sched list

# Force pruning of dead PIDs
os-sched prune

# Show scheduler status
os-sched status
```

### Example session

```sh
$ os-sched register myservice 9900 5
Registered myservice (pid=9900, priority=5)

$ os-sched list
NAME            PID    PRI  NICE  STARTED              RESTARTS
kernel          12345  0    -10   2026-04-03 15:30:00  0
aura-agent      12400  5    -5    2026-04-03 15:30:06  0
myservice       9900   5    -5    2026-04-03 15:31:00  0
health-poll     12450  10   0     2026-04-03 15:30:11  0

$ os-sched renice myservice 15
Reniced myservice to priority 15 (nice +5)

$ os-sched deregister myservice
Deregistered myservice
```

---

## Task Scheduling

Periodic tasks are a higher-level abstraction built on top of the process
scheduler. They are defined in `OS/etc/aura/tasks/` and loaded by `S70-aura-tasks`.

### Task definition format

```sh
# etc/aura/tasks/log-rotate.task
TASK_NAME="log-rotate"
TASK_CMD="OS/bin/os-recover log_rotate"
TASK_INTERVAL=3600       # seconds
TASK_PRIORITY=15
TASK_ENABLED=true
```

### Task runtime

The task framework:
1. Reads all `*.task` files from `etc/aura/tasks/`
2. For each enabled task, starts a polling loop in a background subshell
3. Registers the subshell PID with `os-sched` at the defined priority
4. The loop sleeps for `TASK_INTERVAL` seconds between runs
5. Each run is logged to `var/log/tasks.log`

---

## Integration with Kernel Heartbeat

The kernel daemon (`OS/etc/init.d/os-kernel`) integrates with the scheduler:

- On each heartbeat, it calls `os-sched prune` to remove dead entries
- If a service with `restart=always` dies, the heartbeat triggers a restart
  and re-registers the new PID

### Restart policy (var/service/<name>.health)

```
status=running
restart_policy=always     # always | on-failure | never
max_restarts=5
restarts=0
```

---

## Limitations

| Limitation | Explanation |
|------------|-------------|
| No preemption | Cooperative — host OS manages actual preemption |
| No real-time guarantees | `nice` values are advisory on most host kernels |
| No memory limits | Resource manager is advisory; no cgroups in user-space |
| No CPU affinity | Use `LLAMA_CPU_AFFINITY` env var for LLM threads only |

---

*Last updated: 2026-04-03*
