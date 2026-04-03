#!/usr/bin/env python3
"""ai/core/bots.py — Multi-bot architecture for AIOS.

All specialised bots extend BaseBot.  Each bot owns one functional domain
and exposes a single ``handle(intent)`` method that returns a plain-text
response string.

Registered bots
---------------
HealthBot  — system health checks and status reporting
LogBot     — log inspection and log-writing
RepairBot  — self-repair, reinstall, and recovery triggers
"""
from __future__ import annotations

import os
import subprocess
from typing import Optional

# Lazy import to avoid circular dependency: intent_engine -> bots -> ...
try:
    from .intent_engine import Intent  # type: ignore  (package import)
except ImportError:
    from intent_engine import Intent   # type: ignore  (standalone import)


# ---------------------------------------------------------------------------
# BaseBot
# ---------------------------------------------------------------------------

class BaseBot:
    """Abstract base for all AIOS bots.

    Subclasses must implement ``handle``.

    Attributes:
        name:     Human-readable bot identifier.
        os_root:  Path to the OS_ROOT jail (may be empty string if unknown).
    """

    name: str = "BaseBot"

    def __init__(self, os_root: str = "") -> None:
        self.os_root = os_root or os.environ.get("OS_ROOT", "")

    # ------------------------------------------------------------------
    # Utility helpers available to all bots
    # ------------------------------------------------------------------

    def _log_path(self, name: str = "os.log") -> str:
        return os.path.join(self.os_root, "var", "log", name)

    def _read_file(self, rel_path: str, max_lines: int = 50) -> str:
        """Read the last ``max_lines`` from a file inside OS_ROOT."""
        full = os.path.join(self.os_root, rel_path.lstrip("/"))
        if not os.path.isfile(full):
            return f"[{self.name}] File not found: {rel_path}"
        try:
            with open(full, "r", errors="replace") as fh:
                lines = fh.readlines()
            return "".join(lines[-max_lines:]).rstrip()
        except OSError as exc:
            return f"[{self.name}] Cannot read {rel_path}: {exc}"

    def _run(self, cmd: list, timeout: int = 10) -> str:
        """Run a subprocess and return its combined stdout/stderr."""
        try:
            return subprocess.check_output(
                cmd, stderr=subprocess.STDOUT, text=True, timeout=timeout
            ).strip()
        except (subprocess.CalledProcessError, subprocess.TimeoutExpired,
                FileNotFoundError) as exc:
            return f"[{self.name}] Command failed: {exc}"

    # ------------------------------------------------------------------
    # Interface
    # ------------------------------------------------------------------

    def can_handle(self, intent: Intent) -> bool:
        """Return True if this bot can handle the given intent."""
        return False

    def handle(self, intent: Intent) -> str:
        """Process the intent and return a response string."""
        raise NotImplementedError(f"{self.name}.handle() not implemented")


# ---------------------------------------------------------------------------
# HealthBot
# ---------------------------------------------------------------------------

class HealthBot(BaseBot):
    """Handles health checks and system status queries."""

    name = "HealthBot"
    _CATEGORIES = {"health", "system"}
    _ACTIONS = {"check", "status", "uptime", "disk", "services", "sysinfo"}

    def can_handle(self, intent: Intent) -> bool:
        return intent.category in self._CATEGORIES or intent.action in self._ACTIONS

    def handle(self, intent: Intent) -> str:
        action = intent.action
        if action in ("uptime",):
            return self._uptime()
        if action in ("disk", "diskinfo", "df"):
            return self._disk()
        if action in ("services",):
            return self._services()
        # Default: full status
        return self._full_status()

    # ------------------------------------------------------------------

    def _uptime(self) -> str:
        return self._run(["uptime"])

    def _disk(self) -> str:
        return self._run(["df", "-h"])

    def _services(self) -> str:
        svc_bin = os.path.join(self.os_root, "bin", "os-service-status")
        if os.path.isfile(svc_bin):
            env = dict(os.environ, OS_ROOT=self.os_root)
            try:
                return subprocess.check_output(
                    ["sh", svc_bin], stderr=subprocess.STDOUT,
                    text=True, env=env, timeout=10
                ).strip()
            except Exception as exc:
                return f"[HealthBot] service-status failed: {exc}"
        return self._run(["sh", "-c", "echo 'service-status binary not found'"])

    def _full_status(self) -> str:
        parts = [
            "=== HealthBot Status ===",
            self._uptime(),
            self._disk(),
        ]
        state_file = os.path.join(self.os_root, "proc", "os.state")
        if os.path.isfile(state_file):
            parts.append("--- os.state ---")
            parts.append(self._read_file("proc/os.state"))
        return "\n".join(parts)


