# AIOS-Lite API Reference

> © 2026 Chris Betts | AIOSCPU Official

Complete reference for the AIOS-Lite HTTP REST API, Server-Sent Events (SSE) stream, and WebSocket interface.

---

## Base URL

```
https://api.aios.example.com
```

For local development:

```
http://localhost:8080
```

---

## Authentication

All endpoints except `/api/v1/health` require an API token.

**Header:**

```
X-API-Token: <your-token>
```

**Generate a token:**

```sh
OS_ROOT=/path/to/OS python3 OS/bin/os-httpd --token-gen
```

**Token is stored at:** `OS/etc/api.token`

---

## API Version

Current version: **v1**

All endpoints use the `/api/v1/` prefix. The API version is also returned in the `X-AIOS-Version` response header.

---

## Endpoints

### `GET /api/v1/health`

Unauthenticated liveness probe. Use for load balancer health checks and uptime monitors.

**Auth:** None required

**Request:**

```sh
curl https://api.aios.example.com/api/v1/health
```

**Response `200 OK`:**

```json
{
  "status": "ok",
  "time": "2026-04-03T15:55:10Z"
}
```

---

### `GET /api/v1/status`

Returns the current OS state snapshot.

**Auth:** `X-API-Token` required

**Request:**

```sh
curl -H "X-API-Token: $TOKEN" \
  https://api.aios.example.com/api/v1/status
```

**Response `200 OK`:**

```json
{
  "boot_time": "1775208139",
  "kernel_pid": "5216",
  "os_version": "0.1",
  "runlevel": "3",
  "last_heartbeat": "1775208327",
  "server_time": "2026-04-03T15:55:10Z"
}
```

| Field | Type | Description |
|-------|------|-------------|
| `boot_time` | string (unix ts) | Time the OS was booted |
| `kernel_pid` | string | PID of the kernel daemon |
| `os_version` | string | AIOS-Lite version |
| `runlevel` | string | Current runlevel (2 = multi-user, 3 = full) |
| `last_heartbeat` | string (unix ts) | Most recent kernel heartbeat |
| `server_time` | string (ISO 8601) | Current server time |

---

### `GET /api/v1/services`

Returns the health status of all registered services.

**Auth:** `X-API-Token` required

**Request:**

```sh
curl -H "X-API-Token: $TOKEN" \
  https://api.aios.example.com/api/v1/services
```

**Response `200 OK`:**

```json
{
  "services": "os-kernel: running\naura-agents: running\naura-tasks: running\naura-bridge: running"
}
```

---

### `GET /api/v1/processes`

Returns the current process list (equivalent to `ps aux`).

**Auth:** `X-API-Token` required

**Request:**

```sh
curl -H "X-API-Token: $TOKEN" \
  https://api.aios.example.com/api/v1/processes
```

**Response `200 OK`:**

```json
{
  "processes": "USER       PID %CPU %MEM    VSZ   RSS TTY STAT START   TIME COMMAND\naios      5216  0.0  0.1  12345  1024 ?   Ss   15:00   0:00 sh OS/etc/init.d/os-kernel\n..."
}
```

---

### `GET /api/v1/metrics`

Returns system resource metrics: memory, disk, and uptime.

**Auth:** `X-API-Token` required

**Request:**

```sh
curl -H "X-API-Token: $TOKEN" \
  https://api.aios.example.com/api/v1/metrics
```

**Response `200 OK`:**

