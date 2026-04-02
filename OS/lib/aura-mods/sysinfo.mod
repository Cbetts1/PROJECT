mod_name="sysinfo"
mod_help="System information commands."

sysinfo_uptime() {
    boot=$(awk -F= '/boot_time/ {print $2}' "$OS_ROOT/proc/os.state")
    now=$(date +%s)
    echo "Uptime: $((now - boot)) seconds"
}

sysinfo_kernel() {
    awk -F= '/kernel_pid/ {print "Kernel PID: " $2}' "$OS_ROOT/proc/os.state"
}
