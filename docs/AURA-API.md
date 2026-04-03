# AURA Line Protocol API Reference

> © 2026 Chris Betts | AIOSCPU Official | AI-generated, fully legal

AURA communicates over **stdin/stdout** using a simple newline-delimited
text protocol. One command per line. Responses are written immediately to
stdout, terminated by the `AURA> ` prompt.

---

## Commands

### `ping`
Liveness check.

**Request:**
```
ping
```
**Response:**
```
pong
```

---

### `sysinfo`
Print system information (kernel, CPU, memory, disk, uptime, OS release).

**Request:**
```
sysinfo
```
**Response:**
Multi-line output from `aioscpu-sysinfo`. See that script for format details.

---

### `netinfo`
Print network information (interfaces, routes, DNS, ARP table, open ports).

**Request:**
```
netinfo
```
**Response:**
Multi-line output from `aioscpu-netinfo`.

---

### `remember <scope> <key>=<value>`
Store a key/value pair in persistent memory.

- `scope`: Logical namespace, e.g. `user`, `system`, `task`, `session`
- `key`: Identifier within the scope (no spaces)
- `value`: Arbitrary string value

**Request:**
```
remember user name=Alice
remember session last_cmd=sysinfo
remember system boot_mode=ai
```
**Response:**
```
OK: remembered user/name
```

---

### `recall <scope> <key>`
Retrieve the most recently stored value for a scope/key pair.

**Request:**
```
recall user name
```
**Response (found):**
```
user/name = Alice
```
**Response (not found):**
```
NOT FOUND: user/name
```

---

### `recall-all <scope>`
Retrieve all stored entries within a scope, ordered oldest-first.

**Request:**
```
recall-all user
```
**Response:**
```
Scope: user  (2 entries)
  [2026-01-15T12:00:00Z] name = Alice
  [2026-01-15T12:01:00Z] preference = dark_mode
```

---

### `run <command>`
Execute a shell command via the `aioscpu-secure-run` wrapper.

The command is subject to the denylist in `aioscpu-secure-run`.
All executions are logged to `/var/log/aioscpu-secure-run.log`.

**Request:**
```
run ls /opt/aura
run echo hello world
run cat /etc/aioscpu-release
```
**Response:**
stdout+stderr of the command, or a rejection message:
```
REJECTED: command was blocked by aioscpu-secure-run.
```

---

### `help`
Show available commands.

**Request:**
```
help
```
**Response:**
```
AURA commands:
  ping                          Liveness check
  sysinfo                       Print system information
  netinfo                       Print network information
  remember <scope> <key>=<val>  Store a memory entry
  recall <scope> <key>          Retrieve a memory entry
  recall-all <scope>            List all entries in a scope
  run <cmd>                     Execute via secure-run wrapper
  help                          Show this help
  quit                          Exit AURA
```

---

### `quit` / `exit` / `q`
Gracefully terminate the AURA agent.

**Request:**
```
quit
```
**Response:**
```
Goodbye.
```

---

## Response Format

- Responses are plain UTF-8 text, newline-terminated.
- A blank `AURA> ` prompt follows each response in interactive mode.
- Error responses begin with `ERROR:`.
- Rejection responses begin with `REJECTED:`.
- "Not found" responses begin with `NOT FOUND:`.
- Success responses begin with `OK:` (for state-changing commands).

---

## Extending AURA with an AI Model Backend

The `model_backend` key in `aura-config.json` is reserved for future
integration with a local or remote LLM. When set to a non-null value,
`aura-agent.py` will route unrecognised commands to the model backend
for natural-language processing.

Example future config:
```json
{
  "model_backend": "http://localhost:11434/api/generate",
  "model_name": "llama3"
}
```

The agent will pass the raw input line and any relevant context (recent
memories, last sysinfo snapshot) to the model and return its response.

To implement your own backend, extend `handle_command()` in `aura-agent.py`
to add an `else` branch that calls your backend API.

---

## Example Interactive Session

```
$ auractl interactive
============================================================
  AURA - AI Agent for AIOSCPU
  © 2026 Chris Betts | AIOSCPU Official | AI-generated, fully legal
  Type 'help' for available commands.  Type 'quit' to exit.
============================================================

Connecting to AURA agent...

AURA v1.0 ready. Type 'help' for commands.
AURA> ping
pong
AURA> remember user name=Alice
OK: remembered user/name
AURA> recall user name
user/name = Alice
AURA> sysinfo
============================================================
  AIOSCPU System Information
...
AURA> run uptime
 12:34:56 up 1 min,  1 user,  load average: 0.00, 0.00, 0.00
AURA> run rm -rf /
[aioscpu-secure-run] REJECTED: command matches denylist pattern.
REJECTED: command was blocked by aioscpu-secure-run.
AURA> quit
Goodbye.
```

---

## Non-Interactive (Scripted) Usage

```bash
# Single command via auractl cmd
auractl cmd "sysinfo"

# Pipe multiple commands
printf 'ping\nrecall-all user\nquit\n' | \
    python3 /opt/aura/aura-agent.py --config /opt/aura/aura-config.json
```
