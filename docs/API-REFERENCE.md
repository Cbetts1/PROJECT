# AIOS-Lite API Reference

> © 2026 Chris Betts | AIOSCPU Official | AI-generated, fully legal

---

## Contents

1. [System API (os-syscall)](#1-system-api)
2. [Kernel API (os-kernelctl / os-sched / os-perms / os-resource)](#2-kernel-api)
3. [App / Shell API (os-shell commands)](#3-app-shell-api)
4. [Automation API (os-event / os-service)](#4-automation-api)
5. [AI Plugin API (intent_engine / router / bots)](#5-ai-plugin-api)
6. [HTTP REST API (os-httpd)](#6-http-rest-api)
7. [Network API (os-netconf)](#7-network-api)
8. [Security Model](#8-security-model)

---

## 1. System API

All system calls are invoked through `OS/bin/os-syscall`.

### Invocation

```sh
OS_ROOT=/path/to/OS sh OS/bin/os-syscall <syscall> [args...]
```

### File System Calls

```sh
os-syscall read   <path>              # Read file content
os-syscall write  <path> <data>       # Write/create file
os-syscall append <path> <data>       # Append to file
os-syscall exists <path>              # Returns: true | false
os-syscall stat   <path>              # Returns: isfile, size, mtime
os-syscall mkdir  <path>              # Create directory
os-syscall rm     <path>              # Remove file
os-syscall ls     [path]              # List directory (default: .)
```

### Process Calls

```sh
os-syscall spawn  <cmd> [args...]     # Execute whitelisted binary
os-syscall kill   <pid>               # Send SIGTERM
os-syscall getpid                     # Get current PID
```

### Environment Calls

```sh
os-syscall getenv <name>              # Read env variable (alphanumeric only)
os-syscall setenv <name> <value>      # Set env variable for session
```

### System Info Calls

```sh
os-syscall uptime                     # Host uptime
os-syscall sysinfo                    # OS state dump
os-syscall log    <message>           # Append to audit log
```

**Audit:** Every syscall appends to `OS/var/log/syscall.log` and
`OS/var/log/aura.log`.

---

## 2. Kernel API

### Kernel Control (os-kernelctl)

```sh
os-kernelctl status    # Kernel health summary
os-kernelctl info      # Personality, version, runlevel
os-kernelctl stop      # Stop kernel daemon
os-kernelctl start     # Start kernel daemon
```

### Scheduler (os-sched)

```sh
os-sched start              # Start scheduler daemon
os-sched stop               # Stop scheduler daemon
os-sched status             # Scheduler state
os-sched add  <pid> <pri>   # Track process (priority 0–19)
os-sched rm   <pid>         # Untrack process
os-sched list               # List all tracked processes
os-sched renice <pid> <n>   # Adjust niceness
os-sched info               # Algorithm description
```

### Permissions (os-perms)

```sh
os-perms check  <principal> <capability>   # exit 0=allow, 1=deny
os-perms grant  <principal> <capability>   # Add capability
os-perms revoke <principal> <capability>   # Remove capability
os-perms list   <principal>               # List capabilities
os-perms list-all                          # All principals
os-perms audit  [n]                        # Last n audit entries
os-perms init                              # Create default roles
```

**Capability format:** `<namespace>.<action>` or `<namespace>.*` (wildcard)

### Resource Manager (os-resource)

```sh
os-resource status          # Full resource summary
os-resource cpu             # CPU usage
os-resource mem             # Memory usage
os-resource disk            # Disk usage
os-resource thermal         # Temperature
os-resource limits          # Show configured limits
os-resource check           # Check vs limits (exit 1 on warning)
os-resource snapshot [file] # Save snapshot
```

---

## 3. App / Shell API

These commands are available inside `os-shell` and `os-real-shell`.

### Query & AI

```sh
ask <text>             # Ask the AI (LLaMA or rule-based fallback)
recall <text>          # Hybrid memory recall
```

### Filesystem

```sh
ls [path]              # List directory
cd <path>              # Change directory
cat <path>             # Read file
read <path>            # Same as cat
write <path>           # Write file (interactive)
```

### Memory

```sh
mem.set <key> <value>  # Store symbolic memory
mem.get <key>          # Retrieve symbolic memory
sem.set <key> <text>   # Store semantic embedding
sem.search <query>     # Search semantic memory
```

### System

```sh
sysinfo                # System information
uptime                 # System uptime
disk                   # Disk usage
status                 # Full OS state
services               # Service health overview
ps                     # Process list
```

### Network

```sh
netinfo                # Network interfaces and routes
```

### Service Control

```sh
start <service>        # Start a service
stop  <service>        # Stop a service
restart <service>      # Restart a service
```

### Mode

```sh
mode operator          # Operator mode (full access)
mode system            # System/diagnostic mode
mode talk              # Conversational AI mode
```

---

## 4. Automation API

### Event Bus (os-event)

```sh
os-event <event-name> [data]   # Fire a named event
# Creates: OS/var/events/<timestamp>.event
# Appends: OS/var/log/events.log
```

### Message Bus (os-msg)

```sh
os-msg <message>               # Publish message to OS/proc/os.messages
```

### Service Registry (os-service)

```sh
os-service start <name>        # Start service
os-service stop  <name>        # Stop service
os-service status <name>       # Service status
os-service-status              # All services health overview
os-service-health <name>       # Health file content
```

### Policy Engine

Policy rules in `OS/etc/aura/policy.rules`.  Each rule is:

```
on-event <event> do <action>
```

The `aura-tasks` daemon evaluates rules at `TASK_RUN_INTERVAL_HEARTBEATS`
heartbeat cycles (default: ~60 s).

---

## 5. AI Plugin API

The AI pipeline is fully extensible.  Plugins interact through three interfaces:

### 5.1 IntentEngine (ai/core/intent_engine.py)

```python
from intent_engine import IntentEngine, Intent

engine = IntentEngine()
intent = engine.classify("ping 8.8.8.8")
# intent.category = "command"
# intent.action   = "net.ping"
# intent.entities = {"host": "8.8.8.8"}
# intent.confidence = 0.95
```

To add a new intent rule, append to the `_RULES` list:

```python
("command", "myns.myaction", ("my trigger ",), "entity_slot"),
```

### 5.2 Router (ai/core/router.py)

```python
from router import Router
from intent_engine import IntentEngine

router = Router(os_root="/path/OS", aios_root="/path")
intent = IntentEngine().classify(user_input)
response = router.dispatch(intent)  # Returns str or None
```

### 5.3 Bot Plugin API (ai/core/bots.py)

To create a custom bot, subclass `BaseBot`:

```python
from bots import BaseBot
from intent_engine import Intent

class MyBot(BaseBot):
    name = "MyBot"

    def can_handle(self, intent: Intent) -> bool:
        return intent.category == "my_category"

    def handle(self, intent: Intent) -> str:
        return f"MyBot handling: {intent.raw}"
```

Register it:

```python
router.register_bot(MyBot(os_root=os_root))
```

### 5.4 Shell-Level AI Commands

Call the AI backend from shell:

```sh
python3 ai/core/ai_backend.py \
    --input "health check" \
    --os-root "$OS_ROOT" \
    --aios-root "$AIOS_HOME"
```

---

## 6. HTTP REST API

Start the server:

```sh
# HTTP (development)
OS_ROOT=/path/OS python3 OS/bin/os-httpd --port 8080 --no-auth

# HTTPS (production)
OS_ROOT=/path/OS python3 OS/bin/os-httpd --port 8443 --tls

# Generate token first
OS_ROOT=/path/OS python3 OS/bin/os-httpd --token-gen

# Generate self-signed cert
OS_ROOT=/path/OS python3 OS/bin/os-httpd --gen-cert
```

### Authentication

All endpoints (except `/api/v1/health`) require:

```
X-API-Token: <token>
```

Token is stored in `OS/etc/api.token`.

### Endpoints

#### `GET /api/v1/health`
Unauthenticated liveness probe.

**Response 200:**
```json
{"status": "ok", "time": "2026-04-03T11:00:00Z"}
```

---

#### `GET /api/v1/status`
OS state.

**Response 200:**
```json
{
  "boot_time": "1775208139",
  "kernel_pid": "5216",
  "os_version": "0.1",
  "runlevel": "3",
  "last_heartbeat": "1775208327",
  "server_time": "2026-04-03T11:00:00Z"
}
```

---

#### `GET /api/v1/services`
Service health.

**Response 200:**
```json
{"services": "os-kernel: running\naura-agents: running\n..."}
```

---

#### `GET /api/v1/processes`
Process list (`ps aux` output).

---

#### `GET /api/v1/metrics`
System resource metrics.

**Response 200:**
```json
{
  "timestamp": "2026-04-03T11:00:00Z",
  "mem_total_kb": 8000000,
  "mem_used_kb": 3500000,
  "mem_pct": 43.7,
  "disk_total_kb": 131072000,
  "disk_used_kb": 52000000,
  "disk_pct": 39,
  "uptime_raw": " 11:00:00 up 2 days,  3:14,  1 user"
}
```

---

#### `GET /api/v1/logs?source=os.log&tail=50`
Log tail.

**Query params:**
- `source` — log file name (default: `os.log`)
- `tail` — number of lines (default: 50)

---

#### `POST /api/v1/command`
Execute a shell command via os-shell.

**Request body:**
```json
{"cmd": "uptime"}
```

**Response 200:**
```json
{"cmd": "uptime", "output": " 11:00:00 up 2 days ..."}
```

---

#### `GET /api/v1/events`
Server-Sent Events stream (live `aura.log` tail).

```
data: [2026-04-03T11:00:00Z] [kernel] heartbeat ok

data: [2026-04-03T11:00:05Z] [kernel] heartbeat ok
```

---

#### `GET /ws` (WebSocket)

RFC 6455 WebSocket echo endpoint.

```
→ {"echo": "hello", "time": 1712137200.0}
```

---

## 7. Network API

All network operations go through `OS/bin/os-netconf`:

```sh
os-netconf status                     # Full status
os-netconf interfaces                 # Interface list
os-netconf wifi status|scan|connect <ssid> [pass]|disconnect
os-netconf bt   status|scan
os-netconf ip   show|set <iface> <cidr>|flush <iface>
os-netconf route show|add <dst> <gw>|del <dst>
os-netconf dns  show|set <server>
os-netconf firewall status|enable|disable|rules|add <rule>|flush
os-netconf nat  status|enable <iface>|disable
os-netconf discover                   # LAN service discovery
os-netconf save [file]                # Config snapshot
```

---

## 8. Security Model

### Threat Model

| Threat | Mitigation |
|--------|------------|
| Path traversal | `OS/lib/filesystem.py` realpath check |
| Privilege escalation | Capability model (`os-perms`) + spawn whitelist |
| API abuse | Token auth + audit logging |
| Destructive commands | `aioscpu-secure-run` denylist (AIOSCPU image) |
| Log tampering | Append-only log paths (no rm via API) |
| Runaway processes | Scheduler + heartbeat + kernel daemon |

### Audit Trail

All security-relevant operations are logged to:

| Log | Purpose |
|-----|---------|
| `var/log/syscall.log` | Every system call invocation |
| `var/log/aura.log` | Permissions (allow/deny), boot, repair |
| `var/log/os.log` | General OS operation log |
| `var/log/httpd-access.log` | HTTP request log |
| `var/log/httpd-error.log` | HTTP error log |
| `var/log/recover.log` | Recovery operations |
| `var/log/net.log` | Network configuration changes |

---

*Last updated: 2026-04-03*
