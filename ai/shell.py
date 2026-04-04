#!/usr/bin/env python3
"""ai/shell.py — AIOS interactive AI shell.

Provides a Python-based REPL that:
  - Presents an ``aios> `` prompt with readline history.
  - Parses input through the IntentEngine → Router → Bot pipeline.
  - Falls back to AI (mock or llama) responses for chat / unknown input.
  - Handles built-in meta-commands (help, exit, quit, clear, sys).

Usage:
    python3 ai/shell.py [--os-root <path>] [--aios-root <path>]
    python3 ai/shell.py --non-interactive --input "<text>"
"""
from __future__ import annotations

import argparse
import os
import subprocess
import sys
import traceback

# ---------------------------------------------------------------------------
# Path setup — allow running directly as ``python3 ai/shell.py``
# ---------------------------------------------------------------------------
_HERE = os.path.dirname(os.path.abspath(__file__))
_CORE = os.path.join(_HERE, "core")
sys.path.insert(0, _CORE)

from intent_engine import IntentEngine  # noqa: E402
from router import Router               # noqa: E402
from llama_client import run_mock       # noqa: E402
from commands import parse_natural_language  # noqa: E402

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------
_PROMPT = "aios> "
_BANNER = (
    "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"
    "  AIOS — AI Operating System Shell  (Python AI Shell)\n"
    "  Type 'help' for commands, 'exit' to quit.\n"
    "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
)
_HELP_TEXT = """\
AIOS AI Shell — built-in commands
  help            show this help message
  exit / quit     exit the shell
  clear           clear the terminal screen
  sys [cmd]       run a real OS shell command (or drop to $SHELL)

Routed commands (handled by AI pipeline):
  ls [path]       list files
  cat <file>      show file contents
  mkdir <dir>     create directory
  rm <path>       remove file/directory
  ps              list processes
  kill <pid>      terminate a process
  ping <host>     test network connectivity
  ifconfig        show network interfaces
  status          full system health check
  uptime          system uptime
  disk            disk usage
  services        running services
  repair          run AURA self-repair
  mem.set <k> <v> store a value in memory
  mem.get <k>     retrieve a stored value
  log [source]    read OS log (default: os.log)

Anything else is forwarded to the AI (AURA built-in / LLaMA if configured).
"""

# ---------------------------------------------------------------------------
# Readline history (optional; degrades gracefully if readline is unavailable)
# ---------------------------------------------------------------------------

def _setup_readline(histfile: str) -> None:
    try:
        import readline
        os.makedirs(os.path.dirname(histfile), exist_ok=True)
        if os.path.isfile(histfile):
            readline.read_history_file(histfile)
        readline.set_history_length(500)

        import atexit
        atexit.register(readline.write_history_file, histfile)

        # Tab-completion using the known command vocabulary
        _CANDIDATES = [
            "help", "exit", "quit", "clear", "sys",
            "ls", "cat", "mkdir", "rm", "ps", "kill",
            "ping", "ifconfig", "status", "uptime", "disk",
            "services", "repair", "mem.set", "mem.get",
            "recall", "log", "ask",
        ]

        def _completer(text: str, state: int):
            matches = [c for c in _CANDIDATES if c.startswith(text)]
            return matches[state] if state < len(matches) else None

        readline.set_completer(_completer)
        readline.parse_and_bind("tab: complete")
    except ImportError:
        pass  # readline not available — still functional, just no history


# ---------------------------------------------------------------------------
# Built-in meta-command handlers
# ---------------------------------------------------------------------------

def _handle_sys(rest: str, aios_root: str) -> str:
    """Drop to the real OS shell or run a single shell command."""
    if rest.strip():
        try:
            result = subprocess.run(
                rest,
                shell=True,
                text=True,
                capture_output=True,
            )
            output = (result.stdout or "") + (result.stderr or "")
            return output.rstrip() or "(no output)"
        except Exception as exc:  # pragma: no cover
            return f"[sys] Error: {exc}"
    else:
        shell = os.environ.get("SHELL", "/bin/sh")
        print(f"[sys] Dropping to {shell} (type 'exit' to return to AIOS)")
        try:
            subprocess.run([shell])
        except Exception as exc:  # pragma: no cover
            return f"[sys] Could not launch shell: {exc}"
        return ""


def _handle_clear() -> str:
    os.system("clear" if os.name != "nt" else "cls")
    return ""


