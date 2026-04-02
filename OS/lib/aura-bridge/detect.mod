# Aura Bridge — Host OS and connected device detection

BRIDGE_STATUS="$OS_ROOT/proc/aura/bridge/status"
BRIDGE_LOG="$OS_ROOT/var/log/bridge.log"

bridge_log() {
    mkdir -p "$(dirname "$BRIDGE_LOG")"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [bridge] $*" >> "$BRIDGE_LOG"
}

# Detect the OS this shell is currently running on
detect_host_os() {
    kernel=$(uname -s 2>/dev/null | tr '[:upper:]' '[:lower:]')
    case "$kernel" in
        linux)
            # Check for Android/Termux
            if [ -n "$TERMUX_VERSION" ] || [ -d "/data/data/com.termux" ]; then
                echo "android-termux"
            elif grep -qi "android" /proc/version 2>/dev/null; then
                echo "android"
            else
                echo "linux"
            fi
            ;;
        darwin) echo "macos" ;;
        cygwin*|mingw*|msys*) echo "windows" ;;
        *) echo "unknown" ;;
    esac
}

# Detect connected external devices
detect_devices() {
    found=""

    # iOS: check for libimobiledevice
    if command -v ideviceinfo >/dev/null 2>&1; then
        ios_udid=$(ideviceinfo -k UniqueDeviceID 2>/dev/null)
        if [ -n "$ios_udid" ]; then
            found="${found}ios:$ios_udid "
            bridge_log "iOS device detected: $ios_udid"
        fi
    fi

    # Android: check for ADB
    if command -v adb >/dev/null 2>&1; then
        adb_devs=$(adb devices 2>/dev/null | awk 'NR>1 && $2=="device" {print $1}')
        for dev in $adb_devs; do
            found="${found}android:$dev "
            bridge_log "Android device detected: $dev"
        done
    fi

    # SSH hosts from known_hosts
    if [ -f "$HOME/.ssh/known_hosts" ]; then
        hosts=$(awk '{print $1}' "$HOME/.ssh/known_hosts" 2>/dev/null | head -5)
        for h in $hosts; do
            found="${found}ssh:$h "
        done
    fi

    echo "$found"
}

# Write current bridge status to proc
bridge_write_status() {
    host_os=$(detect_host_os)
    devices=$(detect_devices)
    mkdir -p "$(dirname "$BRIDGE_STATUS")"
    cat > "$BRIDGE_STATUS" << EOF
host_os=$host_os
bridge_active=1
mirror_mounted=0
devices=$devices
updated=$(date +%s)
EOF
    bridge_log "Status updated: host_os=$host_os devices=$devices"
}

# Print bridge summary
bridge_summary() {
    bridge_write_status
    echo "=== Bridge Status ==="
    cat "$BRIDGE_STATUS"
    echo "===================="
}
