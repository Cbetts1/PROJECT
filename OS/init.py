#!/usr/bin/env python3
"""OS/init.py — AIOS Python OS initializer.

Bootstraps the AIOS virtual OS environment:
  1. Resolves and exports OS_ROOT and AIOS_HOME
  2. Creates all required runtime directories and files
  3. Writes the initial OS state record
  4. Optionally launches the Python kernel (kernel.py)

Usage:
    python3 OS/init.py [--no-kernel] [--os-root <path>] [--aios-root <path>]
"""
from __future__ import annotations

import argparse
import os
import sys
import time


# ---------------------------------------------------------------------------
# Required directory / file layout inside OS_ROOT
# ---------------------------------------------------------------------------
REQUIRED_DIRS: list[str] = [
    "bin",
    "dev",
    "etc",
    "etc/aura",
    "init.d",
    "lib",
    "proc",
    "sbin",
    "tmp",
    "var",
    "var/log",
    "var/run",
]

REQUIRED_FILES: dict[str, str] = {
    "proc/os.state": "",
    "var/log/os.log": "",
    "var/log/aura.log": "",
}


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
def _log(msg: str) -> None:
    print(f"[init] {msg}", flush=True)


def _resolve_roots(os_root_arg: str | None, aios_root_arg: str | None) -> tuple[str, str]:
    """Resolve OS_ROOT and AIOS_HOME, preferring CLI args then env vars."""
    script_dir = os.path.dirname(os.path.abspath(__file__))
    default_os_root = script_dir  # OS/ directory
    default_aios_root = os.path.dirname(script_dir)  # project root

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


def _create_dirs(os_root: str) -> int:
    """Create all required runtime directories. Returns count created."""
    created = 0
    for rel in REQUIRED_DIRS:
        path = os.path.join(os_root, rel)
        if not os.path.isdir(path):
            os.makedirs(path, exist_ok=True)
            _log(f"created dir  : {rel}/")
            created += 1
    return created


def _create_files(os_root: str) -> int:
    """Create required runtime files if they don't already exist. Returns count created."""
    created = 0
    for rel, default_content in REQUIRED_FILES.items():
        path = os.path.join(os_root, rel)
        if not os.path.exists(path):
            os.makedirs(os.path.dirname(path), exist_ok=True)
            with open(path, "w") as fh:
                fh.write(default_content)
            _log(f"created file : {rel}")
            created += 1
    return created


def _write_state(os_root: str, aios_root: str) -> None:
    """Write / refresh proc/os.state with current boot metadata."""
    state_path = os.path.join(os_root, "proc", "os.state")
    boot_time = int(time.time())
    content = (
        f"boot_time={boot_time}\n"
        f"kernel_pid={os.getpid()}\n"
        f"os_root={os_root}\n"
        f"aios_root={aios_root}\n"
        f"status=running\n"
    )
    with open(state_path, "w") as fh:
        fh.write(content)
    _log(f"state written: proc/os.state (boot_time={boot_time})")


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
def main() -> None:
    parser = argparse.ArgumentParser(description="AIOS Python OS initializer")
    parser.add_argument("--os-root",   default=None, help="Override OS_ROOT")
    parser.add_argument("--aios-root", default=None, help="Override AIOS_HOME")
    parser.add_argument("--no-kernel", action="store_true",
                        help="Initialize environment only; do not launch kernel.py")
    args = parser.parse_args()

    os_root, aios_root = _resolve_roots(args.os_root, args.aios_root)

    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    print("  AIOS Python Init — environment setup")
    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    _log(f"OS_ROOT   = {os_root}")
    _log(f"AIOS_HOME = {aios_root}")

    # Set environment for any child processes
    os.environ["OS_ROOT"] = os_root
    os.environ["AIOS_HOME"] = aios_root
    os.environ["AIOS_ROOT"] = aios_root

    dirs_created = _create_dirs(os_root)
    files_created = _create_files(os_root)
    _write_state(os_root, aios_root)

    _log(f"init complete: {dirs_created} dirs, {files_created} files created/ensured")
    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

    if not args.no_kernel:
        kernel_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "kernel.py")
        if not os.path.isfile(kernel_path):
            print(f"[init] ERROR: kernel.py not found at {kernel_path}", file=sys.stderr)
            sys.exit(1)
        _log("handing off to kernel.py …")
        os.execv(sys.executable, [sys.executable, kernel_path] + sys.argv[1:])


if __name__ == "__main__":
    main()
