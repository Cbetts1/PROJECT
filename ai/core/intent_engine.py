#!/usr/bin/env python3
"""ai/core/intent_engine.py — AIOS Intent Classification Engine.

Classifies natural-language input into typed Intent objects with a
confidence score and extracted entities.  The intent type drives which
OS subsystem the Router will dispatch to.

Intent types
------------
COMMAND   — direct shell / OS command  (ls, ps, kill …)
QUERY     — system-state query         (status, uptime, health …)
ACTION    — system action              (start, stop, restart, configure …)
REPAIR    — error / problem report     (fix, diagnose, recover …)
WORKFLOW  — multi-step orchestration   (deploy, migrate, backup …)
CHAT      — general conversation / everything else
"""

from __future__ import annotations

import re
from dataclasses import dataclass, field
from enum import Enum
from typing import Dict, List, Tuple


class IntentType(str, Enum):
    COMMAND  = "command"
    QUERY    = "query"
    ACTION   = "action"
    REPAIR   = "repair"
    WORKFLOW = "workflow"
    CHAT     = "chat"


@dataclass
class Intent:
    type: IntentType
    confidence: float                         # 0.0 – 1.0
    raw: str                                  # original user input
    entities: Dict[str, str] = field(default_factory=dict)
    sub_intent: str = ""                      # e.g. "fs.ls", "proc.ps"

    def __repr__(self) -> str:
        return (
            f"Intent(type={self.type.value!r}, confidence={self.confidence:.2f}, "
            f"sub_intent={self.sub_intent!r}, entities={self.entities})"
        )


# ---------------------------------------------------------------------------
# Pattern tables
# ---------------------------------------------------------------------------

# Each entry: (compiled regex, IntentType, sub_intent, confidence, entity_groups)
# entity_groups: list of (group_index, entity_key) tuples
_PATTERNS: List[Tuple[re.Pattern, IntentType, str, float, List[Tuple[int, str]]]] = [
    # --- COMMAND intents ---
    (re.compile(r"^(?:ls|list|dir)\s*(.*)?$",         re.I), IntentType.COMMAND, "fs.ls",        0.95, [(1, "path")]),
    (re.compile(r"^(?:cat|show|read)\s+(\S+)",        re.I), IntentType.COMMAND, "fs.cat",        0.95, [(1, "path")]),
    (re.compile(r"^(?:mkdir|make dir)\s+(\S+)",       re.I), IntentType.COMMAND, "fs.mkdir",      0.95, [(1, "path")]),
    (re.compile(r"^(?:rm|remove|delete)\s+(\S+)",     re.I), IntentType.COMMAND, "fs.rm",         0.95, [(1, "path")]),
    (re.compile(r"^(?:cp|copy)\s+(\S+)\s+(\S+)",      re.I), IntentType.COMMAND, "fs.cp",         0.90, [(1, "src"), (2, "dest")]),
    (re.compile(r"^(?:mv|move|rename)\s+(\S+)\s+(\S+)", re.I), IntentType.COMMAND, "fs.mv",       0.90, [(1, "src"), (2, "dest")]),
    (re.compile(r"^(?:find)\s+(.*)",                   re.I), IntentType.COMMAND, "fs.find",       0.88, [(1, "args")]),
    (re.compile(r"^(?:ps|processes?|list proc(?:esses?)?)$", re.I), IntentType.COMMAND, "proc.ps", 0.95, []),
    (re.compile(r"^(?:kill|kill proc(?:ess)?)\s+(\S+)", re.I), IntentType.COMMAND, "proc.kill",   0.95, [(1, "pid")]),
    (re.compile(r"^ping\s+(\S+)",                     re.I), IntentType.COMMAND, "net.ping",      0.95, [(1, "host")]),
    (re.compile(r"^(?:ifconfig|ip addr|interfaces?)$",re.I), IntentType.COMMAND, "net.ifconfig",  0.92, []),

    # --- QUERY intents ---
    (re.compile(r"^(?:status|state|os[ -]?state)$",   re.I), IntentType.QUERY, "sys.status",      0.93, []),
    (re.compile(r"^(?:health|health ?check)$",         re.I), IntentType.QUERY, "sys.health",      0.93, []),
    (re.compile(r"^(?:services?|svc[ -]?status)$",    re.I), IntentType.QUERY, "sys.services",    0.93, []),
    (re.compile(r"^(?:uptime|up[ -]?time)$",          re.I), IntentType.QUERY, "sys.uptime",      0.93, []),
    (re.compile(r"^(?:disk|disk[ -]?usage|df)$",      re.I), IntentType.QUERY, "sys.disk",        0.93, []),
    (re.compile(r"^(?:mem(?:ory)?|free|ram)$",        re.I), IntentType.QUERY, "sys.memory",      0.90, []),
    (re.compile(r"^(?:sysinfo|sys[ -]?info|info)$",   re.I), IntentType.QUERY, "sys.sysinfo",     0.93, []),
    (re.compile(r"^log(?:s)?\s*(.*)?$",               re.I), IntentType.QUERY, "sys.logs",        0.88, [(1, "filter")]),
    (re.compile(r"^(?:bus|message[ -]?bus)\s*(.*)?$", re.I), IntentType.QUERY, "sys.bus",         0.85, [(1, "filter")]),

    # --- ACTION intents ---
    (re.compile(r"^(?:start|enable)\s+(\S+)",         re.I), IntentType.ACTION, "svc.start",      0.92, [(1, "service")]),
    (re.compile(r"^(?:stop|disable)\s+(\S+)",         re.I), IntentType.ACTION, "svc.stop",       0.92, [(1, "service")]),
    (re.compile(r"^(?:restart|reboot|reload)\s+(\S+)",re.I), IntentType.ACTION, "svc.restart",    0.92, [(1, "service")]),
    (re.compile(r"^(?:install|pkg[ -]?install)\s+(\S+)", re.I), IntentType.ACTION, "pkg.install", 0.90, [(1, "package")]),
    (re.compile(r"^(?:update|upgrade)\s*(\S+)?$",     re.I), IntentType.ACTION, "pkg.update",     0.88, [(1, "package")]),
    (re.compile(r"^(?:config(?:ure)?|set)\s+(\S+)\s+(\S+)", re.I), IntentType.ACTION, "cfg.set", 0.88, [(1, "key"), (2, "value")]),
    (re.compile(r"^(?:mount|attach)\s+(\S+)",         re.I), IntentType.ACTION, "fs.mount",       0.90, [(1, "target")]),
    (re.compile(r"^(?:unmount|umount|detach)\s+(\S+)",re.I), IntentType.ACTION, "fs.unmount",     0.90, [(1, "target")]),

    # --- REPAIR intents ---
    (re.compile(r"\b(?:fix|repair|diagnose|recover|troubleshoot|debug|broken|error|fail(?:ed|ure)?)\b", re.I),
     IntentType.REPAIR, "repair.auto",  0.80, []),

    # --- WORKFLOW intents ---
    (re.compile(r"\b(?:deploy|migrate|backup|restore|provision|bootstrap|pipeline|automate)\b", re.I),
     IntentType.WORKFLOW, "workflow.run", 0.78, []),
]


