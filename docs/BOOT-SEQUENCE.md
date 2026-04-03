# Boot Sequence Specification — AIOS-Lite

> © 2026 Christopher Betts | AIOSCPU Official | AI-generated, fully legal

---

## Overview

AIOS-Lite implements a ten-stage, runlevel-based boot sequence modelled on
SysV init. PID 1 is `OS/sbin/init` (a POSIX shell script). Each stage is
an idempotent rc2.d script that logs its result to `OS/var/log/os.log`.

---

## Boot Sequence Diagram

```
Power-on / sh OS/sbin/init
        │
        ▼
┌─────────────────────────────────────────────────┐
│  Stage 0 — Environment Resolution               │
│  OS/sbin/init                                   │
│  • Resolve OS_ROOT (auto-detect from script dir)│
│  • Load config/aios.conf                        │
│  • Set AIOS_HOME, PATH                          │
└──────────────────┬──────────────────────────────┘
                   │
                   ▼
┌─────────────────────────────────────────────────┐
│  Stage 1 — Filesystem Bootstrap                 │
│  OS/sbin/init (mkdir -p / touch)                │
│  • Create: bin sbin etc lib proc var tmp dev    │
│  • Create: var/log var/service var/events       │
│  • Ensure: var/log/os.log var/log/aura.log      │
│  • Ensure: proc/os.state proc/os.identity       │
└──────────────────┬──────────────────────────────┘
                   │
                   ▼
┌─────────────────────────────────────────────────┐
│  Stage 2 — OS State Initialisation              │
│  OS/sbin/init (write proc/os.state)             │
│  • runlevel=2                                   │
│  • boot_time=<epoch>                            │
│  • kernel_pid=<pid>                             │
│  • aios_version=<ver>                           │
└──────────────────┬──────────────────────────────┘
                   │
                   ▼
┌─────────────────────────────────────────────────┐
│  Stage 3 — Banner (S10-banner)                  │
│  OS/etc/rc2.d/S10-banner                        │
│  • Print AIOS ASCII banner                      │
│  • Print version, OS_ROOT, hostname             │
└──────────────────┬──────────────────────────────┘
                   │
                   ▼
┌─────────────────────────────────────────────────┐
│  Stage 4 — Device Detection (S20-devices)       │
│  OS/etc/rc2.d/S20-devices                       │
│  • Probe for iOS (ideviceinfo)                  │
│  • Probe for Android (adb devices)              │
│  • Probe for SSH targets (config lookup)        │
│  • Write device list to proc/devices            │
└──────────────────┬──────────────────────────────┘
                   │
                   ▼
┌─────────────────────────────────────────────────┐
│  Stage 5 — AURA Bridge (S30-aura-bridge)        │
│  OS/etc/rc2.d/S30-aura-bridge                   │
│  • Load bridge modules from OS/lib/aura-bridge/ │
│  • Initialise detect, ios, android, linux mods  │
│  • Start mirror orchestration layer             │
└──────────────────┬──────────────────────────────┘
                   │
                   ▼
┌─────────────────────────────────────────────────┐
│  Stage 6 — Kernel Daemon (S40-os-kernel)        │
│  OS/etc/rc2.d/S40-os-kernel                     │
│  • Start os-kernelctl daemon                    │
│  • Write kernel PID to proc/os                  │
│  • Begin heartbeat polling (30 s interval)      │
└──────────────────┬──────────────────────────────┘
                   │
                   ▼
┌─────────────────────────────────────────────────┐
│  Stage 7 — AURA Agents (S60-aura-agents)        │
│  OS/etc/rc2.d/S60-aura-agents                   │
│  • Load agent descriptors from etc/aura/agents  │
│  • Start each enabled background agent          │
│  • Register agent PIDs in var/service/          │
└──────────────────┬──────────────────────────────┘
                   │
                   ▼
┌─────────────────────────────────────────────────┐
│  Stage 8 — Task Scheduler (S70-aura-tasks)      │
│  OS/etc/rc2.d/S70-aura-tasks                    │
│  • Load task definitions from etc/aura/tasks    │
│  • Register tasks with os-sched                 │
│  • Emit boot-complete event                     │
└──────────────────┬──────────────────────────────┘
                   │
                   ▼
┌─────────────────────────────────────────────────┐
│  Stage 9 — Interactive Shell                    │
│  exec OS/bin/os-shell  (or bin/aios)            │
│  • Present AIOS prompt                          │
│  • Accept user input                            │
└─────────────────────────────────────────────────┘
```

---

## Stage Detail

### Stage 0 — Environment Resolution

**Script:** `OS/sbin/init`  
**Key actions:**
- Determine `SCRIPT_DIR` using `$0` resolution
- Set `OS_ROOT="${OS_ROOT:-$SCRIPT_DIR/../}"` (normalised with `realpath`)
- Source `config/aios.conf` if present
- Export `AIOS_HOME`, `OS_ROOT`, `PATH`

