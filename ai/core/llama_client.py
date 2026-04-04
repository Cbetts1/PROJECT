#!/usr/bin/env python3
"""ai/core/llama_client.py — LLaMA / mock AI inference client.

Backends
--------
mock   — always works; returns context-aware guidance (no model required).
llama  — calls the llama-cli binary from llama.cpp.
"""
import argparse
import subprocess
import sys
from typing import Iterator, Literal, Optional

Backend = Literal["llama", "mock"]


def _find_llama_bin() -> Optional[str]:
    """Return the first llama binary found in PATH, or None."""
    for candidate in ("llama-cli", "llama", "llama.cpp", "main"):
        result = subprocess.run(
            ["which", candidate], capture_output=True, text=True
        )
        if result.returncode == 0:
            return candidate
    return None


def run_llama(model_path: str, ctx: int, threads: int, prompt: str) -> str:
    """Call the llama-cli binary with the given parameters.

    The binary is looked up in PATH; the model file must exist at model_path.
    Returns the generated text, or an error message if the call fails.
    """
    llama_bin = _find_llama_bin()

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


def stream_llama(model_path: str, ctx: int, threads: int, prompt: str) -> Iterator[str]:
    """Stream tokens from llama-cli line by line.

    Yields each line as it is produced by the subprocess so the caller
    can print it immediately, giving the user a live streaming experience.
    Falls back to a single-shot mock line if the binary is unavailable.
    """
    llama_bin = _find_llama_bin()

    if llama_bin is None:
        yield (
            "[LLAMA] llama-cli binary not found in PATH.\n"
            "Install llama.cpp and ensure the binary is on PATH, then set\n"
            "AI_BACKEND=llama and LLAMA_MODEL_PATH in etc/aios.conf.\n"
        )
        return

    try:
        proc = subprocess.Popen(
            [
                llama_bin,
                "-m", model_path,
                "--n-predict", "256",
                "--temp", "0.7",
                "--ctx-size", str(ctx),
                "--threads", str(threads),
                "-p", prompt,
            ],
            stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL,
            text=True,
            bufsize=1,
        )
        assert proc.stdout is not None
        for line in proc.stdout:
            yield line
        proc.wait()
        if proc.returncode != 0:
            yield f"\n[LLAMA] Inference ended (exit {proc.returncode})\n"
    except FileNotFoundError:
        yield f"[LLAMA] Binary not found: {llama_bin}\n"


