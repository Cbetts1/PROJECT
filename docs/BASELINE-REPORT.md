# AIOS Baseline Report

> Generated: 2026-04-04
> Project: AIOS-Lite v0.1

## Directory Map

```
PROJECT/
├── AIOS/                     # Legacy/placeholder directory (unused)
├── OS/                       # Virtual OS filesystem (primary runtime)
│   ├── bin/                  # OS utilities (os-shell, os-ai, os-check, etc.)
│   ├── dev/                  # Virtual device nodes (null, zero, random)
│   ├── etc/                  # Configuration files
│   │   ├── init.d/           # Service init scripts (actual implementations)
│   │   ├── rc2.d/            # Runlevel 2 symlinks (S10-banner → init.d/banner, etc.)
│   │   ├── aura/             # AURA agent and task lists
│   │   └── os-release        # OS identity file
│   ├── init.d/               # Startup helper (startup.sh)
│   ├── lib/                  # OS-level libraries
│   │   ├── aura-agents/      # Agent modules
│   │   ├── aura-bridge/      # Bridge detection and mounting
│   │   ├── aura-memory/      # Memory subsystem
│   │   ├── aura-policy/      # Policy engine
│   │   ├── aura-semantic/    # Semantic/vector engine
│   │   └── aura-tasks/       # Scheduled task modules
│   ├── mirror/               # Mount points for iOS/Android/Linux bridges
│   ├── proc/                 # Process and state information
│   │   ├── aura/             # AURA subsystem state (context, memory, semantic, bridge)
│   │   ├── os/               # OS kernel state files
│   │   ├── os.messages       # Inter-process messages
│   │   └── os.state          # Boot state file
│   ├── sbin/                 # System binaries (init)
│   ├── tmp/                  # Temporary files
│   └── var/                  # Variable data
│       ├── boot.time         # Boot timestamp
│       ├── events/           # Event storage
│       ├── log/              # Log files (os.log, aura.log, events.log)
│       ├── pkg/              # Package data
│       └── service/          # Service health files and PIDs
│
├── ai/                       # AI pipeline and LLM integration
│   ├── core/                 # Python AI modules
│   │   ├── ai_backend.py     # Main AI dispatch backend
│   │   ├── bots.py           # Bot implementations (HealthBot, LogBot, RepairBot)
│   │   ├── commands.py       # Legacy command parser
│   │   ├── fuzzy.py          # Fuzzy command matching
│   │   ├── intent_engine.py  # Intent classification
│   │   ├── llama_client.py   # LLaMA/mock inference client
│   │   └── router.py         # Intent → Bot dispatcher
│   └── llama-integration/    # LLaMA build scripts and integration
│
├── aioscpu/                  # CPU-specific optimizations
├── aura/                     # AURA library modules (legacy location)
├── bin/                      # User-facing binaries
│   ├── aios                  # AI shell REPL
│   ├── aios-heartbeat        # Heartbeat daemon
│   └── aios-sys              # Real OS shell wrapper
│
├── branding/                 # Brand assets (logos, banners)
├── build/                    # Build scripts
├── config/                   # System configuration
│   └── aios.conf             # OS-level config (device profile, LLM settings)
│
├── docs/                     # Documentation
├── etc/                      # Shell-level configuration
│   └── aios.conf             # Shell config (sourced by lib/aura-core.sh)
│
├── lib/                      # Shell library modules
│   ├── aura-core.sh          # Core library (logging, command registry, path resolver)
│   ├── aura-fs.sh            # Filesystem operations
│   ├── aura-proc.sh          # Process management
│   ├── aura-net.sh           # Network operations
│   ├── aura-typo.sh          # Typo correction
│   ├── aura-llama.sh         # LLaMA wrapper
│   └── aura-ai.sh            # AI backend wrapper
│
├── licenses/                 # License files
├── llama_model/              # LLaMA model storage (.gguf files)
├── mirror/                   # Mirror configuration
├── tests/                    # Test suite
│   └── unit-tests.sh         # 27 shell tests + 134 Python tests
│
├── tools/                    # Operator tools (created by upgrade)
└── var/                      # Variable data (top-level)
    └── log/                  # Application logs
```

