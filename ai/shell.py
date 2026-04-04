#!/usr/bin/env python3
"""ai/shell.py — AIOS interactive Python AI shell.

Provides a fully interactive REPL that:
  - Accepts built-in commands  (help, status, sysinfo, log.tail, exit)
  - Delegates AIOS commands    (fs.*, proc.*, net.*) to the AI backend
  - Falls back to AI responses for free-form natural language

This complements the Bash shell (bin/aios) and can be launched directly:
    python3 ai/shell.py
    python3 ai/shell.py --os-root <path> --aios-root <path>

Or via the Python boot chain:
    python3 OS/init.py  →  OS/kernel.py  →  ai/shell.py
"""
from __future__ import annotations

import os
import readline  # noqa: F401  (activates line-editing / history in input())
import subprocess
import sys
import time

# ---------------------------------------------------------------------------
# Version
# ---------------------------------------------------------------------------
SHELL_VERSION = "1.0.0-aurora"


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
def _resolve_roots() -> tuple[str, str]:
    script_dir = os.path.dirname(os.path.abspath(__file__))
    default_aios_root = os.path.dirname(script_dir)
    aios_root = os.environ.get("AIOS_ROOT") or os.environ.get("AIOS_HOME") or default_aios_root
    os_root = os.environ.get("OS_ROOT") or os.path.join(aios_root, "OS")
    return os.path.abspath(os_root), os.path.abspath(aios_root)


def _log(aios_root: str, level: str, msg: str) -> None:
    log_path = os.path.join(aios_root, "var", "log", "aios.log")
    ts = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
    try:
        os.makedirs(os.path.dirname(log_path), exist_ok=True)
        with open(log_path, "a") as fh:
            fh.write(f"[{ts}] [{level}] {msg}\n")
    except OSError:
        pass


def _banner(os_root: str) -> None:
    ai_backend = os.environ.get("AI_BACKEND", "mock")
    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    print(f"  AIOS Python Shell  v{SHELL_VERSION}")
    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    print(f"  OS jail  : {os_root}")
    if ai_backend == "mock":
        print("  AI mode  : built-in (rule-based) — no LLM loaded")
    else:
        print(f"  AI mode  : {ai_backend}")
    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    print("  Type 'help' for commands, 'exit' to quit.\n")


# ---------------------------------------------------------------------------
# AI backend call
# ---------------------------------------------------------------------------
def _ai_query(user_input: str, os_root: str, aios_root: str) -> str:
    """Delegate a query to ai/core/ai_backend.py and return its response."""
    backend_path = os.path.join(aios_root, "ai", "core", "ai_backend.py")
    if not os.path.isfile(backend_path):
        return _mock_response(user_input)
    try:
        result = subprocess.run(
            [
                sys.executable,
                backend_path,
                "--input", user_input,
                "--os-root", os_root,
                "--aios-root", aios_root,
            ],
            capture_output=True,
            text=True,
            timeout=30,
        )
        return (result.stdout or result.stderr or "").rstrip()
    except (subprocess.SubprocessError, FileNotFoundError) as exc:
        return f"[ERROR] AI backend failed: {exc}"


def _mock_response(user_input: str) -> str:
    """Simple keyword-based fallback when ai_backend.py is unavailable."""
    text = user_input.lower()
    if any(w in text for w in ("hello", "hi", "hey")):
        return "Hello! I'm AIOS. Type 'help' to see available commands."
    if "help" in text:
        return "Try commands like: fs.ls, proc.ps, net.ping, status, sysinfo"
    if any(w in text for w in ("time", "date")):
        return time.strftime("Current time: %Y-%m-%d %H:%M:%S UTC", time.gmtime())
    if any(w in text for w in ("version", "aios")):
        return f"AIOS Python Shell v{SHELL_VERSION}"
    return (
        f"I understood: '{user_input}'\n"
        "No AI model is loaded. Type 'help' for built-in commands."
    )


# ---------------------------------------------------------------------------
# Built-in commands
# ---------------------------------------------------------------------------
_HELP_TEXT = """\
AIOS Python Shell — built-in commands
══════════════════════════════════════════════════════
System:
  status            Show shell + OS status
  sysinfo           Show host information
  version           Print shell version
  log.tail [n]      Show last N lines of aios.log (default 20)
  clear             Clear the screen

AI / Natural language:
  ask <question>    Ask the AI a question
  <any text>        Free-form AI query

Special:
  help              Show this help
  exit / quit       Exit the shell
══════════════════════════════════════════════════════"""