```json
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

| Field | Type | Description |
|-------|------|-------------|
| `timestamp` | string (ISO 8601) | Time of measurement |
| `mem_total_kb` | number | Total RAM in kilobytes |
| `mem_used_kb` | number | Used RAM in kilobytes |
| `mem_pct` | number | RAM used as percentage |
| `disk_total_kb` | number | Total disk in kilobytes |
| `disk_used_kb` | number | Used disk in kilobytes |
| `disk_pct` | number | Disk used as percentage |
| `uptime_raw` | string | Raw uptime string |

---

### `GET /api/v1/logs`

Returns the tail of a named log file.

**Auth:** `X-API-Token` required

**Query Parameters:**

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `source` | string | `os.log` | Log file name within `OS/var/log/` |
| `tail` | integer | `50` | Number of lines to return |

**Available log sources:**

- `os.log` — General OS operation
- `kernel.log` — Kernel daemon
- `aura.log` — AURA audit (permissions, boot, repair)
- `syscall.log` — System call audit
- `httpd-access.log` — HTTP request log
- `httpd-error.log` — HTTP error log
- `net.log` — Network configuration changes
- `events.log` — Event bus
- `recover.log` — Recovery operations

**Request:**

```sh
curl -H "X-API-Token: $TOKEN" \
  "https://api.aios.example.com/api/v1/logs?source=aura.log&tail=10"
```

**Response `200 OK`:**

```json
{
  "source": "aura.log",
  "lines": [
    "[2026-04-03T15:54:50Z] [kernel] heartbeat ok",
    "[2026-04-03T15:54:55Z] [kernel] heartbeat ok",
    "[2026-04-03T15:55:00Z] [perms] allow operator fs.read /proc/os.state",
    "[2026-04-03T15:55:05Z] [kernel] heartbeat ok",
    "[2026-04-03T15:55:10Z] [scheduler] renice pid=5217 nice=5"
  ]
}
```

---

### `POST /api/v1/command`

Execute a command through the AIOS shell pipeline.

> ⚠️ This endpoint executes commands through the AIOS shell. It is restricted to whitelisted commands. Consider disabling in fully public deployments.

**Auth:** `X-API-Token` required

**Request Body:** `application/json`

```json
{
  "cmd": "sysinfo"
}
```

**Request:**

```sh
curl -X POST \
  -H "X-API-Token: $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"cmd": "sysinfo"}' \
  https://api.aios.example.com/api/v1/command
```

**Response `200 OK`:**

```json
{
  "cmd": "sysinfo",
  "output": "OS: AIOS-Lite v0.1\nKernel PID: 5216\nRunlevel: 3\nUptime: 5 days\nMemory: 43% used\nDisk: 39% used"
}
```

**Response `400 Bad Request`:**

```json
{
  "error": "unrecognized command: badcmd"
}
```

**Response `401 Unauthorized`:**

```json
{
  "error": "authentication required"
}
```

**Supported commands** (subset):

| Command | Description |
|---------|-------------|
| `sysinfo` | System information |
| `status` | Full OS state |
| `services` | Service health |
| `uptime` | Uptime |
| `disk` | Disk usage |
| `ps` | Process list |
| `netinfo` | Network interfaces |
| `ask <text>` | AI query |

---

### `GET /api/v1/events`

Server-Sent Events (SSE) stream of the live AURA audit log.

**Auth:** `X-API-Token` required

**Response content-type:** `text/event-stream`

The connection stays open. The server pushes a `data:` line for each new log entry in `OS/var/log/aura.log`.

**Request:**

```sh
# Using curl (stays open)
curl -N \
  -H "X-API-Token: $TOKEN" \
  https://api.aios.example.com/api/v1/events
```

**Response (streaming):**

```
data: [2026-04-03T15:55:10Z] [kernel] heartbeat ok

data: [2026-04-03T15:55:15Z] [kernel] heartbeat ok

data: [2026-04-03T15:55:20Z] [perms] allow operator net.ping 8.8.8.8

```

**JavaScript client:**

```javascript
const evtSource = new EventSource(
  'https://api.aios.example.com/api/v1/events',
  { withCredentials: false }
);

// Note: EventSource doesn't support custom headers natively.
// Pass token as a query parameter or use a token-exchange endpoint.
evtSource.onmessage = (event) => {
  console.log('AIOS Event:', event.data);
};

