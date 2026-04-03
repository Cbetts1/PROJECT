#!/usr/bin/env python3
"""
© 2026 Chris Betts | AIOSCPU Official | AI-generated, fully legal

aura-agent.py - AURA AI Agent for AIOSCPU

AURA (Autonomous Unified Resource Agent) is a lightweight, line-protocol
AI agent that provides structured access to AIOSCPU system resources.

It communicates over stdin/stdout using a simple text protocol:
  - One command per line
  - Responses terminated by a blank line
  - See /usr/share/doc/aioscpu/AURA-API.md for the full protocol spec

Usage:
    python3 aura-agent.py --config /opt/aura/aura-config.json

Supported commands (see handle_command()):
    ping           - Liveness check
    sysinfo        - System information
    netinfo        - Network information
    remember       - Store a key/value in persistent memory
    recall         - Retrieve a stored key
    recall-all     - Retrieve all keys in a scope
    run            - Execute a command via the secure-run wrapper
    upgrade        - Check or apply system upgrades
    version        - Show AURA version information
    help           - Show available commands
    quit           - Exit the agent
"""

import argparse
import json
import os
import sqlite3
import subprocess
import sys
import threading
from datetime import datetime, timezone
from pathlib import Path


# ---------------------------------------------------------------------------
# Default config (overridden by --config file)
# ---------------------------------------------------------------------------
DEFAULT_CONFIG = {
    "agent_name": "AURA",
    "version": "1.1",
    "db_path": "/var/lib/aura/aura-memory.db",
    "log_path": "/var/log/aura-agent.log",
    "secure_run_wrapper": "/usr/local/bin/aioscpu-secure-run",
    "sysinfo_cmd": "/usr/local/bin/aioscpu-sysinfo",
    "netinfo_cmd": "/usr/local/bin/aioscpu-netinfo",
    "cmd_timeout": 60,
    "model_backend": None,
    "max_memory_entries": 10000,
}

# Module-level config (populated in main())
CONFIG = dict(DEFAULT_CONFIG)

# SQLite connection (thread-local for safety)
_db_local = threading.local()


# ---------------------------------------------------------------------------
# Config
# ---------------------------------------------------------------------------

def load_config(path: str) -> dict:
    """Load a JSON config file and merge with defaults.

    Args:
        path: Filesystem path to the JSON config file.

    Returns:
        A dict with config keys, falling back to DEFAULT_CONFIG for missing keys.
    """
    cfg = dict(DEFAULT_CONFIG)
    try:
        with open(path, "r", encoding="utf-8") as fh:
            user_cfg = json.load(fh)
        cfg.update(user_cfg)
    except FileNotFoundError:
        _log(f"WARNING: Config file not found: {path}. Using defaults.")
    except json.JSONDecodeError as exc:
        _log(f"WARNING: Invalid JSON in config {path}: {exc}. Using defaults.")
    return cfg


# ---------------------------------------------------------------------------
# Logging
# ---------------------------------------------------------------------------

def _log(message: str) -> None:
    """Write a timestamped entry to the agent log file and stderr."""
    ts = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    line = f"[{ts}] {message}"
    try:
        log_path = CONFIG.get("log_path", "/var/log/aura-agent.log")
        Path(log_path).parent.mkdir(parents=True, exist_ok=True)
        with open(log_path, "a", encoding="utf-8") as fh:
            fh.write(line + "\n")
    except OSError:
        pass  # Log write failure must never crash the agent
    print(line, file=sys.stderr)


# ---------------------------------------------------------------------------
# Database
# ---------------------------------------------------------------------------

def _get_db() -> sqlite3.Connection:
    """Return a thread-local SQLite connection, creating it if needed."""
    if not hasattr(_db_local, "conn") or _db_local.conn is None:
        db_path = CONFIG.get("db_path", "/var/lib/aura/aura-memory.db")
        Path(db_path).parent.mkdir(parents=True, exist_ok=True)
        _db_local.conn = sqlite3.connect(db_path, check_same_thread=False)
        _db_local.conn.row_factory = sqlite3.Row
    return _db_local.conn


