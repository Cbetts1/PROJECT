#!/usr/bin/env python3
"""ai/core/intent_engine.py — Intent classification for AIOS AI pipeline.

Converts raw user input into a structured Intent that the Router can dispatch
to the appropriate subsystem handler or Bot.

Pipeline:
    user input → IntentEngine.classify() → Intent → Router.dispatch()
"""
from __future__ import annotations

from dataclasses import dataclass, field
from typing import Dict, List


@dataclass
class Intent:
    """Structured representation of the user's intention.

    Attributes:
        category:  High-level category (command, chat, health, log, repair,
                   system, process, network, memory, ai).
        action:    Specific action within the category (e.g. 'ls', 'ping').
        entities:  Named slot values extracted from the text.
        raw:       Original user input string.
        confidence: 0.0–1.0 match score.
    """
    category: str
    action: str
    entities: Dict[str, str] = field(default_factory=dict)
    raw: str = ""
    confidence: float = 1.0


# ---------------------------------------------------------------------------
# Rule tables
# ---------------------------------------------------------------------------

# Each entry: (category, action, trigger_words, entity_slot_index)
# trigger_words is a tuple of lowercase prefixes/full phrases.
_RULES: List[tuple] = [
    # --- filesystem ---
    ("command", "fs.ls",    ("ls", "list", "dir"),           None),
    ("command", "fs.cat",   ("cat ", "show ", "read "),      "path"),
    ("command", "fs.mkdir", ("mkdir ", "make dir ", "create dir "), "path"),
    ("command", "fs.rm",    ("rm ", "remove ", "delete "),   "path"),
    # --- process ---
    ("command", "proc.ps",   ("ps", "processes", "show processes", "list processes"), None),
    ("command", "proc.kill", ("kill ", "kill process "),     "pid"),
    # --- network ---
    ("command", "net.ping",    ("ping ",),                   "host"),
    ("command", "net.ifconfig", ("ifconfig", "ip addr", "network", "interfaces"), None),
    ("command", "net.netconf",  ("netconf", "network config"), None),
    ("command", "net.discover", ("discover", "find services"), None),
    # --- health ---
    ("health", "check",     ("health", "healthcheck", "check health"), None),
    ("health", "status",    ("status", "sysinfo", "system info"),       None),
    # --- repair ---
    ("repair", "self-repair", ("repair", "fix", "self-repair", "selfrepair"), None),
    ("repair", "reinstall",   ("reinstall", "re-install"),  "target"),
    # --- logging ---
    ("log",    "read",      ("log ", "logs", "logread"),     "source"),
    ("log",    "write",     ("log.write ", "write log "),    "message"),
    # --- memory ---
    ("memory", "mem.set",   ("mem.set ", "remember "),       "kv"),
    ("memory", "mem.get",   ("mem.get ", "recall "),         "key"),
    ("memory", "sem.set",   ("sem.set ",),                   "kv"),
    ("memory", "sem.search",("sem.search ", "semaphore search ", "search "), "query"),
    # --- system ---
    ("system", "uptime",    ("uptime",),                     None),
    ("system", "disk",      ("disk", "diskinfo", "df"),      None),
    ("system", "reboot",    ("reboot", "restart system"),    None),
    ("system", "shutdown",  ("shutdown", "halt", "poweroff"), None),
    ("system", "services",  ("services", "service list"),    None),
    # --- ai ---
    ("ai",     "ask",       ("ask ", "query ai ", "ai "),    "query"),
]

_CHAT_KEYWORDS = ("hello", "hi", "hey", "help", "what", "why", "how",
                  "tell me", "explain", "describe", "who", "when", "where")


class IntentEngine:
    """Classify free-form user input into a structured Intent.

    Rules are evaluated in order; the first match wins.  If nothing matches,
    the text is classified as 'chat' / 'ask'.
    """

    def classify(self, text: str) -> Intent:
        """Return an Intent for the given user input."""
        stripped = text.strip()
        lower = stripped.lower()

        for category, action, triggers, entity_slot in _RULES:
            for trigger in triggers:
                if trigger.endswith(" "):
                    if lower.startswith(trigger):
                        entity_val = stripped[len(trigger):].strip()
                        entities = {entity_slot: entity_val} if entity_slot else {}
                        return Intent(
                            category=category,
                            action=action,
                            entities=entities,
                            raw=stripped,
                            confidence=0.95,
                        )
                else:
                    if lower == trigger or lower.startswith(trigger + " "):
                        return Intent(
                            category=category,
                            action=action,
                            entities={},
                            raw=stripped,
                            confidence=0.95,
                        )

        # Chat fallback
        return Intent(
            category="chat",
            action="ask",
            entities={"query": stripped},
            raw=stripped,
            confidence=0.5,
        )
