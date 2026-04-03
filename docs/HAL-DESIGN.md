# AIOS Hardware Abstraction Layer (HAL) Design

> © 2026 Chris Betts | AIOSCPU Official | AI-generated, fully legal

---

## Contents

1. [HAL Architecture](#1-hal-architecture)
2. [Device Categories](#2-device-categories)
3. [HAL Modules](#3-hal-modules)
4. [Resource Access Model](#4-resource-access-model)
5. [Virtual Device Layer](#5-virtual-device-layer)
6. [Android Integration Layer](#6-android-integration-layer)
7. [Power & Thermal Management](#7-power--thermal-management)
8. [Hardware Event System](#8-hardware-event-system)
9. [Security & Isolation](#9-security--isolation)

---

## 1. HAL Architecture

### 1.1 Purpose

The Hardware Abstraction Layer (HAL) is the boundary between raw hardware
(or Android hardware APIs) and all AIOS system modules.  It ensures:

- No system module ever touches hardware directly
- Hardware differences across devices are hidden behind a uniform interface
- Hardware access is auditable, permissioned, and interruptible
- Mock/simulation devices can substitute real hardware for testing

### 1.2 Layered Structure

```
┌──────────────────────────────────────────────────────────────────┐
│                   AIOS User / AI Shell Layer                      │
│   bin/aios  |  bin/aios-sys  |  OS/bin/os-shell                  │
└────────────────────────────┬─────────────────────────────────────┘
                             │ intents / syscalls
┌────────────────────────────▼─────────────────────────────────────┐
│                   AIOS Pseudo-Kernel                               │
│   OS/bin/os-kernelctl  |  OS/bin/os-syscall  |  OS/bin/os-perms  │
│   OS/bin/os-sched      |  OS/bin/os-event    |  OS/bin/os-resource│
└────────────────────────────┬─────────────────────────────────────┘
                             │ HAL requests (hal_request)
┌────────────────────────────▼─────────────────────────────────────┐
│                Hardware Abstraction Layer (HAL)                    │
│                                                                    │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐            │
│  │ hal-cpu  │ │ hal-gpu  │ │ hal-mem  │ │ hal-stor │            │
│  └──────────┘ └──────────┘ └──────────┘ └──────────┘            │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐            │
│  │ hal-pwr  │ │hal-sensor│ │ hal-radio│ │ hal-cam  │            │
│  └──────────┘ └──────────┘ └──────────┘ └──────────┘            │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐                          │
│  │ hal-disp │ │hal-input │ │ hal-usb  │                          │
│  └──────────┘ └──────────┘ └──────────┘                          │
│                                                                    │
│  hal-registry  |  hal-event-bus  |  hal-audit                    │
└────────────────────────────┬─────────────────────────────────────┘
                             │ host OS / Android API boundary
┌────────────────────────────▼─────────────────────────────────────┐
│              Host OS (Android + Termux) / Linux                   │
│   /sys  /proc  termux-api  Android Hardware Abstraction Layer     │
└──────────────────────────────────────────────────────────────────┘
```

### 1.3 Isolation Guarantee

System modules **never** reach below the HAL boundary.  The pseudo-kernel
calls only documented HAL entry points:

```
hal_request <module> <operation> [params...]
```

The HAL resolves the request to a host-OS call, an Android API call via
`termux-api`, or a virtual device — and returns a normalized response.
System modules remain unaware of which backend was used.

### 1.4 Communication Pattern: Kernel ↔ HAL

| Direction     | Mechanism                              | Transport         |
|---------------|----------------------------------------|-------------------|
| Kernel → HAL  | `hal_request <mod> <op> [params]`      | Shell pipe / IPC  |
| HAL → Kernel  | Structured JSON response               | stdout / named pipe|
| HAL → Kernel  | Hardware event notification            | `os-event` bus    |
| Kernel → HAL  | Resource grant / revoke signal         | Signal or flag file|

Response envelope:

```json
{
  "status":  "ok | error | permission_denied | unavailable",
  "module":  "hal-cpu",
  "op":      "get_freq",
  "data":    { ... },
  "ts":      1735000000
}
```

### 1.5 Safety and Permission Boundaries

| Boundary             | Enforcement                                      |
|----------------------|--------------------------------------------------|
| Caller identity      | Checked against `OS/etc/hal-perms.conf`          |
| Operation whitelist  | Each module declares allowed ops at registration |
| Thermal gate         | HAL blocks compute ops when temp ≥ threshold     |
| Power gate           | HAL blocks high-drain ops at critical battery    |
| Audit log            | Every request → `OS/var/log/hal-audit.log`       |
| Sandbox              | HAL process runs as unprivileged `aios` user     |

---

## 2. Device Categories

### 2.1 CPU and Cores

**Primary device**: Exynos 2100 / Snapdragon 888 (Samsung Galaxy S21 FE)

| Property        | Details                                            |
|-----------------|----------------------------------------------------|
| Architecture    | ARM64 (aarch64), big.LITTLE                        |
| Core layout     | 1× Cortex-X1 (prime) · 3× Cortex-A78 · 4× Cortex-A55 |
| Default affinity| Cores 1–3 (A78 big) via `LLAMA_CPU_AFFINITY="1-3"` |
| HAL module      | `hal-cpu`                                          |

Exposed operations:

```
hal_request cpu get_freq        # per-core frequency (MHz)
hal_request cpu get_load        # per-core utilization (%)
hal_request cpu set_affinity    # restrict process to core mask
hal_request cpu get_governor    # schedutil / performance / powersave
hal_request cpu set_governor    # (requires MANAGE_CPU permission)
hal_request cpu get_temp        # CPU package temperature (°C)
```

### 2.2 GPU / Neural Accelerators

| Property      | Details                                              |
|---------------|------------------------------------------------------|
| GPU           | Mali-G78 MP14 (Exynos) or Adreno 660 (Snapdragon)   |
| NPU           | Exynos neural processing unit or Hexagon DSP         |
| HAL module    | `hal-gpu`                                            |

Exposed operations:

```
hal_request gpu get_load        # GPU utilization (%)
hal_request gpu get_freq        # GPU clock (MHz)
hal_request gpu get_temp        # GPU temperature (°C)
hal_request gpu run_inference   # Submit tensor workload (future)
hal_request npu get_status      # NPU availability
```

> Note: Direct GPU/NPU programming is not available in Termux without root.
> `hal-gpu` reports metrics via `/sys/class/devfreq` where exposed and falls
> back to mock data in simulation mode.

### 2.3 Memory (RAM)

| Property    | Details                         |
|-------------|---------------------------------|
| Type        | LPDDR5 6 GB / 8 GB              |
| HAL module  | `hal-mem`                       |

Exposed operations:

```
hal_request mem get_total       # Total RAM (MB)
hal_request mem get_free        # Free RAM (MB)
hal_request mem get_used        # Used RAM (MB)
hal_request mem get_swap        # Swap usage (MB) — if available
hal_request mem get_pressure    # Memory pressure: low | medium | high
```

Source: `/proc/meminfo` (host Linux / Termux).

### 2.4 Storage

| Type          | Backend                              | HAL module    |
|---------------|--------------------------------------|---------------|
| Internal UFS  | Android `/data` via Termux home      | `hal-stor`    |
| External SD   | Mounted under `/sdcard` or `/mnt`    | `hal-stor`    |
| Virtual FS    | `OS_ROOT` jail in AIOS               | `hal-stor`    |

Exposed operations:

```
hal_request stor get_info       # Total / free / used (bytes)
hal_request stor list_mounts    # Mounted volumes
hal_request stor get_type       # internal | external | virtual
hal_request stor sync           # Flush write buffers
```

### 2.5 Battery and Power Subsystem

| Property      | Details                                  |
|---------------|------------------------------------------|
| Capacity      | 4500 mAh                                 |
| HAL module    | `hal-pwr`                                |
| Backend       | `termux-battery-status` / `/sys/class/power_supply` |

Exposed operations:

```
hal_request pwr get_level       # Charge level (%)
hal_request pwr get_status      # charging | discharging | full
hal_request pwr get_health      # good | overheat | dead | over_voltage
hal_request pwr get_temp        # Battery temperature (°C)
hal_request pwr get_voltage     # Battery voltage (mV)
hal_request pwr set_profile     # performance | balanced | saver
```

### 2.6 Sensors

| Sensor         | Android API                          | HAL module    |
|----------------|--------------------------------------|---------------|
| Accelerometer  | `termux-sensor -s android.sensor.accelerometer` | `hal-sensor` |
| Gyroscope      | `termux-sensor -s android.sensor.gyroscope`     | `hal-sensor` |
| Proximity      | `termux-sensor -s android.sensor.proximity`     | `hal-sensor` |
| Magnetometer   | `termux-sensor -s android.sensor.magnetic_field`| `hal-sensor` |
| Barometer      | `termux-sensor -s android.sensor.pressure`      | `hal-sensor` |
| Light sensor   | `termux-sensor -s android.sensor.light`         | `hal-sensor` |
| Fingerprint    | Android BiometricPrompt API          | `hal-sensor` |

Exposed operations:

```
hal_request sensor list                    # Enumerate available sensors
hal_request sensor read <sensor_id>        # Single sample
hal_request sensor subscribe <sensor_id>  # Continuous stream (events)
hal_request sensor unsubscribe <sensor_id>
```

Requires: Termux:API package installed and `termux-sensor` available.

### 2.7 Radios (WiFi, Bluetooth)

| Radio       | Backend                      | HAL module    |
|-------------|------------------------------|---------------|
| WiFi        | `termux-wifi-connectioninfo` | `hal-radio`   |
| Bluetooth   | `termux-bluetooth-*`         | `hal-radio`   |
| Cellular    | `termux-telephony-*`         | `hal-radio`   |

Exposed operations:

```
hal_request radio wifi_status           # connected | disconnected
hal_request radio wifi_info             # SSID, RSSI, IP
hal_request radio bt_status             # on | off
hal_request radio bt_scan               # List nearby devices
hal_request radio cell_info             # Carrier, signal strength
hal_request radio airplane_mode_get     # enabled | disabled
```

### 2.8 Camera and Microphone

| Device       | Backend                                   | HAL module  |
|--------------|-------------------------------------------|-------------|
| Camera       | `termux-camera-photo` / `termux-camera-info` | `hal-cam` |
| Microphone   | `termux-microphone-record`                | `hal-cam`   |

Exposed operations:

```
hal_request cam list                    # Enumerate cameras (id, facing)
hal_request cam photo <id> <path>       # Capture still image
hal_request cam info <id>               # Resolution, orientation
hal_request mic record <duration> <path># Record audio clip (WAV)
hal_request mic status                  # idle | recording
```

Requires: `CAMERA` and `RECORD_AUDIO` permissions granted in Android settings.

### 2.9 Display and Touch Input

| Device       | Backend                               | HAL module    |
|--------------|---------------------------------------|---------------|
| Display      | `/sys/class/backlight` / Android API  | `hal-disp`    |
| Touch input  | Android InputManager                  | `hal-input`   |

Exposed operations:

```
hal_request disp get_brightness         # 0–255
hal_request disp set_brightness <val>   # (requires DISPLAY permission)
hal_request disp get_resolution         # width x height
hal_request disp get_refresh_rate       # Hz
hal_request input get_touch_state       # idle | active
```

> Note: Direct touch input injection is not available without root.
> `hal-input` is informational only in unprivileged mode.

### 2.10 USB and Peripherals

| Device        | Backend                 | HAL module    |
|---------------|-------------------------|---------------|
| USB           | Android USB Host API    | `hal-usb`     |
| Audio jack    | `termux-audio-info`     | `hal-usb`     |
| OTG storage   | Android MTP / UMS       | `hal-usb`     |

Exposed operations:

```
hal_request usb list                    # Enumerate connected USB devices
hal_request usb get_state               # connected | disconnected | charging
hal_request usb audio_info              # Headset / headphone presence
hal_request usb otg_status             # OTG device attached: yes | no
```

---

## 3. HAL Modules

### 3.1 Module Structure

Each HAL module lives under `OS/lib/hal/<module-name>/` and contains:

```
OS/lib/hal/hal-cpu/
├── module.conf          # Metadata: name, version, ops, permissions
├── hal-cpu.sh           # Shell dispatcher (fast path)
├── hal_cpu.py           # Python implementation (rich ops)
└── hal-cpu-mock.sh      # Mock backend for simulation mode
```

`module.conf` example:

```ini
[module]
name        = hal-cpu
version     = 1.0.0
description = CPU core metrics and affinity control

[ops]
allowed     = get_freq get_load set_affinity get_governor get_temp

[permissions]
get_freq    = HARDWARE_READ
get_load    = HARDWARE_READ
set_affinity= MANAGE_CPU
get_governor= HARDWARE_READ
get_temp    = HARDWARE_READ
```

### 3.2 Module Registration

At boot, the HAL registry (`OS/bin/hal-registry`) discovers all modules:

```sh
# Scan OS/lib/hal/*/module.conf
# Validate schema
# Register name → entry point mapping
# Write registry to OS/run/hal/registry.json
```

Registry entry format:

```json
{
  "hal-cpu": {
    "version": "1.0.0",
    "entry":   "OS/lib/hal/hal-cpu/hal-cpu.sh",
    "ops":     ["get_freq","get_load","set_affinity","get_governor","get_temp"],
    "status":  "active"
  }
}
```

Modules may also self-register at runtime via:

```sh
hal_register <module_name> <module_conf_path>
```

### 3.3 Module Lifecycle

```
            ┌──────────┐
            │  DISCOVER │  (boot scan of OS/lib/hal/)
            └─────┬─────┘
                  │
            ┌─────▼─────┐
            │   PROBE    │  (verify backend availability)
            └─────┬─────┘
                  │ available?
         yes ─────┴───── no
          │               │
    ┌─────▼──────┐  ┌─────▼───────┐
    │   ACTIVE   │  │  SIMULATED  │  (mock backend substituted)
    └─────┬──────┘  └─────┬───────┘
          │               │
          └───────┬───────┘
                  │ error / unrecoverable
            ┌─────▼─────┐
            │  FAULTED   │  (module disabled, event emitted)
            └───────────┘
```

State transitions are recorded in `OS/run/hal/module-states.json`.

### 3.4 Error Handling and Fallback

| Failure Scenario               | HAL Behavior                                        |
|--------------------------------|-----------------------------------------------------|
| Backend command not found      | Switch to SIMULATED state; return mock data         |
| Backend returns non-zero       | Return `status: error` with `reason` field          |
| Timeout (default 3 s)          | Return `status: timeout`; increment error counter   |
| Repeated failures (≥ 3)        | Mark module FAULTED; emit `hal.module.faulted` event|
| Permission denied by Android   | Return `status: permission_denied`                  |
| Thermal limit exceeded         | Return `status: thermal_throttle`; block op         |

All failures are written to `OS/var/log/hal-audit.log` with full context.

---

## 4. Resource Access Model

### 4.1 How System Modules Request Hardware Access

System modules (AI Core, bots, kernel services) request hardware through the
pseudo-kernel's resource interface:

```sh
# Example: AI Core requesting CPU temperature
os-syscall hal_request cpu get_temp

# Example: LogBot requesting battery level
os-syscall hal_request pwr get_level
```

The syscall layer forwards the request to the HAL dispatcher after permission
checks, then returns the HAL response to the caller.

### 4.2 Permission Checks

Permissions are defined in `OS/etc/hal-perms.conf`:

```ini
[permissions]
# permission_name = granted_to_roles (comma-separated)
HARDWARE_READ   = ai_core, logbot, healthbot, repairbot, user
MANAGE_CPU      = kernel, repairbot
MANAGE_DISPLAY  = kernel, user
CAMERA          = ai_core (requires Android grant)
RECORD_AUDIO    = ai_core (requires Android grant)
RADIO_READ      = ai_core, healthbot
MANAGE_POWER    = kernel
```

Check flow:

```
caller → os-perms.check(caller, permission) → GRANTED / DENIED
                                                │
                               GRANTED ─────────▼──── HAL dispatch
                               DENIED  → return permission_denied
```

### 4.3 Priority and Scheduling

HAL requests are queued by priority level:

| Priority | Level | Users                                 |
|----------|-------|---------------------------------------|
| CRITICAL | 0     | Thermal emergency, power-off sequence |
| HIGH     | 1     | AI Core inference, kernel services    |
| NORMAL   | 2     | User commands, bots                   |
| LOW      | 3     | Background telemetry, logging         |

Priority is set via the request header:

```sh
os-syscall hal_request --priority HIGH cpu get_temp
```

If the HAL queue is saturated, LOW requests are dropped with a `status: busy`
response.  HIGH requests preempt NORMAL requests.

### 4.4 Safe Failure Modes

| Failure Mode        | System Behavior                                             |
|---------------------|-------------------------------------------------------------|
| HAL module FAULTED  | Caller receives `unavailable`; falls back to cached data    |
| Thermal throttle    | Compute requests blocked; AI Core reduces LLM thread count  |
| Battery critical    | HIGH-drain ops (camera, radio scan) blocked automatically   |
| Permission denied   | Operation rejected; incident logged; caller notified        |
| HAL daemon crash    | `os-recover` restarts HAL; in-flight requests retried once  |

---

## 5. Virtual Device Layer

### 5.1 Virtualized Hardware Interfaces

All HAL modules support a virtual backend.  When a module is in SIMULATED
state (hardware unavailable), it serves responses from a virtual device that
mirrors the real module's interface exactly.

Virtual device definitions live in `OS/lib/hal/<module>/hal-<module>-mock.sh`.

Example — virtual CPU:

```sh
# hal-cpu-mock.sh
case "$1" in
  get_freq)   echo '{"status":"ok","data":{"core0":2800,"core1":2800,"core2":2800,"core3":2800}}' ;;
  get_load)   echo '{"status":"ok","data":{"core0":42,"core1":38,"core2":35,"core3":30}}' ;;
  get_temp)   echo '{"status":"ok","data":{"temp_c":52}}' ;;
  get_governor) echo '{"status":"ok","data":{"governor":"schedutil"}}' ;;
  *)          echo '{"status":"error","reason":"unknown_op"}' ;;
esac
```

### 5.2 Mock Devices for Testing

The test harness (`tests/`) activates mock mode via an environment variable:

```sh
export HAL_MODE=mock
AIOS_HOME=$(pwd) OS_ROOT=$(pwd)/OS bash tests/unit-tests.sh
```

In mock mode:

- All HAL modules use their `-mock.sh` backends
- Responses are deterministic and fast (no real I/O)
- Injected failure scenarios can be triggered:

```sh
export HAL_MOCK_FAULT=hal-pwr   # Force hal-pwr into FAULTED state
export HAL_MOCK_TEMP=75         # Simulate thermal limit exceeded
export HAL_MOCK_BATTERY=5       # Simulate critical battery
```

### 5.3 Simulation Mode for Development

Full simulation mode activates all virtual devices and provides a rich
development environment without physical hardware:

```sh
export HAL_MODE=simulate
export HAL_DEVICE_PROFILE=samsung-s21fe   # Simulate target device profile
```

Simulation mode additionally:

- Emits synthetic sensor events on a configurable schedule
- Simulates battery drain over time
- Simulates thermal ramp-up under compute load
- Records all HAL interactions to `OS/var/log/hal-sim.log` for replay

---

## 6. Android Integration Layer

### 6.1 How AIOS Interacts with Android Hardware APIs

AIOS runs inside Termux on Android.  Direct hardware access is mediated by:

1. **Termux:API** — a companion app exposing Android APIs as shell commands
2. **`/proc` and `/sys`** — Linux kernel interfaces accessible without root
3. **`/proc/meminfo`, `/proc/cpuinfo`** — standard Linux memory/CPU info

```
AIOS HAL module
      │
      ├── /proc/cpuinfo          (CPU info — always available)
      ├── /proc/meminfo          (RAM info — always available)
      ├── /sys/class/thermal/    (temperatures — usually available)
      ├── /sys/class/power_supply/ (battery — usually available)
      │
      └── termux-api commands    (sensors, camera, radio, etc.)
              │
              └── Android API (via Termux:API companion app)
```

### 6.2 Abstraction Boundaries

The HAL module, not the caller, decides which backend to use.  Callers always
use the same `hal_request` interface regardless of whether the data comes from
`/proc`, `termux-api`, or a mock.

```
Caller: hal_request pwr get_level
         │
HAL:    1. Try /sys/class/power_supply/battery/capacity
         2. If unavailable → try termux-battery-status | jq .percentage
         3. If unavailable → return mock value + log warning
```

### 6.3 Safe Access Patterns

- HAL commands are wrapped in timeouts: `timeout 3s termux-battery-status`
- All `termux-api` calls are non-blocking; HAL returns `status: busy` on timeout
- File reads from `/proc` and `/sys` are done with `cat`; errors are caught
- No HAL module ever calls `su` or attempts privilege escalation

### 6.4 Limitations and Fallback

| Limitation                            | Fallback                                     |
|---------------------------------------|----------------------------------------------|
| Termux:API not installed              | Module switches to `/proc`/`/sys` backend or mock |
| Android permission not granted        | Return `permission_denied`; log guidance     |
| `/sys` path not present on device     | Return `unavailable`; use mock               |
| Android kills Termux in background    | `termux-wake-lock` recommended; HAL re-initializes on restart |
| Root not available                    | Read-only metrics only; write ops unsupported|

---

## 7. Power & Thermal Management

### 7.1 Power States

| State        | Description                                    | Trigger                       |
|--------------|------------------------------------------------|-------------------------------|
| `FULL`       | All subsystems active                          | Battery ≥ 50% and charging    |
| `BALANCED`   | Normal operation, mild optimization            | Battery 20–50% or discharging |
| `SAVER`      | Reduce LLM threads, disable background bots   | Battery < 20%                 |
| `CRITICAL`   | Halt LLM, preserve session, prepare shutdown   | Battery < 5%                  |
| `CHARGING`   | Elevated performance allowed                   | Charger connected              |

Power state transitions are managed by `hal-pwr` and broadcast via the event bus.

### 7.2 Thermal Throttling Behavior

| Temperature Range  | Action                                                       |
|--------------------|--------------------------------------------------------------|
| < 60°C             | Normal operation                                             |
| 60–65°C            | Reduce LLM thread count by 25%                               |
| 65–68°C            | Reduce LLM thread count by 50%; log thermal warning          |
| ≥ 68°C             | Pause LLM inference; emit `hal.thermal.limit` event          |
| ≥ 70°C             | Halt all compute ops; wait for cooldown to < 60°C            |

Thermal limit for Samsung Galaxy S21 FE: `DEVICE_THERMAL_LIMIT_C=68`
(configured in `config/aios.conf`).

Cooldown loop:

```sh
while [ "$(hal_request cpu get_temp | jq .data.temp_c)" -ge 60 ]; do
    sleep 5
done
# Resume inference
```

### 7.3 Battery Optimization Rules

| Rule                                     | Condition                  |
|------------------------------------------|----------------------------|
| Disable background telemetry polling     | Battery < 30%              |
| Reduce sensor sampling rate to 1 Hz      | Battery < 20%              |
| Disable radio scans (BT, WiFi discovery) | Battery < 15%              |
| Checkpoint AI session to disk            | Battery < 10%              |
| Halt LLM inference                       | Battery < 5%               |
| Emit `hal.power.critical` event          | Battery < 5%               |

### 7.4 AI-Aware Power Management

The AI Core (`ai/core/`) receives power state events and adapts:

| Power State  | AI Core Behavior                                        |
|--------------|---------------------------------------------------------|
| `FULL`       | Use max threads (`LLM_THREADS=4`), full context window  |
| `BALANCED`   | Use default threads, standard context                   |
| `SAVER`      | Reduce to 2 threads, shorter responses                  |
| `CRITICAL`   | Suspend inference; return cached responses only         |

Power state is injected into the AI Core via `os-event` subscription:

```sh
os-event subscribe hal.power.state_change ai-power-handler.sh
```

---

## 8. Hardware Event System

### 8.1 Event Types

| Event Name                  | Trigger                                  | Payload                    |
|-----------------------------|------------------------------------------|----------------------------|
| `hal.cpu.freq_change`       | CPU frequency scaled up/down             | `{core, old_mhz, new_mhz}` |
| `hal.cpu.thermal_warn`      | CPU temp ≥ 65°C                          | `{temp_c}`                 |
| `hal.thermal.limit`         | CPU/GPU temp ≥ thermal limit             | `{temp_c, source}`         |
| `hal.mem.pressure_high`     | Memory pressure reaches high             | `{free_mb, used_mb}`       |
| `hal.pwr.state_change`      | Power state transition                   | `{old_state, new_state}`   |
| `hal.pwr.critical`          | Battery ≤ 5%                             | `{level_pct}`              |
| `hal.pwr.charger_connect`   | Charger plugged in                       | `{voltage_mv}`             |
| `hal.pwr.charger_disconnect`| Charger unplugged                        | `{level_pct}`              |
| `hal.radio.wifi_connect`    | WiFi association succeeded               | `{ssid, rssi}`             |
| `hal.radio.wifi_disconnect` | WiFi connection lost                     | `{ssid}`                   |
| `hal.radio.bt_device`       | Bluetooth device found/connected         | `{address, name}`          |
| `hal.sensor.shake`          | Accelerometer spike above threshold      | `{magnitude}`              |
| `hal.usb.connect`           | USB device attached                      | `{type, id}`               |
| `hal.usb.disconnect`        | USB device removed                       | `{type, id}`               |
| `hal.module.faulted`        | HAL module entered FAULTED state         | `{module, reason}`         |
| `hal.module.recovered`      | HAL module recovered from FAULTED state  | `{module}`                 |

### 8.2 Event Routing

Events are emitted by HAL modules to the AIOS event bus (`OS/bin/os-event`):

```sh
# HAL module emits an event
os-event emit hal.pwr.critical '{"level_pct":4}'

# System module subscribes
os-event subscribe hal.pwr.critical OS/bin/handlers/pwr-critical-handler.sh
```

Event routing diagram:

```
HAL module
    │ os-event emit
    ▼
os-event bus (OS/run/events/)
    │
    ├──► kernel handlers (os-recover, os-sched)
    ├──► AI Core handlers (power, thermal adaptation)
    ├──► Bot handlers (HealthBot, RepairBot)
    └──► Audit logger (OS/var/log/hal-audit.log)
```

### 8.3 AI Core Awareness of Hardware Events

The AI Core subscribes to hardware events at initialization:

```sh
os-event subscribe hal.thermal.limit    ai/handlers/thermal-handler.sh
os-event subscribe hal.pwr.state_change ai/handlers/power-handler.sh
os-event subscribe hal.mem.pressure_high ai/handlers/mem-handler.sh
os-event subscribe hal.module.faulted   ai/handlers/hal-fault-handler.sh
```

Handlers adjust AI Core behavior at runtime without restarting the service.

---

## 9. Security & Isolation

### 9.1 Hardware Access Permissions

All hardware access requires a declared permission.  Permissions are defined
in `OS/etc/hal-perms.conf` and enforced by `OS/bin/os-perms`.

| Permission       | Scope                                | Default Holders            |
|------------------|--------------------------------------|----------------------------|
| `HARDWARE_READ`  | Read metrics from any HAL module     | all authenticated callers  |
| `MANAGE_CPU`     | Set CPU affinity, governor           | kernel, repairbot          |
| `MANAGE_DISPLAY` | Set brightness                       | kernel, user               |
| `CAMERA`         | Capture photos                       | ai_core (Android grant req)|
| `RECORD_AUDIO`   | Record microphone                    | ai_core (Android grant req)|
| `RADIO_READ`     | Read WiFi/BT/cellular status         | ai_core, healthbot         |
| `MANAGE_POWER`   | Set power profile                    | kernel                     |
| `SENSOR_READ`    | Read sensor values                   | ai_core, healthbot         |

Requesting a permission not held by the caller results in a
`status: permission_denied` response and an audit log entry.

### 9.2 Sandboxing Rules

- All HAL processes run as the unprivileged `aios` OS user
- HAL modules may not spawn processes with elevated privileges
- HAL modules may not write outside `OS_ROOT` (enforced by `OS/lib/filesystem.py`)
- HAL modules may not make outbound network connections
- Each `termux-api` call is wrapped with `timeout 3s` to prevent blocking
- HAL modules are loaded from `OS/lib/hal/` only — no dynamic loading from user paths

### 9.3 Secure Defaults

| Setting                          | Default Value          |
|----------------------------------|------------------------|
| HAL mode at boot                 | Read-only (`HARDWARE_READ` only) |
| Camera access                    | Disabled until explicitly granted |
| Microphone access                | Disabled until explicitly granted |
| Radio management                 | Read-only; no scan unless requested |
| Thermal limit enforcement        | Always on (`DEVICE_THERMAL_LIMIT_C=68`) |
| Mock mode in production          | Disabled (`HAL_MODE=real`) |
| Audit logging                    | Always on               |

### 9.4 Audit Logging for Hardware Access

Every HAL request is logged to `OS/var/log/hal-audit.log`:

```
2026-04-03T16:00:00Z [hal-audit] caller=ai_core op=hal_request/cpu/get_temp perm=HARDWARE_READ status=ok
2026-04-03T16:00:01Z [hal-audit] caller=repairbot op=hal_request/cpu/set_affinity perm=MANAGE_CPU status=ok data="mask=1-3"
2026-04-03T16:00:05Z [hal-audit] caller=user op=hal_request/cam/photo perm=CAMERA status=permission_denied
```

Log format:

```
<ISO8601_TIMESTAMP> [hal-audit] caller=<id> op=<module>/<operation> perm=<required_perm> status=<result> [data=<summary>]
```

Audit log is append-only within `OS_ROOT`.  Log rotation is handled by
`os-service` (daily, keep 7 days).

---

## Appendix A: HAL File Layout

```
OS/
├── bin/
│   └── hal-registry         # HAL module discovery and registration daemon
├── etc/
│   └── hal-perms.conf       # Permission definitions
├── lib/
│   └── hal/
│       ├── hal-cpu/
│       │   ├── module.conf
│       │   ├── hal-cpu.sh
│       │   ├── hal_cpu.py
│       │   └── hal-cpu-mock.sh
│       ├── hal-gpu/
│       ├── hal-mem/
│       ├── hal-stor/
│       ├── hal-pwr/
│       ├── hal-sensor/
│       ├── hal-radio/
│       ├── hal-cam/
│       ├── hal-disp/
│       ├── hal-input/
│       └── hal-usb/
├── run/
│   └── hal/
│       ├── registry.json    # Active module registry (runtime)
│       └── module-states.json
└── var/
    └── log/
        ├── hal-audit.log    # All hardware access (audit trail)
        └── hal-sim.log      # Simulation mode replay log
```

---

## Appendix B: HAL Request Quick Reference

```sh
# CPU
hal_request cpu get_freq | get_load | set_affinity | get_governor | get_temp

# GPU
hal_request gpu get_load | get_freq | get_temp

# Memory
hal_request mem get_total | get_free | get_used | get_swap | get_pressure

# Storage
hal_request stor get_info | list_mounts | get_type | sync

# Power
hal_request pwr get_level | get_status | get_health | get_temp | set_profile

# Sensors
hal_request sensor list | read <id> | subscribe <id> | unsubscribe <id>

# Radio
hal_request radio wifi_status | wifi_info | bt_status | bt_scan | cell_info

# Camera / Microphone
hal_request cam list | photo <id> <path> | info <id>
hal_request mic record <duration> <path> | status

# Display / Input
hal_request disp get_brightness | set_brightness | get_resolution | get_refresh_rate
hal_request input get_touch_state

# USB
hal_request usb list | get_state | audio_info | otg_status
```

---

*Document version 1.0.0 — AIOS-Lite HAL Design*
*Target device: Samsung Galaxy S21 FE (SM-G990B)*
*Deployment environment: Termux / Android 12–14*