def init_db() -> None:
    """Initialize the SQLite database schema.

    Creates the ``memory`` table if it does not already exist.
    Schema:
        id         INTEGER PRIMARY KEY AUTOINCREMENT
        created_at TEXT    ISO-8601 UTC timestamp
        scope      TEXT    Logical namespace for the memory entry
        key        TEXT    Key name within the scope
        value      TEXT    Stored value (arbitrary string)
    """
    conn = _get_db()
    conn.execute("""
        CREATE TABLE IF NOT EXISTS memory (
            id         INTEGER PRIMARY KEY AUTOINCREMENT,
            created_at TEXT    NOT NULL,
            scope      TEXT    NOT NULL,
            key        TEXT    NOT NULL,
            value      TEXT    NOT NULL
        )
    """)
    conn.execute("CREATE INDEX IF NOT EXISTS idx_memory_scope_key ON memory(scope, key)")
    conn.commit()
    _log("Database initialized.")


def remember(scope: str, key: str, value: str) -> None:
    """Persist a key/value pair in the AURA memory database.

    Args:
        scope: Logical namespace (e.g. "user", "system", "session").
        key:   Key name within the scope.
        value: Value to store. Arbitrary string.
    """
    conn = _get_db()
    ts = datetime.now(timezone.utc).isoformat()
    conn.execute(
        "INSERT INTO memory (created_at, scope, key, value) VALUES (?, ?, ?, ?)",
        (ts, scope, key, value),
    )
    conn.commit()

    # Enforce max_memory_entries by pruning oldest rows
    max_entries = CONFIG.get("max_memory_entries", 10000)
    row = conn.execute("SELECT COUNT(*) FROM memory").fetchone()
    if row and row[0] > max_entries:
        excess = row[0] - max_entries
        conn.execute(
            "DELETE FROM memory WHERE id IN (SELECT id FROM memory ORDER BY id ASC LIMIT ?)",
            (excess,),
        )
        conn.commit()


def recall(scope: str, key: str) -> str | None:
    """Retrieve the most recent value for a scope/key pair.

    Args:
        scope: Logical namespace.
        key:   Key name.

    Returns:
        The stored value string, or None if not found.
    """
    conn = _get_db()
    row = conn.execute(
        "SELECT value FROM memory WHERE scope=? AND key=? ORDER BY id DESC LIMIT 1",
        (scope, key),
    ).fetchone()
    return row["value"] if row else None


def recall_all(scope: str) -> list[dict]:
    """Retrieve all memory entries within a scope.

    Args:
        scope: Logical namespace.

    Returns:
        List of dicts with keys: id, created_at, scope, key, value.
        Ordered by id ascending (oldest first).
    """
    conn = _get_db()
    rows = conn.execute(
        "SELECT id, created_at, scope, key, value FROM memory WHERE scope=? ORDER BY id ASC",
        (scope,),
    ).fetchall()
    return [dict(row) for row in rows]


# ---------------------------------------------------------------------------
# System helpers
# ---------------------------------------------------------------------------

def get_sysinfo() -> str:
    """Run the aioscpu-sysinfo helper and return its output.

    Returns:
        Combined stdout of the sysinfo command, or an error message.
    """
    cmd = CONFIG.get("sysinfo_cmd", "/usr/local/bin/aioscpu-sysinfo")
    return _run_helper(cmd)


def get_netinfo() -> str:
    """Run the aioscpu-netinfo helper and return its output.

    Returns:
        Combined stdout of the netinfo command, or an error message.
    """
    cmd = CONFIG.get("netinfo_cmd", "/usr/local/bin/aioscpu-netinfo")
    return _run_helper(cmd)


