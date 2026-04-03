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


def _resolve_model_path(model_path: str) -> str:
    """Resolve model_path to an actual .gguf file.

    If model_path points to a directory, auto-selects the first .gguf (or
    .bin) file found inside it.  Returns the resolved path, or an empty
    string if no model could be found.
    """
    import glob as _glob

    if not model_path:
        return ""

    if os.path.isfile(model_path):
        return model_path

    if os.path.isdir(model_path):
        # Prefer .gguf files; fall back to .bin
        for pattern in ("*.gguf", "*.bin"):
            hits = sorted(_glob.glob(os.path.join(model_path, pattern)))
            if hits:
                return hits[0]

    return ""


def run_llama(model_path: str, ctx: int, threads: int, prompt: str) -> str:
    """Call the llama-cli binary with the given parameters.

    The binary is looked up in PATH; the model file must exist at model_path.
    If model_path is a directory, the first .gguf file found is used.
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

    # Resolve directory → file if needed
    resolved = _resolve_model_path(model_path)
    if not resolved:
        return (
            f"[LLAMA] No model file found at '{model_path}'.\n"
            "Place a .gguf model in the llama_model/ directory, or set\n"
            "LLAMA_MODEL_PATH to the full path of your .gguf file in etc/aios.conf."
        )
    model_path = resolved

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
