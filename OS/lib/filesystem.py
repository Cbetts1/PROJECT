#!/usr/bin/env python3
"""
filesystem.py — AURA Filesystem Interface for AIOSCPU
© 2026 Chris Betts | AIOSCPU Official | AI-generated, fully legal

Provides OS_ROOT-isolated, audited read/write access to all files,
directories, and log sinks under the AIOSCPU virtual filesystem root.

All operations are logged to OS_ROOT/var/log/aura.log for auditability.

CLI usage (called by os-shell and other scripts):
    python3 filesystem.py read    <path>
    python3 filesystem.py write   <path> <text…>
    python3 filesystem.py append  <path> <text…>
    python3 filesystem.py list    [path]
    python3 filesystem.py exists  <path>
    python3 filesystem.py stat    <path>
    python3 filesystem.py log     <path> <message…>

Environment:
    OS_ROOT   Root of the AIOSCPU virtual filesystem (default: /).
              All paths are resolved relative to this root and must
              remain inside it — attempts to escape are rejected.
"""

import os
import sys
import stat as _stat
import hashlib
import hmac
from datetime import datetime, timezone
from pathlib import Path

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

_OS_ROOT: Path = Path(os.environ.get("OS_ROOT", "/")).resolve()
_AURA_LOG: str = "var/log/aura.log"
_HMAC_LOG: str = "var/log/aura.log.hmac"

# HMAC key: read from OS_ROOT/etc/aura/audit.key (created on first use).
# The key is never written to the audit log itself.
_HMAC_KEY_FILE: str = "etc/aura/audit.key"


# ---------------------------------------------------------------------------
# HMAC key management
# ---------------------------------------------------------------------------

def _get_hmac_key() -> bytes:
    """Return the HMAC signing key, generating it on first use."""
    key_path = _OS_ROOT / _HMAC_KEY_FILE
    try:
        key_path.parent.mkdir(parents=True, exist_ok=True)
        if key_path.exists():
            return key_path.read_bytes()
        # Generate a 32-byte random key
        key = os.urandom(32)
        key_path.write_bytes(key)
        key_path.chmod(0o600)
        return key
    except OSError:
        # If key file is inaccessible, use a deterministic fallback (no signing)
        return b""


def _hmac_entry(message: str, prev_hmac: str) -> str:
    """Compute HMAC-SHA256(key, prev_hmac + message) for chained log integrity."""
    key = _get_hmac_key()
    if not key:
        return ""
    data = (prev_hmac + message).encode("utf-8")
    return hmac.new(key, data, hashlib.sha256).hexdigest()


def _last_hmac() -> str:
    """Return the last HMAC value from the rolling HMAC chain file."""
    hmac_path = _OS_ROOT / _HMAC_LOG
    try:
        lines = hmac_path.read_text(encoding="utf-8").splitlines()
        for line in reversed(lines):
            line = line.strip()
            if line:
                # Format: <timestamp> <hmac-hex>
                parts = line.split()
                if len(parts) >= 2:
                    return parts[-1]
    except OSError:
        pass
    return ""


def _write_hmac_chain(message: str, entry_hmac: str) -> None:
    """Append an HMAC chain entry to the rolling HMAC log."""
    if not entry_hmac:
        return
    hmac_path = _OS_ROOT / _HMAC_LOG
    try:
        hmac_path.parent.mkdir(parents=True, exist_ok=True)
        with hmac_path.open("a", encoding="utf-8") as fh:
            fh.write(f"[{_ts()}] {entry_hmac}\n")
    except OSError:
        pass


# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------