def run_mock(prompt: str) -> str:
    """Context-aware built-in assistant — helpful responses without a real LLM.

    Guides users through AIOS usage, answers common questions, and directs
    them to set up a proper LLM for full natural-language capability.
    """
    text = prompt.strip()
    lower = text.lower()

    # --- Greetings ---
    if any(lower == w or lower.startswith(w + " ") or lower.startswith(w + ",")
           for w in ("hello", "hi", "hey", "howdy", "sup")):
        return (
            "Hello! I'm AURA, your AIOS AI assistant.\n"
            "I'm running in built-in mode (no LLM model loaded yet).\n\n"
            "Quick commands to try:\n"
            "  status          — system health overview\n"
            "  ls              — list files in the OS jail\n"
            "  ping 8.8.8.8    — test network connectivity\n"
            "  repair          — run self-repair\n"
            "  help            — show all available commands\n\n"
            "Tip: For full AI understanding, add a .gguf model to llama_model/\n"
            "     and run: bash build/build.sh --target hosted\n"
            "     See docs/AI_MODEL_SETUP.md for step-by-step instructions."
        )

    # --- AI / model setup queries ---
    if any(w in lower for w in ("model", "llama", "llm", "gpt", "ollama",
                                "gguf", "inference", "ai backend")):
        return (
            "AIOS AI Model Setup:\n"
            "1. Download a GGUF model — recommended options:\n"
            "     • Llama-3.2-3B-Instruct-Q4_K_M.gguf  (runs on 6 GB RAM)\n"
            "     • Llama-3.1-7B-Instruct-Q4_K_M.gguf  (runs on 8 GB RAM)\n"
            "   from: https://huggingface.co/bartowski\n"
            "2. Place the .gguf file in:  llama_model/\n"
            "3. Build llama.cpp:          bash build/build.sh --target hosted\n"
            "4. Edit etc/aios.conf and set:\n"
            "     AI_BACKEND=llama\n"
            "     LLAMA_MODEL_PATH=/full/path/to/model.gguf\n"
            "5. Restart AIOS:             bash bin/aios\n\n"
            "Full guide: docs/AI_MODEL_SETUP.md"
        )

    # --- How-to questions ---
    if lower.startswith("how"):
        if any(w in lower for w in ("install", "set up", "setup", "start",
                                    "begin", "get started")):
            return (
                "AIOS Quick Install:\n"
                "  git clone https://github.com/Cbetts1/PROJECT.git\n"
                "  cd PROJECT\n"
                "  bash install.sh\n"
                "  bash bin/aios\n\n"
                "Platform-specific instructions: INSTALL.md\n"
                "Android/Termux: pkg install git python && then the steps above."
            )
        if any(w in lower for w in ("use", "work", "run", "command", "do")):
            return (
                "How to use AIOS:\n"
                "  • Type built-in commands (ls, status, ping 8.8.8.8, repair)\n"
                "  • Or use natural language (show my files, check system health)\n"
                "  • Type 'help' to see all commands with descriptions\n"
                "  • Type 'sys' to drop into the real OS shell\n"
                "  • Type 'exit' to quit\n\n"
                "The AI backend classifies your intent and routes to the right handler.\n"
                "Commands you can use right now: ls, cat, mkdir, rm, ps, ping,\n"
                "ifconfig, status, uptime, disk, repair, mem.set, mem.get, recall."
            )
        if any(w in lower for w in ("bridge", "connect", "android", "ios",
                                    "mirror", "device")):
            return (
                "Cross-OS Bridge Setup:\n"
                "  Android (USB):  enable USB debugging, then: bridge.detect\n"
                "                  mirror.mount android\n"
                "  iOS:            install libimobiledevice, run: os-bridge ios pair\n"
                "                  then: os-mirror mount ios\n"
                "  Remote Linux:   os-mirror mount ssh user@host\n\n"
                "Packages needed:\n"
                "  Android: adb (android-tools)\n"
                "  iOS:     libimobiledevice, ifuse, ideviceinfo\n"
                "  Remote:  ssh, sshfs\n\n"
                "Full guide: docs/INSTALL.md § Cross-OS Bridge Dependencies"
            )

    # --- What-is questions ---
    if lower.startswith("what"):
        if any(w in lower for w in ("aios", "this", "project")):
            return (
                "AIOS-Lite is an AI-augmented portable operating system.\n\n"
                "It runs on top of any POSIX system — Android (Termux), Linux,\n"
                "macOS, or Raspberry Pi — without modifying the host OS.\n\n"
                "Key features:\n"
                "  • AI shell with natural-language command understanding\n"
                "  • AURA cognitive layer (memory, health, repair, LLM)\n"
                "  • Cross-device bridge (iOS, Android, remote Linux via SSH)\n"
                "  • Filesystem mirror: browse any connected device\n"
                "  • Self-repair: automatically recreates broken dirs/files\n"
                "  • Plugin system: drop scripts into OS/lib/aura-mods/\n\n"
                "See README.md for the full overview."
            )
        if "aura" in lower:
            return (
                "AURA is the AIOS cognitive layer — your AI assistant.\n\n"
                "It provides:\n"
                "  • Intent classification (understands what you want)\n"
                "  • HealthBot: system status, uptime, disk, services\n"
                "  • LogBot: read and write OS logs\n"
                "  • RepairBot: detect and fix broken dirs/files\n"
                "  • Hybrid memory: context window + key-value + semantic\n"
                "  • LLM inference (when llama.cpp + model is configured)\n\n"
                "Commands: status, repair, log, mem.set <k> <v>, mem.get <k>"
            )
        if any(w in lower for w in ("command", "can", "do")):
            return (
                "AIOS understands these commands:\n"
                "  fs:      ls [path]  cat <file>  mkdir <dir>  rm <path>\n"
                "  process: ps  kill <pid>\n"
                "  network: ping <host>  ifconfig\n"
                "  health:  status  uptime  disk  services\n"
                "  memory:  mem.set <k> <v>  mem.get <k>  recall <k>\n"
                "  repair:  repair\n"
                "  shell:   sys (real OS shell)\n"
                "  meta:    help  exit\n\n"
                "Type any of these, or use plain English and AURA will try to\n"
                "figure out what you mean."
            )

    # --- Help / commands overview ---
    if any(w in lower for w in ("help", "commands", "what can", "options")):
        return (
            "AIOS Built-in Commands:\n"
            "  ls [path]           list files (OS jail)\n"
            "  cat <file>          show file contents\n"
            "  mkdir <dir>         create directory\n"
            "  rm <path>           remove file or directory\n"
            "  ps                  list running processes\n"
            "  kill <pid>          terminate a process\n"
            "  ping <host>         test network (default: 8.8.8.8)\n"
            "  ifconfig            show network interfaces\n"
            "  status              full system health check\n"
            "  uptime              system uptime\n"
            "  disk                disk usage\n"
            "  repair              run AURA self-repair\n"
            "  mem.set <k> <v>     store a value in memory\n"
            "  mem.get <k>         retrieve a stored value\n"
            "  recall <k>          same as mem.get\n"
            "  sys                 drop into the real OS shell\n"
            "  exit / quit         exit AIOS\n\n"
            "For full AI: set up llama.cpp + a .gguf model (docs/AI_MODEL_SETUP.md)."
        )

    # --- Install / setup ---
    if any(w in lower for w in ("install", "setup", "configure", "config")):
        return (
            "AIOS Setup Checklist:\n"
            "  [1] git clone + cd PROJECT\n"
            "  [2] bash install.sh\n"
            "  [3] bash bin/aios          (AI shell — you are here!)\n"
            "  [4] Add .gguf model to llama_model/  (optional, for full AI)\n"
            "  [5] bash build/build.sh --target hosted  (builds llama.cpp)\n"
            "  [6] Edit etc/aios.conf: AI_BACKEND=llama\n\n"
            "Details: INSTALL.md  |  docs/AI_MODEL_SETUP.md"
        )

    # --- Default helpful fallback ---
    return (
        f"AURA (built-in mode): I received \"{text}\"\n\n"
        "I'm running without a language model, so I can answer common questions\n"
        "and guide you through AIOS, but I can't do full natural-language reasoning.\n\n"
        "Try asking:\n"
        "  'what is AIOS'          — project overview\n"
        "  'how do I install'       — setup guide\n"
        "  'what commands are there' — command list\n"
        "  'how do I set up the AI'  — LLM setup guide\n\n"
        "Or run a command directly: ls, status, ping, repair, help"
    )


def stream_mock(prompt: str) -> Iterator[str]:
    """Streaming mock — yields the response line by line."""
    response = run_mock(prompt)
    for line in response.splitlines(keepends=True):
        yield line
    if not response.endswith("\n"):
        yield "\n"


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
    parser.add_argument("--stream",     action="store_true",
                        help="Stream output token by token")
    args = parser.parse_args()

    if args.stream:
        if args.backend == "llama":
            for chunk in stream_llama(args.model_path, args.ctx, args.threads, args.prompt):
                sys.stdout.write(chunk)
                sys.stdout.flush()
        else:
            for chunk in stream_mock(args.prompt):
                sys.stdout.write(chunk)
                sys.stdout.flush()
    else:
        if args.backend == "llama":
            out = run_llama(args.model_path, args.ctx, args.threads, args.prompt)
        else:
            out = run_mock(args.prompt)

        sys.stdout.write(out)
        if not out.endswith("\n"):
            sys.stdout.write("\n")


if __name__ == "__main__":
    main()
