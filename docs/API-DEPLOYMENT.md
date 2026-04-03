# AIOS-Lite — API Deployment Reference

> © 2026 Chris Betts | AIOSCPU Official | AI-generated, fully legal

---

## Contents

1. [Public API Endpoints](#1-public-api-endpoints)
2. [Internal System API Endpoints](#2-internal-system-api-endpoints)
3. [Authentication Model](#3-authentication-model)
4. [Versioning Strategy](#4-versioning-strategy)
5. [Example Requests and Responses](#5-example-requests-and-responses)

---

## 1. Public API Endpoints

The AIOS-Lite HTTP REST API is served by `OS/bin/os-httpd` and is accessible at:

```
https://api.aios.example.com
```

All public endpoints use the `/api/v1/` prefix. Requests must include a valid `X-API-Token` header (except the health probe).

### Endpoint Catalog

| Method | Path | Auth | Description |
|--------|------|------|-------------|
| `GET` | `/api/v1/health` | None | Liveness / readiness probe |
| `GET` | `/api/v1/status` | Token | Full OS state |
| `GET` | `/api/v1/services` | Token | Service health overview |
| `GET` | `/api/v1/processes` | Token | Running process list |
| `GET` | `/api/v1/metrics` | Token | CPU, memory, disk, uptime metrics |
| `GET` | `/api/v1/logs` | Token | Tail of a named log file |
| `POST` | `/api/v1/command` | Token | Execute an os-shell command |
| `GET` | `/api/v1/events` | Token | Server-Sent Events live log stream |
| `GET` | `/ws` | Token | WebSocket echo / real-time channel |

---

### Endpoint Details

#### `GET /api/v1/health`

Unauthenticated liveness probe. Returns immediately.

| Attribute | Value |
|-----------|-------|
| Auth | None |
| Rate limit | Not rate-limited |
| Use case | Load balancer health checks, uptime monitors |

---

#### `GET /api/v1/status`

Current OS state snapshot.

| Attribute | Value |
|-----------|-------|
| Auth | `X-API-Token` required |
| Response | JSON object |

---

#### `GET /api/v1/metrics`

Live resource metrics (memory, disk, uptime).

| Attribute | Value |
|-----------|-------|
| Auth | `X-API-Token` required |
| Response | JSON object |
| Polling suggestion | Every 30–60 seconds |

---

#### `GET /api/v1/logs`

Tail a log file.

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `source` | string | `os.log` | Log file name (within `OS/var/log/`) |
| `tail` | integer | `50` | Number of lines to return |

Available log sources: `os.log`, `kernel.log`, `aura.log`, `syscall.log`, `httpd-access.log`, `httpd-error.log`, `net.log`, `events.log`, `recover.log`

---

#### `POST /api/v1/command`

Execute a command through the AIOS shell pipeline.

> ⚠️ **Security note:** Restrict access to this endpoint. Commands are filtered through the os-shell whitelist. Consider disabling in fully public deployments.

| Attribute | Value |
|-----------|-------|
| Auth | `X-API-Token` required |
| Body | JSON: `{"cmd": "<command>"}` |
| Response | JSON: `{"cmd": "...", "output": "..."}` |

---

#### `GET /api/v1/events`

Server-Sent Events (SSE) stream of the live AURA audit log (`OS/var/log/aura.log`).

| Attribute | Value |
|-----------|-------|
| Auth | `X-API-Token` required |
| Content-Type | `text/event-stream` |
| Keep-alive | Connection stays open until client disconnects |
| Use case | Real-time monitoring dashboards |

---

#### `GET /ws`

RFC 6455 WebSocket endpoint. Echoes every message with a server timestamp.

| Attribute | Value |
|-----------|-------|
| Auth | `X-API-Token` required (passed as query param `?token=<token>` or initial message) |
| Protocol | WebSocket (ws:// or wss://) |
| Use case | Real-time bidirectional communication, interactive AI shell clients |

---

## 2. Internal System API Endpoints

These endpoints are invoked by AIOS components internally and are not intended for direct external access. They are accessible through the shell interface (`os-shell`) or via the Python AI core.

### Shell System Calls (`OS/bin/os-syscall`)

```sh
os-syscall read   <path>
os-syscall write  <path> <data>
os-syscall append <path> <data>
os-syscall exists <path>
os-syscall stat   <path>
os-syscall mkdir  <path>
os-syscall rm     <path>
os-syscall ls     [path]
os-syscall spawn  <cmd> [args]
os-syscall kill   <pid>
os-syscall getpid
os-syscall getenv <name>
os-syscall setenv <name> <value>
os-syscall uptime
os-syscall sysinfo
os-syscall log    <message>
```

### Kernel API (`OS/bin/os-kernelctl`)

```sh
os-kernelctl status | start | stop | info
```

### Scheduler API (`OS/bin/os-sched`)

```sh
os-sched start | stop | status
os-sched add <pid> <priority>
os-sched rm  <pid>
os-sched list
os-sched renice <pid> <n>
```

### Permissions API (`OS/bin/os-perms`)

```sh
os-perms check  <principal> <capability>
os-perms grant  <principal> <capability>
os-perms revoke <principal> <capability>
os-perms list   <principal>
os-perms list-all
os-perms audit  [n]
```

### Resource Manager (`OS/bin/os-resource`)

```sh
os-resource status | cpu | mem | disk | thermal | limits | check | snapshot
```

### Event Bus (`OS/bin/os-event`, `OS/bin/os-msg`)

```sh
os-event <event-name> [data]    # Fire a named event
os-msg   <message>              # Publish to OS/proc/os.messages
```

### AI Core Internal API (Python)

The AI Core is accessed programmatically or via `ai/core/ai_backend.py`:

```python
from ai.core.intent_engine import IntentEngine
from ai.core.router import Router

engine = IntentEngine()
intent = engine.classify("check disk usage")

router = Router(os_root="/opt/aios/OS", aios_root="/opt/aios")
response = router.dispatch(intent)
```

### Network Configuration (`OS/bin/os-netconf`)

```sh
os-netconf status | interfaces
os-netconf wifi   status | scan | connect <ssid> [pass] | disconnect
os-netconf bt     status | scan
os-netconf ip     show | set <iface> <cidr> | flush <iface>
os-netconf route  show | add <dst> <gw> | del <dst>
os-netconf dns    show | set <server>
os-netconf firewall status | enable | disable | rules | add <rule> | flush
os-netconf nat    status | enable <iface> | disable
os-netconf discover
os-netconf save   [file]
```

---

## 3. Authentication Model

### Token-Based Authentication

AIOS-Lite uses a simple bearer token model.

**Token storage:** `OS/etc/api.token`

**Request header:**

```
X-API-Token: <your-token>
```

**Generating a token:**

```bash
OS_ROOT=/opt/aios/OS python3 OS/bin/os-httpd --token-gen
```

**Token lifecycle:**

| Event | Action |
|-------|--------|
| First deploy | Generate token with `--token-gen` |
| Compromised | Delete `OS/etc/api.token`, regenerate, restart `aios-httpd` |
| Rotation schedule | Recommended every 90 days |

### Authentication Flow

```
Client                     nginx/Caddy              os-httpd
  │                             │                       │
  │── GET /api/v1/status ───────►                       │
  │   X-API-Token: abc123       │                       │
  │                             │── proxy_pass ─────────►
  │                             │                       │── check api.token ──┐
  │                             │                       │                     │
  │                             │                       │◄─ token valid ──────┘
  │                             │◄─ 200 JSON ───────────│
  │◄────────────────────────────│                       │
```

### Future Extension Points

| Extension | Notes |
|-----------|-------|
| OAuth 2.0 / OIDC | Add an authorization server; map scopes to capabilities |
| JWT | Sign tokens with RS256; include `exp`, `iat`, `sub` claims |
| mTLS | Client certificate authentication for high-security deployments |
| API key rotation | Automate rotation via cron + `os-event` trigger |

---

## 4. Versioning Strategy

### URL Versioning

All endpoints are versioned in the URL path:

```
/api/v1/...    ← current stable
/api/v2/...    ← future version (when breaking changes are needed)
```

### Version Header

Clients may also inspect the API version via:

```
X-AIOS-Version: 1.0
```

### Compatibility Policy

| Version | Status | Support |
|---------|--------|---------|
| `v1` | **Current** | Full support |
| `v2` | Planned | Not yet released |

**Rules:**
- Minor, non-breaking additions (new fields, new endpoints) are made within the current version without a version bump.
- Breaking changes (removed fields, changed response shapes, removed endpoints) require a new `/api/v2/` prefix.
- Deprecated endpoints are announced with a `Deprecation` response header at least 90 days before removal.
- The `/api/v1/health` endpoint is guaranteed stable across all versions.

### Release Versioning (Git Tags)

```
MAJOR.MINOR.PATCH
  0.1.0   ← initial release
  0.2.0   ← minor feature additions
  1.0.0   ← first stable release
```

Use `git describe --tags` to embed the version in the binary/config at build time.

---

## 5. Example Requests and Responses

### 5.1 Health Check

**Request:**

```http
GET /api/v1/health HTTP/1.1
Host: api.aios.example.com
```

**Response:**

```http
HTTP/1.1 200 OK
Content-Type: application/json

{"status": "ok", "time": "2026-04-03T15:55:10Z"}
```

---

### 5.2 OS Status

**Request:**

```http
GET /api/v1/status HTTP/1.1
Host: api.aios.example.com
X-API-Token: abc123exampletoken
```

**Response:**

```http
HTTP/1.1 200 OK
Content-Type: application/json

{
  "boot_time": "1775208139",
  "kernel_pid": "5216",
  "os_version": "0.1",
  "runlevel": "3",
  "last_heartbeat": "1775208327",
  "server_time": "2026-04-03T15:55:10Z"
}
```

---

### 5.3 System Metrics

**Request:**

```http
GET /api/v1/metrics HTTP/1.1
Host: api.aios.example.com
X-API-Token: abc123exampletoken
```

**Response:**

```http
HTTP/1.1 200 OK
Content-Type: application/json

{
  "timestamp": "2026-04-03T15:55:10Z",
  "mem_total_kb": 8000000,
  "mem_used_kb": 3500000,
  "mem_pct": 43.7,
  "disk_total_kb": 131072000,
  "disk_used_kb": 52000000,
  "disk_pct": 39,
  "uptime_raw": " 15:55:10 up 5 days,  3:14,  1 user"
}
```

---

### 5.4 Log Tail

**Request:**

```http
GET /api/v1/logs?source=aura.log&tail=5 HTTP/1.1
Host: api.aios.example.com
X-API-Token: abc123exampletoken
```

**Response:**

```http
HTTP/1.1 200 OK
Content-Type: application/json

{
  "source": "aura.log",
  "lines": [
    "[2026-04-03T15:54:55Z] [kernel] heartbeat ok",
    "[2026-04-03T15:55:00Z] [kernel] heartbeat ok",
    "[2026-04-03T15:55:05Z] [perms] allow operator fs.read /proc/os.state",
    "[2026-04-03T15:55:08Z] [kernel] heartbeat ok",
    "[2026-04-03T15:55:10Z] [scheduler] renice pid=5217 nice=5"
  ]
}
```

---

### 5.5 Execute a Shell Command

**Request:**

```http
POST /api/v1/command HTTP/1.1
Host: api.aios.example.com
X-API-Token: abc123exampletoken
Content-Type: application/json

{"cmd": "sysinfo"}
```

**Response:**

```http
HTTP/1.1 200 OK
Content-Type: application/json

{
  "cmd": "sysinfo",
  "output": "OS: AIOS-Lite v0.1\nKernel PID: 5216\nRunlevel: 3\nUptime: 5 days\nMemory: 43% used\nDisk: 39% used"
}
```

**Error (unknown command):**

```http
HTTP/1.1 400 Bad Request
Content-Type: application/json

{"error": "unrecognized command: badcmd"}
```

**Error (missing token):**

```http
HTTP/1.1 401 Unauthorized
Content-Type: application/json

{"error": "authentication required"}
```

---

### 5.6 Server-Sent Events Stream

**Request:**

```http
GET /api/v1/events HTTP/1.1
Host: api.aios.example.com
X-API-Token: abc123exampletoken
Accept: text/event-stream
```

**Response (streaming):**

```
HTTP/1.1 200 OK
Content-Type: text/event-stream
Cache-Control: no-cache

data: [2026-04-03T15:55:10Z] [kernel] heartbeat ok

data: [2026-04-03T15:55:15Z] [kernel] heartbeat ok

data: [2026-04-03T15:55:20Z] [perms] allow operator net.ping 8.8.8.8

```

**JavaScript client:**

```javascript
const source = new EventSource(
  'https://api.aios.example.com/api/v1/events',
  { headers: { 'X-API-Token': 'abc123exampletoken' } }
);
source.onmessage = (e) => console.log('Event:', e.data);
```

---

### 5.7 WebSocket Connection

**Handshake:**

```http
GET /ws HTTP/1.1
Host: api.aios.example.com
Upgrade: websocket
Connection: Upgrade
Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==
Sec-WebSocket-Version: 13
```

**Send message:**

```json
"ping"
```

**Receive:**

```json
{"echo": "ping", "time": 1775208600.0}
```

**JavaScript client:**

```javascript
const ws = new WebSocket('wss://api.aios.example.com/ws');
ws.onopen    = () => ws.send('ping');
ws.onmessage = (e) => console.log(JSON.parse(e.data));
// → { echo: "ping", time: 1775208600.0 }
```

---

### 5.8 curl Quick-Reference

```bash
BASE="https://api.aios.example.com"
TOKEN="abc123exampletoken"

# Health (no auth)
curl -s "$BASE/api/v1/health"

# OS status
curl -s -H "X-API-Token: $TOKEN" "$BASE/api/v1/status" | python3 -m json.tool

# Metrics
curl -s -H "X-API-Token: $TOKEN" "$BASE/api/v1/metrics" | python3 -m json.tool

# Last 20 lines of kernel log
curl -s -H "X-API-Token: $TOKEN" "$BASE/api/v1/logs?source=kernel.log&tail=20"

# Run a command
curl -s -X POST \
  -H "X-API-Token: $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"cmd":"services"}' \
  "$BASE/api/v1/command"

# Watch live events (SSE)
curl -N -H "X-API-Token: $TOKEN" "$BASE/api/v1/events"
```

---

*Last updated: 2026-04-03*
