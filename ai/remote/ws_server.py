#!/usr/bin/env python3
"""ai/remote/ws_server.py — Remote WebSocket shell for AIOS-Lite.

Provides an authenticated, multiplexed WebSocket server that allows a
remote client to run AIOS AI-shell commands over a persistent connection.
Authentication uses capability tokens stored in OS_ROOT/etc/perms.d/.

Protocol (JSON messages):
  Client → Server:
    {"type": "auth",  "token": "<api-token>"}
    {"type": "cmd",   "id": "<req-id>",  "input": "<text>"}
    {"type": "ping"}

  Server → Client:
    {"type": "auth_ok"}
    {"type": "auth_fail", "reason": "..."}
    {"type": "output", "id": "<req-id>", "text": "...", "done": bool}
    {"type": "pong"}
    {"type": "error",  "id": "<req-id>", "text": "..."}

Usage:
    python3 ai/remote/ws_server.py [--host 0.0.0.0] [--port 8765] [--no-auth]

The server reads the API token from OS_ROOT/etc/api.token (same file used
by os-httpd) so clients share a single credential.
"""
from __future__ import annotations

import argparse
import base64
import hashlib
import json
import os
import select
import socket
import struct
import subprocess
import sys
import threading
import time
from typing import Optional

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
_HERE = os.path.dirname(os.path.abspath(__file__))
OS_ROOT = os.environ.get(
    "OS_ROOT",
    os.path.join(os.path.dirname(os.path.dirname(_HERE)), "OS")
)
AIOS_HOME = os.environ.get("AIOS_HOME", os.path.dirname(os.path.dirname(_HERE)))

TOKEN_FILE = os.path.join(OS_ROOT, "etc", "api.token")
LOG_FILE   = os.path.join(OS_ROOT, "var", "log", "ws-server.log")

os.makedirs(os.path.join(OS_ROOT, "var", "log"), exist_ok=True)

_WS_MAGIC = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"

# ---------------------------------------------------------------------------
# Logging
# ---------------------------------------------------------------------------

def _log(msg: str) -> None:
    ts = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
    entry = f"[{ts}] [ws-server] {msg}\n"
    sys.stdout.write(entry)
    try:
        with open(LOG_FILE, "a") as fh:
            fh.write(entry)
    except OSError:
        pass


# ---------------------------------------------------------------------------
# Auth
# ---------------------------------------------------------------------------

def _load_token() -> str:
    try:
        with open(TOKEN_FILE) as f:
            return f.read().strip()
    except FileNotFoundError:
        return ""


# ---------------------------------------------------------------------------
# WebSocket framing helpers
# ---------------------------------------------------------------------------

def _ws_accept(key: str) -> str:
    combined = (key + _WS_MAGIC).encode()
    return base64.b64encode(hashlib.sha1(combined).digest()).decode()


def _ws_encode(message: str) -> bytes:
    payload = message.encode("utf-8")
    n = len(payload)
    if n < 126:
        header = bytes([0x81, n])
    elif n < 65536:
        header = struct.pack(">BBH", 0x81, 126, n)
    else:
        header = struct.pack(">BBQ", 0x81, 127, n)
    return header + payload


def _ws_decode(data: bytes) -> Optional[str]:
    if len(data) < 2:
        return None
    b2 = data[1]
    masked = (b2 >> 7) & 1
    plen = b2 & 0x7F
    offset = 2
    if plen == 126:
        plen = struct.unpack(">H", data[2:4])[0]
        offset = 4
    elif plen == 127:
        plen = struct.unpack(">Q", data[2:10])[0]
        offset = 10
    if masked:
        mask = data[offset:offset + 4]
        offset += 4
        payload = bytes(data[offset + i] ^ mask[i % 4] for i in range(plen))
    else:
        payload = data[offset:offset + plen]
    return payload.decode("utf-8", errors="replace")


# ---------------------------------------------------------------------------
# AIOS command executor
# ---------------------------------------------------------------------------

def _run_aios_command(text: str) -> str:
    """Route a text command through the ai_backend and return the response."""
    ai_backend = os.path.join(AIOS_HOME, "ai", "core", "ai_backend.py")
    if not os.path.isfile(ai_backend):
        return f"[ws-server] ai_backend.py not found at {ai_backend}"
    env = dict(os.environ, OS_ROOT=OS_ROOT, AIOS_HOME=AIOS_HOME)
    try:
        return subprocess.check_output(
            [sys.executable, ai_backend,
             "--os-root", OS_ROOT,
             "--aios-root", AIOS_HOME,
             "--input", text],
            stderr=subprocess.STDOUT, text=True, env=env, timeout=30
        ).strip()
    except subprocess.TimeoutExpired:
        return "[ws-server] Command timed out"
    except subprocess.CalledProcessError as exc:
        return exc.output.strip() or f"[ws-server] Exit {exc.returncode}"
    except FileNotFoundError as exc:
        return f"[ws-server] {exc}"


# ---------------------------------------------------------------------------
# Client connection handler
# ---------------------------------------------------------------------------

