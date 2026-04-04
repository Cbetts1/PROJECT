#!/usr/bin/env bash
# tools/module-ctl.sh — Module Management Tool
# © 2026 Chris Betts | AIOSCPU Official
#
# Manages AIOS modules from config/module-registry.conf:
#   - list    — Show all registered modules
#   - info    — Show module metadata
#   - enable  — Enable a module
#   - disable — Disable a module
#   - check   — Verify all enabled modules are present
#
# Usage:
#   module-ctl.sh <action> [module]
#
# Exit codes:
#   0 — Success
#   1 — Error

set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AIOS_ROOT="${AIOS_ROOT:-$(cd "$SCRIPT_DIR/.." && pwd)}"

REGISTRY="$AIOS_ROOT/config/module-registry.conf"
SIMPLE_REGISTRY="$AIOS_ROOT/config/modules.list"

usage() {
    cat << 'EOF'
Usage: module-ctl.sh <action> [module]

Actions:
  list              List all registered modules
  info <module>     Show detailed info for a module
  enable <module>   Enable a module
  disable <module>  Disable a module
  check             Verify all enabled modules exist

Examples:
  module-ctl.sh list
  module-ctl.sh info aura-core
  module-ctl.sh enable aura-llama
  module-ctl.sh check
EOF
    exit 1
}

# ---------------------------------------------------------------------------
# Parse INI-style module registry
# ---------------------------------------------------------------------------
parse_module() {
    local module="$1"
    local field="$2"
    local in_section=0
    
    while IFS= read -r line; do
        # Skip empty lines and comments
        [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
        
        # Section header
        if [[ "$line" =~ ^\[([^\]]+)\] ]]; then
            if [[ "${BASH_REMATCH[1]}" == "$module" ]]; then
                in_section=1
            else
                in_section=0
            fi
            continue
        fi
        
        # Key=value pair in our section
        if [[ $in_section -eq 1 ]] && [[ "$line" =~ ^([^=]+)=(.*)$ ]]; then
            local key="${BASH_REMATCH[1]}"
            local value="${BASH_REMATCH[2]}"
            if [[ "$key" == "$field" ]]; then
                echo "$value"
                return 0
            fi
        fi
    done < "$REGISTRY"
    
    return 1
}

# Get all module names
get_all_modules() {
    grep -E '^\[' "$REGISTRY" 2>/dev/null | tr -d '[]' | sort
}

# ---------------------------------------------------------------------------
# List all modules
# ---------------------------------------------------------------------------
action_list() {
    echo "=== AIOS Module Registry ==="
    printf "%-20s %-8s %-10s %-8s %s\n" "MODULE" "VERSION" "TYPE" "ENABLED" "PATH"
    printf "%-20s %-8s %-10s %-8s %s\n" "------" "-------" "----" "-------" "----"
    
    for module in $(get_all_modules); do
        local path=$(parse_module "$module" "path")
        local version=$(parse_module "$module" "version" 2>/dev/null || echo "1.0")
        local type=$(parse_module "$module" "type" 2>/dev/null || echo "unknown")
        local enabled=$(parse_module "$module" "enabled" 2>/dev/null || echo "true")
        
        # Check if file exists
        local exists="✓"
        [ ! -e "$AIOS_ROOT/$path" ] && exists="✗"
        
        printf "%-20s %-8s %-10s %-8s %s %s\n" "$module" "$version" "$type" "$enabled" "$path" "$exists"
    done
    
    echo ""
    echo "Legend: ✓ = file exists, ✗ = file missing"
}

# ---------------------------------------------------------------------------
# Show module info
# ---------------------------------------------------------------------------
action_info() {
    local module="$1"
    [ -z "$module" ] && { echo "Error: module name required"; exit 1; }
    
    # Check if module exists in registry
    if ! grep -q "^\[$module\]" "$REGISTRY" 2>/dev/null; then
        echo "Error: module '$module' not found in registry"
        exit 1
    fi
    
    echo "=== Module: $module ==="
    echo ""
    
    local path=$(parse_module "$module" "path")
    local lang=$(parse_module "$module" "lang" 2>/dev/null || echo "unknown")
    local type=$(parse_module "$module" "type" 2>/dev/null || echo "unknown")
    local load_order=$(parse_module "$module" "load_order" 2>/dev/null || echo "0")
    local enabled=$(parse_module "$module" "enabled" 2>/dev/null || echo "true")
    local description=$(parse_module "$module" "description" 2>/dev/null || echo "No description")
    
    echo "  Path:        $path"
    echo "  Language:    $lang"
    echo "  Type:        $type"
    echo "  Load Order:  $load_order"
    echo "  Enabled:     $enabled"
    echo "  Description: $description"
    echo ""
    
    # Check if file exists
    if [ -e "$AIOS_ROOT/$path" ]; then
        echo "  File Status: EXISTS"
        local size=$(stat -c%s "$AIOS_ROOT/$path" 2>/dev/null || stat -f%z "$AIOS_ROOT/$path" 2>/dev/null || echo "unknown")
        echo "  File Size:   $size bytes"
    else
        echo "  File Status: MISSING"
    fi
}

