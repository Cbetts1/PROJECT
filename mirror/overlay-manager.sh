#!/bin/bash
# mirror/overlay-manager.sh
# Manages OverlayFS mounts for transparent host filesystem mirroring.
#
# Usage:
#   bash mirror/overlay-manager.sh mount    # set up all overlay mounts
#   bash mirror/overlay-manager.sh unmount  # tear down all overlay mounts
#   bash mirror/overlay-manager.sh status   # show mount status

set -euo pipefail

AIOS_ROOT="${AIOS_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
CONF="$AIOS_ROOT/mirror/mount-points.conf"
OVERLAY_BASE="$AIOS_ROOT/OS/overlay"
LOG="$AIOS_ROOT/OS/var/log/overlay.log"

log()  { echo "[overlay] $(date '+%H:%M:%S') $*" | tee -a "$LOG"; }
die()  { echo "[overlay] ERROR: $*" >&2; exit 1; }
need_root() { [[ $(id -u) -eq 0 ]] || die "Root required for overlay mounts. Use: su -c '$0 $*'"; }

CMD="${1:-status}"

mkdir -p "$OVERLAY_BASE" "$(dirname "$LOG")"

# ── Parse mount-points.conf ───────────────────────────────────────────────────
# Format: <host_path> <mount_point> [ro|rw]
parse_conf() {
    [[ -f "$CONF" ]] || die "Config not found: $CONF"
    grep -v '^\s*#' "$CONF" | grep -v '^\s*$'
}

# ── Mount a single overlay ────────────────────────────────────────────────────
mount_overlay() {
    local host_path="$1"
    local mount_point="$2"
    local mode="${3:-ro}"
    local name
    name=$(echo "$mount_point" | tr '/' '_' | sed 's/^_//')

    local upper="$OVERLAY_BASE/upper/$name"
    local work="$OVERLAY_BASE/work/$name"
    local merged="$OVERLAY_BASE/merged/$name"

    mkdir -p "$upper" "$work" "$merged"

    if mountpoint -q "$merged" 2>/dev/null; then
        log "Already mounted: $merged"
        return 0
    fi

    if [[ "$mode" == "ro" ]]; then
        mount --bind -o ro "$host_path" "$merged" \
            && log "Bind-mounted (ro): $host_path -> $merged"
    else
        mount -t overlay overlay \
            -o lowerdir="$host_path",upperdir="$upper",workdir="$work" \
            "$merged" \
            && log "Overlay mounted (rw): $host_path -> $merged"
    fi
}

# ── Unmount a single overlay ──────────────────────────────────────────────────
unmount_overlay() {
    local merged="$1"
    if mountpoint -q "$merged" 2>/dev/null; then
        umount "$merged" && log "Unmounted: $merged"
    fi
}

# ── Commands ──────────────────────────────────────────────────────────────────
case "$CMD" in
    mount)
        need_root
        log "Mounting overlays..."
        while IFS=' ' read -r host_path mount_point mode; do
            mount_overlay "$host_path" "$mount_point" "${mode:-ro}"
        done < <(parse_conf)
        log "All overlays mounted."
        ;;

    unmount)
        need_root
        log "Unmounting overlays..."
        find "$OVERLAY_BASE/merged" -mindepth 1 -maxdepth 1 -type d | while read -r merged; do
            unmount_overlay "$merged"
        done
        log "All overlays unmounted."
        ;;

    status)
        echo "=== AIOS Overlay Status ==="
        while IFS=' ' read -r host_path mount_point mode; do
            local_name=$(echo "$mount_point" | tr '/' '_' | sed 's/^_//')
            merged="$OVERLAY_BASE/merged/$local_name"
            if mountpoint -q "$merged" 2>/dev/null; then
                echo "  [MOUNTED] $host_path -> $merged ($mode)"
            else
                echo "  [  -  ]  $host_path -> $merged ($mode)"
            fi
        done < <(parse_conf)
        ;;

    *)
        die "Unknown command: $CMD. Use mount|unmount|status"
        ;;
esac
