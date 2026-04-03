#!/usr/bin/env python3
"""ai/core/ai_backend.py — AI dispatch backend for AIOS.

Called by lib/aura-ai.sh.  Routes natural language through the Intent Engine
and AI Core Router, which dispatch to the correct OS subsystem.

Pipeline
--------
  user_input
      │
      ▼
  IntentEngine.classify()     (intent_engine.py)
      │
      ▼
  Router.dispatch(intent)     (router.py)
      │
      ├─ COMMAND/QUERY/ACTION → bin/aios-sys
      ├─ REPAIR               → repair analyser
      ├─ WORKFLOW             → workflow planner
      └─ CHAT                 → LLaMA / mock AI
      │
      ▼
  stdout

Fallback: if the Router or Intent Engine is unavailable, falls back to the
legacy commands.py path so existing callers continue to work.

Usage:
    python3 ai_backend.py --input "<text>" --os-root <path> --aios-root <path>
"""
import argparse
import os
import sys

# Allow importing sibling modules regardless of the current working directory.
_HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, _HERE)


def main() -> None:
    parser = argparse.ArgumentParser(description="AIOS AI dispatch backend")
    parser.add_argument("--input",      required=True, help="User input string")
    parser.add_argument("--os-root",    required=True, help="OS_ROOT jail path")
    parser.add_argument("--aios-root",  required=True, help="AIOS project root")
    args = parser.parse_args()

    resp = _dispatch(args.input, args.os_root, args.aios_root)
    sys.stdout.write(resp)
    if not resp.endswith("\n"):
        sys.stdout.write("\n")


def _dispatch(user_input: str, os_root: str, aios_root: str) -> str:
    """Route *user_input* through the AI Core Router.

    Falls back to the legacy commands.py path if the router is unavailable.
    """
    try:
        from router import Router, RouterContext
        ctx = RouterContext(os_root=os_root, aios_root=aios_root)
        router = Router(ctx)
        resp = router.route(user_input)
        return resp.output
    except ImportError:
        pass

    # Legacy fallback (commands.py + llama_client.py)
    from commands import parse_natural_language
    from llama_client import run_mock
    import subprocess

    plan = parse_natural_language(user_input)
    if plan.command == "chat":
        return run_mock(user_input)

    aios_sys = os.path.join(aios_root, "bin", "aios-sys")
    env = dict(os.environ)
    env["AIOS_ROOT"] = aios_root
    env["OS_ROOT"]   = os_root
    try:
        out = subprocess.check_output(
            [aios_sys, "--", plan.command] + plan.args,
            stderr=subprocess.STDOUT,
            text=True,
            env=env,
        )
        return out
    except subprocess.CalledProcessError as exc:
        return f"[ERROR] {exc.output}"
    except FileNotFoundError:
        return f"[ERROR] bin/aios-sys not found at {aios_sys}"


if __name__ == "__main__":
    main()
