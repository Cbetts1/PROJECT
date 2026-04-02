#!/bin/sh

OS_ROOT="${OS_ROOT:-/}"

# Create runlevel directories
mkdir -p "$OS_ROOT/etc/rc0.d"
mkdir -p "$OS_ROOT/etc/rc1.d"
mkdir -p "$OS_ROOT/etc/rc2.d"

# Create default boot target
echo "2" > "$OS_ROOT/etc/boot.target"

# Create shutdown script
cat > "$OS_ROOT/bin/shutdown" << 'EOS'
#!/bin/sh
echo "System shutting down..."
exit 0
EOS
chmod +x "$OS_ROOT/bin/shutdown"

# Create reboot script
cat > "$OS_ROOT/bin/reboot" << 'EOR'
#!/bin/sh
echo "System rebooting..."
exit 0
EOR
chmod +x "$OS_ROOT/bin/reboot"

# Patch init to load boot target
sed -i '/Starting services/a \
BOOT_TARGET=$(cat $OS_ROOT/etc/boot.target 2>/dev/null || echo 2) \
SERV_DIR="$OS_ROOT/etc/rc${BOOT_TARGET}.d"' "$OS_ROOT/sbin/init"

echo "[OS] Runlevels installed and init patched."
