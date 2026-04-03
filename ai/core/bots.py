#!/usr/bin/env python3
"""ai/core/bots.py — AIOS Bot System.

The bot system provides autonomous agents that run on a schedule or in
response to system events.  Each bot is a subclass of BaseBot.

Built-in bots
-------------
HealthBot   — polls service health and emits repair suggestions on failures.
LogBot      — rotates and summarises system logs on a configurable interval.
RepairBot   — watches the error log and attempts automatic self-repair.

Usage (from shell)::

    python3 bots.py --list                   # list available bots
    python3 bots.py --run health             # run HealthBot once
    python3 bots.py --run log                # run LogBot once
    python3 bots.py --run repair             # run RepairBot once
    python3 bots.py --run-all                # run all bots once

All bots are stateless single-invocation by default; schedule them from
OS/lib/aura-tasks or a cron-equivalent for continuous operation.
"""

from __future__ import annotations

import os
import re
import sys
import time
from abc import ABC, abstractmethod
from dataclasses import dataclass, field
from typing import ClassVar, Dict, List, Optional, Type


# ---------------------------------------------------------------------------
# BotResult
# ---------------------------------------------------------------------------

@dataclass
class BotResult:
    bot_name: str
    success: bool
    message: str
    actions_taken: List[str] = field(default_factory=list)
    elapsed_sec: float = 0.0

    def __str__(self) -> str:
        status = "OK" if self.success else "FAIL"
        lines = [f"[{self.bot_name}] [{status}] {self.message}"]
        for action in self.actions_taken:
            lines.append(f"  → {action}")
        if self.elapsed_sec:
            lines.append(f"  (elapsed: {self.elapsed_sec:.3f}s)")
        return "\n".join(lines)


# ---------------------------------------------------------------------------
# BaseBot
# ---------------------------------------------------------------------------

class BaseBot(ABC):
    """Abstract base class for all AIOS bots.

    Subclasses must implement :meth:`run_once`.
    """

    name: ClassVar[str] = "base"
    description: ClassVar[str] = "Abstract base bot."

    # Bot registry: name → class
    _registry: ClassVar[Dict[str, Type["BaseBot"]]] = {}

    def __init_subclass__(cls, **kwargs: object) -> None:
        super().__init_subclass__(**kwargs)
        if hasattr(cls, "name") and cls.name != "base":
            BaseBot._registry[cls.name] = cls

    def __init__(
        self,
        os_root: str = "",
        aios_root: str = "",
        config: Optional[Dict[str, str]] = None,
    ) -> None:
        self.os_root   = os_root   or os.environ.get("OS_ROOT",   "")
        self.aios_root = aios_root or os.environ.get("AIOS_ROOT", "")
        self.config    = config or {}

    @abstractmethod
    def run_once(self) -> BotResult:
        """Execute one cycle of the bot's work and return a BotResult."""

    # ------------------------------------------------------------------
    # Helpers available to all bots
    # ------------------------------------------------------------------

    def _log_path(self, name: str = "aura.log") -> str:
        return os.path.join(self.os_root, "var", "log", name)

    def _append_log(self, log_name: str, message: str) -> None:
        path = self._log_path(log_name)
        os.makedirs(os.path.dirname(path), exist_ok=True)
        ts = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
        with open(path, "a") as fh:
            fh.write(f"[{ts}] [{self.name}] {message}\n")

    def _service_dir(self) -> str:
        return os.path.join(self.os_root, "var", "service")

    def _read_file_tail(self, path: str, lines: int = 50) -> List[str]:
        try:
            with open(path) as fh:
                return fh.readlines()[-lines:]
        except OSError:
            return []


# ---------------------------------------------------------------------------
# HealthBot
# ---------------------------------------------------------------------------

