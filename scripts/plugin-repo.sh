#!/usr/bin/env bash
# scripts/plugin-repo.sh — AIOS-Lite plugin repository client
#
# Fetches a JSON catalogue from PLUGIN_REPO_URL and supports:
#   install <name>    — download and install a plugin
#   remove  <name>    — remove an installed plugin
#   list              — list available plugins from the catalogue
#   update            — update all installed plugins to their latest version
#   list-installed    — list currently installed plugins
#
# Usage:
#   PLUGIN_REPO_URL=https://example.com/aios-plugins.json \
#     bash scripts/plugin-repo.sh list
#   bash scripts/plugin-repo.sh install hello-bot
#
# Environment:
#   PLUGIN_REPO_URL   Base URL for the plugin catalogue JSON index
#   OS_ROOT           AIOS virtual filesystem root (default: ./OS)
#   AIOS_HOME         AIOS project root (default: .)

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OS_ROOT="${OS_ROOT:-${REPO_ROOT}/OS}"
AIOS_HOME="${AIOS_HOME:-${REPO_ROOT}}"
PLUGIN_REPO_URL="${PLUGIN_REPO_URL:-https://raw.githubusercontent.com/Cbetts1/PROJECT/main/plugins/catalogue.json}"
PLUGIN_INSTALL_DIR="${OS_ROOT}/var/pkg/plugins"
PLUGIN_CACHE_DIR="${OS_ROOT}/var/pkg/cache"

mkdir -p "${PLUGIN_INSTALL_DIR}" "${PLUGIN_CACHE_DIR}"

info()  { printf '[plugin-repo] %s\n' "$*"; }
die()   { printf '[plugin-repo] ERROR: %s\n' "$*" >&2; exit 1; }
warn()  { printf '[plugin-repo] WARN: %s\n' "$*" >&2; }

_need_curl() { command -v curl &>/dev/null || die "curl not found"; }

# ---------------------------------------------------------------------------
# fetch_catalogue — download and return the catalogue JSON
# ---------------------------------------------------------------------------
fetch_catalogue() {
    _need_curl
    local cache="${PLUGIN_CACHE_DIR}/catalogue.json"
    info "Fetching catalogue from ${PLUGIN_REPO_URL} ..."
    if ! curl -sf --connect-timeout 10 -o "${cache}" "${PLUGIN_REPO_URL}"; then
        warn "Cannot reach plugin repository; using cached catalogue (if any)"
        [[ -f "${cache}" ]] || die "No cached catalogue available"
    fi
    cat "${cache}"
}

# ---------------------------------------------------------------------------
# list — show available plugins
# ---------------------------------------------------------------------------
cmd_list() {
    local catalogue; catalogue="$(fetch_catalogue)"
    info "Available plugins:"
    echo "${catalogue}" | python3 -c "
import json, sys
data = json.load(sys.stdin)
for p in data.get('plugins', []):
    print(f\"  {p['name']:<20} v{p['version']:<10} {p.get('description','')}\")
"
}

# ---------------------------------------------------------------------------
# list_installed — show installed plugins
# ---------------------------------------------------------------------------
cmd_list_installed() {
    info "Installed plugins:"
    local count=0
    for d in "${PLUGIN_INSTALL_DIR}"/*/; do
        [[ -f "${d}/plugin.json" ]] || continue
        local name; name="$(python3 - "${d}/plugin.json" <<'PYEOF'
import json, sys
d = json.load(open(sys.argv[1]))
print(d.get('name','?'), 'v'+d.get('version','?'))
PYEOF
)"
        echo "  ${name}"
        count=$(( count + 1 ))
    done
    [[ "${count}" -eq 0 ]] && echo "  (none)"
}

# ---------------------------------------------------------------------------
# install <name> — download and install a plugin
# ---------------------------------------------------------------------------
cmd_install() {
    local name="${1:-}"
    [[ -z "${name}" ]] && die "Usage: plugin-repo.sh install <name>"
    _need_curl

    local catalogue; catalogue="$(fetch_catalogue)"
    local url; url="$(echo "${catalogue}" | python3 -c "
import json, sys
name='${name}'
data = json.load(sys.stdin)
for p in data.get('plugins', []):
    if p['name'] == name:
        print(p.get('url',''))
        break
" 2>/dev/null)"

    [[ -z "${url}" ]] && die "Plugin '${name}' not found in catalogue"

    local target_dir="${PLUGIN_INSTALL_DIR}/${name}"
    local bundle="${PLUGIN_CACHE_DIR}/${name}.tar.gz"

    info "Downloading ${name} from ${url} ..."
    curl -sf --connect-timeout 10 -L -o "${bundle}" "${url}" || die "Download failed"

    info "Verifying bundle ..."
    if [[ -f "${bundle}.sha256" ]]; then
        bash "${REPO_ROOT}/scripts/ota-verify.sh" "${bundle}" || die "Bundle verification failed"
    else
        warn "No signature available for ${name} — installing unverified"
    fi

    info "Installing ${name} ..."
    mkdir -p "${target_dir}"
    tar -xzf "${bundle}" -C "${target_dir}" --strip-components=1
    info "Plugin '${name}' installed at ${target_dir}"
}

# ---------------------------------------------------------------------------
# remove <name> — uninstall a plugin
# ---------------------------------------------------------------------------
cmd_remove() {
    local name="${1:-}"
    [[ -z "${name}" ]] && die "Usage: plugin-repo.sh remove <name>"
    local target_dir="${PLUGIN_INSTALL_DIR}/${name}"
    [[ -d "${target_dir}" ]] || die "Plugin '${name}' is not installed"
    rm -rf "${target_dir}"
    info "Plugin '${name}' removed."
}

# ---------------------------------------------------------------------------
# update — update all installed plugins
# ---------------------------------------------------------------------------
cmd_update() {
    info "Checking for plugin updates ..."
    for d in "${PLUGIN_INSTALL_DIR}"/*/; do
        [[ -f "${d}/plugin.json" ]] || continue
        local name; name="$(python3 - "${d}/plugin.json" <<'PYEOF'
import json, sys
print(json.load(open(sys.argv[1])).get('name',''))
PYEOF
)" 2>/dev/null
        [[ -z "${name}" ]] && continue
        info "Updating ${name} ..."
        cmd_install "${name}" || warn "Update failed for ${name}"
    done
    info "All plugins updated."
}

# ---------------------------------------------------------------------------
# Dispatch
# ---------------------------------------------------------------------------
case "${1:-list}" in
    list)           cmd_list ;;
    list-installed) cmd_list_installed ;;
    install)        cmd_install "${2:-}" ;;
    remove)         cmd_remove  "${2:-}" ;;
    update)         cmd_update ;;
    *) die "Unknown command: $1  (list|list-installed|install|remove|update)" ;;
esac