def _cmd_status(os_root: str, aios_root: str) -> str:
    log_file = os.path.join(aios_root, "var", "log", "aios.log")
    log_lines = 0
    try:
        with open(log_file) as fh:
            log_lines = sum(1 for _ in fh)
    except OSError:
        pass

    state_path = os.path.join(os_root, "proc", "os.state")
    uptime = "unknown"
    try:
        with open(state_path) as fh:
            for line in fh:
                if line.startswith("boot_time="):
                    bt = int(line.split("=", 1)[1].strip())
                    secs = int(time.time()) - bt
                    h, rem = divmod(secs, 3600)
                    m, s = divmod(rem, 60)
                    uptime = f"{h}h {m}m {s}s"
    except (OSError, ValueError):
        pass

    lines = [
        "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━",
        "  AIOS System Status",
        "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━",
        f"  AI backend : {os.environ.get('AI_BACKEND', 'mock')}",
        f"  OS jail    : {os_root}",
        f"  AIOS root  : {aios_root}",
        f"  Log lines  : {log_lines}",
        f"  Uptime     : {uptime}",
        "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━",
    ]
    return "\n".join(lines)


def _cmd_sysinfo() -> str:
    import platform
    lines = [
        "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━",
        "  AIOS System Information",
        "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━",
        f"  OS name    : AIOS Aurora v{SHELL_VERSION}",
        f"  Host OS    : {platform.system()} {platform.release()}",
        f"  Machine    : {platform.machine()}",
        f"  Hostname   : {platform.node()}",
        f"  Python     : {sys.version.split()[0]}",
        "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━",
    ]
    return "\n".join(lines)


def _cmd_log_tail(aios_root: str, n: int = 20) -> str:
    log_file = os.path.join(aios_root, "var", "log", "aios.log")
    try:
        with open(log_file) as fh:
            lines = fh.readlines()
        tail = lines[-n:]
        return f"--- last {n} lines of aios.log ---\n" + "".join(tail).rstrip()
    except OSError:
        return "(log file not found or empty)"


# ---------------------------------------------------------------------------
# REPL
# ---------------------------------------------------------------------------
def run_shell(os_root: str, aios_root: str) -> None:
    _banner(os_root)
    _log(aios_root, "INFO",
         f"AIOS Python shell started. OS_ROOT={os_root} AIOS_ROOT={aios_root}")

    # Configure readline history
    hist_path = os.path.join(aios_root, "var", "run", "aios_py_history")
    try:
        os.makedirs(os.path.dirname(hist_path), exist_ok=True)
        readline.read_history_file(hist_path)
    except OSError:
        pass
    readline.set_history_length(500)

    prompt = "aios-py> "

    while True:
        try:
            try:
                line = input(prompt).strip()
            except EOFError:
                print()
                break
        except KeyboardInterrupt:
            print("\n[Use 'exit' to quit]")
            continue

        if not line:
            continue

        # Save history
        try:
            readline.write_history_file(hist_path)
        except OSError:
            pass

        cmd_lower = line.lower()
        first_word = line.split()[0].lower() if line.split() else ""

        # --- Built-ins ------------------------------------------------
        if cmd_lower in ("exit", "quit"):
            _log(aios_root, "INFO", "AIOS Python shell exited by user")
            print("Goodbye.")
            break

        if cmd_lower in ("help", "?"):
            print(_HELP_TEXT)
            continue

        if cmd_lower in ("clear", "cls"):
            print("\033[2J\033[H", end="")
            continue

        if cmd_lower == "version":
            print(f"AIOS Python Shell v{SHELL_VERSION}")
            continue

        if cmd_lower == "status":
            print(_cmd_status(os_root, aios_root))
            continue

        if cmd_lower == "sysinfo":
            print(_cmd_sysinfo())
            continue

        if first_word == "log.tail":
            parts = line.split()
            n = 20
            if len(parts) > 1 and parts[1].isdigit():
                n = int(parts[1])
            print(_cmd_log_tail(aios_root, n))
            continue

        # Strip "ask " prefix if present
        query = line[4:].strip() if first_word == "ask" else line

        # --- AI / AIOS backend ----------------------------------------
        _log(aios_root, "INFO", f"query: {query!r}")
        response = _ai_query(query, os_root, aios_root)
        print(response)


# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------
def main() -> None:
    import argparse

    parser = argparse.ArgumentParser(description="AIOS Python interactive shell")
    parser.add_argument("--os-root",   default=None, help="Override OS_ROOT")
    parser.add_argument("--aios-root", default=None, help="Override AIOS_HOME/AIOS_ROOT")
    args, _ = parser.parse_known_args()

    os_root, aios_root = _resolve_roots()
    if args.os_root:
        os_root = os.path.abspath(args.os_root)
    if args.aios_root:
        aios_root = os.path.abspath(args.aios_root)

    os.environ["OS_ROOT"] = os_root
    os.environ["AIOS_ROOT"] = aios_root
    os.environ["AIOS_HOME"] = aios_root

    run_shell(os_root, aios_root)


if __name__ == "__main__":
    main()