class HealthBot(BaseBot):
    """Polls all PID files in var/service/ and reports dead services.

    For each dead service it logs a repair suggestion and writes to the
    AURA audit log.
    """

    name = "health"
    description = "Checks service health via PID files and reports failures."

    def run_once(self) -> BotResult:
        t0 = time.monotonic()
        svc_dir = self._service_dir()
        actions: List[str] = []
        dead: List[str] = []

        if not os.path.isdir(svc_dir):
            return BotResult(
                bot_name=self.name,
                success=True,
                message="No service directory found — nothing to check.",
                elapsed_sec=time.monotonic() - t0,
            )

        for entry in os.listdir(svc_dir):
            if not entry.endswith(".pid"):
                continue
            pid_path = os.path.join(svc_dir, entry)
            svc_name = entry[:-4]
            try:
                pid = int(open(pid_path).read().strip())
            except (OSError, ValueError):
                continue
            alive = os.path.isdir(f"/proc/{pid}")
            if not alive:
                dead.append(svc_name)
                actions.append(f"dead service: {svc_name} (pid={pid}) — restart recommended")
                self._append_log("aura.log", f"dead service: {svc_name} pid={pid}")

        if dead:
            msg = f"Dead services detected: {', '.join(dead)}"
            success = False
        else:
            msg = "All services healthy."
            success = True

        return BotResult(
            bot_name=self.name,
            success=success,
            message=msg,
            actions_taken=actions,
            elapsed_sec=time.monotonic() - t0,
        )


# ---------------------------------------------------------------------------
# LogBot
# ---------------------------------------------------------------------------

class LogBot(BaseBot):
    """Rotates system logs that exceed a configurable line threshold.

    Keeps the most recent *keep_lines* lines and archives the rest to
    var/log/<name>.1 (single rotation).
    """

    name = "log"
    description = "Rotates and summarises system logs."

    DEFAULT_MAX_LINES: ClassVar[int] = 1000
    DEFAULT_KEEP_LINES: ClassVar[int] = 200

    def run_once(self) -> BotResult:
        t0 = time.monotonic()
        log_dir  = os.path.join(self.os_root, "var", "log")
        max_lines  = int(self.config.get("max_lines",  self.DEFAULT_MAX_LINES))
        keep_lines = int(self.config.get("keep_lines", self.DEFAULT_KEEP_LINES))
        actions: List[str] = []

        if not os.path.isdir(log_dir):
            return BotResult(
                bot_name=self.name, success=True,
                message="Log directory not found.",
                elapsed_sec=time.monotonic() - t0,
            )

        rotated = 0
        for fname in os.listdir(log_dir):
            if not fname.endswith(".log"):
                continue
            fpath = os.path.join(log_dir, fname)
            try:
                with open(fpath) as fh:
                    all_lines = fh.readlines()
            except OSError:
                continue

            if len(all_lines) > max_lines:
                archive_path = fpath + ".1"
                # Write archive
                with open(archive_path, "w") as fh:
                    fh.writelines(all_lines[:-keep_lines])
                # Truncate original to last keep_lines
                with open(fpath, "w") as fh:
                    fh.writelines(all_lines[-keep_lines:])
                actions.append(f"rotated {fname}: {len(all_lines)} → {keep_lines} lines")
                rotated += 1

        msg = f"Rotated {rotated} log file(s)." if rotated else "No rotation needed."
        return BotResult(
            bot_name=self.name, success=True, message=msg,
            actions_taken=actions, elapsed_sec=time.monotonic() - t0,
        )


# ---------------------------------------------------------------------------
# RepairBot
# ---------------------------------------------------------------------------

_ERROR_PATTERNS = [
    re.compile(r"\bERROR\b",   re.I),
    re.compile(r"\bFAILED?\b", re.I),
    re.compile(r"\bCRITICAL\b",re.I),
    re.compile(r"\bpanic\b",   re.I),
    re.compile(r"\bdead\b",    re.I),
]


