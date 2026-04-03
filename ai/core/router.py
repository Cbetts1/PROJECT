#!/usr/bin/env python3
"""ai/core/router.py — AIOS AI Core Router.

The Router is the central dispatch layer of the AI Core.  It receives an
Intent (from intent_engine.py) and routes it to the correct OS subsystem
handler.  Each subsystem registers a handler function; the router calls the
best match and returns the subsystem's response.

Architecture
------------
  User input
      │
      ▼
  IntentEngine.classify()
      │
      ▼
  Router.dispatch(intent, context)
      │
      ├─ COMMAND  → CommandSubsystem
      ├─ QUERY    → QuerySubsystem
      ├─ ACTION   → ActionSubsystem
      ├─ REPAIR   → RepairSubsystem
      ├─ WORKFLOW → WorkflowSubsystem
      └─ CHAT     → ChatSubsystem
      │
      ▼
  SubsystemResponse
      │
      ▼
  Shell output
"""

from __future__ import annotations

import os
import subprocess
from dataclasses import dataclass, field
from typing import Callable, Dict, List, Optional

from intent_engine import Intent, IntentType, classify


# ---------------------------------------------------------------------------
# Data types
# ---------------------------------------------------------------------------

@dataclass
class RouterContext:
    """Runtime context passed to every subsystem handler."""
    os_root: str   = ""
    aios_root: str = ""
    shell_mode: str = "operator"   # operator | system | talk
    extra: Dict[str, str] = field(default_factory=dict)


@dataclass
class SubsystemResponse:
    success: bool
    output: str
    subsystem: str = ""
    intent_type: str = ""

    def __str__(self) -> str:
        return self.output


# ---------------------------------------------------------------------------
# Subsystem handler type
# ---------------------------------------------------------------------------

SubsystemHandler = Callable[[Intent, RouterContext], SubsystemResponse]


# ---------------------------------------------------------------------------
# Built-in subsystem handlers
# ---------------------------------------------------------------------------

def _run_aios_sys(command: str, args: List[str], ctx: RouterContext) -> SubsystemResponse:
    """Delegate a command to bin/aios-sys for execution."""
    aios_sys = os.path.join(ctx.aios_root, "bin", "aios-sys")
    env = dict(os.environ)
    env["AIOS_ROOT"] = ctx.aios_root
    env["OS_ROOT"]   = ctx.os_root
    try:
        out = subprocess.check_output(
            [aios_sys, "--", command] + args,
            stderr=subprocess.STDOUT,
            text=True,
            env=env,
        )
        return SubsystemResponse(success=True, output=out, subsystem="command")
    except subprocess.CalledProcessError as exc:
        return SubsystemResponse(success=False, output=f"[ERROR] {exc.output}", subsystem="command")
    except FileNotFoundError:
        return SubsystemResponse(success=False, output=f"[ERROR] aios-sys not found at {aios_sys}", subsystem="command")


def _handle_command(intent: Intent, ctx: RouterContext) -> SubsystemResponse:
    """Route COMMAND intents to the aios-sys shell executor."""
    cmd  = intent.sub_intent          # e.g. "fs.ls"
    args = list(intent.entities.values())
    return _run_aios_sys(cmd, args, ctx)


def _handle_query(intent: Intent, ctx: RouterContext) -> SubsystemResponse:
    """Route QUERY intents — most map to aios-sys commands."""
    return _run_aios_sys(intent.sub_intent, [], ctx)


def _handle_action(intent: Intent, ctx: RouterContext) -> SubsystemResponse:
    """Route ACTION intents (start/stop/install/configure)."""
    args = list(intent.entities.values())
    return _run_aios_sys(intent.sub_intent, args, ctx)


