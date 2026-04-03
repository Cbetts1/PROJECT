# AIOS-Lite Kernel Design

> © 2026 Chris Betts | AIOSCPU Official | AI-generated, fully legal

---

## 1. Overview

AIOS-Lite implements a **pseudo-kernel** — a user-space abstraction layer that
provides kernel-like services (process management, IPC, scheduling, permissions,
resource tracking) without requiring hardware privilege rings.  The kernel runs
entirely in POSIX shell + Python 3, making it portable to any Unix host:
Android/Termux, Linux, or macOS.

```
┌─────────────────────────────────────────────────────────────────┐
│                     User / AI Shell Layer                        │
│   os-shell  |  os-real-shell  |  aios  |  aios-sys             │
└──────────────────────────┬──────────────────────────────────────┘
                           │ system calls (os-syscall)
┌──────────────────────────▼──────────────────────────────────────┐
│                     AIOS Pseudo-Kernel                           │
│  os-kernelctl  |  os-syscall  |  os-sched  |  os-perms          │
│  os-resource   |  os-recover  |  os-service  |  os-event        │
└──────────────────────────┬──────────────────────────────────────┘
                           │ OS_ROOT filesystem jail
┌──────────────────────────▼──────────────────────────────────────┐
│               OS_ROOT Virtual Filesystem                         │
│  OS/bin/  OS/sbin/  OS/etc/  OS/proc/  OS/var/  OS/mirror/     │
└──────────────────────────┬──────────────────────────────────────┘
                           │ host OS boundary (chroot-style)
┌──────────────────────────▼──────────────────────────────────────┐
│               Host OS (Android/Linux/macOS)                      │
└─────────────────────────────────────────────────────────────────┘
```

---

## 2. Kernel Boundary Definition

The kernel boundary is enforced by two mechanisms:

### 2.1 OS_ROOT Filesystem Jail

All file I/O passes through `OS/lib/filesystem.py`, which:

- Resolves every path relative to `OS_ROOT`
- Uses `os.path.realpath()` to resolve symlinks before comparison
- Denies (returns `Access denied`) any path that resolves outside `OS_ROOT`
- Provides a minimal, auditable API: `read`, `write`, `append`, `list`,
  `exists`, `stat`, `log`

```python
# From OS/lib/filesystem.py
full = os.path.realpath(os.path.join(OS_ROOT, rel))
if not full.startswith(os.path.realpath(OS_ROOT) + os.sep):
    raise PermissionError("Access denied")
```

### 2.2 Capability-Based Permission Model

Every cross-kernel operation first calls `os-perms check <principal> <cap>`:

```sh
os-perms check operator fs.read        # exit 0 = allowed
os-perms check aura     proc.kill      # exit 1 = denied
```

Capabilities are stored in `OS/etc/perms.d/<principal>.caps`.  Wildcard
matching (`fs.*`) is supported.

---

## 3. System Calls

System calls are implemented as a single dispatching script: `OS/bin/os-syscall`.

Every syscall:
1. Validates its arguments
2. Appends an audit entry to `var/log/syscall.log` and `var/log/aura.log`
3. Executes the requested operation within the OS_ROOT boundary
4. Returns 0 on success, non-zero on error

### Syscall Table

| Syscall | Arguments | Description |
|---------|-----------|-------------|
| `read`    | `<path>` | Read file (OS_ROOT-jailed) |
| `write`   | `<path> <data>` | Write/create file |
| `append`  | `<path> <data>` | Append to file |
| `exists`  | `<path>` | Test existence → `true`/`false` |
| `stat`    | `<path>` | File metadata |
| `mkdir`   | `<path>` | Create directory |
| `rm`      | `<path>` | Remove file |
| `ls`      | `[path]` | List directory |
| `spawn`   | `<cmd> [args]` | Run whitelisted binary |
| `kill`    | `<pid>` | SIGTERM to process |
| `getpid`  | — | Current process PID |
| `getenv`  | `<name>` | Read environment variable |
| `setenv`  | `<name> <value>` | Set environment variable |
| `uptime`  | — | System uptime |
| `sysinfo` | — | Kernel / OS state dump |
| `log`     | `<message>` | Append message to audit log |

---

## 4. Process Model

AIOS uses a flat process model.  Every "process" is a shell script or Python
module that:

1. Registers itself by writing its PID to `OS/var/service/<name>.pid`
2. Writes a health file to `OS/var/service/<name>.health`
3. Is polled by the kernel heartbeat every `KERNEL_HEARTBEAT_INTERVAL` seconds
4. Can be optionally tracked by `os-sched` for priority management

### Process Lifecycle

```
[spawn]  → write pidfile → register with os-sched (optional)
[alive]  → kernel heartbeat polls pidfile → prune if dead
[stop]   → send SIGTERM → remove pidfile
[crash]  → heartbeat detects dead pid → logs event → emits repair signal
```

### Scheduler

`OS/bin/os-sched` implements priority round-robin:

- Priority range: 0 (highest) → 19 (lowest), mapped to POSIX `nice` values
- Background scan every 5 s prunes dead PIDs from `OS/proc/sched.table`
- `renice` delegates to the host OS for actual CPU time allocation

---

## 5. Permissions Model