# ---------------------------------------------------------------------------
# LogBot
# ---------------------------------------------------------------------------

class LogBot(BaseBot):
    """Handles log reading and writing."""

    name = "LogBot"
    _CATEGORIES = {"log"}

    def can_handle(self, intent: Intent) -> bool:
        return intent.category in self._CATEGORIES

    def handle(self, intent: Intent) -> str:
        action = intent.action
        if action == "write":
            msg = intent.entities.get("message", "")
            return self._write(msg)
        # Default: read
        source = intent.entities.get("source", "os.log")
        return self._read(source)

    def _read(self, source: str = "os.log") -> str:
        # Strip leading 'log ' prefix that sometimes bleeds in
        source = source.removeprefix("log ").strip() or "os.log"
        rel = f"var/log/{source}" if not source.startswith("var/") else source
        return self._read_file(rel)

    def _write(self, message: str) -> str:
        log_path = self._log_path("os.log")
        try:
            import datetime
            ts = datetime.datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%SZ")
            with open(log_path, "a") as fh:
                fh.write(f"[{ts}] [logbot] {message}\n")
            return f"[LogBot] Logged: {message}"
        except OSError as exc:
            return f"[LogBot] Write failed: {exc}"


# ---------------------------------------------------------------------------
# RepairBot
# ---------------------------------------------------------------------------

class RepairBot(BaseBot):
    """Handles self-repair, reinstall, and recovery mode triggers."""

    name = "RepairBot"
    _CATEGORIES = {"repair"}

    def can_handle(self, intent: Intent) -> bool:
        return intent.category in self._CATEGORIES

    def handle(self, intent: Intent) -> str:
        action = intent.action
        if action == "reinstall":
            target = intent.entities.get("target", "all")
            return self._reinstall(target)
        return self._self_repair()

    def _self_repair(self) -> str:
        """Run the OS self-repair sequence."""
        lines = ["[RepairBot] Starting self-repair ..."]
        # 1. Check required directories exist; recreate if missing
        required_dirs = [
            "var/log", "var/service", "var/events",
            "proc", "proc/aura/context", "proc/aura/memory",
            "proc/aura/semantic", "proc/aura/bridge",
            "mirror/ios", "mirror/android", "mirror/linux",
            "tmp",
        ]
        repaired = 0
        for d in required_dirs:
            full = os.path.join(self.os_root, d)
            if not os.path.isdir(full):
                os.makedirs(full, exist_ok=True)
                lines.append(f"  [REPAIR] Recreated missing dir: {d}")
                repaired += 1
        # 2. Check required state files exist
        required_files = [
            ("var/log/os.log", ""),
            ("var/log/aura.log", ""),
            ("var/log/events.log", ""),
            ("proc/os.messages", ""),
        ]
        for rel, default in required_files:
            full = os.path.join(self.os_root, rel)
            if not os.path.isfile(full):
                with open(full, "w") as fh:
                    fh.write(default)
                lines.append(f"  [REPAIR] Recreated missing file: {rel}")
                repaired += 1
        # 3. Summary
        if repaired == 0:
            lines.append("  [REPAIR] All directories and files intact. No repair needed.")
        else:
            lines.append(f"  [REPAIR] Repaired {repaired} item(s).")
        lines.append("[RepairBot] Self-repair complete.")
        return "\n".join(lines)

    def _reinstall(self, target: str) -> str:
        install_sh = os.path.join(self.os_root, "..", "install.sh")
        if os.path.isfile(install_sh):
            env = dict(os.environ, OS_ROOT=self.os_root)
            return self._run(["sh", install_sh, "--repair", target])
        return f"[RepairBot] install.sh not found; cannot reinstall '{target}'"
