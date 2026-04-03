#!/usr/bin/env python3
"""ai/core/commands.py — lightweight natural-language → command planner.

Converts simple natural-language phrases into structured CommandPlan objects
that the AI shell can dispatch to the correct aura module function.
"""
from dataclasses import dataclass, field
from typing import List


@dataclass
class CommandPlan:
    command: str
    args: List[str] = field(default_factory=list)


def parse_natural_language(user_input: str) -> CommandPlan:
    """Map a natural-language phrase to the best-matching AIOS command.

    Returns a CommandPlan whose command is 'chat' when no mapping is found,
    so that the caller can fall through to the AI response path.
    """
    text = user_input.strip()
    lower = text.lower()

    # --- Filesystem ---
    if lower.startswith(("ls ", "list ", "dir ")):
        path = text.split(maxsplit=1)[1] if " " in text else "."
        return CommandPlan("fs.ls", [path])
    if lower in ("ls", "list", "dir"):
        return CommandPlan("fs.ls", ["."])
    if lower.startswith(("cat ", "show ", "read ")):
        path = text.split(maxsplit=1)[1]
        return CommandPlan("fs.cat", [path])
    if lower.startswith(("mkdir ", "make dir ", "create dir ")):
        path = text.split(maxsplit=1)[1]
        return CommandPlan("fs.mkdir", [path])
    if lower.startswith(("rm ", "remove ", "delete ")):
        path = text.split(maxsplit=1)[1]
        return CommandPlan("fs.rm", [path])

    # --- Process ---
    if lower in ("ps", "processes", "show processes", "list processes"):
        return CommandPlan("proc.ps", [])
    if lower.startswith(("kill ", "kill process ")):
        pid = text.split(maxsplit=1)[1]
        return CommandPlan("proc.kill", [pid])

    # --- Network ---
    if lower.startswith("ping "):
        host = text.split(maxsplit=1)[1]
        return CommandPlan("net.ping", [host])
    if lower in ("ifconfig", "ip addr", "network", "interfaces"):
        return CommandPlan("net.ifconfig", [])

    # --- Fallback to chat ---
    return CommandPlan("chat", [text])