# ---------------------------------------------------------------------------
# Classifier
# ---------------------------------------------------------------------------

def classify(user_input: str) -> Intent:
    """Classify *user_input* and return the best-matching Intent.

    The first pattern that matches (patterns are ordered by specificity) is
    used.  If no pattern matches, CHAT intent with 0.5 confidence is returned.
    """
    text = user_input.strip()

    for pattern, intent_type, sub_intent, confidence, eg in _PATTERNS:
        m = pattern.search(text)
        if m:
            entities: Dict[str, str] = {}
            for group_idx, key in eg:
                try:
                    val = (m.group(group_idx) or "").strip()
                    if val:
                        entities[key] = val
                except IndexError:
                    pass
            return Intent(
                type=intent_type,
                confidence=confidence,
                raw=text,
                entities=entities,
                sub_intent=sub_intent,
            )

    return Intent(type=IntentType.CHAT, confidence=0.5, raw=text)


def classify_batch(inputs: List[str]) -> List[Intent]:
    """Classify a list of inputs and return a list of Intents."""
    return [classify(t) for t in inputs]


# ---------------------------------------------------------------------------
# CLI entry point (for shell integration / testing)
# ---------------------------------------------------------------------------
if __name__ == "__main__":
    import argparse
    import json

    parser = argparse.ArgumentParser(description="AIOS Intent Engine")
    parser.add_argument("--input", required=True, help="Natural-language input to classify")
    parser.add_argument("--json",  action="store_true", help="Output as JSON")
    args = parser.parse_args()

    intent = classify(args.input)

    if args.json:
        import json as _json
        print(_json.dumps({
            "type":       intent.type.value,
            "confidence": round(intent.confidence, 4),
            "sub_intent": intent.sub_intent,
            "entities":   intent.entities,
            "raw":        intent.raw,
        }, indent=2))
    else:
        print(repr(intent))
