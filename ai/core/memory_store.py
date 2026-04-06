#!/usr/bin/env python3
"""ai/core/memory_store.py — Encrypted persistent memory store for AIOS-Lite.

Provides a key-value and semantic memory store backed by SQLite with
AES-GCM encryption via the `cryptography` library (pure-Python, Termux-
compatible).  Falls back gracefully to plaintext SQLite if `cryptography`
is not installed.

The store is a drop-in replacement for the plaintext file-based store in
MemoryBot, exposing the same mem_set / mem_get / sem_set / sem_search API.

Encryption:
  - AES-256-GCM per record (nonce stored alongside ciphertext)
  - Encryption key derived from a 32-byte master key stored in
    OS_ROOT/etc/aura/memory.key (mode 0600, auto-generated on first use)
  - Without `cryptography` installed, records are stored as plaintext
    SQLite and a warning is emitted once at import time.

Usage:
    from memory_store import MemoryStore
    store = MemoryStore(os_root="/path/to/OS")
    store.mem_set("greeting", "Hello, World!")
    print(store.mem_get("greeting"))   # → "Hello, World!"
"""
from __future__ import annotations

import os
import sqlite3
import warnings
from pathlib import Path
from typing import List, Optional

# ---------------------------------------------------------------------------
# Optional cryptography import
# ---------------------------------------------------------------------------
try:
    from cryptography.hazmat.primitives.ciphers.aead import AESGCM
    _CRYPTO_AVAILABLE = True
except ImportError:
    _CRYPTO_AVAILABLE = False
    warnings.warn(
        "memory_store: 'cryptography' package not installed — "
        "memory records will be stored as plaintext. "
        "Install with: pip install cryptography",
        stacklevel=2,
    )

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

_DB_PATH    = os.path.join("proc", "aura", "memory.db")
_KEY_PATH   = os.path.join("etc", "aura", "memory.key")
_KEY_BYTES  = 32  # AES-256


# ---------------------------------------------------------------------------
# MemoryStore
# ---------------------------------------------------------------------------

