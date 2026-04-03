# AIOS-Lite — Deployment Guide

> © 2026 Chris Betts | AIOSCPU Official | AI-generated, fully legal

---

## Contents

1. [Deployment Architecture](#1-deployment-architecture)
2. [Server Setup](#2-server-setup)
3. [Deployment Scripts](#3-deployment-scripts)

---

## 1. Deployment Architecture

### 1.1 Recommended Hosting Environments

| Mode | Use Case | Examples |
|------|----------|---------|
| **Static** | Landing page, documentation, API reference | GitHub Pages, Netlify, Vercel, Cloudflare Pages |
| **Dynamic** | AIOS-Lite HTTP daemon (`os-httpd`), REST API, WebSocket, SSE | VPS, Fly.io, Railway, DigitalOcean Droplet |
| **Hybrid** | Static docs front-end + dynamic API back-end | Netlify (static) + DigitalOcean (API) |
| **Self-Hosted** | On-device (Android/Termux, Raspberry Pi, bare-metal x86) | Local LAN, Tailscale mesh, Tor hidden service |
| **Container** | Reproducible deployment via Docker/OCI image | Docker Hub, GitHub Container Registry (GHCR) |

**Recommended production topology:** Hybrid — static documentation/landing page on Netlify or GitHub Pages, API server (`os-httpd`) on a VPS or container host behind a reverse proxy (nginx/Caddy).

---

### 1.2 Deployment Diagram

```
                           ┌─────────────────────────────────┐
                           │         DNS / CDN Layer          │
                           │  aios.example.com (A / CNAME)   │
                           │  api.aios.example.com            │
                           │  docs.aios.example.com           │
                           └────────────┬────────────────────┘
                                        │ HTTPS (443)
                        ┌───────────────┴──────────────┐
                        │        Reverse Proxy          │
                        │    (nginx / Caddy / Traefik)  │
                        │    TLS termination + routing  │
                        └──┬────────────┬──────────────┘
                           │            │
             ┌─────────────┘            └─────────────────┐
             ▼                                             ▼
  ┌─────────────────────┐                    ┌────────────────────────┐
  │   Static File Host  │                    │   AIOS-Lite API Server  │
  │  (GitHub Pages /    │                    │   (os-httpd Python)     │
  │   Netlify / Vercel) │                    │   Port 8080 / 8443      │
  │                     │                    │                         │
  │  docs.aios.*/       │                    │  /api/v1/*              │
  │  aios.example.com   │                    │  GET /api/v1/status     │
  │  (landing page)     │                    │  GET /api/v1/metrics    │
  └─────────────────────┘                    │  POST /api/v1/command   │
                                             │  GET /api/v1/events(SSE)│
                                             │  WS  /ws                │
                                             └──────────┬─────────────┘
                                                        │
                                             ┌──────────▼─────────────┐
                                             │     AIOS-Lite OS       │
                                             │   (Shell + AI Core)    │
                                             │   ai/core/*.py         │
                                             │   OS/bin/os-shell      │
                                             │   OS/bin/os-kernelctl  │
                                             └──────────┬─────────────┘
                                                        │
                              ┌─────────────────────────┼────────────────────┐
                              ▼                         ▼                    ▼
                   ┌──────────────────┐    ┌─────────────────┐   ┌──────────────────┐
                   │  LLaMA Model     │    │  Memory/State    │   │  Cross-OS Bridge │
                   │  (llama_model/)  │    │  (OS/proc/ +     │   │  iOS/Android/SSH │
                   │  llama-cli       │    │   OS/var/log/)   │   │  (os-bridge)     │
                   └──────────────────┘    └─────────────────┘   └──────────────────┘
```

---

### 1.3 Server Roles

| Role | Host | Port | Responsibility |
|------|------|------|---------------|
| **API Server** | VPS / container | 8080 (HTTP), 8443 (HTTPS) | `os-httpd` — REST, SSE, WebSocket |
| **Auth Server** | Same host as API server | — | Token validation via `OS/etc/api.token`; future OAuth2 extension point |
| **File Server** | Static CDN (Netlify / GitHub Pages) | 443 | Documentation, landing page, assets |
| **Event Server** | Same host as API server | 8080 / 8443 | SSE endpoint `/api/v1/events`; WebSocket `/ws` |
| **LLM Worker** | Same host (CPU-bound) or GPU sidecar | — | `llama-cli` subprocess, managed by `ai/core/llama_client.py` |

---

### 1.4 Domain / Subdomain Structure

```
aios.example.com          →  Landing page (static)
docs.aios.example.com     →  Documentation site (static)
api.aios.example.com      →  REST API + SSE + WebSocket (dynamic)
status.aios.example.com   →  (Optional) uptime/health dashboard
```

All domains must have:
- A/AAAA records pointing to the appropriate host or CDN
- CNAME records where the registrar requires them
- CAA records restricting certificate issuance to your CA of choice (e.g., Let's Encrypt)

---

### 1.5 HTTPS / TLS Requirements

| Requirement | Detail |
|-------------|--------|
| Minimum TLS version | TLS 1.2; **TLS 1.3 preferred** |
| Certificate | Let's Encrypt (Certbot / `caddy` auto-HTTPS) or commercial CA |
| Self-signed (dev only) | `OS_ROOT=... python3 OS/bin/os-httpd --gen-cert` |
| HSTS | `Strict-Transport-Security: max-age=63072000; includeSubDomains; preload` |
| Certificate renewal | Automated (Certbot cron / Caddy built-in) |
| Cipher suites | Restrict to ECDHE+AES-GCM and ECDHE+CHACHA20 |

---

### 1.6 Reverse Proxy Configuration

#### nginx (recommended)

```nginx
# /etc/nginx/sites-available/aios-api
server {
    listen 443 ssl http2;
    server_name api.aios.example.com;

    ssl_certificate     /etc/letsencrypt/live/api.aios.example.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/api.aios.example.com/privkey.pem;
    ssl_protocols       TLSv1.2 TLSv1.3;
    ssl_ciphers         ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-CHACHA20-POLY1305;
    ssl_prefer_server_ciphers off;

    add_header Strict-Transport-Security "max-age=63072000; includeSubDomains; preload" always;
    add_header X-Content-Type-Options nosniff;
    add_header X-Frame-Options DENY;
    add_header X-XSS-Protection "1; mode=block";

    # REST + SSE
    location /api/ {
        proxy_pass         http://127.0.0.1:8080;
        proxy_http_version 1.1;
        proxy_set_header   Host $host;
        proxy_set_header   X-Real-IP $remote_addr;
        proxy_set_header   X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header   X-Forwarded-Proto $scheme;

        # SSE / streaming
        proxy_buffering    off;
        proxy_cache        off;
        proxy_read_timeout 3600s;
    }

    # WebSocket
    location /ws {
        proxy_pass         http://127.0.0.1:8080;
        proxy_http_version 1.1;
        proxy_set_header   Upgrade $http_upgrade;
        proxy_set_header   Connection "upgrade";
        proxy_set_header   Host $host;
        proxy_read_timeout 3600s;
    }
}

# HTTP → HTTPS redirect
server {
    listen 80;
    server_name api.aios.example.com;
    return 301 https://$host$request_uri;
}
```

#### Caddy (alternative — auto-HTTPS)

```caddy
# /etc/caddy/Caddyfile
api.aios.example.com {
    reverse_proxy /api/* localhost:8080
    reverse_proxy /ws    localhost:8080 {
        header_up Upgrade {>Upgrade}
        header_up Connection {>Connection}
    }
    encode gzip
    header {
        Strict-Transport-Security "max-age=63072000; includeSubDomains; preload"
        X-Content-Type-Options nosniff
        X-Frame-Options DENY
    }
}

docs.aios.example.com {
    root * /var/www/aios-docs
    file_server
    encode gzip
}
```

---

## 2. Server Setup

### 2.1 Server Configuration Templates

#### System Requirements (minimum)

| Resource | Minimum | Recommended |
|----------|---------|-------------|
| CPU | 1 vCPU | 2+ vCPU |
| RAM | 512 MB | 2 GB (4 GB with LLM) |
| Disk | 2 GB | 20 GB |
| OS | Debian 11+, Ubuntu 22.04+, Android Termux | Same |
| Python | 3.8+ | 3.11+ |
| Shell | POSIX sh (bash, dash, ash) | bash |

#### Environment Configuration (`/etc/environment` or systemd unit)

```ini
# AIOS-Lite production environment
OS_ROOT=/opt/aios/OS
AIOS_HOME=/opt/aios
AIOS_PORT=8080
AIOS_TLS_PORT=8443
AIOS_LOG_LEVEL=info
AIOS_RATE_LIMIT=60
LLAMA_CPU_AFFINITY=1-3
LLAMA_THREADS=4
```

#### systemd Unit File

```ini
# /etc/systemd/system/aios-httpd.service
[Unit]
Description=AIOS-Lite HTTP API Server
After=network.target
Wants=network-online.target

[Service]
Type=simple
User=aios
Group=aios
WorkingDirectory=/opt/aios
Environment=OS_ROOT=/opt/aios/OS
Environment=AIOS_HOME=/opt/aios
ExecStart=/usr/bin/python3 /opt/aios/OS/bin/os-httpd --port 8080
ExecStartPost=/bin/sh -c 'sh /opt/aios/OS/sbin/init'
Restart=on-failure
RestartSec=5s
StandardOutput=journal
StandardError=journal
SyslogIdentifier=aios-httpd
NoNewPrivileges=true
ProtectSystem=strict
ReadWritePaths=/opt/aios/OS/var /opt/aios/OS/proc
PrivateTmp=true

[Install]
WantedBy=multi-user.target
```

```ini
# /etc/systemd/system/aios-kernel.service
[Unit]
Description=AIOS-Lite Kernel Daemon
After=network.target

[Service]
Type=forking
User=aios
Group=aios
WorkingDirectory=/opt/aios/OS
Environment=OS_ROOT=/opt/aios/OS
ExecStart=/bin/sh /opt/aios/OS/etc/init.d/os-kernel start
ExecStop=/bin/sh /opt/aios/OS/etc/init.d/os-kernel stop
Restart=on-failure
RestartSec=10s
PIDFile=/opt/aios/OS/var/service/os-kernel.pid

[Install]
WantedBy=multi-user.target
```

---

### 2.2 API Gateway Configuration

The `os-httpd` daemon acts as both the API server and a lightweight gateway. For production, place it behind nginx or Caddy (see §1.6).

```python
# Startup with token authentication and TLS
OS_ROOT=/opt/aios/OS python3 OS/bin/os-httpd \
    --port 8443 \
    --tls \
    --token-file OS/etc/api.token

# Generate a fresh API token
OS_ROOT=/opt/aios/OS python3 OS/bin/os-httpd --token-gen

# Generate a self-signed certificate (development / internal use only)
OS_ROOT=/opt/aios/OS python3 OS/bin/os-httpd --gen-cert
```

**Gateway capabilities built into `os-httpd`:**

| Feature | Implementation |
|---------|---------------|
| Token authentication | `X-API-Token` header, stored in `OS/etc/api.token` |
| Request logging | `OS/var/log/httpd-access.log` |
| Error logging | `OS/var/log/httpd-error.log` |
| TLS/HTTPS | Python `ssl` module (self-signed or CA-signed cert) |
| Rate limiting | Configurable via `AIOS_RATE_LIMIT` (requests/min/IP) |
| CORS | `Access-Control-Allow-Origin` configurable header |

---

### 2.3 WebSocket Server Configuration

The WebSocket endpoint is served by `os-httpd` at `GET /ws` (RFC 6455 compliant).

```
Connection lifecycle:
  Client → HTTP Upgrade → ws://api.aios.example.com/ws
  Server ← sends: {"echo": <msg>, "time": <unix_ts>}
```

**nginx WebSocket proxy block** (already included in §1.6):

```nginx
location /ws {
    proxy_pass         http://127.0.0.1:8080;
    proxy_http_version 1.1;
    proxy_set_header   Upgrade $http_upgrade;
    proxy_set_header   Connection "upgrade";
    proxy_read_timeout 3600s;
}
```

**Client test:**

```javascript
const ws = new WebSocket('wss://api.aios.example.com/ws');
ws.onopen  = () => ws.send('hello');
ws.onmessage = (e) => console.log(JSON.parse(e.data));
// → { echo: "hello", time: 1775208327.4 }
```

---

### 2.4 REST Endpoint Structure

| Method | Path | Auth | Description |
|--------|------|------|-------------|
| `GET` | `/api/v1/health` | None | Liveness probe |
| `GET` | `/api/v1/status` | Token | OS state |
| `GET` | `/api/v1/services` | Token | Service health |
| `GET` | `/api/v1/processes` | Token | Process list |
| `GET` | `/api/v1/metrics` | Token | CPU/mem/disk metrics |
| `GET` | `/api/v1/logs` | Token | Log tail (query: `source`, `tail`) |
| `POST` | `/api/v1/command` | Token | Execute shell command |
| `GET` | `/api/v1/events` | Token | SSE live log stream |
| `GET` | `/ws` | Token | WebSocket echo |

**URL base:** `https://api.aios.example.com`

---

### 2.5 Logging and Monitoring Setup

#### Log Files

| Log | Path | Rotated |
|-----|------|---------|
| OS general | `OS/var/log/os.log` | ✅ (1000 lines) |
| Kernel | `OS/var/log/kernel.log` | ✅ |
| AURA audit | `OS/var/log/aura.log` | ✅ |
| Syscall audit | `OS/var/log/syscall.log` | ✅ |
| HTTP access | `OS/var/log/httpd-access.log` | ✅ |
| HTTP error | `OS/var/log/httpd-error.log` | ✅ |
| Network | `OS/var/log/net.log` | ✅ |
| Events | `OS/var/log/events.log` | ✅ |
| Recovery | `OS/var/log/recover.log` | ✅ |

#### Structured Log Shipping (optional)

```bash
# Ship logs to a remote syslog or log aggregator (e.g. Loki, Papertrail)
tail -F /opt/aios/OS/var/log/os.log | \
  logger -n logs.papertrailapp.com -P 12345 -t aios
```

#### Prometheus Metrics Endpoint (planned extension)

Expose `/metrics` in Prometheus text format by wrapping the existing `/api/v1/metrics` response:

```
# HELP aios_mem_used_kb Memory used in KB
# TYPE aios_mem_used_kb gauge
aios_mem_used_kb 3500000

# HELP aios_disk_used_pct Disk used percent
# TYPE aios_disk_used_pct gauge
aios_disk_used_pct 39
```

#### Health Check (for uptime monitors)

```bash
# Simple curl-based health check
curl -sf https://api.aios.example.com/api/v1/health && echo "OK"
```

---

### 2.6 Rate Limiting and Security Recommendations

#### Rate Limiting

```nginx
# /etc/nginx/conf.d/aios-rate-limit.conf
limit_req_zone $binary_remote_addr zone=aios_api:10m rate=60r/m;
limit_req_zone $binary_remote_addr zone=aios_cmd:10m rate=10r/m;

server {
    # ...
    location /api/ {
        limit_req zone=aios_api burst=20 nodelay;
    }
    location /api/v1/command {
        limit_req zone=aios_cmd burst=5 nodelay;
    }
}
```

#### Security Recommendations

| Category | Recommendation |
|----------|---------------|
| **API token** | Rotate regularly; use `os-httpd --token-gen` |
| **TLS** | Enforce TLS 1.2+; disable SSLv3/TLS 1.0/1.1 |
| **Headers** | Add `X-Content-Type-Options`, `X-Frame-Options`, `CSP` |
| **Firewall** | Expose only 80/443 publicly; keep 8080 localhost-only |
| **User** | Run `aios-httpd.service` as unprivileged `aios` user |
| **OS_ROOT jail** | All file I/O stays within `OS_ROOT` (enforced by `OS/lib/filesystem.py`) |
| **Spawn whitelist** | Only whitelisted binaries can be executed via `os-syscall spawn` |
| **Secrets** | Never commit `OS/etc/api.token` or TLS private keys to Git |
| **Updates** | Keep Python, OpenSSL, and system packages patched |
| **Audit logs** | Monitor `syscall.log` and `aura.log` for anomalous activity |
| **CORS** | Restrict `Access-Control-Allow-Origin` to known front-end domains |
| **Command endpoint** | Consider disabling `POST /api/v1/command` in public deployments |

---

## 3. Deployment Scripts

> These scripts are described and outlined below. They are intended to be implemented as shell scripts in a `scripts/` directory. They are **not** executed during documentation generation.

---

### 3.1 Build Script (`scripts/build.sh`)

**Purpose:** Prepare all artifacts for deployment.

**Outline:**

1. Check prerequisites (`python3`, `bash`, `openssl`, `git`)
2. Export `OS_ROOT` and `AIOS_HOME`
3. Run unit test suite (`bash tests/unit-tests.sh`) — abort on failure
4. Run integration tests (`bash tests/integration-tests.sh`) — abort on failure
5. Run Python module tests (`python3 tests/test_python_modules.py`) — abort on failure
6. Generate API token if `OS/etc/api.token` does not exist (`os-httpd --token-gen`)
7. Generate TLS certificate if not present (`os-httpd --gen-cert`) *(dev only)*
8. Copy documentation web assets to `build/web/` output directory
9. Build static docs site (if using MkDocs/Docusaurus)
10. Print build summary (version, token hash, output path)

```bash
#!/usr/bin/env bash
# scripts/build.sh — AIOS-Lite build script (outline)
set -euo pipefail

AIOS_HOME="${AIOS_HOME:-$(pwd)}"
OS_ROOT="${OS_ROOT:-$AIOS_HOME/OS}"

echo "[build] Running test suite..."
AIOS_HOME="$AIOS_HOME" OS_ROOT="$OS_ROOT" bash tests/unit-tests.sh
AIOS_HOME="$AIOS_HOME" OS_ROOT="$OS_ROOT" bash tests/integration-tests.sh
python3 tests/test_python_modules.py

echo "[build] Generating API token (if absent)..."
[ -f "$OS_ROOT/etc/api.token" ] || \
  OS_ROOT="$OS_ROOT" python3 OS/bin/os-httpd --token-gen

echo "[build] Build complete."
```

---

### 3.2 Deploy Script (`scripts/deploy.sh`)

**Purpose:** Deploy the built artifacts to the target environment.

**Outline:**

1. Parse target argument: `local | vps | docker | github-pages`
2. **For `vps` target:**
   a. `rsync` the `AIOS_HOME` directory to the remote server (excluding `.git`, `llama_model/`, test artifacts)
   b. SSH into the server and run `systemctl daemon-reload`
   c. `systemctl restart aios-kernel aios-httpd`
   d. Wait for health check (`/api/v1/health`) to return `200`
   e. Print confirmation
3. **For `docker` target:**
   a. Build Docker image from `Dockerfile`
   b. Tag with `git describe --tags`
   c. Push to container registry (GHCR or Docker Hub)
   d. Pull and restart on remote host
4. **For `github-pages` target:**
   a. Copy `docs/web/` to `gh-pages` branch
   b. Commit and push

```bash
#!/usr/bin/env bash
# scripts/deploy.sh — AIOS-Lite deploy script (outline)
set -euo pipefail

TARGET="${1:-local}"
REMOTE_HOST="${AIOS_REMOTE_HOST:-aios.example.com}"
REMOTE_USER="${AIOS_REMOTE_USER:-aios}"
REMOTE_PATH="${AIOS_REMOTE_PATH:-/opt/aios}"

case "$TARGET" in
  vps)
    echo "[deploy] Syncing to $REMOTE_HOST..."
    rsync -avz --delete \
      --exclude='.git' \
      --exclude='llama_model/*.gguf' \
      --exclude='OS/var/log/*' \
      --exclude='OS/proc/*' \
      . "$REMOTE_USER@$REMOTE_HOST:$REMOTE_PATH/"
    ssh "$REMOTE_USER@$REMOTE_HOST" \
      "sudo systemctl daemon-reload && sudo systemctl restart aios-kernel aios-httpd"
    echo "[deploy] Waiting for health check..."
    until curl -sf "https://$REMOTE_HOST/api/v1/health"; do sleep 2; done
    echo "[deploy] Deployment complete."
    ;;
  docker)
    echo "[deploy] Building Docker image..."
    docker build -t ghcr.io/cbetts1/aios-lite:"$(git describe --tags)" .
    docker push ghcr.io/cbetts1/aios-lite:"$(git describe --tags)"
    ;;
  github-pages)
    echo "[deploy] Deploying docs to GitHub Pages..."
    # Implemented via gh-pages branch or GitHub Actions workflow
    ;;
  *)
    echo "[deploy] Unknown target: $TARGET"
    exit 1
    ;;
esac
```

---

### 3.3 Update Script (`scripts/update.sh`)

**Purpose:** Pull the latest version and apply updates with zero downtime.

**Outline:**

1. Record the current running version (`git describe --tags`)
2. `git fetch origin && git pull --ff-only`
3. Run `scripts/build.sh` (tests + pre-flight checks)
4. Backup current state: `OS/bin/os-recover backup`
5. Apply update: `rsync` new files into place (or `systemctl restart`)
6. Verify health: poll `/api/v1/health` for 30 seconds
7. If health check fails → trigger rollback (call `scripts/rollback.sh`)
8. Log the update to `OS/var/log/os.log`

---

### 3.4 Rollback Script (`scripts/rollback.sh`)

**Purpose:** Revert to the previous known-good state.

**Outline:**

1. Locate the most recent backup created by `os-recover backup` in `OS/var/backups/`
2. Stop the `aios-httpd` and `aios-kernel` services
3. Restore files: `OS/bin/os-recover restore <backup-path>`
4. `git checkout <previous-tag>` (code rollback)
5. Restart services: `systemctl start aios-kernel aios-httpd`
6. Poll `/api/v1/health` to confirm recovery
7. Log the rollback event and alert operator

```bash
#!/usr/bin/env bash
# scripts/rollback.sh — AIOS-Lite rollback script (outline)
set -euo pipefail

PREVIOUS_TAG="${1:-$(git describe --tags --abbrev=0 HEAD^)}"
OS_ROOT="${OS_ROOT:-$(pwd)/OS}"

echo "[rollback] Stopping services..."
sudo systemctl stop aios-httpd aios-kernel 2>/dev/null || true

echo "[rollback] Restoring OS state from backup..."
OS_ROOT="$OS_ROOT" bash OS/bin/os-recover restore

echo "[rollback] Checking out previous tag: $PREVIOUS_TAG"
git checkout "$PREVIOUS_TAG"

echo "[rollback] Restarting services..."
sudo systemctl start aios-kernel aios-httpd

echo "[rollback] Waiting for health check..."
until curl -sf "http://127.0.0.1:8080/api/v1/health"; do sleep 2; done
echo "[rollback] Rollback to $PREVIOUS_TAG complete."
```

---

*Last updated: 2026-04-03*
