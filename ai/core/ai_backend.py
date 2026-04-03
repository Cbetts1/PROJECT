#!/usr/bin/env python3
"""ai/core/ai_backend.py — AI dispatch backend for AIOS.

Called by lib/aura-ai.sh.  Translates natural language to a command (via
commands.py) and either:
  - executes it by delegating to bin/aios-sys (shell command path), or
  - returns a chat response from the AI model (llama_client.py).

Usage:
    python3 ai_backend.py --input "<text>" --os-root <path> --aios-root <path>
"""
import argparse
import os
import subprocess
import sys

# Allow importing sibling modules (fuzzy, commands, llama_client) regardless
# of the current working directory.
_HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, _HERE)

from commands import parse_natural_language          # noqa: E402
from llama_client import run_llama, run_mock         # noqa: E402


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
    """Return a chat response from the configured AI backend.

    Respects the AI_BACKEND, LLAMA_MODEL_PATH, LLAMA_CTX, and LLAMA_THREADS
    environment variables (set via etc/aios.conf or the calling shell).
    Falls back to the mock backend when the llama backend is selected but the
    binary or model is unavailable, or when environment variables contain
    invalid values.
    """
    backend = os.environ.get("AI_BACKEND", "mock").strip().lower()
    if backend == "llama":
        model_path = os.environ.get("LLAMA_MODEL_PATH", "").strip()
        try:
            ctx = int(os.environ.get("LLAMA_CTX", "4096"))
            threads = int(os.environ.get("LLAMA_THREADS", "4"))
        except ValueError:
            ctx = 4096
            threads = 4
        if model_path:
            ok, result = run_llama(model_path, ctx, threads, user_input)
            if ok:
                return result
    return run_mock(user_input)


def main() -> None:
    parser = argparse.ArgumentParser(description="AIOS AI dispatch backend")
    parser.add_argument("--input",      required=True, help="User input string")
    parser.add_argument("--os-root",    required=True, help="OS_ROOT jail path")
    parser.add_argument("--aios-root",  required=True, help="AIOS project root")
    args = parser.parse_args()

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