class MemoryStore:
    """Encrypted SQLite-backed key-value and semantic memory store.

    Args:
        os_root: Path to OS_ROOT.  Defaults to the OS_ROOT environment variable.
    """

    def __init__(self, os_root: str = "") -> None:
        self._root = Path(os_root or os.environ.get("OS_ROOT", "")).resolve()
        self._db_path  = self._root / _DB_PATH
        self._key_path = self._root / _KEY_PATH
        self._db_path.parent.mkdir(parents=True, exist_ok=True)
        self._key_path.parent.mkdir(parents=True, exist_ok=True)
        self._key: Optional[bytes] = self._load_or_gen_key()
        self._conn: sqlite3.Connection = self._open_db()

    # ------------------------------------------------------------------
    # Key management
    # ------------------------------------------------------------------

    def _load_or_gen_key(self) -> Optional[bytes]:
        """Load the master encryption key, generating it on first use."""
        if not _CRYPTO_AVAILABLE:
            return None
        if self._key_path.exists():
            return self._key_path.read_bytes()
        key = os.urandom(_KEY_BYTES)
        self._key_path.write_bytes(key)
        self._key_path.chmod(0o600)
        return key

    # ------------------------------------------------------------------
    # Database setup
    # ------------------------------------------------------------------

    def _open_db(self) -> sqlite3.Connection:
        conn = sqlite3.connect(str(self._db_path), check_same_thread=False)
        conn.execute(
            """CREATE TABLE IF NOT EXISTS kv (
                key       TEXT PRIMARY KEY,
                value     BLOB NOT NULL,
                nonce     BLOB,
                encrypted INTEGER DEFAULT 0
            )"""
        )
        conn.execute(
            """CREATE TABLE IF NOT EXISTS sem (
                key       TEXT PRIMARY KEY,
                document  BLOB NOT NULL,
                nonce     BLOB,
                encrypted INTEGER DEFAULT 0
            )"""
        )
        conn.commit()
        return conn

    # ------------------------------------------------------------------
    # Encryption helpers
    # ------------------------------------------------------------------

    def _encrypt(self, plaintext: str) -> tuple[bytes, bytes]:
        """Return (ciphertext, nonce) for *plaintext* using AES-256-GCM."""
        if not _CRYPTO_AVAILABLE or self._key is None:
            return plaintext.encode("utf-8"), b""
        nonce = os.urandom(12)  # 96-bit nonce for AES-GCM
        aesgcm = AESGCM(self._key)
        ct = aesgcm.encrypt(nonce, plaintext.encode("utf-8"), None)
        return ct, nonce

    def _decrypt(self, ciphertext: bytes, nonce: bytes, encrypted: int) -> str:
        """Decrypt *ciphertext* and return the plaintext string."""
        if not encrypted or not _CRYPTO_AVAILABLE or self._key is None or not nonce:
            return ciphertext.decode("utf-8", errors="replace")
        aesgcm = AESGCM(self._key)
        try:
            return aesgcm.decrypt(nonce, ciphertext, None).decode("utf-8")
        except Exception:
            return "[memory_store] Decryption failed"

    # ------------------------------------------------------------------
    # Public API — Key-Value store
    # ------------------------------------------------------------------

    def mem_set(self, key: str, value: str) -> str:
        """Store *value* under *key* (encrypted if crypto available)."""
        if not key:
            return "[MemoryStore] Usage: mem_set(key, value)"
        ct, nonce = self._encrypt(value)
        self._conn.execute(
            "INSERT OR REPLACE INTO kv (key, value, nonce, encrypted) VALUES (?,?,?,?)",
            (key, ct, nonce if nonce else None, 1 if nonce else 0)
        )
        self._conn.commit()
        enc_marker = " [encrypted]" if _CRYPTO_AVAILABLE and nonce else ""
        return f"[MemoryStore] Stored: {key}{enc_marker}"

    def mem_get(self, key: str) -> str:
        """Retrieve the value for *key*."""
        if not key:
            return "[MemoryStore] Usage: mem_get(key)"
        row = self._conn.execute(
            "SELECT value, nonce, encrypted FROM kv WHERE key=?", (key,)
        ).fetchone()
        if row is None:
            return f"[MemoryStore] (no memory for '{key}')"
        value, nonce, encrypted = row
        return self._decrypt(
            bytes(value), bytes(nonce) if nonce else b"", int(encrypted)
        )

    def mem_del(self, key: str) -> str:
        """Delete a key from the memory store."""
        if not key:
            return "[MemoryStore] Usage: mem_del(key)"
        self._conn.execute("DELETE FROM kv WHERE key=?", (key,))
        self._conn.commit()
        return f"[MemoryStore] Deleted: {key}"

    def mem_keys(self) -> List[str]:
        """Return all stored keys."""
        return [row[0] for row in self._conn.execute("SELECT key FROM kv ORDER BY key")]

    # ------------------------------------------------------------------
    # Public API — Semantic store
    # ------------------------------------------------------------------

    def sem_set(self, key: str, document: str) -> str:
        """Store a semantic document under *key*."""
        if not key or not document:
            return "[MemoryStore] Usage: sem_set(key, document)"
        ct, nonce = self._encrypt(document)
        self._conn.execute(
            "INSERT OR REPLACE INTO sem (key, document, nonce, encrypted) VALUES (?,?,?,?)",
            (key, ct, nonce if nonce else None, 1 if nonce else 0)
        )
        self._conn.commit()
        return f"[MemoryStore] Semantic stored: {key}"

    def sem_search(self, query: str) -> str:
        """Search semantic entries by key or content match."""
        if not query:
            return "[MemoryStore] Usage: sem_search(query)"
        hits = []
        q_lower = query.lower()
        for row in self._conn.execute("SELECT key, document, nonce, encrypted FROM sem"):
            key, doc_bytes, nonce, encrypted = row
            if q_lower in key.lower():
                hits.append(f"{key}: (key match)")
                continue
            doc = self._decrypt(
                bytes(doc_bytes), bytes(nonce) if nonce else b"", int(encrypted)
            )
            if q_lower in doc.lower():
                hits.append(f"{key}: {doc[:80]}")
        if not hits:
            return f"[MemoryStore] No semantic matches for '{query}'"
        return "\n".join(hits)

    # ------------------------------------------------------------------
    # Housekeeping
    # ------------------------------------------------------------------

    def close(self) -> None:
        """Close the SQLite connection."""
        self._conn.close()

    def __del__(self) -> None:
        try:
            self._conn.close()
        except Exception:
            pass
