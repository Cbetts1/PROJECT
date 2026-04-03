# Service Registry — AIOS-Lite

> © 2026 Christopher Betts | AIOSCPU Official | AI-generated, fully legal

---

## Overview

The AIOS-Lite service registry tracks all background services, manages their
lifecycle, and provides health monitoring. It is implemented by `OS/bin/os-service`
and `OS/bin/os-service-status`.

---

## Service Registry Architecture

```
┌─────────────────────────────────────────────────────────┐
│                  Service Registry                        │
│                                                         │
│  OS/etc/init.d/     — service scripts (start/stop/status│
│  OS/etc/rc2.d/      — runlevel 2 symlinks (S##-name)    │
│  OS/var/service/    — runtime state (PID + health files) │
│  OS/proc/os.manifest— component manifest                │
│                                                         │
│  os-service     — lifecycle control (start/stop/restart) │
│  os-service-status — health overview dashboard          │
│  os-service-health — health check wrapper               │
└─────────────────────────────────────────────────────────┘
```

---

## Registered Services

### Boot-time Services (rc2.d)

| Service name | Script | Start order | Description |
|-------------|--------|-------------|-------------|
| `banner` | `S10-banner` | 10 | Print AIOS boot banner |
| `devices` | `S20-devices` | 20 | Detect connected devices |
| `aura-bridge` | `S30-aura-bridge` | 30 | Cross-OS bridge initialisation |
| `os-kernel` | `S40-os-kernel` | 40 | Kernel daemon and heartbeat |
| `aura-agents` | `S60-aura-agents` | 60 | Background AI agents |
| `aura-tasks` | `S70-aura-tasks` | 70 | Scheduled task runner |

### Runtime Services

| Service name | Binary | Description | Restart policy |
|-------------|--------|-------------|----------------|
| `kernel` | `OS/etc/init.d/os-kernel` | Kernel heartbeat daemon | always |
| `os-httpd` | `OS/bin/os-httpd` | HTTP REST / WebSocket server | on-failure |
| `aura-agent` | `aura/aura-agent.py` | AURA AI agent daemon | always |
| `health-monitor` | `OS/bin/os-service-health` | Health polling service | always |
| `bridge-ios` | `OS/lib/aura-bridge/ios.mod` | iOS device bridge | on-failure |
| `bridge-android` | `OS/lib/aura-bridge/android.mod` | Android ADB bridge | on-failure |
| `bridge-linux` | `OS/lib/aura-bridge/linux.mod` | Linux/SSH bridge | on-failure |
| `net-monitor` | `OS/bin/os-netconf` | Network configuration monitor | on-failure |

---

## Service Definition Format

Each service is defined as an init.d script in `OS/etc/init.d/`:

```sh
#!/bin/sh
# Service: os-httpd
# Description: AIOS HTTP REST and WebSocket server
# Default-Start: 2
# Default-Stop: 0 1 6
# Required-Start: os-kernel
# Required-Stop:

SERVICE_NAME="os-httpd"
SERVICE_CMD="python3 $OS_ROOT/bin/os-httpd"
SERVICE_PID="$OS_ROOT/var/service/os-httpd.pid"
SERVICE_LOG="$OS_ROOT/var/log/os-httpd.log"
RESTART_POLICY="on-failure"
MAX_RESTARTS=5

start() {
    echo "[os-httpd] Starting..."
    $SERVICE_CMD >> "$SERVICE_LOG" 2>&1 &
    echo $! > "$SERVICE_PID"
    echo "status=running" > "$OS_ROOT/var/service/os-httpd.health"
    echo "[os-httpd] Started (PID=$(cat $SERVICE_PID))"
}

stop() {
    pid=$(cat "$SERVICE_PID" 2>/dev/null)
    [ -n "$pid" ] && kill "$pid" 2>/dev/null
    rm -f "$SERVICE_PID"
    echo "status=stopped" > "$OS_ROOT/var/service/os-httpd.health"
    echo "[os-httpd] Stopped"
}

status() {
    pid=$(cat "$SERVICE_PID" 2>/dev/null)
    if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
        echo "os-httpd: RUNNING (PID=$pid)"
    else
        echo "os-httpd: STOPPED"
    fi
}

case "$1" in
    start)   start   ;;
    stop)    stop    ;;
    restart) stop; start ;;
    status)  status  ;;
    *) echo "Usage: $0 {start|stop|restart|status}"; exit 1 ;;
esac
```

---

## Health File Format

Runtime health state is stored in `OS/var/service/<name>.health`:

```
status=running
started=1743695424
pid=12345
cmd=python3 /home/user/PROJECT/OS/bin/os-httpd
restarts=0
restart_policy=on-failure
max_restarts=5
last_check=1743695454
```

---

## os-service Commands

```sh
# Lifecycle
os-service start   <name>      # Start a service
os-service stop    <name>      # Stop a service
os-service restart <name>      # Restart a service
os-service reload  <name>      # Send SIGHUP (reload config)

# Status
os-service status  <name>      # Health of one service
os-service list                # List all registered services
os-service-status              # Full dashboard of all services

# Registration
os-service register <name> <cmd>    # Register a new service
os-service unregister <name>        # Remove a service

# Startup control
os-service enable  <name>      # Enable service at boot
os-service disable <name>      # Disable service at boot
```

### Example dashboard

```
$ os-service-status

╔══════════════════════════════════════════════════════════╗
║               AIOS Service Status                        ║
╠══════════════════╦═══════════╦═══════╦═══════════════════╣
║ Service          ║ Status    ║ PID   ║ Uptime            ║
╠══════════════════╬═══════════╬═══════╬═══════════════════╣
║ kernel           ║ RUNNING   ║ 12345 ║ 2h 14m            ║
║ os-httpd         ║ RUNNING   ║ 12400 ║ 2h 13m            ║
║ aura-agent       ║ RUNNING   ║ 12410 ║ 2h 13m            ║
║ health-monitor   ║ RUNNING   ║ 12450 ║ 2h 13m            ║
║ bridge-ios       ║ STOPPED   ║  —    ║  —                ║
║ bridge-android   ║ STOPPED   ║  —    ║  —                ║
║ bridge-linux     ║ STOPPED   ║  —    ║  —                ║
║ net-monitor      ║ RUNNING   ║ 12460 ║ 2h 13m            ║
╚══════════════════╩═══════════╩═══════╩═══════════════════╝
```

---

## Service Dependency Resolution

Service dependencies are declared in init.d scripts with `Required-Start:`.
`os-service start` validates dependencies before starting:

```
os-service start os-httpd
  → requires: os-kernel
  → check: os-kernel RUNNING ✓
  → start os-httpd
```

If a dependency is not running, `os-service` starts it first (up to
`MAX_DEPENDENCY_DEPTH=3` levels).

---

## Auto-Restart Behaviour

The kernel heartbeat polls `var/service/*.pid` every 30 seconds. If a
service PID is dead and its restart policy is not `never`:

| Policy | Action |
|--------|--------|
| `always` | Restart immediately |
| `on-failure` | Restart if exit code ≠ 0 |
| `never` | Leave stopped; fire `service.stopped` event |

`max_restarts` limits the number of automatic restarts. After the limit:
- Health file updated: `status=failed`
- Event `service.failed` fired
- AURA RepairBot notified

---

*Last updated: 2026-04-03*