evtSource.onerror = () => {
  console.error('SSE connection lost, reconnecting...');
};
```

---

### `GET /ws`

WebSocket endpoint (RFC 6455). Provides a real-time bidirectional channel to the AIOS-Lite system.

**Auth:** Token required (pass as `?token=<token>` query param)

**URL:** `wss://api.aios.example.com/ws`

**Behavior:** The server echoes every message with a server timestamp.

**Client → Server:**

```json
"ping"
```

**Server → Client:**

```json
{
  "echo": "ping",
  "time": 1775208600.0
}
```

**JavaScript client:**

```javascript
const ws = new WebSocket(
  `wss://api.aios.example.com/ws?token=${encodeURIComponent(apiToken)}`
);

ws.onopen    = () => ws.send('ping');
ws.onmessage = (e) => console.log('WS message:', JSON.parse(e.data));
ws.onerror   = (e) => console.error('WS error:', e);
ws.onclose   = ()  => console.log('WS closed');
```

---

## Error Responses

| HTTP Status | Meaning | Example |
|-------------|---------|---------|
| `200 OK` | Success | Normal response |
| `400 Bad Request` | Invalid input | Missing `cmd` field, unknown command |
| `401 Unauthorized` | Token missing or invalid | No `X-API-Token` header |
| `404 Not Found` | Unknown endpoint | Typo in path |
| `429 Too Many Requests` | Rate limit exceeded | More than 60 req/min per IP |
| `500 Internal Server Error` | Server error | Check `httpd-error.log` |

All errors return a JSON body:

```json
{
  "error": "human-readable error message"
}
```

---

## Rate Limits

| Endpoint | Limit |
|----------|-------|
| All `/api/v1/*` | 60 requests per minute per IP |
| `POST /api/v1/command` | 10 requests per minute per IP |
| `/api/v1/health` | Not rate-limited |
| `/api/v1/events` (SSE) | 1 persistent connection per token |
| `/ws` (WebSocket) | 1 persistent connection per token |

---

## Starting the API Server

```sh
# Development (no auth, HTTP)
OS_ROOT=/path/to/OS python3 OS/bin/os-httpd --port 8080 --no-auth

# Production (token auth, HTTP — behind nginx/Caddy for TLS)
OS_ROOT=/path/to/OS python3 OS/bin/os-httpd --port 8080

# Production (TLS, direct)
OS_ROOT=/path/to/OS python3 OS/bin/os-httpd --port 8443 --tls

# Token management
OS_ROOT=/path/to/OS python3 OS/bin/os-httpd --token-gen   # Generate token
OS_ROOT=/path/to/OS python3 OS/bin/os-httpd --gen-cert    # Generate self-signed TLS cert
```

---

## Quick Reference: curl Examples

```bash
export BASE="https://api.aios.example.com"
export TOKEN="your-api-token-here"

# Health check (no auth)
curl -s "$BASE/api/v1/health"

# OS status
curl -s -H "X-API-Token: $TOKEN" "$BASE/api/v1/status" | python3 -m json.tool

# Metrics
curl -s -H "X-API-Token: $TOKEN" "$BASE/api/v1/metrics" | python3 -m json.tool

# Services
curl -s -H "X-API-Token: $TOKEN" "$BASE/api/v1/services"

# Processes
curl -s -H "X-API-Token: $TOKEN" "$BASE/api/v1/processes"

# Log tail (last 20 lines of kernel.log)
curl -s -H "X-API-Token: $TOKEN" "$BASE/api/v1/logs?source=kernel.log&tail=20"

# Execute a command
curl -s -X POST \
  -H "X-API-Token: $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"cmd":"status"}' \
  "$BASE/api/v1/command" | python3 -m json.tool

# Live event stream (SSE — streams until Ctrl+C)
curl -N -H "X-API-Token: $TOKEN" "$BASE/api/v1/events"
```

---

*© 2026 Chris Betts | AIOSCPU Official | Last updated: 2026-04-03*