# ---------------------------------------------------------------------------
# Enable module
# ---------------------------------------------------------------------------
action_enable() {
    local module="$1"
    [ -z "$module" ] && { echo "Error: module name required"; exit 1; }
    
    if ! grep -q "^\[$module\]" "$REGISTRY" 2>/dev/null; then
        echo "Error: module '$module' not found in registry"
        exit 1
    fi
    
    # Update enabled=true in registry
    local temp_file="${REGISTRY}.tmp"
    local in_section=0
    local updated=0
    
    while IFS= read -r line; do
        if [[ "$line" =~ ^\[([^\]]+)\] ]]; then
            if [[ "${BASH_REMATCH[1]}" == "$module" ]]; then
                in_section=1
            else
                in_section=0
            fi
            echo "$line"
        elif [[ $in_section -eq 1 ]] && [[ "$line" =~ ^enabled= ]]; then
            echo "enabled=true"
            updated=1
        else
            echo "$line"
        fi
    done < "$REGISTRY" > "$temp_file"
    
    mv "$temp_file" "$REGISTRY"
    
    if [ $updated -eq 1 ]; then
        echo "Module '$module' enabled"
    else
        echo "Module '$module' was already enabled or has no enabled field"
    fi
}

# ---------------------------------------------------------------------------
# Disable module
# ---------------------------------------------------------------------------
action_disable() {
    local module="$1"
    [ -z "$module" ] && { echo "Error: module name required"; exit 1; }
    
    if ! grep -q "^\[$module\]" "$REGISTRY" 2>/dev/null; then
        echo "Error: module '$module' not found in registry"
        exit 1
    fi
    
    # Update enabled=false in registry
    local temp_file="${REGISTRY}.tmp"
    local in_section=0
    local updated=0
    
    while IFS= read -r line; do
        if [[ "$line" =~ ^\[([^\]]+)\] ]]; then
            if [[ "${BASH_REMATCH[1]}" == "$module" ]]; then
                in_section=1
            else
                in_section=0
            fi
            echo "$line"
        elif [[ $in_section -eq 1 ]] && [[ "$line" =~ ^enabled= ]]; then
            echo "enabled=false"
            updated=1
        else
            echo "$line"
        fi
    done < "$REGISTRY" > "$temp_file"
    
    mv "$temp_file" "$REGISTRY"
    
    if [ $updated -eq 1 ]; then
        echo "Module '$module' disabled"
    else
        echo "Module '$module' was already disabled or has no enabled field"
    fi
}

# ---------------------------------------------------------------------------
# Check all enabled modules exist
# ---------------------------------------------------------------------------
action_check() {
    echo "=== Module Verification ==="
    
    local total=0
    local present=0
    local missing=0
    
    for module in $(get_all_modules); do
        local enabled=$(parse_module "$module" "enabled" 2>/dev/null || echo "true")
        [ "$enabled" != "true" ] && continue
        
        total=$((total + 1))
        local path=$(parse_module "$module" "path")
        
        if [ -e "$AIOS_ROOT/$path" ]; then
            echo "[OK]      $module ($path)"
            present=$((present + 1))
        else
            echo "[MISSING] $module ($path)"
            missing=$((missing + 1))
        fi
    done
    
    echo ""
    echo "=== Summary ==="
    echo "Total enabled: $total"
    echo "Present:       $present"
    echo "Missing:       $missing"
    
    if [ $missing -gt 0 ]; then
        exit 1
    fi
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
[ ! -f "$REGISTRY" ] && { echo "Error: Module registry not found: $REGISTRY"; exit 1; }

ACTION="${1:-list}"
shift 2>/dev/null || true

case "$ACTION" in
    list)    action_list ;;
    info)    action_info "$1" ;;
    enable)  action_enable "$1" ;;
    disable) action_disable "$1" ;;
    check)   action_check ;;
    help|--help|-h) usage ;;
    *)
        echo "Unknown action: $ACTION"
        usage
        ;;
esac
