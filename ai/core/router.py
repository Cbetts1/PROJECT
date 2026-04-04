#!/usr/bin/env python3
"""ai/core/router.py — Intent router for the AIOS AI pipeline.

Receives a classified Intent and dispatches it to the appropriate Bot or
falls back to the legacy command/chat path.

Pipeline:
    IntentEngine.classify(text) → Intent → Router.dispatch(intent) → str

The router maintains a priority-ordered list of Bots.  The first bot whose
``can_handle()`` method returns True is used.  If no bot matches, the
router delegates to the legacy ``commands.parse_natural_language`` path (for
structured commands) or the mock/llama chat path.
"""
from __future__ import annotations

import os
from typing import List, Optional

try:
    from .intent_engine import Intent              # type: ignore  (package)
    from .bots import BaseBot, HealthBot, LogBot, RepairBot, UpgradeBot, ProcessBot, NetworkBot, MemoryBot  # type: ignore
except ImportError:
    from intent_engine import Intent               # type: ignore  (standalone)
    from bots import BaseBot, HealthBot, LogBot, RepairBot, UpgradeBot, ProcessBot, NetworkBot, MemoryBot   # type: ignore


class Router:
    """Dispatch an Intent to the correct handler.

    Args:
        os_root:   Path to the OS_ROOT jail.
        aios_root: Path to the AIOS project root.
    """

    def __init__(self, os_root: str = "", aios_root: str = "") -> None:
        self.os_root = os_root or os.environ.get("OS_ROOT", "")
        self.aios_root = aios_root or os.environ.get("AIOS_ROOT", "")
        self._bots: List[BaseBot] = self._init_bots()

    # ------------------------------------------------------------------
    # Bot registry
    # ------------------------------------------------------------------

    def _init_bots(self) -> List[BaseBot]:
        """Instantiate all registered bots in priority order."""
        return [
            RepairBot(os_root=self.os_root),
            UpgradeBot(os_root=self.os_root),
            HealthBot(os_root=self.os_root),
            LogBot(os_root=self.os_root),
            ProcessBot(os_root=self.os_root),
            NetworkBot(os_root=self.os_root),
            MemoryBot(os_root=self.os_root),
        ]

    def register_bot(self, bot: BaseBot) -> None:
        """Register a new bot (prepended for highest priority)."""
        self._bots.insert(0, bot)

    # ------------------------------------------------------------------
    # Dispatch
    # ------------------------------------------------------------------

    def dispatch(self, intent: Intent) -> Optional[str]:
        """Route the intent to the best-matching bot.

        Returns the bot's response string, or ``None`` if no bot matched
        (caller should fall through to the legacy command / chat path).
        """
        for bot in self._bots:
            if bot.can_handle(intent):
                return bot.handle(intent)
        return None  # no bot matched — fall through to legacy path
