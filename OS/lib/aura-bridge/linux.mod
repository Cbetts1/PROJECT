# Aura Bridge — Linux/macOS/SSH bridge

LINUX_MIRROR="$OS_ROOT/mirror/linux"
LINUX_BRIDGE_LOG="$OS_ROOT/var/log/bridge-linux.log"

linux_log() {
    mkdir -p "$(dirname "$LINUX_BRIDGE_LOG")"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [linux] $*" >> "$LINUX_BRIDGE_LOG"
}

linux_host_info() {
    echo "=== Host System Info ==="
    echo "OS:       $(uname -s)"
    echo "Kernel:   $(uname -r)"
    echo "Arch:     $(uname -m)"
    echo "Hostname: $(hostname 2>/dev/null)"
    echo "User:     $(id 2>/dev/null)"
    if command -v lsb_release >/dev/null 2>&1; then
        echo "Distro:   $(lsb_release -d 2>/dev/null | cut -d: -f2 | xargs)"
    elif [ -f /etc/os-release ]; then
        echo "Distro:   $(grep PRETTY_NAME /etc/os-release | cut -d= -f2 | tr -d '"')"
    fi
    echo "========================"
}

linux_mount_host() {
    # Mirror the host Linux/macOS filesystem key dirs into our namespace
    mkdir -p "$LINUX_MIRROR"
    echo "[linux] Creating mirror of host filesystem..."

    for dir in /home /Users /tmp /var /etc; do
        [ -d "$dir" ] || continue
        mirror_target="$LINUX_MIRROR$(echo "$dir" | tr '/' '_')"
        if command -v bindfs >/dev/null 2>&1; then
            mkdir -p "$mirror_target"
            bindfs "$dir" "$mirror_target" 2>/dev/null && \
                echo "[linux] Bind-mounted $dir → $mirror_target" && continue
        fi
        # Fallback: create symlink
        mirror_link="$LINUX_MIRROR/$(basename "$dir")"
        ln -sf "$dir" "$mirror_link" 2>/dev/null
        echo "[linux] Linked $dir → $mirror_link"
        linux_log "Linked $dir"
    done

    cat > "$LINUX_MIRROR/.bridge_info" << EOF
type=linux
host_os=$(uname -s)
hostname=$(hostname 2>/dev/null)
mounted=$(date +%s)
mirror_path=$LINUX_MIRROR
EOF
    sed -i "s/mirror_mounted=0/mirror_mounted=1/" "$OS_ROOT/proc/aura/bridge/status" 2>/dev/null
    echo "[linux] Host mirror created at $LINUX_MIRROR"
    linux_log "Host mirror created"
}

linux_ssh_connect() {
    host="$1"
    user="${2:-$(id -un 2>/dev/null)}"
    port="${3:-22}"
    if [ -z "$host" ]; then
        echo "Usage: bridge ssh-connect <host> [user] [port]"
        return 1
    fi
    echo "[linux] Connecting to $user@$host:$port ..."
    linux_log "SSH connect to $user@$host:$port"
    ssh -p "$port" "$user@$host"
}

linux_ssh_mount() {
    host="$1"
    user="${2:-$(id -un 2>/dev/null)}"
    remote_path="${3:-/}"
    port="${4:-22}"
    if ! command -v sshfs >/dev/null 2>&1; then
        echo "[linux] sshfs not found. Install: apt install sshfs / pkg install sshfs"
        return 1
    fi
    mount_point="$LINUX_MIRROR/ssh_${host}"
    mkdir -p "$mount_point"
    echo "[linux] Mounting $user@$host:$remote_path → $mount_point"
    sshfs -p "$port" "$user@$host:$remote_path" "$mount_point"
    if [ $? -eq 0 ]; then
        echo "[linux] Mounted at $mount_point"
        linux_log "SSHFS mounted $host:$remote_path at $mount_point"
        sed -i "s/mirror_mounted=0/mirror_mounted=1/" "$OS_ROOT/proc/aura/bridge/status" 2>/dev/null
    else
        echo "[linux] Mount failed."
        linux_log "SSHFS mount failed: $host"
        return 1
    fi
}
