# AIOS Service Lifecycle Model

This document describes how services are managed in AIOS-Lite.

## Overview

AIOS uses a traditional init.d/rc2.d service model:

- **init.d scripts** (`OS/etc/init.d/`) — Service implementations
- **rc2.d symlinks** (`OS/etc/rc2.d/`) — Service startup order
- **Health files** (`OS/var/service/*.health`) — Service health status
- **PID files** (`OS/var/service/*.pid`) — Running service PIDs

## Service States

| State | Description |
|-------|-------------|
| `running` | Service is active and healthy |
| `stopped` | Service is not running |
| `dead` | Service has crashed (PID file exists but process gone) |
| `error` | Service encountered an error |

## Service Management

### Using service-ctl.sh

The primary tool for managing services:

```bash
# List all services
bash tools/service-ctl.sh list

# Check service status
bash tools/service-ctl.sh status os-kernel

# Start/stop/restart
bash tools/service-ctl.sh start banner
bash tools/service-ctl.sh stop os-kernel
bash tools/service-ctl.sh restart aura-agents

# Enable/disable (manage symlinks)
bash tools/service-ctl.sh enable aura-llm
bash tools/service-ctl.sh disable aura-tasks
```

### Using os-svc (from OS shell)

```bash
os-svc list
os-svc status os-kernel
os-svc restart aura-agents
```

## Service Script Structure

Each service in `OS/etc/init.d/` follows this pattern:

```bash
#!/bin/sh

OS_ROOT="${OS_ROOT:-/}"
HEALTH="$OS_ROOT/var/service/myservice.health"
PID_FILE="$OS_ROOT/var/service/myservice.pid"

health() { 
    mkdir -p "$(dirname "$HEALTH")"
    echo "$1" > "$HEALTH"
}

case "$1" in
    start)
        # Start the service
        echo "Starting myservice..."
        health "status=ok"
        ;;
    stop)
        # Stop the service
        echo "Stopping myservice..."
        health "status=stopped"
        ;;
    status)
        # Report current status
        if [ -f "$HEALTH" ]; then
            cat "$HEALTH"
        else
            echo "status=unknown"
        fi
        ;;
    *)
        echo "Usage: myservice {start|stop|status}"
        exit 1
        ;;
esac
```

## Current Services

| Service | Order | Description |
|---------|-------|-------------|
| S10-banner | 10 | Display system banner |
| S20-devices | 20 | Device initialization |
| S30-aura-bridge | 30 | Cross-OS bridge |
| S40-os-kernel | 40 | Kernel daemon |
| S50-aura-llm | 50 | LLM subsystem |
| S60-aura-agents | 60 | Agent runtime |
| S70-aura-tasks | 70 | Task scheduler |

## Boot Sequence

1. `OS/sbin/init` starts
2. Creates runtime directories
3. Loads configuration
4. Iterates `OS/etc/rc2.d/S*` in numerical order
5. Calls each script with `start` argument
6. Records boot completion

## Health Monitoring

The os-kernel service monitors other services:

1. Reads PID files from `var/service/`
2. Checks if processes are alive
3. Updates health files
4. Emits events for dead services

## Adding a New Service

1. Create script in `OS/etc/init.d/`:
   ```bash
   touch OS/etc/init.d/myservice
   chmod +x OS/etc/init.d/myservice
   # Edit to add start/stop/status logic
   ```

2. Enable the service:
   ```bash
   bash tools/service-ctl.sh enable myservice
   ```

3. Start the service:
   ```bash
   bash tools/service-ctl.sh start myservice
   ```

## Log Locations

- Service actions: `OS/var/log/service.log`
- Service-specific logs: `OS/var/log/<service>.log`
- Boot log: `OS/var/boot.time`

## Troubleshooting

### Service won't start

Check the init.d script exists and is executable:

```bash
ls -la OS/etc/init.d/myservice
chmod +x OS/etc/init.d/myservice
```

### Service shows as "dead"

The process crashed. Check logs and restart:

```bash
cat OS/var/log/os.log | tail -50
bash tools/service-ctl.sh restart myservice
```

### Service not in list

Ensure it has an rc2.d symlink:

```bash
bash tools/service-ctl.sh enable myservice
```