def _ts() -> str:
    """Return the current UTC time as an ISO-8601 string."""
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def _write_aura_log(message: str) -> None:
    """Append a timestamped, HMAC-signed line to the AURA audit log (best-effort)."""
    try:
        log_file = _OS_ROOT / _AURA_LOG
        log_file.parent.mkdir(parents=True, exist_ok=True)
        entry = f"[{_ts()}] [filesystem] {message}\n"
        with log_file.open("a", encoding="utf-8") as fh:
            fh.write(entry)
        # Maintain rolling HMAC chain for log integrity verification
        prev = _last_hmac()
        entry_hmac = _hmac_entry(entry.rstrip("\n"), prev)
        _write_hmac_chain(message, entry_hmac)
    except OSError:
        pass  # Log failures must never crash callers


def _resolve(path: str) -> Path:
    """Resolve *path* relative to OS_ROOT and verify it stays inside.

    Absolute paths have their leading ``/`` stripped so they are treated
    as relative to OS_ROOT (POSIX chroot-style semantics).

    Raises:
        PermissionError: if the resolved path escapes OS_ROOT.
    """
    raw = Path(path)
    if raw.is_absolute():
        # Strip the leading separator and re-join under OS_ROOT
        parts = raw.parts[1:]  # drop leading '/'
        resolved = (_OS_ROOT / Path(*parts) if parts else _OS_ROOT).resolve()
    else:
        resolved = (_OS_ROOT / raw).resolve()

    try:
        resolved.relative_to(_OS_ROOT)
    except ValueError:
        raise PermissionError(
            f"Access denied: '{path}' resolves outside OS_ROOT ({_OS_ROOT})"
        )
    return resolved


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

def fs_read(path: str) -> str:
    """Read a text file within OS_ROOT and return its contents.

    Args:
        path: Path relative to (or absolute under) OS_ROOT.

    Returns:
        File contents as a string.

    Raises:
        PermissionError: path escapes OS_ROOT.
        FileNotFoundError: file does not exist.
    """
    target = _resolve(path)
    _write_aura_log(f"READ {target}")
    return target.read_text(encoding="utf-8", errors="replace")


def fs_write(path: str, content: str) -> None:
    """Overwrite (or create) a text file within OS_ROOT.

    Args:
        path:    Path relative to (or absolute under) OS_ROOT.
        content: Text to write (existing content is replaced).

    Raises:
        PermissionError: path escapes OS_ROOT.
    """
    target = _resolve(path)
    target.parent.mkdir(parents=True, exist_ok=True)
    _write_aura_log(f"WRITE {target}")
    target.write_text(content, encoding="utf-8")


def fs_append(path: str, content: str) -> None:
    """Append *content* to a text file within OS_ROOT.

    The file is created if it does not exist.

    Args:
        path:    Path relative to (or absolute under) OS_ROOT.
        content: Text to append.

    Raises:
        PermissionError: path escapes OS_ROOT.
    """
    target = _resolve(path)
    target.parent.mkdir(parents=True, exist_ok=True)
    _write_aura_log(f"APPEND {target}")
    with target.open("a", encoding="utf-8") as fh:
        fh.write(content)


def fs_list(path: str = ".") -> list:
    """List the contents of a directory within OS_ROOT.

    Args:
        path: Directory path relative to (or absolute under) OS_ROOT.
              Defaults to OS_ROOT itself.

    Returns:
        Sorted list of dicts, each with keys: ``name``, ``type``
        (``"file"`` or ``"dir"``), ``size`` (bytes; 0 for directories).

    Raises:
        PermissionError:   path escapes OS_ROOT.
        NotADirectoryError: path exists but is not a directory.
    """
    target = _resolve(path)
    _write_aura_log(f"LIST {target}")
    if not target.is_dir():
        raise NotADirectoryError(f"Not a directory: {target}")
    entries = []
    for item in sorted(target.iterdir()):
        try:
            size = item.stat().st_size if item.is_file() else 0
            ftype = "dir" if item.is_dir() else "file"
        except OSError:
            size = 0
            ftype = "unknown"
        entries.append({"name": item.name, "type": ftype, "size": size})
    return entries


