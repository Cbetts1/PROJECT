# AIOS-Lite — Instruction Manual

> © 2026 Christopher Betts | AIOSCPU Official
> *Created and developed by Christopher Betts. All code was generated or refined using AI tools under the creator's direction.*

---

## Table of Contents

1. [What is AIOS-Lite?](#1-what-is-aios-lite)
2. [How It Works](#2-how-it-works)
3. [Installation](#3-installation)
4. [Operation](#4-operation)
5. [Updating](#5-updating)
6. [Repair and Recovery](#6-repair-and-recovery)
7. [Extending the System](#7-extending-the-system)
8. [Troubleshooting](#8-troubleshooting)
9. [Glossary](#9-glossary)

---

## 1. What is AIOS-Lite?

AIOS-Lite is a **portable, AI-augmented operating system** that runs on top of any POSIX host environment. It is not a full OS in the traditional sense — it does not contain a kernel or device drivers. Instead, it provides a complete **OS-like environment in userspace**: its own process model, service registry, scheduler, permissions system, memory system, and AI cognitive layer (AURA).

**Key characteristics:**

- **Portable**: Runs from any directory on any Unix-like system. No root required.
- **AI-native**: Every part of the system can be queried and controlled through natural language using AURA.
- **Cross-device**: A built-in bridge layer connects to iOS, Android, and remote Linux/macOS systems.
- **Self-contained**: All state, logs, and data live inside `$OS_ROOT` — uninstalling is as simple as deleting the directory.
- **Extensible**: Drop a shell script into `OS/lib/aura-mods/` and it becomes part of the OS.

### System Layers

```
+--------------------------------------+
|         You (the operator)           |
|    natural language / shell cmds     |
+--------------------------------------+
|         AI Shell (os-shell)          |
|    interprets, responds, executes    |
+--------------------------------------+
|         AURA (AI cognitive layer)    |
|    intent -> routing -> LLM/bots     |
+--------------------------------------+
|         OS Services Layer            |
|    logging, events, health, state    |
+--------------------------------------+
|         Pseudo-Kernel                |
|    scheduler, perms, svc registry    |
+--------------------------------------+
|         Bridge / Mirror Layer        |
|    iOS . Android . SSH               |
+--------------------------------------+
|         Your Host OS                 |
|    Android/Termux . Linux . macOS    |
+--------------------------------------+
```

---

## 2. How It Works

### 2.1 Boot

When you run `sh OS/sbin/init`, the boot sequence proceeds in phases:

1. **Bootstrap** - the environment is set up, `$OS_ROOT` is fixed, and `lib/aura-core.sh` is sourced.
2. **Early services** - the OS identity is written, the banner is printed, and the state is set to `booting`.
3. **Subsystem init** - the log system, event bus, message bus, and service health daemon start.
4. **Kernel services** - the pseudo-kernel, AURA bridge, LLM layer, memory systems, policy engine, and agents start.
5. **Shell ready** - the state becomes `running` and `os-shell` is launched.

### 2.2 The AI Shell

`os-shell` is the main interface. It accepts both OS commands and natural language. When you type something:

1. The **IntentEngine** classifies it (is it a memory operation? a service query? a bridge command? general chat?).
2. The **Router** dispatches it to the right handler (HealthBot, LogBot, RepairBot, command handler, or LLM).
3. The **response** is displayed and, if relevant, stored in the context window memory.

### 2.3 AURA Memory

AURA has three memory layers:

| Layer | What it stores | How to use |
|---|---|---|
| **Context window** | Last 50 interactions | Automatic |
| **Symbolic memory** | Named key-value facts | `mem.set key value` |
| **Semantic memory** | Embedding-indexed text | `sem.set key value` |

All three combine in **hybrid recall**: `recall "some topic"` searches all layers at once.

### 2.4 The Bridge

The bridge layer (`OS/lib/aura-bridge/`) connects AIOS-Lite to other devices:

- **iOS bridge**: uses `libimobiledevice` and `ifuse` to mount iPhone/iPad filesystems.
- **Android bridge**: uses `adb` to list and mirror Android device storage.
- **SSH bridge**: uses `ssh` and `sshfs` to mount remote Linux/macOS filesystems.

After mounting, the device's files appear inside `$OS_ROOT/mirror/<type>/`.

### 2.5 Services

Services are long-running background processes managed by the service registry. Each service has a PID file in `var/run/`, a health file in `var/service/`, and a config in `var/service/`. The service registry is controlled with `os-service`.

---

## 3. Installation

### 3.1 Minimum Requirements

| Requirement | Minimum |
|---|---|
| POSIX shell | `sh`, `bash`, or `dash` |
| Core utilities | `awk`, `grep`, `sed`, `cksum`, `date` |
| Python | 3.8+ (for AI Core) |
| RAM | 256 MB (without LLM); 4 GB+ (with 7B model) |
| Storage | 50 MB (without model); 3-8 GB (with GGUF model) |

### 3.2 Quick Install (Android/Termux)

```sh
pkg update && pkg upgrade -y
pkg install git python openssh android-tools libimobiledevice
git clone https://github.com/Cbetts1/PROJECT.git
cd PROJECT/OS
export OS_ROOT="$(pwd)"
export PATH="$OS_ROOT/bin:$OS_ROOT/sbin:$PATH"
sh sbin/init
```

### 3.3 Quick Install (Linux)

```sh
sudo apt-get install -y git python3 openssh-client android-tools-adb libimobiledevice-utils
git clone https://github.com/Cbetts1/PROJECT.git
cd PROJECT/OS
export OS_ROOT="$(pwd)"
sh sbin/init
```

### 3.4 Making the Environment Persistent

Add to your shell profile (`~/.bashrc`, `~/.zshrc`, or Termux `~/.bash_profile`):

```sh
export AIOS_HOME="$HOME/PROJECT"
export OS_ROOT="$AIOS_HOME/OS"
export PATH="$OS_ROOT/bin:$OS_ROOT/sbin:$PATH"
alias aios="sh $OS_ROOT/sbin/init"
alias aios-shell="os-shell"
```

Then reload: `source ~/.bashrc`

### 3.5 Adding an LLM

```sh
mkdir -p "$OS_ROOT/../llama_model"
# Place any GGUF model file there (2-8 GB depending on size)
# Then build llama.cpp:
bash "$OS_ROOT/../build/build.sh" --target hosted
```

---

## 4. Operation

### 4.1 Starting the OS

```sh
# Full boot (recommended):
sh $OS_ROOT/sbin/init

# AI shell only (if OS already booted):
os-shell

# OS system shell (lower-level):
bin/aios-sys
```

### 4.2 AI Shell Commands

#### General

| Command | Action |
|---|---|
| `help` | Print all available commands |
| `status` | Full OS state dump |
| `services` | Service health table |
| `exit` / `quit` | Exit the shell |

#### AI Queries

| Command | Action |
|---|---|
| `ask <text>` | Ask AURA a question |
| `mode talk` | Enter conversational mode |
| `mode operator` | Enter operator (command) mode |
| `mode system` | Enter system administration mode |

#### Memory

| Command | Action |
|---|---|
| `mem.set <key> <value>` | Store a fact |
| `mem.get <key>` | Retrieve a fact |
| `mem.delete <key>` | Delete a fact |
| `sem.set <key> <value>` | Store semantic memory |
| `sem.search <query>` | Search semantic memory |
| `recall <query>` | Hybrid recall across all memory |

#### Bridge and Mirror

| Command | Action |
|---|---|
| `bridge.detect` | Detect connected devices |
| `mirror.mount ios` | Mount iOS device |
| `mirror.mount android` | Mount Android device |
| `mirror.mount ssh <host>` | Mount remote host via SSH |
| `mirror.ls <type>` | List files on mounted device |
| `mirror.unmount <type>` | Unmount device |

#### System Administration

| Command | Action |
|---|---|
| `os-info` | Show OS identity and capabilities |
| `os-ps` | List running processes |
| `os-log <message>` | Write to system log |
| `os-event fire <name>` | Fire a system event |
| `os-service list` | List all services |
| `os-service start <name>` | Start a service |
| `os-service stop <name>` | Stop a service |
| `os-kernelctl status` | Pseudo-kernel status |
| `os-resource status` | Resource usage summary |
| `os-perms list <svc>` | Show service permissions |
| `os-netconf wifi status` | WiFi status |
| `os-recover` | Run self-repair |

### 4.3 Dual Shell Mode

AIOS-Lite ships with two shell binaries:

- **`bin/aios`** - AI-first shell. Natural language primary, OS commands secondary.
- **`bin/aios-sys`** - System shell. OS commands primary, AI secondary.

Both connect to the same underlying OS and memory systems.

### 4.4 Service Management

```sh
os-service list
os-service start aura-bridge
os-service stop aura-llm
os-service-health
os-service restart aura-agents
```

### 4.5 Logging

All logs go to `$OS_ROOT/var/log/aios.log`. Logs are auto-rotated at 1000 lines.

```sh
os-log "my message"
tail -20 $OS_ROOT/var/log/aios.log
```

---

## 5. Updating

### 5.1 Update the Code

```sh
cd $AIOS_HOME
git pull origin main
```

After pulling: if `sbin/init` or `lib/aura-core.sh` changed, restart the OS.  
Python changes in `ai/core/` take effect immediately on next query.

### 5.2 Update the LLM Model

```sh
rm $OS_ROOT/../llama_model/*.gguf
# Download new model and place in llama_model/
```

### 5.3 Version Check

```sh
os-info
cat $OS_ROOT/etc/os-release
```

---

## 6. Repair and Recovery

### 6.1 Automatic Self-Repair

```sh
os-recover
```

`os-recover` checks and repairs: missing directories, stopped services, broken log permissions, missing `os-release`, and Python import errors.

### 6.2 Manual Recovery

**OS will not start:**
```sh
sh -n lib/aura-core.sh          # Check for syntax errors
OS_RUNLEVEL=1 sh OS/sbin/init   # Single-user mode
```

**Service will not start:**
```sh
os-service status <name>
os-service restart <name>
```

**Bridge mount stuck:**
```sh
os-mirror unmount ios
fusermount -u $OS_ROOT/mirror/ios 2>/dev/null || umount $OS_ROOT/mirror/ios
```

### 6.3 Full State Reset

```sh
os-kernelctl halt
rm -rf $OS_ROOT/var/run/*.pid
rm -rf $OS_ROOT/var/service/*.health
rm -rf $OS_ROOT/proc/os $OS_ROOT/proc/os.state
sh $OS_ROOT/sbin/init
```

---

## 7. Extending the System

### 7.1 Writing a Plugin

Create a file in `OS/lib/aura-mods/my-plugin.mod`:

```sh
#!/bin/sh
PLUGIN_NAME="my-plugin"
PLUGIN_VERSION="1.0"

plugin_init() {
    os-log "my-plugin: loaded"
}

cmd_myplugin() {
    echo "Hello from my plugin!"
}

plugin_init
```

Add `my-plugin` to `OS/etc/aura/modules`.

### 7.2 Adding a Service

1. Create `OS/etc/init.d/my-service` with `start` and `stop` functions.
2. Run `os-service register my-service $OS_ROOT/etc/init.d/my-service`.
3. Add a symlink in `OS/etc/rc2.d/` for auto-start.

### 7.3 Writing an Event Handler

```sh
os-event listen system.startup my_startup_handler

my_startup_handler() {
    os-log "System started"
}
```

---

## 8. Troubleshooting

**`os-shell` command not found**  
`$OS_ROOT/bin` is not in PATH. Fix: `export PATH="$OS_ROOT/bin:$OS_ROOT/sbin:$PATH"`

**`ask` returns rule-based response only**  
No GGUF model file in `llama_model/`, or `llama-cli` not installed.

**`bridge.detect` finds no devices**  
ADB not installed, or device not in USB debugging mode. Run `adb devices` to diagnose.

**`os-mirror mount ssh` hangs**  
SSH host unreachable or `sshfs` not installed. Run `ssh <user>@<host> echo ok` to test.

**High CPU from llama.cpp**  
Set `LLAMA_THREADS=3` and `LLAMA_CPU_AFFINITY=1-3` in `config/llama-settings.conf`.

**Services not starting at boot**  
Check symlinks in `rc2.d/`, then run `os-recover`.

---

## 9. Glossary

| Term | Definition |
|---|---|
| **AIOS-Lite** | AI-Augmented Portable Operating System, Lite edition |
| **AIOSCPU** | The x86-64 disk image variant |
| **AURA** | Autonomous Unified Resource Agent - the AI cognitive layer |
| **OS_ROOT** | Root directory of the AIOS-Lite environment (`PROJECT/OS`) |
| **AIOS_HOME** | Parent directory of the repository clone |
| **Pseudo-kernel** | Daemons that perform kernel-like functions in userspace |
| **Bridge** | Subsystem connecting AIOS-Lite to external devices |
| **Mirror** | External device filesystem mounted under `$OS_ROOT/mirror/` |
| **GGUF** | File format for quantised LLaMA models |
| **llama.cpp** | Open-source C++ inference engine for local LLaMA models |
| **IntentEngine** | Classifies user input into intent categories |
| **Router** | Dispatches intents to the appropriate handler |
| **Bot** | Specialised handler (HealthBot, LogBot, RepairBot) |
| **Service registry** | Database of registered services managed by `os-service` |
| **Runlevel** | Integer (0-3) describing current OS operational state |
| **Syscall** | Standardised call to the pseudo-kernel via `os-syscall` |
| **Plugin** | Shell script in `OS/lib/aura-mods/` extending the OS |
| **Symbolic memory** | Key-value memory accessed with `mem.set` / `mem.get` |
| **Semantic memory** | Embedding-indexed memory for similarity search |
| **Hybrid recall** | Simultaneous search across all memory layers |
| **Context window** | Rolling 50-line file of recent interactions |
| **os-recover** | Self-repair command for common subsystem failures |
| **ADB** | Android Debug Bridge for USB communication with Android |
| **libimobiledevice** | Library for communicating with iOS devices |
| **ifuse** | FUSE driver for mounting iOS device filesystems |
| **sshfs** | FUSE driver for mounting remote filesystems over SSH |
| **heartbeat** | Daemon that periodically checks all services |
| **Event bus** | System for firing and consuming named events |
| **Message bus** | IPC system for messages between OS components |

---

*End of Instruction Manual*

> (c) 2026 Christopher Betts | AIOS-Lite v0.2 | https://github.com/Cbetts1/PROJECT