## Boot Chain

The AIOS boot sequence follows this flow:

```
1. Entry Point: bash OS/init.d/startup.sh [args]
       │
       ├── Sets AIOS_HOME and OS_ROOT environment variables
       └── exec's OS/sbin/init

2. Primary Init: sh OS/sbin/init [--no-shell] [--shell=<shell>]
       │
       ├── Resolves OS_ROOT from script location
       ├── Loads config/aios.conf (device profile, features)
       ├── Creates runtime directories:
       │   └── var/log, var/service, var/events, var/pkg, proc/, mirror/, tmp/
       ├── Initializes state files (os.state, proc/os/*)
       ├── Displays boot banner
       │
       └── Starts rc2.d services in order:
           ├── S10-banner      → Displays AIOS identity banner
           ├── S20-devices     → Sets up virtual device nodes (/dev/null, etc.)
           ├── S30-aura-bridge → Initializes cross-OS bridge detection
           ├── S40-os-kernel   → Starts the OS kernel (heartbeat, service monitor)
           ├── S60-aura-agents → Starts AURA agent runtime
           └── S70-aura-tasks  → Starts AURA task scheduler

3. Shell Launch (unless --no-shell):
       └── exec sh OS/bin/os-shell  (or fallback to /bin/sh)
```

### Service Scripts

Each service in `OS/etc/rc2.d/` is a symlink to `OS/etc/init.d/<service>` and supports:
- `start` — Start the service
- `stop` — Stop the service
- `status` — Report service status (some services)

Services write health status to `OS/var/service/<name>.health`.

## Config Architecture

### config/aios.conf (OS-level)
- **Purpose**: Device profile, hardware settings, feature flags
- **Sourced by**: `OS/sbin/init`, boot services
- **Key settings**:
  - `AIOS_NAME`, `AIOS_VERSION`, `AIOS_VENDOR` — Identity
  - `LLAMA_MODEL_DIR`, `LLAMA_CPU_AFFINITY` — LLM settings
  - `DEVICE_RAM_GB`, `DEVICE_THERMAL_LIMIT_C`, `DEVICE_PROFILE` — Hardware profile
  - `DEFAULT_SHELL`, `AURA_DEFAULT_MODE`, `AURA_CONTEXT_WINDOW` — Shell settings
  - `ENABLE_LLM`, `ENABLE_BRIDGE`, `ENABLE_AGENTS`, `ENABLE_POLICY` — Feature flags

### etc/aios.conf (Shell-level)
- **Purpose**: Shell/REPL configuration, AI backend settings
- **Sourced by**: `lib/aura-core.sh`
- **Key settings**:
  - `OS_ROOT` — Filesystem jail root
  - `REAL_SHELL` — Real OS shell for `sys` command
  - `AI_BACKEND` — `mock` or `llama`
  - `LLAMA_MODEL_PATH`, `LLAMA_CTX`, `LLAMA_THREADS` — LLaMA settings
  - `AIOS_LOG_FILE`, `HEARTBEAT_LOG_FILE` — Log paths
  - `HEARTBEAT_INTERVAL_SEC`, `HEARTBEAT_TARGETS` — Heartbeat settings

## AI Pipeline

```
User Input
    │
    ▼
┌─────────────────────────────────────────────────────────────┐
│                     ai_backend.py                           │
│                                                             │
│  1. IntentEngine.classify(text) → Intent                    │
│     - Pattern matching against rule tables                  │
│     - Categories: command, chat, health, log, repair,       │
│                   system, process, network, memory, ai      │
│     - Extracts entities (path, host, pid, etc.)             │
│     - Falls back to 'chat' with confidence=0.5              │
│                                                             │
│  2. Router.dispatch(intent) → response                      │
│     - Iterates through registered bots                      │
│     - First bot where can_handle() returns True wins        │
│     - Bot order: RepairBot > HealthBot > LogBot             │
│                                                             │
│  3. Fallback (if no bot matches):                           │
│     - parse_natural_language() → CommandPlan                │
│     - If command == "chat": run_mock() (built-in responses) │
│     - Else: run_system_command() via bin/aios-sys           │
└─────────────────────────────────────────────────────────────┘
    │
    ▼
Response Output (stdout)
```

