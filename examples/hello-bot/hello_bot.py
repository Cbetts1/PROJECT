#!/usr/bin/env python3
"""examples/hello-bot/hello_bot.py — Reference AIOS-Lite plugin.

Demonstrates the minimum required structure for a third-party bot plugin:
  1. Import BaseBot (relative or absolute depending on how it is loaded).
  2. Define a class that extends BaseBot.
  3. Implement can_handle(intent) and handle(intent).

Install by copying this directory to OS/var/pkg/plugins/hello-bot/ and
sending SIGUSR1 to the running aios process (hot-reload), or restart aios.
"""
from __future__ import annotations

import os
import sys

# Support both package import (ai.core.bots) and standalone plugin import
try:
    from ai.core.bots import BaseBot
    from ai.core.intent_engine import Intent
except ImportError:
    try:
        from bots import BaseBot          # type: ignore
        from intent_engine import Intent  # type: ignore
    except ImportError:
        # Absolute fallback when loaded by plugin_loader from an arbitrary path
        _core = os.path.join(os.path.dirname(__file__), "..", "..", "ai", "core")
        sys.path.insert(0, _core)
        from bots import BaseBot          # type: ignore
        from intent_engine import Intent  # type: ignore


class HelloBot(BaseBot):
    """A friendly reference plugin that responds to 'hello' queries.

    Demonstrates:
      - Using self.os_root for plugin-scoped OS access
      - Implementing can_handle() and handle()
    """

    name = "HelloBot"
    _TRIGGERS = {"hello", "hi", "hey", "greet", "greeting"}

    def can_handle(self, intent: Intent) -> bool:
        return (
            intent.category == "chat"
            and any(t in intent.raw.lower() for t in self._TRIGGERS)
        )

    def handle(self, intent: Intent) -> str:
        user_text = intent.raw.strip()
        return (
            f"[HelloBot] 👋  Hello! You said: '{user_text}'\n"
            f"  I am the hello-bot reference plugin running in AIOS-Lite.\n"
            f"  Plugin root: {self.os_root}"
        )