def _run_helper(cmd: str) -> str:
    """Execute a helper binary and capture its stdout.

    Args:
        cmd: Path to the executable.

    Returns:
        stdout as a string, or an error description.
    """
    timeout = CONFIG.get("cmd_timeout", 60)
    try:
        result = subprocess.run(
            [cmd],
            capture_output=True,
            text=True,
            timeout=timeout,
        )
        return result.stdout + (result.stderr if result.returncode != 0 else "")
    except FileNotFoundError:
        return f"ERROR: helper not found: {cmd}"
    except subprocess.TimeoutExpired:
        return f"ERROR: helper timed out after {timeout}s: {cmd}"
    except Exception as exc:  # noqa: BLE001
        return f"ERROR: {exc}"


def secure_run(cmd: str) -> str:
    """Execute a shell command through the aioscpu-secure-run wrapper.

    The secure-run wrapper enforces a denylist and logs all invocations.
    The aura user must have sudo permission for the wrapper (see sudoers.d).

    Args:
        cmd: Shell command string to execute.

    Returns:
        Combined stdout/stderr from the command, or an error description.
    """
    wrapper = CONFIG.get("secure_run_wrapper", "/usr/local/bin/aioscpu-secure-run")
    timeout = CONFIG.get("cmd_timeout", 60)
    _log(f"secure_run: {cmd!r}")
    try:
        result = subprocess.run(
            ["sudo", wrapper, cmd],
            capture_output=True,
            text=True,
            timeout=timeout,
        )
        output = result.stdout
        if result.returncode == 2:
            output = f"REJECTED: command was blocked by aioscpu-secure-run.\n{result.stderr}"
        elif result.returncode != 0:
            output += f"\n[exit code {result.returncode}]\n{result.stderr}"
        return output
    except FileNotFoundError:
        return f"ERROR: secure-run wrapper not found: {wrapper}"
    except subprocess.TimeoutExpired:
        return f"ERROR: command timed out after {timeout}s"
    except Exception as exc:  # noqa: BLE001
        return f"ERROR: {exc}"


# ---------------------------------------------------------------------------
# Command dispatcher
# ---------------------------------------------------------------------------

def handle_command(line: str) -> str:
    """Parse and dispatch a single AURA protocol command line.

    Supported commands::

        ping
        sysinfo
        netinfo
        remember <scope> <key>=<value>
        recall <scope> <key>
        recall-all <scope>
        run <shell command>
        upgrade [--apply]
        version
        help
        quit

    Args:
        line: Raw input line from stdin (stripped of leading/trailing whitespace).

    Returns:
        Response string to send back to the caller.
        Returns the special sentinel string "QUIT" when the session should end.
    """
    parts = line.split(None, 1)
    if not parts:
        return ""

    verb = parts[0].lower()
    rest = parts[1].strip() if len(parts) > 1 else ""

    if verb == "ping":
        return "pong"

    elif verb == "sysinfo":
        return get_sysinfo()

    elif verb == "netinfo":
        return get_netinfo()

    elif verb == "remember":
        # Syntax: remember <scope> <key>=<value>
        rem_parts = rest.split(None, 1)
        if len(rem_parts) < 2 or "=" not in rem_parts[1]:
            return "ERROR: Usage: remember <scope> <key>=<value>"
        scope = rem_parts[0]
        kv = rem_parts[1]
        key, _, value = kv.partition("=")
        key = key.strip()
        value = value.strip()
        if not key:
            return "ERROR: key must not be empty"
        remember(scope, key, value)
        return f"OK: remembered {scope}/{key}"

    elif verb == "recall":
        # Syntax: recall <scope> <key>
        rc_parts = rest.split(None, 1)
        if len(rc_parts) < 2:
            return "ERROR: Usage: recall <scope> <key>"
        scope, key = rc_parts[0], rc_parts[1].strip()
        value = recall(scope, key)
        if value is None:
            return f"NOT FOUND: {scope}/{key}"
        return f"{scope}/{key} = {value}"

    elif verb == "recall-all":
        # Syntax: recall-all <scope>
        if not rest:
            return "ERROR: Usage: recall-all <scope>"
        scope = rest
        entries = recall_all(scope)
        if not entries:
            return f"NO ENTRIES in scope: {scope}"
        lines = [f"Scope: {scope}  ({len(entries)} entries)"]
        for entry in entries:
            lines.append(f"  [{entry['created_at']}] {entry['key']} = {entry['value']}")
        return "\n".join(lines)

    elif verb == "run":
        if not rest:
            return "ERROR: Usage: run <command>"
        return secure_run(rest)

    elif verb == "upgrade":
        # Syntax: upgrade [--apply | --check | --status]
        # Delegates to aioscpu-upgrade via the secure-run wrapper.
        flag = rest.strip() if rest else "--check"
        if flag not in ("--apply", "--check", "--status"):
            return "ERROR: Usage: upgrade [--check | --apply | --status]"
        return secure_run(f"aioscpu-upgrade {flag}")

    elif verb == "version":
        agent_name = CONFIG.get("agent_name", "AURA")
        version = CONFIG.get("version", "1.1")
        return f"{agent_name} v{version}"

    elif verb == "help":
        return (
            "AURA commands:\n"
            "  ping                          Liveness check\n"
            "  sysinfo                       Print system information\n"
            "  netinfo                       Print network information\n"
            "  remember <scope> <key>=<val>  Store a memory entry\n"
            "  recall <scope> <key>          Retrieve a memory entry\n"
            "  recall-all <scope>            List all entries in a scope\n"
            "  run <cmd>                     Execute via secure-run wrapper\n"
            "  upgrade [--apply]             Check or apply system upgrades\n"
            "  version                       Show AURA version\n"
            "  help                          Show this help\n"
            "  quit                          Exit AURA"
        )

    elif verb in ("quit", "exit", "q"):
        return "QUIT"

    else:
        return f"UNKNOWN COMMAND: {verb!r}  (type 'help' for available commands)"


