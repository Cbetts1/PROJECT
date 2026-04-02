#!/bin/sh

OS_ROOT="${OS_ROOT:-/}"

RC2="$OS_ROOT/etc/rc2.d"
INITD="$OS_ROOT/etc/init.d"

mkdir -p "$RC2"

# Assign S-numbers to existing services
i=10
for svc in banner devices os-kernel; do
    if [ -f "$INITD/$svc" ]; then
        ln -sf "../init.d/$svc" "$RC2/S${i}-$svc"
        i=$((i+10))
    fi
done

# Create service manager command
cat > "$OS_ROOT/bin/os-service" << 'EOS'
#!/bin/sh

OS_ROOT="${OS_ROOT:-/}"
RC2="$OS_ROOT/etc/rc2.d"

case "$1" in
  enable)
    ln -sf "../init.d/$2" "$RC2/S99-$2"
    echo "Enabled: $2"
    ;;
  disable)
    rm -f "$RC2/"*"$2"
    echo "Disabled: $2"
    ;;
  list)
    ls "$RC2"
    ;;
  *)
    echo "Usage: os-service {enable|disable|list} <service>"
    ;;
esac
EOS

chmod +x "$OS_ROOT/bin/os-service"

echo "[OS] Service ordering + os-service installed."
