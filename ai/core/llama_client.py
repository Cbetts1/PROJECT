#!/usr/bin/env python3
"""ai/core/llama_client.py — LLaMA / mock AI inference client.

Backends
--------
mock   — always works; returns the prompt echoed back (useful for testing).
llama  — calls the llama-cli binary from llama.cpp.
"""
import argparse
import subprocess
import sys
from typing import Literal

Backend = Literal["llama", "mock"]


def run_llama(model_path: str, ctx: int, threads: int, prompt: str) -> str:
    """Call the llama-cli binary with the given parameters.

    The binary is looked up in PATH; the model file must exist at model_path.
    Returns the generated text, or an error message if the call fails.
    """
    llama_bin = None
    for candidate in ("llama-cli", "llama", "llama.cpp", "main"):
        result = subprocess.run(
            ["which", candidate], capture_output=True, text=True
        )
        if result.returncode == 0:
            llama_bin = candidate
            break

    if llama_bin is None:
        return (
            "[LLAMA] llama-cli binary not found in PATH.\n"
            "Install llama.cpp and ensure the binary is on PATH, then set\n"
            "AI_BACKEND=llama and LLAMA_MODEL_PATH in etc/aios.conf."
        )

    try:
        out = subprocess.check_output(
            [
                llama_bin,
                "-m", model_path,
                "--n-predict", "256",
                "--temp", "0.7",
                "--ctx-size", str(ctx),
                "--threads", str(threads),
                "-p", prompt,
            ],
            stderr=subprocess.DEVNULL,
            text=True,
        )
        return out.strip() or "[LLAMA] (empty response)"
    except subprocess.CalledProcessError as exc:
        return f"[LLAMA] Inference failed (exit {exc.returncode})"
    except FileNotFoundError:
        return f"[LLAMA] Binary not found: {llama_bin}"


def run_mock(prompt: str) -> str:
    """Mock backend — always works, returns a canned response."""
    return f"[MOCK AI] You said: {prompt}"


def main() -> None:
    parser = argparse.ArgumentParser(description="LLaMA inference client")
    parser.add_argument("--backend",    default="mock",
                        choices=["llama", "mock"])
    parser.add_argument("--model-path", default="",
                        help="Path to .gguf model (llama backend)")
    parser.add_argument("--ctx",        type=int, default=4096,
                        help="Context size in tokens")
    parser.add_argument("--threads",    type=int, default=4,
                        help="Number of CPU threads")
    parser.add_argument("--prompt",     required=True,
                        help="The prompt text to send")
    args = parser.parse_args()

    if args.backend == "llama":
        out = run_llama(args.model_path, args.ctx, args.threads, args.prompt)
    else:
        out = run_mock(args.prompt)

    sys.stdout.write(out)
    if not out.endswith("\n"):
        sys.stdout.write("\n")


if __name__ == "__main__":
    main()