def _handle_repair(intent: Intent, ctx: RouterContext) -> SubsystemResponse:
    """Route REPAIR intents — attempt auto-diagnosis then suggest fixes."""
    problem = intent.raw
    # Try to pull relevant log lines for context
    log_path = os.path.join(ctx.os_root, "var", "log", "os.log")
    log_tail = ""
    try:
        with open(log_path) as fh:
            lines = fh.readlines()
            log_tail = "".join(lines[-20:])
    except OSError:
        pass

    response_lines = [
        f"[REPAIR] Analysing: {problem!r}",
        "[REPAIR] Checking service health...",
    ]

    # Check for dead services via os-service-status
    svc_bin = os.path.join(ctx.os_root, "bin", "os-service-status")
    if os.path.isfile(svc_bin):
        try:
            out = subprocess.check_output(
                ["sh", svc_bin], stderr=subprocess.STDOUT, text=True,
                env={**os.environ, "OS_ROOT": ctx.os_root}
            )
            response_lines.append(out.strip())
        except (subprocess.CalledProcessError, FileNotFoundError):
            response_lines.append("[REPAIR] Could not query service status.")
    else:
        response_lines.append("[REPAIR] os-service-status not available.")

    if log_tail:
        response_lines.append("[REPAIR] Recent log entries:")
        response_lines.append(log_tail.strip())

    response_lines.append(
        "[REPAIR] Suggested actions: check logs above, restart affected services, "
        "or run 'os-kernelctl reload' to refresh the kernel daemon."
    )
    return SubsystemResponse(
        success=True,
        output="\n".join(response_lines),
        subsystem="repair",
    )


def _handle_workflow(intent: Intent, ctx: RouterContext) -> SubsystemResponse:
    """Route WORKFLOW intents — emit a structured workflow plan."""
    description = intent.raw
    plan = [
        f"[WORKFLOW] Request: {description!r}",
        "[WORKFLOW] Generating execution plan...",
        "  Step 1 — Validate environment (os-health-wrapper)",
        "  Step 2 — Snapshot current state (os-state)",
        "  Step 3 — Execute workflow actions",
        "  Step 4 — Verify post-condition (os-service-status)",
        "  Step 5 — Log outcome to var/log/aura.log",
        "[WORKFLOW] Run each step manually or implement in OS/lib/aura-tasks/.",
    ]
    return SubsystemResponse(
        success=True,
        output="\n".join(plan),
        subsystem="workflow",
    )


def _handle_chat(intent: Intent, ctx: RouterContext) -> SubsystemResponse:
    """Route CHAT intents to the AI model (mock or llama)."""
    from llama_client import run_mock
    response = run_mock(intent.raw)
    return SubsystemResponse(success=True, output=response, subsystem="chat")


# ---------------------------------------------------------------------------
# Router
# ---------------------------------------------------------------------------

class Router:
    """Central dispatch layer for the AIOS AI Core.

    Usage::

        router = Router(ctx)
        response = router.route("list files in /etc")
        print(response)
    """

    _DEFAULT_HANDLERS: Dict[IntentType, SubsystemHandler] = {
        IntentType.COMMAND:  _handle_command,
        IntentType.QUERY:    _handle_query,
        IntentType.ACTION:   _handle_action,
        IntentType.REPAIR:   _handle_repair,
        IntentType.WORKFLOW: _handle_workflow,
        IntentType.CHAT:     _handle_chat,
    }

    def __init__(self, ctx: Optional[RouterContext] = None) -> None:
        self.ctx = ctx or RouterContext()
        self._handlers: Dict[IntentType, SubsystemHandler] = dict(self._DEFAULT_HANDLERS)

    def register(self, intent_type: IntentType, handler: SubsystemHandler) -> None:
        """Override or extend the handler for a specific IntentType."""
        self._handlers[intent_type] = handler

    def route(self, user_input: str) -> SubsystemResponse:
        """Classify *user_input* and dispatch to the appropriate subsystem."""
        intent = classify(user_input)
        return self.dispatch(intent)

    def dispatch(self, intent: Intent) -> SubsystemResponse:
        """Dispatch a pre-classified Intent to the correct subsystem."""
        handler = self._handlers.get(intent.type, _handle_chat)
        response = handler(intent, self.ctx)
        response.intent_type = intent.type.value
        return response


# ---------------------------------------------------------------------------
# CLI entry point
# ---------------------------------------------------------------------------

if __name__ == "__main__":
    import argparse

    parser = argparse.ArgumentParser(description="AIOS AI Core Router")
    parser.add_argument("--input",      required=True, help="User input string")
    parser.add_argument("--os-root",    default="",    help="OS_ROOT jail path")
    parser.add_argument("--aios-root",  default="",    help="AIOS project root")
    args = parser.parse_args()

    ctx = RouterContext(
        os_root=args.os_root   or os.environ.get("OS_ROOT",   ""),
        aios_root=args.aios_root or os.environ.get("AIOS_ROOT", ""),
    )

    router = Router(ctx)
    resp = router.route(args.input)
    print(resp.output)
    raise SystemExit(0 if resp.success else 1)
