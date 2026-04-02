# Aura Bridge — Android bridge via ADB

ANDROID_MIRROR="$OS_ROOT/mirror/android"
ANDROID_BRIDGE_LOG="$OS_ROOT/var/log/bridge-android.log"

android_log() {
    mkdir -p "$(dirname "$ANDROID_BRIDGE_LOG")"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [android] $*" >> "$ANDROID_BRIDGE_LOG"
}

android_check_tools() {
    if ! command -v adb >/dev/null 2>&1; then
        echo "[android] ADB not found."
        echo "[android] Install with: pkg install android-tools  (Termux)"
        echo "[android]           or: apt install adb             (Debian/Ubuntu)"
        return 1
    fi
    return 0
}

android_devices() {
    android_check_tools || return 1
    echo "=== Connected Android Devices ==="
    adb devices -l 2>/dev/null
    echo "================================="
}

android_device_info() {
    android_check_tools || return 1
    serial="${1:-}"
    adb_cmd="adb${serial:+ -s $serial}"
    echo "=== Android Device Info ==="
    for prop in ro.product.model ro.product.manufacturer ro.build.version.release ro.serialno; do
        val=$($adb_cmd shell getprop "$prop" 2>/dev/null | tr -d '\r')
        printf '%-35s %s\n' "$prop:" "$val"
    done
    echo "==========================="
}

android_mount() {
    android_check_tools || return 1
    serial="${1:-}"
    adb_cmd="adb${serial:+ -s $serial}"
    mkdir -p "$ANDROID_MIRROR"

    echo "[android] Pulling device filesystem overview..."
    android_log "Mounting android device (serial=${serial:-default})"

    # Mirror key directories
    for dir in /sdcard /storage/emulated/0; do
        result=$($adb_cmd shell ls "$dir" 2>/dev/null)
        if [ -n "$result" ]; then
            echo "[android] Accessible at: $dir"
            echo "$result" | head -20
            # Create mirror index
            echo "$result" > "$ANDROID_MIRROR/$(echo "$dir" | tr '/' '_').listing"
            android_log "Mirrored listing of $dir"
        fi
    done

    cat > "$ANDROID_MIRROR/.bridge_info" << EOF
type=android
serial=${serial:-auto}
mounted=$(date +%s)
mirror_path=$ANDROID_MIRROR
EOF
    sed -i "s/mirror_mounted=0/mirror_mounted=1/" "$OS_ROOT/proc/aura/bridge/status" 2>/dev/null
    echo "[android] Mirror index created at $ANDROID_MIRROR"
}

android_shell() {
    android_check_tools || return 1
    serial="${1:-}"
    adb_cmd="adb${serial:+ -s $serial}"
    echo "[android] Opening ADB shell (type 'exit' to return to AIOS)..."
    android_log "Shell opened"
    $adb_cmd shell
    android_log "Shell closed"
}

android_push() {
    android_check_tools || return 1
    local_file="$1"
    remote_path="${2:-/sdcard/}"
    serial="${3:-}"
    adb_cmd="adb${serial:+ -s $serial}"
    adb $adb_cmd push "$local_file" "$remote_path"
    android_log "Pushed $local_file to $remote_path"
}

android_pull() {
    android_check_tools || return 1
    remote_file="$1"
    local_path="${2:-$ANDROID_MIRROR/}"
    serial="${3:-}"
    adb_cmd="adb${serial:+ -s $serial}"
    mkdir -p "$local_path"
    adb $adb_cmd pull "$remote_file" "$local_path"
    android_log "Pulled $remote_file to $local_path"
}
