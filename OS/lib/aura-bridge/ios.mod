# Aura Bridge — Apple iOS bridge via libimobiledevice

IOS_MIRROR="$OS_ROOT/mirror/ios"
IOS_BRIDGE_LOG="$OS_ROOT/var/log/bridge-ios.log"

ios_log() {
    mkdir -p "$(dirname "$IOS_BRIDGE_LOG")"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [ios] $*" >> "$IOS_BRIDGE_LOG"
}

ios_check_tools() {
    missing=""
    for tool in ideviceinfo idevicepair; do
        command -v "$tool" >/dev/null 2>&1 || missing="$missing $tool"
    done
    if [ -n "$missing" ]; then
        echo "[ios] Missing tools:$missing"
        echo "[ios] Install with: pkg install libimobiledevice  (Termux)"
        echo "[ios]           or: apt install libimobiledevice-utils  (Debian/Ubuntu)"
        return 1
    fi
    return 0
}

ios_device_info() {
    ios_check_tools || return 1
    echo "=== iOS Device Info ==="
    for key in DeviceName ProductType ProductVersion UniqueDeviceID; do
        val=$(ideviceinfo -k "$key" 2>/dev/null)
        printf '%-20s %s\n' "$key:" "$val"
    done
    echo "======================"
}

ios_pair() {
    ios_check_tools || return 1
    echo "[ios] Pairing with device..."
    idevicepair pair 2>&1
    ios_log "Pairing attempted"
}

ios_mount() {
    ios_check_tools || return 1
    if ! command -v ifuse >/dev/null 2>&1; then
        echo "[ios] 'ifuse' not found. Install: pkg install ifuse  (Termux)"
        echo "[ios] Falling back to AFC file listing..."
        ios_list_files "/"
        return 0
    fi
    mkdir -p "$IOS_MIRROR"
    echo "[ios] Mounting iOS filesystem at $IOS_MIRROR ..."
    ifuse "$IOS_MIRROR" 2>&1
    if [ $? -eq 0 ]; then
        echo "[ios] Mounted at $IOS_MIRROR"
        ios_log "Mounted at $IOS_MIRROR"
        # Update bridge status
        sed "s/mirror_mounted=0/mirror_mounted=1/" "$OS_ROOT/proc/aura/bridge/status" > "$OS_ROOT/proc/aura/bridge/status.tmp" 2>/dev/null \
            && mv "$OS_ROOT/proc/aura/bridge/status.tmp" "$OS_ROOT/proc/aura/bridge/status" 2>/dev/null
    else
        echo "[ios] Mount failed. Ensure device is paired and unlocked."
        ios_log "Mount failed"
        return 1
    fi
}

ios_unmount() {
    if command -v fusermount >/dev/null 2>&1; then
        fusermount -u "$IOS_MIRROR" 2>/dev/null
    elif command -v umount >/dev/null 2>&1; then
        umount "$IOS_MIRROR" 2>/dev/null
    fi
    echo "[ios] Unmounted $IOS_MIRROR"
    sed "s/mirror_mounted=1/mirror_mounted=0/" "$OS_ROOT/proc/aura/bridge/status" > "$OS_ROOT/proc/aura/bridge/status.tmp" 2>/dev/null \
        && mv "$OS_ROOT/proc/aura/bridge/status.tmp" "$OS_ROOT/proc/aura/bridge/status" 2>/dev/null
    ios_log "Unmounted"
}

ios_list_files() {
    path="${1:-/}"
    if command -v idevicecrashreport >/dev/null 2>&1 || command -v idevicebackup2 >/dev/null 2>&1; then
        echo "[ios] File listing via AFC not available without ifuse."
        echo "[ios] Mount with 'os-mirror mount ios' first, then browse $IOS_MIRROR"
    elif [ -d "$IOS_MIRROR" ] && [ "$(ls -A "$IOS_MIRROR" 2>/dev/null)" ]; then
        ls -la "$IOS_MIRROR$path" 2>/dev/null
    else
        echo "[ios] Mirror not mounted. Run 'os-mirror mount ios' first."
    fi
}

ios_shell() {
    ios_check_tools || return 1
    if ! command -v iproxy >/dev/null 2>&1; then
        echo "[ios] 'iproxy' not found. Install libimobiledevice for SSH tunneling."
        return 1
    fi
    echo "[ios] Setting up SSH tunnel to iOS device (port 2222 → device port 22)..."
    iproxy 2222 22 &
    IPROXY_PID=$!
    echo "[ios] Tunnel PID: $IPROXY_PID"
    echo "[ios] Connect with: ssh -p 2222 mobile@localhost"
    echo "[ios] Press Enter when done to close tunnel."
    read -r _
    kill "$IPROXY_PID" 2>/dev/null
    echo "[ios] Tunnel closed."
}
