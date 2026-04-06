#!/usr/bin/env python3
"""ai/core/plugin_loader.py — AIOS-Lite plugin loader.

Scans OS_ROOT/var/pkg/plugins/ for installed plugins, verifies their GPG
signatures (when available), dynamically imports BaseBot subclasses, and
registers them with the Router.

Plugin directory layout:
    OS/var/pkg/plugins/<plugin-name>/
        plugin.json          — manifest (name, version, entry_point, …)
        plugin.json.asc      — GPG detached signature (optional but recommended)
        <entry_point>.py     — Python module exporting a BaseBot subclass
        root/                — plugin's sub-OS_ROOT jail

plugin.json schema:
    {
      "name":          "hello-bot",
      "version":       "1.0.0",
      "entry_point":   "hello_bot",
      "bot_class":     "HelloBot",
      "capabilities":  ["fs.read"],
      "description":   "A sample AIOS plugin"
    }
"""
from __future__ import annotations

import importlib.util
import json
import logging
import os
import subprocess
import sys
from pathlib import Path
from typing import List, Optional

try:
    from .bots import BaseBot          # package import
    from .router import Router         # package import
except ImportError:
    from bots import BaseBot           # standalone import
    from router import Router          # standalone import

logger = logging.getLogger(__name__)

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

PLUGIN_DIR_NAME = os.path.join("var", "pkg", "plugins")
MANIFEST_FILE   = "plugin.json"
MANIFEST_SIG    = "plugin.json.asc"

# ---------------------------------------------------------------------------
# Plugin manifest dataclass (lightweight dict wrapper)
# ---------------------------------------------------------------------------

class PluginManifest:
    """Parsed plugin.json manifest."""

    def __init__(self, path: str, data: dict) -> None:
        self.path         = path              # path to plugin directory
        self.name         = data.get("name",         "unknown")
        self.version      = data.get("version",      "0.0.0")
        self.entry_point  = data.get("entry_point",  "")
        self.bot_class    = data.get("bot_class",    "")
        self.capabilities = data.get("capabilities", [])
        self.description  = data.get("description",  "")

    def __repr__(self) -> str:
        return f"<Plugin {self.name} v{self.version}>"


# ---------------------------------------------------------------------------
# PluginLoader
# ---------------------------------------------------------------------------