AIOS implements a **capability-based security model**:

### Principals

| Principal | Role | Default Capabilities |
|-----------|------|---------------------|
| `operator` | Human user | All capabilities (`*.*`) |
| `aura`    | AI agent daemon | `fs.read`, `fs.list`, `log.read`, `memory.*`, `health.check`, `ai.ask`, `net.ping` |
| `service` | Background service | `log.write`, `health.status`, `system.sysinfo` |

### Capability Namespaces

| Namespace | Description |
|-----------|-------------|
| `fs.*`    | Filesystem operations |
| `proc.*`  | Process management |
| `net.*`   | Network operations |
| `log.*`   | Log read/write |
| `memory.*` | Memory read/write |
| `system.*` | System info / control |
| `ai.*`    | AI query / inference |
| `health.*` | Health check / status |
| `repair.*` | Self-repair operations |

---

## 6. Resource Manager

`OS/bin/os-resource` monitors and enforces soft limits:

| Resource | Metric | Default Warn Threshold |
|----------|--------|----------------------|
| CPU | Usage % | 80% |
| Memory | Usage % | 85% |
| Disk | Usage % | 90% |
| Thermal | Temperature °C | 68°C (Samsung S21 FE limit) |

Limits are configured in `OS/etc/resource.limits`.  When a threshold is
crossed, a warning is logged to `var/log/os.log`.

---

## 7. Boot Sequence

```
1. OS/sbin/init         — resolves OS_ROOT, loads config/aios.conf
2. mkdir -p             — creates all required runtime directories
3. touch                — ensures required files exist (logs, state)
4. write os.state       — initialises runlevel, boot_time, kernel_pid
5. /etc/rc2.d/S10-banner      — prints AIOS banner
6. /etc/rc2.d/S20-devices     — detects connected devices
7. /etc/rc2.d/S30-aura-bridge — starts cross-OS bridge
8. /etc/rc2.d/S40-os-kernel   — starts kernel daemon (heartbeat)
9. /etc/rc2.d/S60-aura-agents — starts background agents
10./etc/rc2.d/S70-aura-tasks  — starts task scheduler
11. exec os-shell             — launches interactive AI shell
```

Each rc2.d script is idempotent and logs its output to `var/log/os.log`.

---

## 8. Recovery Mode

`OS/bin/os-recover` implements a five-stage recovery sequence:

```
1. Directory / File Repair   — recreate missing OS_ROOT directories and files
2. State File Repair         — restore proc/os.state from defaults if corrupt
3. Service Cleanup           — remove stale pidfiles for dead services
4. Log Rotation              — truncate oversized log files (>1000 lines → 500)
5. Dependency Audit          — verify required binaries (sh, python3, awk, ...)
```

**Recovery mode activation:**
```sh
# Full repair (non-interactive)
OS_ROOT=/path/to/OS sh OS/bin/os-recover repair

# Integrity check only (no changes)
OS_ROOT=/path/to/OS sh OS/bin/os-recover check

# Backup before repair
OS_ROOT=/path/to/OS sh OS/bin/os-recover backup
OS_ROOT=/path/to/OS sh OS/bin/os-recover repair
```

---

## 9. Module List

| Module | Location | Language | Purpose |
|--------|----------|----------|---------|
| init | `OS/sbin/init` | POSIX sh | Boot / PID 1 |
| os-syscall | `OS/bin/os-syscall` | POSIX sh | System call gate |
| os-sched | `OS/bin/os-sched` | POSIX sh | Process scheduler |
| os-perms | `OS/bin/os-perms` | POSIX sh | Permissions model |
| os-resource | `OS/bin/os-resource` | POSIX sh | Resource manager |
| os-recover | `OS/bin/os-recover` | POSIX sh | Recovery mode |
| os-shell | `OS/bin/os-shell` | POSIX sh | AI interactive shell |
| os-real-shell | `OS/bin/os-real-shell` | POSIX sh | Full OS shell |
| os-service | `OS/bin/os-service` | POSIX sh | Service control |
| os-event | `OS/bin/os-event` | POSIX sh | Event bus |
| os-httpd | `OS/bin/os-httpd` | Python 3 | REST / WebSocket server |
| os-netconf | `OS/bin/os-netconf` | POSIX sh | Network configuration |
| filesystem.py | `OS/lib/filesystem.py` | Python 3 | OS_ROOT-jailed file I/O |
| intent_engine.py | `ai/core/intent_engine.py` | Python 3 | NL intent classification |
| router.py | `ai/core/router.py` | Python 3 | Intent → Bot dispatch |
| bots.py | `ai/core/bots.py` | Python 3 | HealthBot/LogBot/RepairBot |
| ai_backend.py | `ai/core/ai_backend.py` | Python 3 | AI dispatch backend |
| llama_client.py | `ai/core/llama_client.py` | Python 3 | LLaMA / mock inference |
| aura-core.sh | `lib/aura-core.sh` | Bash | AIOS core library |
| aura-net.sh | `lib/aura-net.sh` | Bash | Network commands |
| aura-proc.sh | `lib/aura-proc.sh` | Bash | Process commands |
| aura-ai.sh | `lib/aura-ai.sh` | Bash | AI query dispatch |

---

*Last updated: 2026-04-03*
