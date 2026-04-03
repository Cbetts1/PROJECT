# Resource Manager Description — AIOS-Lite

> © 2026 Christopher Betts | AIOSCPU Official | AI-generated, fully legal

---

## Overview

`OS/bin/os-resource` is the AIOS-Lite resource manager. It monitors system
resources, enforces soft limits, fires warning events, and provides resource
information to the AI and kernel subsystems.

Because AIOS runs in user-space, resource enforcement is **advisory** —
the manager cannot forcibly kill processes for exceeding limits but will log
warnings, fire events, and optionally request graceful shutdown.

---

## Architecture

```
┌──────────────────────────────────────────────────────────┐
│                   os-resource                             │
│                                                          │
│  ┌─────────────┐  ┌───────────┐  ┌──────────────────┐  │
│  │ CPU Monitor │  │ RAM Mon.  │  │  Disk Monitor    │  │
│  │ /proc/stat  │  │ /proc/mem │  │  df              │  │
│  └──────┬──────┘  └─────┬─────┘  └────────┬─────────┘  │
│         │               │                  │            │
│  ┌──────▼───────────────▼──────────────────▼─────────┐  │
│  │              Threshold Checker                     │  │
│  │  compare current value vs. limit in               │  │
│  │  OS/etc/resource.limits                           │  │
│  └──────────────────────┬──────────────────────────  ┘  │
│                         │                               │
│  ┌──────────────────────▼──────────────────────────┐    │
│  │           Action Dispatcher                      │    │
│  │  • log warning to var/log/os.log                │    │
│  │  • fire resource.warning event                  │    │
│  │  • optionally notify AURA agent                 │    │
│  └─────────────────────────────────────────────────┘    │
└──────────────────────────────────────────────────────────┘
```

---

## Monitored Resources

### CPU Usage

| Metric | Source | Description |
|--------|--------|-------------|
| `cpu_pct` | `/proc/stat` (Linux) or `top` | System-wide CPU utilisation (%) |
| `cpu_user` | `/proc/stat` | User-space CPU (%) |
| `cpu_sys` | `/proc/stat` | Kernel CPU (%) |
| `load_1` | `/proc/loadavg` | 1-minute load average |
| `load_5` | `/proc/loadavg` | 5-minute load average |
| `load_15` | `/proc/loadavg` | 15-minute load average |

### Memory

| Metric | Source | Description |
|--------|--------|-------------|
| `mem_total_mb` | `/proc/meminfo` | Total RAM (MB) |
| `mem_avail_mb` | `/proc/meminfo` | Available RAM (MB) |
| `mem_used_pct` | derived | Memory usage (%) |
| `swap_used_pct` | `/proc/meminfo` | Swap usage (%) |

### Disk

| Metric | Source | Description |
|--------|--------|-------------|
| `disk_used_pct` | `df $OS_ROOT` | Disk usage of OS_ROOT filesystem (%) |
| `disk_avail_mb` | `df $OS_ROOT` | Available space (MB) |
| `inode_used_pct` | `df -i $OS_ROOT` | Inode usage (%) |

### Thermal (Samsung Galaxy S21 FE)

| Metric | Source | Description |
|--------|--------|-------------|
| `cpu_temp_c` | `/sys/class/thermal/thermal_zone*/temp` | CPU temperature (°C) |
| `battery_temp_c` | `/sys/class/power_supply/battery/temp` | Battery temperature (°C÷10) |

### Network

| Metric | Source | Description |
|--------|--------|-------------|
| `rx_bytes` | `/proc/net/dev` | Bytes received |
| `tx_bytes` | `/proc/net/dev` | Bytes transmitted |
| `net_errors` | `/proc/net/dev` | Interface error count |

---

## Resource Limits Configuration

File: `OS/etc/resource.limits`

```sh
# AIOS Resource Limits
# Format: RESOURCE=WARN_THRESHOLD[:CRITICAL_THRESHOLD]
# Percentages (%) or absolute values (MB, °C)

CPU_WARN_PCT=80
CPU_CRITICAL_PCT=95

MEM_WARN_PCT=85
MEM_CRITICAL_PCT=95

DISK_WARN_PCT=90
DISK_CRITICAL_PCT=98

THERMAL_WARN_C=65
THERMAL_CRITICAL_C=68

SWAP_WARN_PCT=70

LOAD_WARN_FACTOR=2.0      # warn if load_1 > (cores * factor)
```

---

## Threshold Actions

| Level | Action |
|-------|--------|
| **warn** | Log to `var/log/os.log`; fire `resource.warning` event |
| **critical** | Log + fire `resource.critical` event; AURA RepairBot notified |

The `resource.warning` event payload format:

```
resource=cpu
value=87
threshold=80
level=warn
timestamp=1743695424
```

---

## os-resource Commands

```sh
# Show current resource snapshot
os-resource status

# Show resource history (last n samples)
os-resource history [n]

# Watch resources in real time (updates every 5 s)
os-resource watch

# Check a single resource
os-resource check cpu
os-resource check memory
os-resource check disk
os-resource check thermal

# Set a limit at runtime (non-persistent)
os-resource set CPU_WARN_PCT 75

# Run a single collection cycle and exit
os-resource sample
```

### Example output

```
$ os-resource status
╔══════════════════════════════════════════════╗
║           AIOS Resource Status               ║
╠══════════════╦═══════════════╦═══════════════╣
║ Resource     ║  Value        ║  Status       ║
╠══════════════╬═══════════════╬═══════════════╣
║ CPU          ║  23%          ║  OK           ║
║ Memory       ║  62% (4.9 GB) ║  OK           ║
║ Disk         ║  41% (24 GB)  ║  OK           ║
║ CPU Temp     ║  42°C         ║  OK           ║
║ Load (1m)    ║  1.2          ║  OK           ║
╚══════════════╩═══════════════╩═══════════════╝
```

---

## Integration with AURA

The AURA AI agent (`aura/aura-agent.py`) subscribes to resource events:

```python
# From aura-agent.py (simplified)
if event == "resource.critical" and data["resource"] == "memory":
    # Trigger RepairBot to free memory
    router.dispatch(Intent(type="repair", detail="memory_pressure"))
```

HealthBot can query resource status directly:

```sh
aios> ask how much memory is available
# HealthBot calls os-resource check memory → returns current stats
```

---

## Polling Interval

| Mode | Interval |
|------|---------|
| Normal operation | Every 60 seconds |
| Warning state | Every 15 seconds |
| Critical state | Every 5 seconds |

Polling is done by the kernel daemon heartbeat. The interval is configurable
in `config/aios.conf`:

```sh
RESOURCE_POLL_INTERVAL=60
```

---

*Last updated: 2026-04-03*