# ---------------------------------------------------------------------------
# Main entry point
# ---------------------------------------------------------------------------

def main() -> None:
    """Main entry point for the AURA agent.

    Parses command-line arguments, initialises the database, then enters a
    read-eval-print loop reading commands from stdin and writing responses
    to stdout.
    """
    parser = argparse.ArgumentParser(
        description="AURA AI Agent for AIOSCPU",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="© 2026 Chris Betts | AIOSCPU Official | AI-generated, fully legal",
    )
    parser.add_argument(
        "--config",
        default="/opt/aura/aura-config.json",
        help="Path to JSON config file (default: /opt/aura/aura-config.json)",
    )
    parser.add_argument(
        "--version",
        action="store_true",
        help="Print AURA version and exit",
    )
    args = parser.parse_args()

    # Load and apply config
    global CONFIG  # noqa: PLW0603
    CONFIG = load_config(args.config)

    agent_name = CONFIG.get("agent_name", "AURA")
    version = CONFIG.get("version", "1.1")

    if args.version:
        print(f"{agent_name} v{version}")
        sys.exit(0)

    _log(f"{agent_name} v{version} starting. Config: {args.config}")

    # Initialise the SQLite memory database
    try:
        init_db()
    except Exception as exc:  # noqa: BLE001
        _log(f"WARNING: Could not initialise database: {exc}")

    # Print startup banner to stdout (visible to interactive users)
    print(f"AURA v{version} ready. Type 'help' for commands.")
    sys.stdout.flush()

    # ---------------------------------------------------------------------------
    # REPL – read from stdin, dispatch, write response to stdout
    # ---------------------------------------------------------------------------
    try:
        for raw_line in sys.stdin:
            line = raw_line.rstrip("\n").strip()

            if not line:
                # Empty line – print prompt and continue
                print("AURA> ", end="", flush=True)
                continue

            _log(f"CMD: {line!r}")

            response = handle_command(line)

            if response == "QUIT":
                print("Goodbye.")
                sys.stdout.flush()
                _log("Session ended by client.")
                break

            if response:
                print(response)
                sys.stdout.flush()

            # Print prompt for interactive use
            print("AURA> ", end="", flush=True)

    except (EOFError, KeyboardInterrupt):
        print("\nGoodbye.", flush=True)
        _log("Session ended (EOF/interrupt).")


if __name__ == "__main__":
    main()