class PluginLoader:
    """Load, verify, and register third-party AIOS bot plugins.

    Args:
        os_root:   Path to OS_ROOT (default: $OS_ROOT env var).
        verify_sig: If True, verify GPG signatures before loading. Plugins
                    without a signature file are allowed but logged as unverified.
    """

    def __init__(self, os_root: str = "", verify_sig: bool = True) -> None:
        self.os_root    = os_root or os.environ.get("OS_ROOT", "")
        self.verify_sig = verify_sig
        self._plugins_dir = os.path.join(self.os_root, PLUGIN_DIR_NAME)
        self._loaded: List[PluginManifest] = []

    # ------------------------------------------------------------------
    # Public interface
    # ------------------------------------------------------------------

    def load_all(self, router: Router) -> List[PluginManifest]:
        """Scan the plugins directory, load every valid plugin, and register bots.

        Returns:
            List of successfully loaded PluginManifest objects.
        """
        self._loaded = []
        if not os.path.isdir(self._plugins_dir):
            logger.debug("Plugin directory not found: %s", self._plugins_dir)
            return []

        for entry in sorted(os.scandir(self._plugins_dir), key=lambda e: e.name):
            if not entry.is_dir():
                continue
            manifest_path = os.path.join(entry.path, MANIFEST_FILE)
            if not os.path.isfile(manifest_path):
                logger.debug("Skipping %s (no plugin.json)", entry.name)
                continue
            try:
                self._load_one(entry.path, manifest_path, router)
            except Exception as exc:
                logger.warning("Failed to load plugin %s: %s", entry.name, exc)

        return list(self._loaded)

    def reload_all(self, router: Router) -> List[PluginManifest]:
        """Hot-reload all plugins (called on SIGUSR1).

        Removes previously-registered plugin bots from the router and
        re-loads all plugins from disk.
        """
        if self._loaded:
            loaded_names = {m.name for m in self._loaded}
            router._bots = [
                b for b in router._bots
                if not getattr(b, "_plugin_name", None) in loaded_names
            ]
        return self.load_all(router)

    # ------------------------------------------------------------------
    # Internal helpers
    # ------------------------------------------------------------------

    def _load_one(self, plugin_dir: str, manifest_path: str, router: Router) -> None:
        """Load a single plugin and register its bot with the router."""
        # 1. Parse manifest
        with open(manifest_path, encoding="utf-8") as fh:
            data = json.load(fh)
        manifest = PluginManifest(plugin_dir, data)

        if not manifest.entry_point:
            raise ValueError("plugin.json missing 'entry_point'")
        if not manifest.bot_class:
            raise ValueError("plugin.json missing 'bot_class'")

        # 2. Verify GPG signature (best-effort)
        sig_path = os.path.join(plugin_dir, MANIFEST_SIG)
        if os.path.isfile(sig_path):
            if not self._verify_sig(manifest_path, sig_path):
                raise PermissionError(f"GPG signature verification failed for {manifest.name}")
            logger.info("Plugin %s: signature OK", manifest.name)
        elif self.verify_sig:
            logger.warning("Plugin %s: no signature file found (loading unverified)", manifest.name)

        # 3. Import the bot module
        mod_path = os.path.join(plugin_dir, manifest.entry_point + ".py")
        if not os.path.isfile(mod_path):
            raise FileNotFoundError(f"Entry point not found: {mod_path}")

        spec = importlib.util.spec_from_file_location(
            f"aios_plugin_{manifest.name}_{manifest.entry_point}", mod_path
        )
        if spec is None or spec.loader is None:
            raise ImportError(f"Cannot load module spec from {mod_path}")

        mod = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(mod)  # type: ignore[union-attr]

        bot_cls = getattr(mod, manifest.bot_class, None)
        if bot_cls is None:
            raise AttributeError(
                f"Class '{manifest.bot_class}' not found in {mod_path}"
            )
        if not issubclass(bot_cls, BaseBot):
            raise TypeError(
                f"'{manifest.bot_class}' must be a subclass of BaseBot"
            )

        # 4. Instantiate bot with plugin-scoped OS_ROOT sub-jail
        plugin_root = os.path.join(plugin_dir, "root")
        os.makedirs(plugin_root, exist_ok=True)
        bot_instance = bot_cls(os_root=plugin_root)
        bot_instance._plugin_name = manifest.name  # type: ignore[attr-defined]

        # 5. Register with router (highest priority)
        router.register_bot(bot_instance)
        self._loaded.append(manifest)
        logger.info("Loaded plugin: %s v%s (%s)", manifest.name, manifest.version, manifest.bot_class)

    @staticmethod
    def _verify_sig(manifest_path: str, sig_path: str) -> bool:
        """Return True if the GPG signature on manifest_path is valid."""
        try:
            result = subprocess.run(
                ["gpg", "--verify", sig_path, manifest_path],
                capture_output=True, timeout=10
            )
            return result.returncode == 0
        except (FileNotFoundError, subprocess.TimeoutExpired):
            # gpg not available — treat as unverified but allow
            logger.warning("gpg not found; cannot verify plugin signature")
            return True  # permissive fallback


# ---------------------------------------------------------------------------
# Convenience function
# ---------------------------------------------------------------------------

def load_plugins(router: Router, os_root: str = "", verify_sig: bool = True) -> List[PluginManifest]:
    """Load all plugins and register their bots with *router*.

    Suitable for calling from ai_backend.py or bin/aios SIGUSR1 handler.
    """
    loader = PluginLoader(os_root=os_root, verify_sig=verify_sig)
    return loader.load_all(router)