class _ClientHandler:
    """Manages one WebSocket client connection."""

    def __init__(self, conn: socket.socket, addr: tuple,
                 api_token: str, no_auth: bool) -> None:
        self._conn    = conn
        self._addr    = addr
        self._token   = api_token
        self._no_auth = no_auth
        self._authed  = no_auth or (not api_token)  # open if no token configured

    def _send(self, obj: dict) -> None:
        self._conn.sendall(_ws_encode(json.dumps(obj)))

    def _recv_msg(self) -> Optional[str]:
        try:
            rlist, _, _ = select.select([self._conn], [], [], 60)
            if not rlist:
                return None
            data = self._conn.recv(8192)
            if not data:
                return None
            return _ws_decode(data)
        except OSError:
            return None

    def run(self) -> None:
        _log(f"Client connected: {self._addr}")
        try:
            while True:
                raw = self._recv_msg()
                if raw is None:
                    break
                try:
                    msg = json.loads(raw)
                except json.JSONDecodeError:
                    self._send({"type": "error", "id": None, "text": "Invalid JSON"})
                    continue

                msg_type = msg.get("type", "")

                if msg_type == "ping":
                    self._send({"type": "pong"})
                    continue

                if msg_type == "auth":
                    provided = str(msg.get("token", ""))
                    if self._no_auth or not self._token or provided == self._token:
                        self._authed = True
                        self._send({"type": "auth_ok"})
                    else:
                        self._send({"type": "auth_fail", "reason": "bad token"})
                    continue

                if not self._authed:
                    self._send({"type": "auth_fail", "reason": "not authenticated"})
                    continue

                if msg_type == "cmd":
                    req_id = msg.get("id", "")
                    text   = str(msg.get("input", "")).strip()
                    if not text:
                        self._send({"type": "error", "id": req_id, "text": "empty input"})
                        continue
                    _log(f"{self._addr} cmd: {text[:80]}")
                    # Run in a thread so we don't block the recv loop
                    def _exec(rid=req_id, t=text):
                        output = _run_aios_command(t)
                        self._send({"type": "output", "id": rid,
                                    "text": output, "done": True})
                    threading.Thread(target=_exec, daemon=True).start()
                else:
                    self._send({"type": "error", "id": msg.get("id"), "text": f"unknown type: {msg_type}"})

        except OSError:
            pass
        finally:
            _log(f"Client disconnected: {self._addr}")
            self._conn.close()


# ---------------------------------------------------------------------------
# WebSocket HTTP handshake
# ---------------------------------------------------------------------------

def _do_ws_handshake(conn: socket.socket) -> bool:
    """Read the HTTP upgrade request and complete the WebSocket handshake."""
    try:
        raw = conn.recv(4096).decode("utf-8", errors="replace")
    except OSError:
        return False
    if "Upgrade: websocket" not in raw and "upgrade: websocket" not in raw.lower():
        conn.sendall(b"HTTP/1.1 400 Bad Request\r\nContent-Length: 0\r\n\r\n")
        return False
    key = ""
    for line in raw.split("\r\n"):
        if line.lower().startswith("sec-websocket-key:"):
            key = line.split(":", 1)[1].strip()
    if not key:
        return False
    accept = _ws_accept(key)
    response = (
        "HTTP/1.1 101 Switching Protocols\r\n"
        "Upgrade: websocket\r\n"
        "Connection: Upgrade\r\n"
        f"Sec-WebSocket-Accept: {accept}\r\n\r\n"
    )
    conn.sendall(response.encode())
    return True


# ---------------------------------------------------------------------------
# Server
# ---------------------------------------------------------------------------

def run_server(host: str, port: int, no_auth: bool) -> None:
    api_token = _load_token()
    _log(f"Starting AIOS Remote WS Shell on ws://{host}:{port}/")
    _log(f"OS_ROOT : {OS_ROOT}")
    _log(f"Auth    : {'disabled' if no_auth else ('token' if api_token else 'open')}")

    srv = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    srv.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    srv.bind((host, port))
    srv.listen(16)

    try:
        while True:
            conn, addr = srv.accept()
            conn.settimeout(120)
            if not _do_ws_handshake(conn):
                conn.close()
                continue
            handler = _ClientHandler(conn, addr, api_token, no_auth)
            t = threading.Thread(target=handler.run, daemon=True)
            t.start()
    except KeyboardInterrupt:
        _log("Server shutting down.")
    finally:
        srv.close()


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

def main() -> None:
    parser = argparse.ArgumentParser(
        description="AIOS Remote WebSocket Shell",
        formatter_class=argparse.ArgumentDefaultsHelpFormatter,
    )
    parser.add_argument("--host",    default="0.0.0.0")
    parser.add_argument("--port",    type=int, default=8765)
    parser.add_argument("--no-auth", action="store_true",
                        help="Disable token authentication")
    args = parser.parse_args()
    run_server(args.host, args.port, args.no_auth)


if __name__ == "__main__":
    main()