class RepairBot(BaseBot):
    """Scans the AURA audit log for errors and generates repair actions.

    It does not automatically mutate system state; it emits structured repair
    recommendations that an operator or the AI Core can act on.
    """

    name = "repair"
    description = "Scans logs for errors and suggests automated repairs."

    def run_once(self) -> BotResult:
        t0 = time.monotonic()
        log_path = self._log_path("aura.log")
        actions: List[str] = []

        recent = self._read_file_tail(log_path, lines=100)
        error_lines: List[str] = []
        for line in recent:
            if any(p.search(line) for p in _ERROR_PATTERNS):
                error_lines.append(line.rstrip())

        if not error_lines:
            return BotResult(
                bot_name=self.name, success=True,
                message="No errors found in recent log.",
                elapsed_sec=time.monotonic() - t0,
            )

        seen_services: set = set()
        for line in error_lines:
            # Heuristic: extract service name from "dead service: <name>"
            m = re.search(r"dead service:\s*(\S+)", line, re.I)
            if m:
                svc = m.group(1).rstrip(",")
                if svc not in seen_services:
                    seen_services.add(svc)
                    actions.append(f"restart service '{svc}': sh OS/etc/init.d/{svc} restart")

        actions.append("review full log: cat OS/var/log/aura.log")
        actions.append("run health check: python3 ai/core/bots.py --run health")

        self._append_log(
            "aura.log",
            f"RepairBot: found {len(error_lines)} error(s); "
            f"{len(actions)} repair action(s) generated.",
        )

        return BotResult(
            bot_name=self.name, success=False,
            message=f"{len(error_lines)} error(s) found in recent logs.",
            actions_taken=actions,
            elapsed_sec=time.monotonic() - t0,
        )


# ---------------------------------------------------------------------------
# BotRunner
# ---------------------------------------------------------------------------

class BotRunner:
    """Instantiates and runs bots by name."""

    def __init__(self, os_root: str = "", aios_root: str = "") -> None:
        self.os_root   = os_root   or os.environ.get("OS_ROOT",   "")
        self.aios_root = aios_root or os.environ.get("AIOS_ROOT", "")

    def _make(self, name: str) -> BaseBot:
        cls = BaseBot._registry.get(name)
        if cls is None:
            raise ValueError(f"Unknown bot: {name!r}. Available: {list(BaseBot._registry)}")
        return cls(os_root=self.os_root, aios_root=self.aios_root)

    def run(self, name: str) -> BotResult:
        bot = self._make(name)
        return bot.run_once()

    def run_all(self) -> List[BotResult]:
        results = []
        for name in BaseBot._registry:
            bot = self._make(name)
            results.append(bot.run_once())
        return results

    @staticmethod
    def list_bots() -> List[str]:
        return [
            f"{name}: {cls.description}"
            for name, cls in BaseBot._registry.items()
        ]


# ---------------------------------------------------------------------------
# CLI entry point
# ---------------------------------------------------------------------------

if __name__ == "__main__":
    import argparse

    parser = argparse.ArgumentParser(description="AIOS Bot System")
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument("--list",    action="store_true",  help="List available bots")
    group.add_argument("--run",     metavar="BOT",        help="Run a specific bot")
    group.add_argument("--run-all", action="store_true",  help="Run all bots")
    parser.add_argument("--os-root",   default="", help="OS_ROOT path")
    parser.add_argument("--aios-root", default="", help="AIOS project root")
    args = parser.parse_args()

    runner = BotRunner(
        os_root=args.os_root   or os.environ.get("OS_ROOT",   ""),
        aios_root=args.aios_root or os.environ.get("AIOS_ROOT", ""),
    )

    if args.list:
        for line in BotRunner.list_bots():
            print(line)
        sys.exit(0)

    if args.run_all:
        results = runner.run_all()
        ok = True
        for r in results:
            print(r)
            print()
            if not r.success:
                ok = False
        sys.exit(0 if ok else 1)

    # --run <name>
    result = runner.run(args.run)
    print(result)
    sys.exit(0 if result.success else 1)
