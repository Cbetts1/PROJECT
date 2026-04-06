#!/usr/bin/env python3
"""ai/voice/whisper_input.py — On-device voice input for AIOS-Lite.

Records audio from the microphone, transcribes it using OpenAI Whisper
(fully on-device, no network required), and pipes the transcript into the
AIOS IntentEngine → Router pipeline.

Two operating modes:
  1. Single-shot (default):  record for N seconds, transcribe, print result.
  2. Continuous mode:         loop until Ctrl-C, feeding each utterance to
                               the AIOS AI backend.

Dependencies (install with pip):
  openai-whisper  — local Whisper model (CPU-only, no GPU needed)
  sounddevice     — microphone capture
  numpy           — audio buffer

Usage:
  python3 ai/voice/whisper_input.py [--model tiny] [--duration 5] [--continuous]
  python3 ai/voice/whisper_input.py --help

The model is downloaded automatically on first use (~40 MB for 'tiny').
For the Samsung Galaxy S21 FE's CPU constraints, use --model tiny or small.
"""
from __future__ import annotations

import argparse
import os
import sys
import time
from typing import Optional

# ---------------------------------------------------------------------------
# Dependency checks (graceful degradation)
# ---------------------------------------------------------------------------
_WHISPER_AVAILABLE  = False
_SOUNDDEVICE_AVAILABLE = False
_NUMPY_AVAILABLE    = False

try:
    import whisper as _whisper
    _WHISPER_AVAILABLE = True
except ImportError:
    pass

try:
    import sounddevice as _sd
    _SOUNDDEVICE_AVAILABLE = True
except ImportError:
    pass

try:
    import numpy as _np
    _NUMPY_AVAILABLE = True
except ImportError:
    pass

# ---------------------------------------------------------------------------
# AI pipeline (optional — falls back to printing the transcript)
# ---------------------------------------------------------------------------
_HERE     = os.path.dirname(os.path.abspath(__file__))
_AI_CORE  = os.path.join(os.path.dirname(_HERE), "core")
_OS_ROOT  = os.environ.get("OS_ROOT", "")
_AIOS_HOME = os.environ.get("AIOS_HOME", os.path.dirname(os.path.dirname(_HERE)))

sys.path.insert(0, _AI_CORE)

_router_available = False
try:
    from intent_engine import IntentEngine  # type: ignore
    from router import Router               # type: ignore
    _router_available = True
except ImportError:
    pass


# ---------------------------------------------------------------------------
# WhisperInput
# ---------------------------------------------------------------------------