# ---------------------------------------------------------------------------
# Core dispatch
# ---------------------------------------------------------------------------

def dispatch(user_input: str, engine: IntentEngine, router: Router,
             aios_root: str) -> str:
    """Parse ``user_input`` and return a response string.

    Pipeline:
        meta-commands (help/exit/clear/sys)
        → IntentEngine.classify()
        → Router.dispatch()          (bot-based)
        → parse_natural_language()   (legacy structured fallback)
        → run_mock()                 (AI chat fallback)
    """
    stripped = user_input.strip()
    if not stripped:
        return ""

    lower = stripped.lower()

    # -- Meta commands -------------------------------------------------------
    if lower in ("help", "?"):
        return _HELP_TEXT.rstrip()

    if lower in ("exit", "quit"):
        raise SystemExit(0)

    if lower == "clear":
        return _handle_clear()

    if lower == "sys" or lower.startswith("sys "):
        rest = stripped[3:].strip()
        return _handle_sys(rest, aios_root)

    # -- AI pipeline ---------------------------------------------------------
    intent = engine.classify(stripped)
    bot_response = router.dispatch(intent)
    if bot_response is not None:
        return bot_response

    # -- Legacy structured command fallback ----------------------------------
    plan = parse_natural_language(stripped)
    if plan.command != "chat":
        # Return a readable message — actual execution is done via aios-sys
        aios_sys = os.path.join(aios_root, "bin", "aios-sys")
        if os.path.isfile(aios_sys):
            env = dict(os.environ, AIOS_ROOT=aios_root)
            try:
                out = subprocess.check_output(
                    [aios_sys, "--", plan.command] + plan.args,
                    stderr=subprocess.STDOUT,
                    text=True,
                    env=env,
                )
                return out.rstrip()
            except subprocess.CalledProcessError as exc:
                return f"[ERROR] {exc.output.rstrip()}"
            except FileNotFoundError:
                pass  # fall through to mock

    # -- AI chat / fallback --------------------------------------------------
    return run_mock(stripped)


# ---------------------------------------------------------------------------
# Interactive REPL
# ---------------------------------------------------------------------------

class AIShell:
    """AIOS interactive Python shell.

    Args:
        os_root:   Path to the OS_ROOT jail directory.
        aios_root: Path to the AIOS project root.
    """

    def __init__(self, os_root: str = "", aios_root: str = "") -> None:
        self.aios_root = aios_root or os.environ.get("AIOS_ROOT", "")
        self.os_root = os_root or os.environ.get("OS_ROOT", "")

        self._engine = IntentEngine()
        self._router = Router(os_root=self.os_root, aios_root=self.aios_root)

        histfile = os.path.join(
            self.aios_root or os.path.expanduser("~"),
            "var", "run", "aios_py_history",
        )
        _setup_readline(histfile)

    # ------------------------------------------------------------------

    def run_once(self, user_input: str) -> str:
        """Dispatch a single input and return the response (no I/O)."""
        return dispatch(user_input, self._engine, self._router, self.aios_root)

    def run(self) -> None:
        """Start the interactive REPL loop."""
        print(_BANNER)

        while True:
            try:
                line = input(_PROMPT)
            except EOFError:
                print()  # newline after ^D
                break
            except KeyboardInterrupt:
                print()  # newline after ^C — clear the line, stay in loop
                continue

            try:
                response = self.run_once(line)
            except SystemExit:
                print("Goodbye.")
                break
            except Exception:  # pragma: no cover
                traceback.print_exc()
                continue

            if response:
                print(response)


# ---------------------------------------------------------------------------
# CLI entry point
# ---------------------------------------------------------------------------

def _build_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(
        description="AIOS interactive AI shell",
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    p.add_argument("--os-root",   default="",
                   help="OS_ROOT jail path (default: $OS_ROOT)")
    p.add_argument("--aios-root", default="",
                   help="AIOS project root (default: $AIOS_ROOT)")
    p.add_argument("--non-interactive", action="store_true",
                   help="Process a single --input and exit")
    p.add_argument("--input", default="",
                   help="Input string for --non-interactive mode")
    return p


def main() -> None:
    args = _build_parser().parse_args()

    shell = AIShell(os_root=args.os_root, aios_root=args.aios_root)

    if args.non_interactive:
        response = shell.run_once(args.input)
        if response:
            print(response)
        return

    shell.run()


if __name__ == "__main__":
    main()
