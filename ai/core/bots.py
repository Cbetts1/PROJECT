#!/usr/bin/env python3
"""ai/core/bots.py — Multi-bot architecture for AIOS.

All specialised bots extend BaseBot.  Each bot owns one functional domain
and exposes a single ``handle(intent)`` method that returns a plain-text
response string.

Registered bots
---------------
HealthBot   — system health checks and status reporting
LogBot      — log inspection and log-writing
RepairBot   — self-repair, reinstall, and recovery triggers
UpgradeBot  — package and system upgrade/update management
ProcessBot  — process listing and termination
NetworkBot  — ping, ifconfig, and other network operations
MemoryBot   — key-value and semantic memory store
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


# ---------------------------------------------------------------------------
# UpgradeBot
# ---------------------------------------------------------------------------

class UpgradeBot(BaseBot):
    """Handles package and system upgrade/update operations.

    Dispatches to OS/bin/os-install for package-level upgrades and to
    tools/update-check.sh / tools/apply-update.sh for system-level updates.
    """

    name = "UpgradeBot"
    _CATEGORIES = {"upgrade"}

    def can_handle(self, intent: Intent) -> bool:
        return intent.category in self._CATEGORIES

    def handle(self, intent: Intent) -> str:
        action = intent.action
        if action == "pkg.check":
            return self._check_updates()
        if action == "pkg.apply":
            return self._apply_update()
        if action == "pkg.upgrade-all":
            return self._upgrade_all()
        if action == "pkg.upgrade":
            target = intent.entities.get("target", "").strip()
            if not target:
                return "[UpgradeBot] Usage: upgrade <package-name>"
            return self._upgrade_pkg(target)
        return self._check_updates()

    # ------------------------------------------------------------------

    def _aios_root(self) -> str:
        """Resolve the AIOS project root from os_root (one level up)."""
        return os.environ.get("AIOS_ROOT", "") or os.path.abspath(
            os.path.join(self.os_root, "..")
        )

    def _check_updates(self) -> str:
        script = os.path.join(self._aios_root(), "tools", "update-check.sh")
        if os.path.isfile(script):
            return self._run(["bash", script])
        return "[UpgradeBot] update-check.sh not found"

    def _apply_update(self) -> str:
        script = os.path.join(self._aios_root(), "tools", "apply-update.sh")
        if os.path.isfile(script):
            return self._run(["bash", script])
        return "[UpgradeBot] apply-update.sh not found"

    def _upgrade_pkg(self, package: str) -> str:
        os_install = os.path.join(self.os_root, "bin", "os-install")
        if os.path.isfile(os_install):
            env = dict(os.environ, OS_ROOT=self.os_root)
            try:
                return subprocess.check_output(
                    ["sh", os_install, "upgrade", package],
                    stderr=subprocess.STDOUT, text=True, env=env, timeout=30
                ).strip()
            except (subprocess.CalledProcessError, subprocess.TimeoutExpired) as exc:
                return f"[UpgradeBot] upgrade failed: {exc}"
        return f"[UpgradeBot] os-install not found; cannot upgrade '{package}'"

    def _upgrade_all(self) -> str:
        os_install = os.path.join(self.os_root, "bin", "os-install")
        if os.path.isfile(os_install):
            env = dict(os.environ, OS_ROOT=self.os_root)
            try:
                return subprocess.check_output(
                    ["sh", os_install, "upgrade-all"],
                    stderr=subprocess.STDOUT, text=True, env=env, timeout=60
                ).strip()
            except (subprocess.CalledProcessError, subprocess.TimeoutExpired) as exc:
                return f"[UpgradeBot] upgrade-all failed: {exc}"
        return "[UpgradeBot] os-install not found; cannot upgrade packages"


# ---------------------------------------------------------------------------
# ProcessBot
# ---------------------------------------------------------------------------

class ProcessBot(BaseBot):
    """Handles process listing and termination.

    Mirrors the aura_proc_ps / aura_proc_kill logic from lib/aura-proc.sh
    directly in Python so these intents don't fall through to the legacy
    commands.py path.
    """

    name = "ProcessBot"
    _CATEGORIES = {"command"}
    _ACTIONS = {"proc.ps", "proc.kill"}

    def can_handle(self, intent: Intent) -> bool:
        return intent.category in self._CATEGORIES and intent.action in self._ACTIONS

    def handle(self, intent: Intent) -> str:
        if intent.action == "proc.kill":
            pid = intent.entities.get("pid", "").strip()
            if not pid:
                return "[ProcessBot] Usage: kill <pid>"
            return self._kill(pid)
        return self._ps()

    # ------------------------------------------------------------------

    def _ps(self) -> str:
        return self._run(["ps", "aux"])

    def _kill(self, pid: str) -> str:
        if not pid.isdigit():
            return f"[ProcessBot] Invalid PID: {pid}"
        result = self._run(["kill", pid])
        if result.startswith(f"[{self.name}]"):
            return result  # error from _run
        return f"[ProcessBot] Sent SIGTERM to PID {pid}"


# ---------------------------------------------------------------------------
# NetworkBot
# ---------------------------------------------------------------------------

class NetworkBot(BaseBot):
    """Handles network operations: ping, ifconfig, and discovery.

    Mirrors the aura_net_ping / aura_net_ifconfig logic from lib/aura-net.sh
    directly in Python, including the OFFLINE_MODE guard.
    """

    name = "NetworkBot"
    _CATEGORIES = {"command"}
    _ACTIONS = {"net.ping", "net.ifconfig", "net.netconf", "net.discover"}

    def can_handle(self, intent: Intent) -> bool:
        return intent.category in self._CATEGORIES and intent.action in self._ACTIONS

    def handle(self, intent: Intent) -> str:
        action = intent.action
        if action == "net.ping":
            host = intent.entities.get("host", "8.8.8.8").strip() or "8.8.8.8"
            return self._ping(host)
        if action == "net.ifconfig":
            return self._ifconfig()
        if action == "net.discover":
            return self._discover()
        # net.netconf — show resolved network config
        return self._ifconfig()

    # ------------------------------------------------------------------

    def _offline(self) -> bool:
        return os.environ.get("OFFLINE_MODE", "0") == "1"

    def _ping(self, host: str) -> str:
        if self._offline():
            return "[NetworkBot] Network disabled (OFFLINE_MODE=1)"
        return self._run(["ping", "-c", "4", host])

    def _ifconfig(self) -> str:
        import shutil
        if shutil.which("ip"):
            return self._run(["ip", "addr", "show"])
        if shutil.which("ifconfig"):
            return self._run(["ifconfig"])
        return "[NetworkBot] Neither 'ip' nor 'ifconfig' found"

    def _discover(self) -> str:
        if self._offline():
            return "[NetworkBot] Network disabled (OFFLINE_MODE=1)"
        # Best-effort: list active network interfaces with addresses
        return self._ifconfig()


# ---------------------------------------------------------------------------
# MemoryBot
# ---------------------------------------------------------------------------

class MemoryBot(BaseBot):
    """Handles key-value and semantic memory operations.

    The key-value store mirrors the shell logic from
    OS/lib/aura-memory/engine.mod, storing values as plain-text files in
    OS_ROOT/proc/aura/memory/ and maintaining an index in
    OS_ROOT/etc/aura/memory.index.
    """

    name = "MemoryBot"
    _CATEGORIES = {"memory"}

    def can_handle(self, intent: Intent) -> bool:
        return intent.category in self._CATEGORIES

    def handle(self, intent: Intent) -> str:
        action = intent.action
        if action == "mem.set":
            kv = intent.entities.get("kv", "").strip()
            return self._mem_set(kv)
        if action == "mem.get":
            key = intent.entities.get("key", "").strip()
            return self._mem_get(key)
        if action == "sem.set":
            kv = intent.entities.get("kv", "").strip()
            return self._sem_set(kv)
        if action == "sem.search":
            query = intent.entities.get("query", "").strip()
            return self._sem_search(query)
        return "[MemoryBot] Unknown memory action"

    # ------------------------------------------------------------------

    def _mem_root(self) -> str:
        return os.path.join(self.os_root, "proc", "aura", "memory")

    def _mem_index(self) -> str:
        return os.path.join(self.os_root, "etc", "aura", "memory.index")

    def _sem_root(self) -> str:
        return os.path.join(self.os_root, "proc", "aura", "semantic")

    def _sem_index(self) -> str:
        return os.path.join(self.os_root, "etc", "aura", "semantic.index")

    def _ensure_dirs(self) -> None:
        os.makedirs(self._mem_root(), exist_ok=True)
        os.makedirs(self._sem_root(), exist_ok=True)
        os.makedirs(os.path.dirname(self._mem_index()), exist_ok=True)

    def _mem_set(self, kv: str) -> str:
        """Store key=value or 'key value' into the memory store."""
        if not kv:
            return "[MemoryBot] Usage: mem.set <key> <value>"
        # Accept both "key value" and "key=value"
        if "=" in kv and " " not in kv.split("=")[0]:
            key, _, val = kv.partition("=")
        else:
            parts = kv.split(maxsplit=1)
            if len(parts) < 2:
                return "[MemoryBot] Usage: mem.set <key> <value>"
            key, val = parts
        key = key.strip()
        val = val.strip()
        self._ensure_dirs()
        filename = key.replace(".", "_") + ".mem"
        try:
            with open(os.path.join(self._mem_root(), filename), "w") as fh:
                fh.write(val)
            self._index_update(self._mem_index(), key, filename)
            return f"[MemoryBot] Stored: {key} = {val}"
        except OSError as exc:
            return f"[MemoryBot] Write failed: {exc}"

    def _mem_get(self, key: str) -> str:
        """Retrieve a value from the memory store by key."""
        if not key:
            return "[MemoryBot] Usage: mem.get <key>"
        filename = self._index_lookup(self._mem_index(), key)
        if not filename:
            return f"[MemoryBot] (no memory for '{key}')"
        full = os.path.join(self._mem_root(), filename)
        if not os.path.isfile(full):
            return f"[MemoryBot] (memory file missing for '{key}')"
        try:
            with open(full) as fh:
                return fh.read().strip()
        except OSError as exc:
            return f"[MemoryBot] Read failed: {exc}"

    def _sem_set(self, kv: str) -> str:
        """Store a semantic entry (key=document or 'key document')."""
        if not kv:
            return "[MemoryBot] Usage: sem.set <key> <text>"
        if "=" in kv and " " not in kv.split("=")[0]:
            key, _, val = kv.partition("=")
        else:
            parts = kv.split(maxsplit=1)
            if len(parts) < 2:
                return "[MemoryBot] Usage: sem.set <key> <text>"
            key, val = parts
        key = key.strip()
        val = val.strip()
        self._ensure_dirs()
        filename = key.replace(".", "_") + ".sem"
        try:
            with open(os.path.join(self._sem_root(), filename), "w") as fh:
                fh.write(val)
            self._index_update(self._sem_index(), key, filename)
            return f"[MemoryBot] Semantic stored: {key}"
        except OSError as exc:
            return f"[MemoryBot] Write failed: {exc}"

    def _sem_search(self, query: str) -> str:
        """Search semantic entries by key name or document content."""
        if not query:
            return "[MemoryBot] Usage: sem.search <query>"
        sem_root = self._sem_root()
        index_path = self._sem_index()
        if not os.path.isfile(index_path):
            return f"[MemoryBot] No semantic matches for '{query}'"
        try:
            with open(index_path) as fh:
                lines = fh.readlines()
        except OSError as exc:
            return f"[MemoryBot] Search failed: {exc}"

        hits = []
        q_lower = query.lower()
        for line in lines:
            parts = line.strip().split("|")
            if len(parts) < 2:
                continue
            key = parts[0].strip()
            filename = parts[1].strip()
            # Match on key name
            if q_lower in key.lower():
                hits.append(f"{key}: (key match)")
                continue
            # Match on file content
            sem_file = os.path.join(sem_root, filename)
            try:
                with open(sem_file) as fh:
                    content = fh.read()
                if q_lower in content.lower():
                    hits.append(f"{key}: {content.strip()}")
            except OSError:
                pass

        if not hits:
            return f"[MemoryBot] No semantic matches for '{query}'"
        return "\n".join(hits)

    # ------------------------------------------------------------------
    # Index helpers
    # ------------------------------------------------------------------

    @staticmethod
    def _index_update(index_path: str, key: str, filename: str) -> None:
        """Upsert a key entry in the index file."""
        lines: list[str] = []
        try:
            with open(index_path) as fh:
                lines = fh.readlines()
        except FileNotFoundError:
            pass
        lines = [l for l in lines if not l.startswith(f"{key} |")]
        lines.append(f"{key} | {filename} |\n")
        with open(index_path, "w") as fh:
            fh.writelines(lines)

    @staticmethod
    def _index_lookup(index_path: str, key: str) -> str:
        """Return the filename for a key, or empty string if not found."""
        try:
            with open(index_path) as fh:
                for line in fh:
                    if line.startswith(f"{key} |"):
                        parts = line.split("|")
                        if len(parts) >= 2:
                            return parts[1].strip()
        except FileNotFoundError:
            pass
        return ""

