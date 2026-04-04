#!/usr/bin/env python3
"""OS/kernel.py — AIOS Python kernel / command router.

The kernel sits between the OS initializer (init.py) and the AI shell
(ai/shell.py).  It handles:
  - System command routing  (proc.*, fs.*, net.*, system.*)
  - Kernel-level introspection (status, version, uptime)
  - Launching the AI shell

Usage:
    python3 OS/kernel.py [--no-shell] [--os-root <path>] [--aios-root <path>]
"""
from __future__ import annotations

import argparse
import os
import subprocess
import sys
import time


# ---------------------------------------------------------------------------
# Version
# ---------------------------------------------------------------------------
KERNEL_VERSION = "1.0.0-aurora"


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
def _log(msg: str) -> None:
    print(f"[kernel] {msg}", flush=True)


def _resolve_roots(os_root_arg: str | None, aios_root_arg: str | None) -> tuple[str, str]:
    script_dir = os.path.dirname(os.path.abspath(__file__))
    default_os_root = script_dir
    default_aios_root = os.path.dirname(script_dir)

    os_root = (
        os_root_arg
        or os.environ.get("OS_ROOT")
        or default_os_root
    )
    aios_root = (
        aios_root_arg
        or os.environ.get("AIOS_HOME")
        or os.environ.get("AIOS_ROOT")
        or default_aios_root
    )
    return os.path.abspath(os_root), os.path.abspath(aios_root)


def _read_state(os_root: str) -> dict[str, str]:
    """Read proc/os.state into a dict."""
    state_path = os.path.join(os_root, "proc", "os.state")
    result: dict[str, str] = {}
    try:
        with open(state_path) as fh:
            for line in fh:
                line = line.strip()
                if "=" in line and not line.startswith("#"):
                    k, _, v = line.partition("=")
                    result[k.strip()] = v.strip()
    except OSError:
        pass
    return result


# ---------------------------------------------------------------------------
# Built-in command router
# ---------------------------------------------------------------------------
class Kernel:
    """Minimal OS kernel: route system commands and launch the AI shell."""

    COMMANDS: dict[str, str] = {
        "status":  "Show kernel status",
        "version": "Print kernel version",
        "uptime":  "Show system uptime",
        "ps":      "List running processes (top 20)",
        "help":    "Show this help",
    }

    def __init__(self, os_root: str, aios_root: str) -> None:
        self.os_root = os_root
        self.aios_root = aios_root
        self._start_time = time.time()

    # ------------------------------------------------------------------
    # Dispatch
    # ------------------------------------------------------------------
    def dispatch(self, cmd: str, args: list[str]) -> str | None:
        """Route a command.  Returns response string, or None if unknown."""
        handlers = {
            "status":  self._cmd_status,
            "version": self._cmd_version,
            "uptime":  self._cmd_uptime,
            "ps":      self._cmd_ps,
            "help":    self._cmd_help,
        }
        handler = handlers.get(cmd.lower())
        if handler is None:
            return None
        return handler(args)

    # ------------------------------------------------------------------
    # Built-in handlers
    # ------------------------------------------------------------------
    def _cmd_status(self, _args: list[str]) -> str:
        state = _read_state(self.os_root)
        lines = [
            "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━",
            "  AIOS Kernel Status",
            "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━",
            f"  Version    : {KERNEL_VERSION}",
            f"  OS_ROOT    : {self.os_root}",
            f"  AIOS_HOME  : {self.aios_root}",
            f"  Kernel PID : {os.getpid()}",
            f"  OS status  : {state.get('status', 'unknown')}",
            "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━",
        ]
        return "\n".join(lines)

    def _cmd_version(self, _args: list[str]) -> str:
        return f"AIOS kernel {KERNEL_VERSION}"

    def _cmd_uptime(self, _args: list[str]) -> str:
        state = _read_state(self.os_root)
        now = int(time.time())
        bt_str = state.get("boot_time", "")
        if bt_str.isdigit():
            secs = now - int(bt_str)
            h, rem = divmod(secs, 3600)
            m, s = divmod(rem, 60)
            return f"Uptime: {h}h {m}m {s}s"
        return "Uptime: unknown (state file not found)"

    def _cmd_ps(self, _args: list[str]) -> str:
        try:
            out = subprocess.check_output(
                ["ps", "aux", "--no-headers"],
                text=True,
                stderr=subprocess.DEVNULL,
            )
            lines = out.strip().splitlines()[:20]
            return "\n".join(lines)
        except (subprocess.SubprocessError, FileNotFoundError) as exc:
            return f"[ERROR] ps failed: {exc}"

    def _cmd_help(self, _args: list[str]) -> str:
        lines = ["AIOS Kernel — built-in commands", ""]
        for cmd, desc in self.COMMANDS.items():
            lines.append(f"  {cmd:<12} {desc}")
        return "\n".join(lines)


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
def main() -> None:
    parser = argparse.ArgumentParser(description="AIOS Python kernel")
    parser.add_argument("--os-root",   default=None, help="Override OS_ROOT")
    parser.add_argument("--aios-root", default=None, help="Override AIOS_HOME")
    parser.add_argument("--no-shell",  action="store_true",
                        help="Stay in kernel REPL; do not launch ai/shell.py")
    # Forward any remaining args (e.g. from init.py exec chain)
    args, _extra = parser.parse_known_args()

    os_root, aios_root = _resolve_roots(args.os_root, args.aios_root)
    os.environ["OS_ROOT"] = os_root
    os.environ["AIOS_HOME"] = aios_root
    os.environ["AIOS_ROOT"] = aios_root

    kernel = Kernel(os_root=os_root, aios_root=aios_root)

    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    print(f"  AIOS Kernel {KERNEL_VERSION} — ready")
    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    _log(f"OS_ROOT   = {os_root}")
    _log(f"AIOS_HOME = {aios_root}")

    if not args.no_shell:
        shell_path = os.path.join(aios_root, "ai", "shell.py")
        if os.path.isfile(shell_path):
            _log("handing off to ai/shell.py …")
            os.execv(sys.executable, [sys.executable, shell_path])
        else:
            _log(f"ai/shell.py not found at {shell_path} — falling back to kernel REPL")

    # Kernel REPL (reached when --no-shell or shell.py missing)
    print("\n  Type 'help' for commands, 'exit' to quit.\n")
    try:
        while True:
            try:
                line = input("kernel> ").strip()
            except EOFError:
                print()
                break
            if not line:
                continue
            if line in ("exit", "quit"):
                break
            parts = line.split()
            cmd, cmd_args = parts[0], parts[1:]
            response = kernel.dispatch(cmd, cmd_args)
            if response is None:
                print(f"[kernel] unknown command: {cmd!r}  (type 'help')")
            else:
                print(response)
    except KeyboardInterrupt:
        print("\n[kernel] interrupted")


if __name__ == "__main__":
    main()
