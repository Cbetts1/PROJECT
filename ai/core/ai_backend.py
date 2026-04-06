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
            HealthBot  — health / system status
            LogBot     — log reading / writing
            RepairBot  — self-repair / reinstall
            UpgradeBot — package / system upgrades
            ProcessBot — process listing / termination
            NetworkBot — ping / ifconfig / discover
            MemoryBot  — key-value and semantic memory
        → [fallback] parse_natural_language()  ← legacy structured commands
        → [fallback] run_mock()            ← chat / LLaMA

Usage:
    python3 ai_backend.py --input "<text>" --os-root <path> --aios-root <path>
    python3 ai_backend.py --input "<text>" --os-root <path> --aios-root <path> --json-output
"""
import argparse
import datetime
import json
import os
import subprocess
import sys
import time

# Allow importing sibling modules regardless of the current working directory.
_HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, _HERE)

from commands import parse_natural_language  # noqa: E402  (legacy fallback)
from llama_client import run_mock, stream_llama, stream_mock, autodetect_model  # noqa: E402
from intent_engine import IntentEngine       # noqa: E402
from router import Router                    # noqa: E402


def log_query(os_root: str, user_input: str, intent_str: str, confidence: float,
              response_length: int, duration_ms: int) -> None:
    """Log AI query to OS/var/log/ai-queries.log in structured JSON format."""
    log_dir = os.path.join(os_root, "var", "log")
    os.makedirs(log_dir, exist_ok=True)
    log_file = os.path.join(log_dir, "ai-queries.log")
    
    ts = datetime.datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%SZ")
    
    # Escape special characters for JSON
    escaped_input = user_input.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n")
    
    entry = {
        "ts": ts,
        "level": "INFO",
        "component": "ai-backend",
        "input": escaped_input,
        "intent": intent_str,
        "confidence": round(confidence, 2),
        "response_length": response_length,
        "duration_ms": duration_ms,
    }
    
    try:
        with open(log_file, "a") as f:
            f.write(json.dumps(entry) + "\n")
    except OSError:
        pass  # Silently ignore logging errors


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


def chat_response_stream(user_input: str, os_root: str = "", aios_root: str = ""):
    """Yield chat response tokens as they arrive (streaming).

    When AI_BACKEND=llama and a model is available, delegates to
    stream_llama() for live token output.  Falls back to stream_mock()
    otherwise.
    """
    backend = os.environ.get("AI_BACKEND", "mock")
    if backend == "llama":
        model_path = os.environ.get("LLAMA_MODEL_PATH", "")
        if not model_path and os_root:
            model_path = autodetect_model(os_root) or ""
        if model_path and os.path.isfile(model_path):
            ctx     = int(os.environ.get("LLAMA_CTX_SIZE",  "4096"))
            threads = int(os.environ.get("LLAMA_THREADS",   "4"))
            yield from stream_llama(model_path, ctx, threads, user_input)
            return
    yield from stream_mock(user_input)


def main() -> None:
    parser = argparse.ArgumentParser(description="AIOS AI dispatch backend")
    parser.add_argument("--input",       required=True, help="User input string")
    parser.add_argument("--os-root",     required=True, help="OS_ROOT jail path")
    parser.add_argument("--aios-root",   required=True, help="AIOS project root")
    parser.add_argument("--json-output", action="store_true",
                        help="Wrap response in JSON format")
    parser.add_argument("--stream",      action="store_true",
                        help="Stream tokens as they arrive (chat path only)")
    args = parser.parse_args()

    start_time = time.time()

    # ------------------------------------------------------------------
    # Primary path: IntentEngine → Router → Bot
    # ------------------------------------------------------------------
    engine = IntentEngine()
    intent = engine.classify(args.input)
    intent_str = f"{intent.category}.{intent.action}"

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
            if args.stream and not args.json_output:
                # Streaming: print tokens as they arrive; skip buffered response
                chunk = ""
                for chunk in chat_response_stream(
                    args.input, os_root=args.os_root, aios_root=args.aios_root
                ):
                    sys.stdout.write(chunk)
                    sys.stdout.flush()
                if not chunk.endswith("\n"):
                    sys.stdout.write("\n")
                return
            resp = chat_response(args.input)
        else:
            resp = run_system_command(plan, args.aios_root)

    # Calculate duration
    duration_ms = int((time.time() - start_time) * 1000)

    # Log the query
    log_query(
        os_root=args.os_root,
        user_input=args.input,
        intent_str=intent_str,
        confidence=intent.confidence,
        response_length=len(resp),
        duration_ms=duration_ms,
    )

    # Output response
    if args.json_output:
        output = {
            "status": "ok",
            "response": resp.rstrip("\n"),
            "intent": intent_str,
        }
        sys.stdout.write(json.dumps(output) + "\n")
    else:
        sys.stdout.write(resp)
        if not resp.endswith("\n"):
            sys.stdout.write("\n")


if __name__ == "__main__":
    main()
