# Syscall List — AIOS-Lite

> © 2026 Christopher Betts | AIOSCPU Official | AI-generated, fully legal

---

## Overview

All system calls are dispatched through a single gate: `OS/bin/os-syscall`.
Every invocation is:

1. **Validated** — argument count and format checked
2. **Audited** — appended to `var/log/syscall.log` and `var/log/aura.log`
3. **Executed** — within the OS_ROOT jail (filesystem calls) or with
   capability check (process/system calls)
4. **Returning** — exit code 0 on success, non-zero on error

### Invocation syntax

```sh
OS_ROOT=/path/to/OS os-syscall <syscall> [args...]
```

### Audit log format

```
<epoch> <pid> <principal> <syscall> <args...>
```

Example:
```
1743695424 9812 operator read /var/log/os.log
```

---

## Complete Syscall Table

### Filesystem Syscalls

| Syscall | Arguments | Returns | Description |
|---------|-----------|---------|-------------|
| `read` | `<path>` | file content | Read file (OS_ROOT-jailed). Returns error if path escapes jail. |
| `write` | `<path> <data>` | — | Write/create file. Creates parent directories if needed. |
| `append` | `<path> <data>` | — | Append data to file. Creates file if not present. |
| `exists` | `<path>` | `true` \| `false` | Test whether path exists (file or directory). |
| `stat` | `<path>` | metadata | Returns: `isfile=`, `isdir=`, `size=`, `mtime=`. |
| `mkdir` | `<path>` | — | Create directory (recursive, `mkdir -p`). |
| `rm` | `<path>` | — | Remove file. Will not remove directories. |
| `rmdir` | `<path>` | — | Remove empty directory. |
| `ls` | `[path]` | listing | List directory (default `.`). One entry per line. |
| `cp` | `<src> <dst>` | — | Copy file within OS_ROOT. |
| `mv` | `<src> <dst>` | — | Move/rename file within OS_ROOT. |
| `chmod` | `<path> <mode>` | — | Set file permissions (octal mode). |
| `cat` | `<path>` | file content | Alias for `read`. |
| `head` | `<path> <n>` | first n lines | Read first n lines of file. |
| `tail` | `<path> <n>` | last n lines | Read last n lines of file. |
| `grep` | `<pattern> <path>` | matching lines | Search file for pattern. |
| `wc` | `<path>` | `<lines> <words> <bytes>` | Count lines/words/bytes. |

### Process Syscalls

| Syscall | Arguments | Returns | Description |
|---------|-----------|---------|-------------|
| `spawn` | `<cmd> [args...]` | output | Execute whitelisted binary. Validated against allowed-list in `etc/spawn.allow`. |
| `kill` | `<pid>` | — | Send SIGTERM to process. Requires `proc.kill` capability. |
| `kill9` | `<pid>` | — | Send SIGKILL to process. Requires `proc.kill` capability. |
| `getpid` | — | PID | Return current shell PID. |
| `ppid` | — | PPID | Return parent PID. |
| `ps` | — | process table | List AIOS-tracked processes from `var/service/*.pid`. |
| `nice` | `<pid> <priority>` | — | Renice a process (0=high, 19=low). Delegates to host OS. |

### Environment Syscalls

| Syscall | Arguments | Returns | Description |
|---------|-----------|---------|-------------|
| `getenv` | `<name>` | value | Read environment variable. Name must be alphanumeric + `_`. |
| `setenv` | `<name> <value>` | — | Set environment variable for current session. |
| `unsetenv` | `<name>` | — | Unset environment variable. |
| `printenv` | — | all vars | Print all AIOS_ and OS_ environment variables. |

### System Info Syscalls

| Syscall | Arguments | Returns | Description |
|---------|-----------|---------|-------------|
| `uptime` | — | uptime string | Host system uptime (delegates to `uptime`). |
| `sysinfo` | — | JSON object | OS state dump (runlevel, PIDs, memory, disk). |
| `meminfo` | — | memory stats | RAM usage (total, available, used, percent). |
| `diskinfo` | — | disk stats | Disk usage for OS_ROOT filesystem. |
| `cpuinfo` | — | CPU model/cores | CPU model name and core count. |
| `netinfo` | — | interface list | Network interfaces and IP addresses. |
| `hostname` | — | hostname | Current hostname. |
| `uname` | — | kernel info | Host OS uname output. |

