# Aura Bridge — Mirror orchestration (unified cross-OS namespace)

MIRROR_ROOT="$OS_ROOT/mirror"
MIRROR_LOG="$OS_ROOT/var/log/mirror.log"

mirror_log() {
    mkdir -p "$(dirname "$MIRROR_LOG")"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [mirror] $*" >> "$MIRROR_LOG"
}

mirror_init() {
    mkdir -p "$MIRROR_ROOT/ios" \
             "$MIRROR_ROOT/android" \
             "$MIRROR_ROOT/linux" \
             "$MIRROR_ROOT/custom"
    mirror_log "Mirror namespace initialized"
}

mirror_detect_and_mount() {
    mirror_init
    echo "[mirror] Detecting connected devices..."

    host_os=$(detect_host_os)
    echo "[mirror] Host OS: $host_os"

    # Always mirror host
    case "$host_os" in
        linux|macos|android-termux|android)
            echo "[mirror] Mounting host Linux/macOS/Android filesystem..."
            linux_mount_host ;;
    esac

    # iOS device?
    if command -v ideviceinfo >/dev/null 2>&1; then
        udid=$(ideviceinfo -k UniqueDeviceID 2>/dev/null)
        if [ -n "$udid" ]; then
            echo "[mirror] iOS device found, mounting..."
            ios_mount
        fi
    fi

    # Android via ADB?
    if command -v adb >/dev/null 2>&1; then
        devs=$(adb devices 2>/dev/null | awk 'NR>1 && $2=="device" {print $1}')
        if [ -n "$devs" ]; then
            for d in $devs; do
                echo "[mirror] Android device found ($d), mirroring..."
                android_mount "$d"
            done
        fi
    fi

    mirror_status
}

mirror_mount() {
    target="${1:-auto}"
    shift
    mirror_init
    case "$target" in
        ios)     ios_mount "$@" ;;
        android) android_mount "$@" ;;
        linux|host)   linux_mount_host ;;
        ssh)     linux_ssh_mount "$@" ;;
        auto)    mirror_detect_and_mount ;;
        *)
            echo "Usage: os-mirror mount {ios|android|linux|ssh|auto}"
            return 1
            ;;
    esac
}

mirror_unmount() {
    target="${1:-all}"
    case "$target" in
        ios)    ios_unmount ;;
        android)
            rm -f "$MIRROR_ROOT/android/.bridge_info"
            echo "[mirror] Android mirror cleared."
            ;;
        linux)
            # Unmount any sshfs mounts
            for mp in "$MIRROR_ROOT"/linux/ssh_*; do
                [ -d "$mp" ] && { fusermount -u "$mp" 2>/dev/null || umount "$mp" 2>/dev/null; }
            done
            rm -f "$MIRROR_ROOT/linux/.bridge_info"
            echo "[mirror] Linux mirror cleared."
            ;;
        all)
            mirror_unmount ios
            mirror_unmount android
            mirror_unmount linux
            sed -i "s/mirror_mounted=1/mirror_mounted=0/" "$OS_ROOT/proc/aura/bridge/status" 2>/dev/null
            ;;
    esac
    mirror_log "Unmounted: $target"
}

mirror_status() {
    echo "=== Mirror Status ==="
    cat "$OS_ROOT/proc/aura/bridge/status" 2>/dev/null
    echo
    echo "Mirror directories:"
    for d in "$MIRROR_ROOT"/*/; do
        [ -d "$d" ] || continue
        name=$(basename "$d")
        if [ -f "$d/.bridge_info" ]; then
            printf '  %-12s [mounted]\n' "$name"
            awk '{printf "    %s\n", $0}' "$d/.bridge_info"
        else
            printf '  %-12s [empty]\n' "$name"
        fi
    done
    echo "===================="
}

mirror_ls() {
    target="${1:-.}"
    path="${2:-/}"
    ls -la "$MIRROR_ROOT/$target$path" 2>/dev/null || echo "[mirror] Not mounted: $target"
}