**Failure mode:** If `OS_ROOT` cannot be resolved, init prints an error and
exits with code 1.

---

### Stage 1 — Filesystem Bootstrap

**Script:** `OS/sbin/init` (inline)  
**Directories created (idempotent):**

```
$OS_ROOT/bin        $OS_ROOT/sbin       $OS_ROOT/lib
$OS_ROOT/etc        $OS_ROOT/etc/init.d $OS_ROOT/etc/rc2.d
$OS_ROOT/etc/perms.d $OS_ROOT/proc      $OS_ROOT/var
$OS_ROOT/var/log    $OS_ROOT/var/service $OS_ROOT/var/events
$OS_ROOT/var/backup $OS_ROOT/tmp        $OS_ROOT/dev
$OS_ROOT/mirror     $OS_ROOT/mirror/ios $OS_ROOT/mirror/android
$OS_ROOT/mirror/linux $OS_ROOT/mirror/custom
```

**Files touched:**

```
$OS_ROOT/var/log/os.log
$OS_ROOT/var/log/aura.log
$OS_ROOT/var/log/syscall.log
$OS_ROOT/var/log/bridge.log
$OS_ROOT/proc/os.state
$OS_ROOT/proc/os.identity
$OS_ROOT/proc/os.manifest
$OS_ROOT/proc/sched.table
$OS_ROOT/proc/aura.memory
```

---

### Stage 2 — OS State Initialisation

**Script:** `OS/sbin/init` (inline)  
**State file format** (`proc/os.state`):

```
runlevel=2
boot_time=1743695424
kernel_pid=12345
aios_version=1.4.0
os_root=/home/user/PROJECT/OS
hostname=aios-device
```

---

### Stage 3 — Banner (S10-banner)

**Script:** `OS/etc/rc2.d/S10-banner` → `OS/etc/init.d/banner`  
Prints the AIOS ASCII art logo (from `branding/LOGO_ASCII.txt`) and OS info.

---

### Stage 4 — Device Detection (S20-devices)

**Script:** `OS/etc/rc2.d/S20-devices` → `OS/etc/init.d/devices`  
Probes for connected devices and records results in `proc/devices`.  
No failure if no devices found — this stage is advisory.

---

### Stage 5 — AURA Bridge (S30-aura-bridge)

**Script:** `OS/etc/rc2.d/S30-aura-bridge` → `OS/etc/init.d/aura-bridge`  
Loads `OS/lib/aura-bridge/` modules in order:
1. `detect.mod` — host OS detection
2. `ios.mod` — Apple iOS bridge
3. `android.mod` — Android ADB bridge
4. `linux.mod` — Linux/SSH bridge
5. `mirror.mod` — unified mirror orchestration

---

### Stage 6 — Kernel Daemon (S40-os-kernel)

**Script:** `OS/etc/rc2.d/S40-os-kernel` → `OS/etc/init.d/os-kernel`  
Starts the kernel heartbeat daemon in the background.  
PID written to `proc/os` and `var/service/kernel.pid`.

---

### Stage 7 — AURA Agents (S60-aura-agents)

**Script:** `OS/etc/rc2.d/S60-aura-agents`  
Reads agent descriptors from `etc/aura/agents/` and starts each enabled agent.

---

### Stage 8 — Task Scheduler (S70-aura-tasks)

**Script:** `OS/etc/rc2.d/S70-aura-tasks`  
Loads periodic task definitions and registers them with `os-sched`.  
Fires the `boot.complete` event via `os-event`.

---

### Stage 9 — Interactive Shell

**Binary:** `OS/bin/os-shell` (or `bin/aios` for the AI-enhanced dual-shell)  
Entered via `exec` — the PID 1 process is replaced by the shell.

---

## Boot Targets

Configured in `OS/etc/boot.target`:

| Target | Description |
|--------|-------------|
| `default` | Full boot (all stages, interactive shell) |
| `recovery` | Stages 0–2 only, then `os-recover repair` |
| `minimal` | Stages 0–3 only, then plain `sh` |
| `service` | Stages 0–8, no interactive shell (headless) |

---

## Boot Timing (typical, Samsung Galaxy S21 FE)

| Stage | Typical time |
|-------|-------------|
| 0 — Environment | < 0.1 s |
| 1 — Filesystem | < 0.2 s |
| 2 — State init | < 0.1 s |
| 3 — Banner | < 0.1 s |
| 4 — Device detection | 1–3 s |
| 5 — AURA bridge | 0.5–1 s |
| 6 — Kernel daemon | < 0.5 s |
| 7 — Agents | 0.5–2 s |
| 8 — Tasks | < 0.3 s |
| **Total** | **3–8 s** |

---

*Last updated: 2026-04-03*