### Bots

| Bot | Category | Actions | Description |
|-----|----------|---------|-------------|
| HealthBot | health, system | check, status, uptime, disk, services | System health and status |
| LogBot | log | read, write | Log inspection and writing |
| RepairBot | repair | self-repair, reinstall | Self-repair and recovery |

### Adding New Bots

1. Create a class extending `BaseBot` in `ai/core/bots.py`
2. Implement `can_handle(intent)` and `handle(intent)`
3. Register in `Router._init_bots()` (priority order matters)

### Intent Categories

| Category | Actions | Description |
|----------|---------|-------------|
| command | fs.ls, fs.cat, fs.mkdir, fs.rm | Filesystem operations |
| command | proc.ps, proc.kill | Process operations |
| command | net.ping, net.ifconfig, net.netconf | Network operations |
| health | check, status | Health queries |
| repair | self-repair, reinstall | Repair operations |
| log | read, write | Log operations |
| memory | mem.set, mem.get, sem.set, sem.search | Memory operations |
| system | uptime, disk, reboot, shutdown, services | System operations |
| ai | ask | AI queries |
| chat | ask | Fallback for unmatched input |

## Tool Inventory (OS/bin/)

| Tool | Description |
|------|-------------|
| os-shell | Confined AI shell (default login shell) |
| os-real-shell | Full OS shell access |
| os-ai | AI backend CLI wrapper |
| os-bridge | Cross-OS bridge management |
| os-check | System health check |
| os-event | Event emission and logging |
| os-health-wrapper | Health check wrapper |
| os-httpd | Simple HTTP server |
| os-info | System information |
| os-install | Installation helper |
| os-kernelctl | Kernel control interface |
| os-log | Log management |
| os-login | Login handler |
| os-mirror | Filesystem mirroring |
| os-msg | Message passing |
| os-netconf | Network configuration |
| os-perms | Permission management |
| os-ps | Process listing |
| os-recover | Recovery mode |
| os-resource | Resource monitoring |
| os-sched | Scheduler interface |
| os-selftest | Self-test suite |
| os-service | Service management |
| os-service-health | Service health reporting |
| os-service-status | Service status reporting |
| os-state | State management |
| os-syscall | Syscall interface |
| sysinfo | System information |
| busybox, cat, echo, ls, mkdir, ps, reboot, sh, shutdown, sleep, uname | Standard utilities |

## Health Status

### Tests
- **Shell tests**: 27 passing
- **Python tests**: 134 passing
- **Total**: 161 tests, all passing

### Known Gaps

1. **LLM Subsystem Service**: No dedicated S*-aura-llm service to start/check LLM availability
2. **Boot Complete Timestamp**: `os.state` lacks a `last_boot_complete` field
3. **Empty rc2.d Check**: `OS/sbin/init` doesn't warn if no S* scripts exist
4. **Executable Validation**: `OS/init.d/startup.sh` doesn't verify `sbin/init` is executable

### Coverage

- Core boot chain: ✓ Tested via unit tests
- Filesystem operations: ✓ Comprehensive tests
- AI pipeline: ✓ Full coverage of bots, router, intent engine
- Fuzzy matching: ✓ Tested
- Shell libraries: ✓ Core functions tested

## Recommendations

1. Add `S50-aura-llm` service for LLM subsystem
2. Update `os.state` with `last_boot_complete` timestamp
3. Add validation in init scripts
4. Create operator tools for health checks and system audits
5. Document the AI protocol for extension