### Logging Syscalls

| Syscall | Arguments | Returns | Description |
|---------|-----------|---------|-------------|
| `log` | `<message>` | — | Append message to `var/log/aura.log` with timestamp. |
| `log.write` | `<file> <message>` | — | Append to any log file within `var/log/`. |
| `log.read` | `<file> [n]` | log lines | Read log file, optionally last n lines. |
| `log.rotate` | `<file>` | — | Rotate log: trim to 500 lines if over 1000. |

### Memory Syscalls

| Syscall | Arguments | Returns | Description |
|---------|-----------|---------|-------------|
| `mem.set` | `<key> <value>` | — | Store key-value in symbolic memory. |
| `mem.get` | `<key>` | value | Retrieve from symbolic memory. |
| `mem.del` | `<key>` | — | Delete key from symbolic memory. |
| `mem.list` | — | key list | List all symbolic memory keys. |
| `mem.search` | `<query>` | matching keys | Substring search across all keys and values. |
| `sem.set` | `<key> <text>` | — | Store semantic memory entry. |
| `sem.search` | `<query>` | matches | Cosine-similarity search across semantic embeddings. |
| `recall` | `<query>` | combined result | Hybrid recall: context + symbolic + semantic. |

### Event Syscalls

| Syscall | Arguments | Returns | Description |
|---------|-----------|---------|-------------|
| `event.fire` | `<name> [data]` | — | Fire a named system event. |
| `event.list` | — | event names | List pending events in `var/events/`. |
| `event.read` | `<name>` | event data | Read event payload. |
| `event.clear` | `<name>` | — | Delete event file. |
| `msg.send` | `<topic> <data>` | — | Send message to event bus. |

### Service Syscalls

| Syscall | Arguments | Returns | Description |
|---------|-----------|---------|-------------|
| `service.start` | `<name>` | — | Start registered service. |
| `service.stop` | `<name>` | — | Stop running service (SIGTERM). |
| `service.status` | `<name>` | running/stopped | Check service health. |
| `service.list` | — | service list | List all registered services. |
| `service.register` | `<name> <cmd>` | — | Register a new service. |

### Network Syscalls

| Syscall | Arguments | Returns | Description |
|---------|-----------|---------|-------------|
| `net.ping` | `<host>` | latency ms | Ping a host (requires `net.ping` capability). |
| `net.dns` | `<hostname>` | IP address | DNS lookup. |
| `net.http` | `<url>` | response body | HTTP GET (requires `net.http` capability). |
| `net.iflist` | — | interface list | List network interfaces. |
| `net.route` | — | routing table | Show routing table. |

---

## Syscall Error Codes

| Code | Meaning |
|------|---------|
| `0` | Success |
| `1` | Generic error |
| `2` | Missing argument |
| `3` | Path escape denied (OS_ROOT jail violation) |
| `4` | File not found |
| `5` | Permission denied (capability check failed) |
| `6` | Process not found |
| `7` | Spawn denied (binary not in allowed-list) |
| `8` | Network error |
| `9` | Argument format error |
| `10` | Service not registered |

---

## Capability Requirements

| Syscall group | Required capability |
|---------------|-------------------|
| Filesystem (read/ls/stat/exists) | `fs.read` |
| Filesystem (write/append/mkdir/rm) | `fs.write` |
| Process (spawn) | `proc.spawn` |
| Process (kill/kill9) | `proc.kill` |
| Process (ps/getpid) | `proc.read` |
| Memory (mem.*/sem.*/recall) | `memory.*` |
| Logging | `log.write` |
| Events | `system.event` |
| Network | `net.*` |
| Services | `system.service` |

See `OS/etc/perms.d/` for per-principal capability assignments.

---

*Last updated: 2026-04-03*