class WhisperInput:
    """On-device speech-to-text input using OpenAI Whisper.

    Args:
        model_name:   Whisper model size ('tiny', 'base', 'small', 'medium').
                      'tiny' is recommended for resource-constrained devices.
        sample_rate:  Audio sample rate in Hz (default: 16000, required by Whisper).
        language:     Force a language code (e.g. 'en'). None = auto-detect.
        os_root:      Path to OS_ROOT for pipeline dispatch.
    """

    def __init__(
        self,
        model_name: str = "tiny",
        sample_rate: int = 16000,
        language: Optional[str] = "en",
        os_root: str = "",
    ) -> None:
        self.model_name  = model_name
        self.sample_rate = sample_rate
        self.language    = language
        self.os_root     = os_root or _OS_ROOT
        self._model      = None
        self._router     = None
        self._ie         = None

    def _load_model(self) -> None:
        if not _WHISPER_AVAILABLE:
            raise ImportError(
                "openai-whisper not installed. Run: pip install openai-whisper"
            )
        if self._model is None:
            print(f"[voice] Loading Whisper model '{self.model_name}' …", flush=True)
            self._model = _whisper.load_model(self.model_name)
            print(f"[voice] Model ready.", flush=True)

    def _load_pipeline(self) -> None:
        if _router_available and self._router is None:
            self._ie     = IntentEngine()
            self._router = Router(os_root=self.os_root, aios_root=_AIOS_HOME)

    def record(self, duration_sec: float = 5.0) -> Optional["_np.ndarray"]:
        """Record *duration_sec* seconds of audio from the default microphone.

        Returns:
            1-D float32 numpy array at ``self.sample_rate``, or None on error.
        """
        if not _SOUNDDEVICE_AVAILABLE:
            print("[voice] sounddevice not installed. Run: pip install sounddevice")
            return None
        if not _NUMPY_AVAILABLE:
            print("[voice] numpy not installed. Run: pip install numpy")
            return None
        frames = int(self.sample_rate * duration_sec)
        print(f"[voice] Recording for {duration_sec}s …", end=" ", flush=True)
        audio = _sd.rec(frames, samplerate=self.sample_rate, channels=1,
                        dtype="float32")
        _sd.wait()
        print("done.", flush=True)
        return audio.flatten()

    def transcribe(self, audio: "_np.ndarray") -> str:
        """Transcribe a raw audio array.  Returns the transcript string."""
        self._load_model()
        kwargs = {"language": self.language} if self.language else {}
        result = self._model.transcribe(audio, fp16=False, **kwargs)
        return result.get("text", "").strip()

    def process(self, text: str) -> str:
        """Route a transcript through the AIOS AI pipeline."""
        if not text:
            return ""
        self._load_pipeline()
        if self._router and self._ie:
            intent = self._ie.classify(text)
            response = self._router.dispatch(intent)
            if response is not None:
                return response
        # Fallback: just echo the transcript
        return f"[voice] Transcribed: {text}"

    def run_once(self, duration_sec: float = 5.0) -> str:
        """Record, transcribe, and process one utterance."""
        audio = self.record(duration_sec)
        if audio is None:
            return "[voice] Recording failed"
        transcript = self.transcribe(audio)
        if not transcript:
            return "[voice] (no speech detected)"
        print(f"[voice] Transcript: {transcript}", flush=True)
        return self.process(transcript)

    def run_continuous(self, duration_sec: float = 5.0) -> None:
        """Continuously record and process utterances until Ctrl-C."""
        print("[voice] Continuous mode. Press Ctrl-C to stop.", flush=True)
        try:
            while True:
                result = self.run_once(duration_sec)
                if result:
                    print(result, flush=True)
                time.sleep(0.2)
        except KeyboardInterrupt:
            print("\n[voice] Stopped.", flush=True)


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

def main() -> None:
    parser = argparse.ArgumentParser(
        description="AIOS-Lite Voice Input (on-device Whisper)",
        formatter_class=argparse.ArgumentDefaultsHelpFormatter,
    )
    parser.add_argument("--model",      default="tiny",
                        choices=["tiny", "base", "small", "medium", "large"],
                        help="Whisper model size")
    parser.add_argument("--duration",   type=float, default=5.0,
                        help="Recording duration in seconds")
    parser.add_argument("--continuous", action="store_true",
                        help="Loop continuously until Ctrl-C")
    parser.add_argument("--language",   default="en",
                        help="Language code (empty = auto-detect)")
    parser.add_argument("--no-pipeline", action="store_true",
                        help="Print transcript only; skip AIOS routing")
    args = parser.parse_args()

    if not _WHISPER_AVAILABLE:
        print("ERROR: openai-whisper not installed.", file=sys.stderr)
        print("  Install with: pip install openai-whisper", file=sys.stderr)
        sys.exit(1)
    if not _SOUNDDEVICE_AVAILABLE:
        print("ERROR: sounddevice not installed.", file=sys.stderr)
        print("  Install with: pip install sounddevice", file=sys.stderr)
        sys.exit(1)

    os_root = _OS_ROOT if not args.no_pipeline else ""
    vi = WhisperInput(
        model_name=args.model,
        language=args.language or None,
        os_root=os_root,
    )

    if args.continuous:
        vi.run_continuous(duration_sec=args.duration)
    else:
        result = vi.run_once(duration_sec=args.duration)
        print(result)


if __name__ == "__main__":
    main()
