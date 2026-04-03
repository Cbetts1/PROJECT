# AURA — Autonomous Unified Resource Agent

> © 2026 Chris Betts | AIOSCPU Official | AI-generated, fully legal

AURA is the built-in AI agent for [AIOSCPU](https://github.com/Cbetts1/PROJECT).
It provides a structured, audited interface between an AI backend (or a human
operator) and the underlying Linux system.

---

## What AURA Does

- Exposes system information (`sysinfo`, `netinfo`) via safe helper scripts
- Stores and retrieves persistent key/value memories in a local SQLite database
- Executes shell commands **only** through the `aioscpu-secure-run` wrapper,
  which enforces a denylist and logs every invocation
- Communicates over a simple line-based text protocol (stdin/stdout)

## Files

| File | Description |
|------|-------------|
| `aura-agent.py` | Main Python agent script |
| `aura-config.json` | Default configuration |
| `schema-memory.sql` | SQLite schema (applied automatically at startup) |

## Quick Start

```bash
# Interactive session
auractl interactive

# Single command
auractl cmd "sysinfo"

# Direct invocation
python3 /opt/aura/aura-agent.py --config /opt/aura/aura-config.json
```

## Line Protocol

Send commands to AURA's stdin, one per line. Responses are written to stdout.

| Command | Description |
|---------|-------------|
| `ping` | Liveness check → `pong` |
| `sysinfo` | Print system information |
| `netinfo` | Print network information |
| `remember <scope> <key>=<value>` | Store a memory entry |
| `recall <scope> <key>` | Retrieve a memory entry |
| `recall-all <scope>` | List all memories in a scope |
| `run <cmd>` | Execute a command via `aioscpu-secure-run` |
| `help` | Show available commands |
| `quit` | Exit AURA |

## Configuration (`aura-config.json`)

| Key | Default | Description |
|-----|---------|-------------|
| `db_path` | `/var/lib/aura/aura-memory.db` | SQLite database path |
| `log_path` | `/var/log/aura-agent.log` | Agent log file |
| `secure_run_wrapper` | `/usr/local/bin/aioscpu-secure-run` | Command execution wrapper |
| `cmd_timeout` | `60` | Timeout (seconds) for helper commands |
| `max_memory_entries` | `10000` | Maximum rows in the memory table |
| `model_backend` | `null` | Future: path/URL to an LLM backend |

## Security

- AURA runs as the locked `aura` system user (no interactive login shell)
- It may only execute commands via `aioscpu-secure-run` (sudo-restricted)
- All command executions are logged to `/var/log/aioscpu-secure-run.log`
- The systemd service applies `NoNewPrivileges`, `PrivateTmp`,
  `ProtectSystem=strict`, and `ProtectHome=read-only`

See `docs/SECURITY.md` and `docs/LEGAL.md` for full details.
