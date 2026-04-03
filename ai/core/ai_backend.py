#!/usr/bin/env python3
"""ai/core/ai_backend.py — AI dispatch backend for AIOS.

Called by lib/aura-ai.sh.  Translates natural language into an Intent (via
intent_engine.py), dispatches it through the Router (router.py → bots.py),
and falls back to the legacy command path (commands.py) or the mock/LLaMA
chat path (llama_client.py) when no bot matches.

Pipeline:
    user input
        → IntentEngine.classify()
        → Router.dispatch(intent)          ← primary (bot-based) path
        → [fallback] parse_natural_language()  ← legacy structured commands
        → [fallback] run_mock()            ← chat / LLaMA

Usage:
    python3 ai_backend.py --input "<text>" --os-root <path> --aios-root <path>
"""
import argparse
import os
import subprocess
import sys

# Allow importing sibling modules regardless of the current working directory.
_HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, _HERE)

from commands import parse_natural_language  # noqa: E402  (legacy fallback)
from llama_client import run_mock            # noqa: E402
from intent_engine import IntentEngine       # noqa: E402
from router import Router                    # noqa: E402


def run_system_command(plan, aios_root: str) -> str:
    """Delegate a structured command to bin/aios-sys for execution.

    aios-sys re-sources the aura modules in a clean subprocess and runs the
    requested registered command, so stdout is captured and returned.
    """
    aios_sys = os.path.join(aios_root, "bin", "aios-sys")
    cmd = [aios_sys, "--", plan.command] + plan.args
    env = dict(os.environ)
    env["AIOS_ROOT"] = aios_root
    try:
        out = subprocess.check_output(
            cmd,
            stderr=subprocess.STDOUT,
            text=True,
            env=env,
        )
        return out
    except subprocess.CalledProcessError as exc:
        return f"[ERROR] {exc.output}"
    except FileNotFoundError:
        return f"[ERROR] bin/aios-sys not found at {aios_sys}"


def chat_response(user_input: str) -> str:
    """Return a chat response from the mock (or real) AI model."""
    return run_mock(user_input)


def main() -> None:
    parser = argparse.ArgumentParser(description="AIOS AI dispatch backend")
    parser.add_argument("--input",      required=True, help="User input string")
    parser.add_argument("--os-root",    required=True, help="OS_ROOT jail path")
    parser.add_argument("--aios-root",  required=True, help="AIOS project root")
    args = parser.parse_args()

    # ------------------------------------------------------------------
    # Primary path: IntentEngine → Router → Bot
    # ------------------------------------------------------------------
    engine = IntentEngine()
    intent = engine.classify(args.input)

    router = Router(os_root=args.os_root, aios_root=args.aios_root)
    bot_response = router.dispatch(intent)
    if bot_response is not None:
        resp = bot_response
    else:
        # ------------------------------------------------------------------
        # Fallback path: legacy command parser → aios-sys execution
        # ------------------------------------------------------------------
        plan = parse_natural_language(args.input)
        if plan.command == "chat":
            resp = chat_response(args.input)
        else:
            resp = run_system_command(plan, args.aios_root)

    sys.stdout.write(resp)
    if not resp.endswith("\n"):
        sys.stdout.write("\n")


if __name__ == "__main__":
    main()
