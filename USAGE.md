# Usage Guide — AIOS-Lite / AIOSCPU

> © 2026 Christopher Betts | AIOSCPU Official | AI-generated, fully legal

---

## Table of Contents

1. [Starting AIOS](#1-starting-aios)
2. [Shell Modes](#2-shell-modes)
3. [AI Shell Commands](#3-ai-shell-commands)
4. [OS Shell Commands](#4-os-shell-commands)
5. [Memory System](#5-memory-system)
6. [Cross-OS Bridge](#6-cross-os-bridge)
7. [Service Management](#7-service-management)
8. [Log Management](#8-log-management)
9. [AI Query Examples](#9-ai-query-examples)
10. [Kernel Control](#10-kernel-control)
11. [Recovery Mode](#11-recovery-mode)
12. [Environment Variables](#12-environment-variables)

---

## 1. Starting AIOS

```sh
# Boot the OS (required once per session)
export AIOS_HOME="/path/to/PROJECT"
export OS_ROOT="$AIOS_HOME/OS"
export PATH="$OS_ROOT/bin:$OS_ROOT/sbin:$AIOS_HOME/bin:$PATH"
sh OS/sbin/init

# Launch the AI shell
os-shell

# Or launch the full OS shell
bin/aios-sys
```

---

## 2. Shell Modes

AIOS-Lite has three interaction modes:

| Mode | Command | Description |
|------|---------|-------------|
| `operator` | `mode operator` | Full system access (default) |
| `system` | `mode system` | OS administration commands only |
| `talk` | `mode talk` | Pure AI conversation mode |

Switch modes at runtime:

```sh
aios> mode talk
aios> Hello, what can you do?

aios> mode operator
aios> services
```

---

## 3. AI Shell Commands

Type any command at the `aios>` prompt:

### General

| Command | Description |
|---------|-------------|
| `help` | Show full command list |
| `status` | Full OS state summary |
| `ask <text>` | Ask the AI a question |
| `exit` | Exit the shell |

### AI Memory

| Command | Description |
|---------|-------------|
| `mem.set <key> <value>` | Store a named fact |
| `mem.get <key>` | Retrieve a stored fact |
| `mem.list` | List all symbolic memory entries |
| `sem.set <key> <value>` | Store a semantic memory entry |
| `sem.search <query>` | Semantic similarity search |
| `recall <query>` | Hybrid recall (context + symbolic + semantic) |

### System

| Command | Description |
|---------|-------------|
| `services` | Show all service statuses |
| `procs` | List running processes |
| `sysinfo` | Hardware and OS info |
| `logs [n]` | Show last n log lines (default 20) |
| `event <name>` | Fire a system event |

### Bridge & Mirror

| Command | Description |
|---------|-------------|
| `bridge.detect` | Auto-detect connected devices |
| `mirror.mount <type>` | Mount device: `ios`, `android`, `linux`, `auto` |
| `mirror.ls <type>` | Browse mirrored files |
| `mirror.unmount <type>` | Unmount device |

---

## 4. OS Shell Commands

Available from `$OS_ROOT/bin/`:

```sh
os-shell           # Interactive AI shell
os-real-shell      # Full OS shell (bash-like)
os-info            # System info
os-state           # OS runtime state dump
os-log <msg>       # Write to system log
os-ps              # List processes
os-kernelctl       # Kernel daemon control
os-service         # Service lifecycle management
os-service-status  # All services health overview
os-sched           # Process scheduler
os-perms           # Permissions check
os-resource        # Resource monitor
os-recover         # Recovery mode
os-syscall         # Raw system call interface
os-event           # Fire system event
os-msg             # Send message to event bus
os-bridge          # Cross-OS bridge control
os-mirror          # Device filesystem mirror
os-netconf         # Network configuration
os-httpd           # HTTP REST server
os-health-wrapper  # AURA health wrapper
os-install         # AIOS package installer
```

---

## 5. Memory System

AIOS-Lite has three memory layers that combine in hybrid recall:

### Context Window

Automatically maintained — stores the last 50 interactions.

```sh
aios> What did I say earlier?
# The AI recalls from the context window
```

### Symbolic Memory

Named key-value facts stored permanently:

```sh
aios> mem.set my_name "Christopher Betts"
aios> mem.set my_phone "Samsung Galaxy S21 FE"
aios> mem.get my_name
Christopher Betts
```

### Semantic Memory

Embedding-based search for concepts:

```sh
aios> sem.set phone_info "Samsung Galaxy S21 FE 8GB variant"
aios> sem.search "what device do I have"
# Returns: phone_info → Samsung Galaxy S21 FE 8GB variant
```

### Hybrid Recall

Combines all three layers:

```sh
aios> recall "what phone did I connect"
# Searches context window + symbolic + semantic simultaneously
```

---

## 6. Cross-OS Bridge

```sh
# Detect all connected devices
os-bridge detect

# ── iOS (requires libimobiledevice + ifuse) ──
os-bridge ios pair           # Pair with iPhone
os-mirror mount ios          # Mount iPhone filesystem
ls $OS_ROOT/mirror/ios/      # Browse iOS files
os-mirror unmount ios        # Unmount

# ── Android (requires ADB + USB debugging) ──
os-bridge android devices    # List ADB devices
os-mirror mount android      # Mount Android filesystem
cat $OS_ROOT/mirror/android/_sdcard.listing
os-mirror unmount android

# ── Remote Linux / macOS via SSH ──
os-mirror mount ssh myuser@192.168.1.100
ls $OS_ROOT/mirror/linux/ssh_192.168.1.100/
os-mirror unmount ssh

# ── Auto-detect ──
os-mirror mount auto         # Mounts first available device
```

---

## 7. Service Management

```sh
# List all services and their status
os-service-status

# Start / stop / restart a service
os-service start  <name>
os-service stop   <name>
os-service restart <name>

# Check a specific service
os-service status <name>

# Register a new service
os-service register <name> <cmd>
```

---

## 8. Log Management

```sh
# Read the system log
os-log read          # Print all entries
os-log read 50       # Print last 50 lines
os-log write "msg"   # Append a message

# Log files
$OS_ROOT/var/log/os.log        # Main OS log
$OS_ROOT/var/log/aura.log      # AURA AI agent log
$OS_ROOT/var/log/syscall.log   # System call audit log
$OS_ROOT/var/log/bridge.log    # Cross-OS bridge log
```

Logs auto-rotate at 1000 lines (trimmed to 500).

---

## 9. AI Query Examples

```sh
aios> ask how much memory is available
# Returns: current RAM usage from /proc/meminfo

aios> ask what services are running
# Equivalent to: os-service-status

aios> ask repair the system
# Invokes RepairBot → runs os-recover check

aios> ask what did I set for my phone
# Hybrid recall: searches memory for "phone"

aios> ask show disk usage
# Returns: df -h output within OS_ROOT

aios> ask connect to my android phone
# Guides you through os-bridge android + os-mirror mount android
```

---

## 10. Kernel Control

```sh
os-kernelctl status   # Show kernel health summary
os-kernelctl info     # Personality, version, runlevel
os-kernelctl start    # Start kernel daemon
os-kernelctl stop     # Stop kernel daemon
os-kernelctl restart  # Restart kernel daemon
```

---

## 11. Recovery Mode

Use when the OS state becomes corrupted:

```sh
# Check integrity without making changes
OS_ROOT=/path/to/OS sh OS/bin/os-recover check

# Backup current state
OS_ROOT=/path/to/OS sh OS/bin/os-recover backup

# Full repair (recreate missing dirs, restore state, clean stale pids)
OS_ROOT=/path/to/OS sh OS/bin/os-recover repair
```

Recovery stages:
1. Directory / file repair
2. State file restoration
3. Service cleanup (stale PIDs)
4. Log rotation
5. Dependency audit

---

## 12. Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `AIOS_HOME` | *(required)* | Root of the AIOS-Lite repository |
| `OS_ROOT` | `$AIOS_HOME/OS` | Virtual OS filesystem root |
| `AIOS_MODE` | `operator` | Shell mode on startup |
| `LLAMA_MODEL` | *(optional)* | Path to GGUF model file |
| `LLAMA_BINARY` | `llama-cli` | Path to llama.cpp binary |
| `LLAMA_CPU_AFFINITY` | `1-3` | CPU cores for inference |
| `KERNEL_HEARTBEAT_INTERVAL` | `30` | Heartbeat poll interval (seconds) |
| `AIOS_LOG_LEVEL` | `info` | Log verbosity: `debug`, `info`, `warn`, `error` |
| `AIOS_BRIDGE_TIMEOUT` | `10` | Bridge operation timeout (seconds) |

---

*For a complete reference, see [docs/INSTRUCTION-MANUAL.md](docs/INSTRUCTION-MANUAL.md).*