def fs_exists(path: str) -> bool:
    """Return ``True`` if *path* exists within OS_ROOT.

    Returns ``False`` (rather than raising) for paths outside OS_ROOT.
    """
    try:
        return _resolve(path).exists()
    except PermissionError:
        return False


def fs_stat(path: str) -> dict:
    """Return metadata for *path* within OS_ROOT.

    Returns:
        Dict with keys: ``path``, ``size``, ``mtime``, ``isdir``,
        ``isfile``.

    Raises:
        PermissionError:    path escapes OS_ROOT.
        FileNotFoundError:  path does not exist.
    """
    target = _resolve(path)
    _write_aura_log(f"STAT {target}")
    st = target.stat()
    return {
        "path": str(target),
        "size": st.st_size,
        "mtime": st.st_mtime,
        "isdir": _stat.S_ISDIR(st.st_mode),
        "isfile": _stat.S_ISREG(st.st_mode),
    }


def fs_log(logpath: str, message: str) -> None:
    """Append a timestamped *message* to a log file within OS_ROOT.

    This is the canonical method for AURA subsystems to write auditable
    log entries.  The message is prefixed with an ISO-8601 UTC timestamp
    and a trailing newline is appended automatically.

    Args:
        logpath: Path relative to (or absolute under) OS_ROOT.
        message: Log message text.

    Raises:
        PermissionError: path escapes OS_ROOT.
    """
    fs_append(logpath, f"[{_ts()}] {message}\n")


# ---------------------------------------------------------------------------
# CLI dispatcher
# ---------------------------------------------------------------------------

def _cli() -> int:  # noqa: C901
    """Command-line interface — dispatches argv to public API functions."""
    if len(sys.argv) < 2:
        print(__doc__, file=sys.stderr)
        return 1

    verb = sys.argv[1].lower()

    try:
        if verb == "read":
            if len(sys.argv) < 3:
                print("Usage: filesystem.py read <path>", file=sys.stderr)
                return 1
            print(fs_read(sys.argv[2]), end="")

        elif verb == "write":
            if len(sys.argv) < 4:
                print("Usage: filesystem.py write <path> <text…>", file=sys.stderr)
                return 1
            fs_write(sys.argv[2], " ".join(sys.argv[3:]))

        elif verb == "append":
            if len(sys.argv) < 4:
                print("Usage: filesystem.py append <path> <text…>  (appends text + newline)", file=sys.stderr)
                return 1
            # CLI append always adds a trailing newline so each call produces a new line.
            fs_append(sys.argv[2], " ".join(sys.argv[3:]) + "\n")

        elif verb == "list":
            target = sys.argv[2] if len(sys.argv) > 2 else "."
            entries = fs_list(target)
            for e in entries:
                marker = "/" if e["type"] == "dir" else " "
                print(f"{e['size']:>10}  {e['name']}{marker}")

        elif verb == "exists":
            if len(sys.argv) < 3:
                print("Usage: filesystem.py exists <path>", file=sys.stderr)
                return 1
            result = fs_exists(sys.argv[2])
            print("true" if result else "false")
            return 0 if result else 1

        elif verb == "stat":
            if len(sys.argv) < 3:
                print("Usage: filesystem.py stat <path>", file=sys.stderr)
                return 1
            info = fs_stat(sys.argv[2])
            for k, v in info.items():
                print(f"{k}: {v}")

        elif verb == "log":
            if len(sys.argv) < 4:
                print("Usage: filesystem.py log <path> <message…>", file=sys.stderr)
                return 1
            fs_log(sys.argv[2], " ".join(sys.argv[3:]))

        else:
            print(f"Unknown verb: {verb!r}", file=sys.stderr)
            print("Verbs: read  write  append  list  exists  stat  log", file=sys.stderr)
            return 1

    except PermissionError as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 1
    except FileNotFoundError as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 1
    except NotADirectoryError as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 1
    except (OSError, ValueError) as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 1

    return 0


if __name__ == "__main__":
    sys.exit(_cli())
