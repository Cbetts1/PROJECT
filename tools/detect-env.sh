#!/usr/bin/env bash
# tools/detect-env.sh — Environment Detection Script
# © 2026 Chris Betts | AIOSCPU Official
#
# Detects the current runtime environment and available tools.
# Can be sourced (sets env vars) or run standalone (prints matrix).
#
# Usage:
#   source tools/detect-env.sh    # Sets AIOS_ENV and related vars
#   bash tools/detect-env.sh      # Prints portability matrix
#
# Detected environments: termux | linux | macos | docker | unknown

# Prevent re-sourcing
[[ -n "${_DETECT_ENV_LOADED:-}" ]] && return 0 2>/dev/null || true
_DETECT_ENV_LOADED=1

# ---------------------------------------------------------------------------
# Environment detection functions
# ---------------------------------------------------------------------------

_detect_termux() {
    # Termux on Android has PREFIX set and specific paths
    if [[ -n "${PREFIX:-}" ]] && [[ "${PREFIX}" == *"com.termux"* ]]; then
        return 0
    fi
    if [[ -d "/data/data/com.termux" ]]; then
        return 0
    fi
    return 1
}

_detect_docker() {
    # Check for Docker indicators
    if [[ -f "/.dockerenv" ]]; then
        return 0
    fi
    if grep -q "docker\|lxc\|containerd" /proc/1/cgroup 2>/dev/null; then
        return 0
    fi
    if [[ -f "/run/.containerenv" ]]; then
        return 0
    fi
    return 1
}

_detect_macos() {
    if [[ "$(uname -s)" == "Darwin" ]]; then
        return 0
    fi
    return 1
}

_detect_linux() {
    if [[ "$(uname -s)" == "Linux" ]]; then
        return 0
    fi
    return 1
}

_detect_wsl() {
    if grep -qiE "(microsoft|wsl)" /proc/version 2>/dev/null; then
        return 0
    fi
    return 1
}

# ---------------------------------------------------------------------------
# Tool availability checks
# ---------------------------------------------------------------------------

_check_tool() {
    command -v "$1" >/dev/null 2>&1
}

_get_bash_version() {
    if _check_tool bash; then
        bash --version 2>/dev/null | head -1 | grep -oE '[0-9]+\.[0-9]+' | head -1
    else
        echo "n/a"
    fi
}

_get_python_version() {
    if _check_tool python3; then
        python3 --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+' | head -1
    elif _check_tool python; then
        python --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+'
    else
        echo "n/a"
    fi
}

# ---------------------------------------------------------------------------
# Main detection
# ---------------------------------------------------------------------------

detect_environment() {
    # Order matters: more specific checks first
    if _detect_termux; then
        AIOS_ENV="termux"
    elif _detect_docker; then
        AIOS_ENV="docker"
    elif _detect_wsl; then
        AIOS_ENV="wsl"
    elif _detect_macos; then
        AIOS_ENV="macos"
    elif _detect_linux; then
        AIOS_ENV="linux"
    else
        AIOS_ENV="unknown"
    fi
    
    export AIOS_ENV
    
    # Set environment-specific defaults
    case "$AIOS_ENV" in
        termux)
            AIOS_PREFIX="${PREFIX:-/data/data/com.termux/files/usr}"
            AIOS_HOME_DEFAULT="$HOME/aios"
            AIOS_SHELL_DEFAULT="$AIOS_PREFIX/bin/bash"
            ;;
        docker)
            AIOS_PREFIX="/usr"
            AIOS_HOME_DEFAULT="/opt/aios"
            AIOS_SHELL_DEFAULT="/bin/bash"
            ;;
        macos)
            AIOS_PREFIX="/usr/local"
            AIOS_HOME_DEFAULT="$HOME/aios"
            AIOS_SHELL_DEFAULT="/bin/zsh"
            ;;
        linux|wsl)
            AIOS_PREFIX="/usr"
            AIOS_HOME_DEFAULT="$HOME/aios"
            AIOS_SHELL_DEFAULT="/bin/bash"
            ;;
        *)
            AIOS_PREFIX="/usr"
            AIOS_HOME_DEFAULT="$HOME/aios"
            AIOS_SHELL_DEFAULT="/bin/sh"
            ;;
    esac
    
    export AIOS_PREFIX AIOS_HOME_DEFAULT AIOS_SHELL_DEFAULT
    
    # Detect tools
    AIOS_HAS_PYTHON3=$(_check_tool python3 && echo "yes" || echo "no")
    AIOS_HAS_CURL=$(_check_tool curl && echo "yes" || echo "no")
    AIOS_HAS_WGET=$(_check_tool wget && echo "yes" || echo "no")
    AIOS_HAS_GIT=$(_check_tool git && echo "yes" || echo "no")
    AIOS_HAS_JQ=$(_check_tool jq && echo "yes" || echo "no")
    AIOS_BASH_VERSION=$(_get_bash_version)
    AIOS_PYTHON_VERSION=$(_get_python_version)
    
    export AIOS_HAS_PYTHON3 AIOS_HAS_CURL AIOS_HAS_WGET AIOS_HAS_GIT AIOS_HAS_JQ
    export AIOS_BASH_VERSION AIOS_PYTHON_VERSION
}

# ---------------------------------------------------------------------------
# Portability matrix output
# ---------------------------------------------------------------------------

print_portability_matrix() {
    detect_environment
    
    echo "=== AIOS Environment Detection ==="
    echo ""
    echo "Detected Environment: $AIOS_ENV"
    echo "  PREFIX: $AIOS_PREFIX"
    echo "  Default HOME: $AIOS_HOME_DEFAULT"
    echo "  Default Shell: $AIOS_SHELL_DEFAULT"
    echo ""
    echo "=== Tool Availability ==="
    echo ""
    printf "  %-15s %s\n" "Tool" "Status"
    printf "  %-15s %s\n" "----" "------"
    printf "  %-15s %s\n" "bash" "$AIOS_BASH_VERSION"
    printf "  %-15s %s\n" "python3" "$AIOS_PYTHON_VERSION"
    printf "  %-15s %s\n" "curl" "$AIOS_HAS_CURL"
    printf "  %-15s %s\n" "wget" "$AIOS_HAS_WGET"
    printf "  %-15s %s\n" "git" "$AIOS_HAS_GIT"
    printf "  %-15s %s\n" "jq" "$AIOS_HAS_JQ"
    echo ""
    echo "=== Portability Matrix ==="
    echo ""
    printf "  %-20s %-8s %-8s %-8s %-8s %-8s\n" "Feature" "termux" "linux" "macos" "docker" "wsl"
    printf "  %-20s %-8s %-8s %-8s %-8s %-8s\n" "-------" "------" "-----" "-----" "------" "---"
    printf "  %-20s %-8s %-8s %-8s %-8s %-8s\n" "Core Shell" "✓" "✓" "✓" "✓" "✓"
    printf "  %-20s %-8s %-8s %-8s %-8s %-8s\n" "AI Backend" "✓" "✓" "✓" "✓" "✓"
    printf "  %-20s %-8s %-8s %-8s %-8s %-8s\n" "LLaMA Inference" "✓*" "✓" "✓" "✓" "✓"
    printf "  %-20s %-8s %-8s %-8s %-8s %-8s\n" "iOS Bridge" "—" "—" "✓" "—" "—"
    printf "  %-20s %-8s %-8s %-8s %-8s %-8s\n" "Android Bridge" "local" "✓" "✓" "✓" "✓"
    printf "  %-20s %-8s %-8s %-8s %-8s %-8s\n" "Linux Bridge" "✓" "✓" "✓" "✓" "✓"
    printf "  %-20s %-8s %-8s %-8s %-8s %-8s\n" "HTTP API" "✓" "✓" "✓" "✓" "✓"
    printf "  %-20s %-8s %-8s %-8s %-8s %-8s\n" "Systemd Services" "—" "✓" "—" "varies" "✓"
    echo ""
    echo "Legend: ✓ = supported, — = not applicable, * = with limitations"
    echo ""
    
    # Environment-specific notes
    case "$AIOS_ENV" in
        termux)
            echo "Note: Running on Termux/Android"
            echo "  - LLaMA works but may be slow on older devices"
            echo "  - Use PREFIX=$PREFIX for package paths"
            ;;
        docker)
            echo "Note: Running in Docker container"
            echo "  - Persistent storage requires volume mounts"
            echo "  - Device bridges may need --privileged flag"
            ;;
        macos)
            echo "Note: Running on macOS"
            echo "  - iOS bridge available via libimobiledevice"
            echo "  - Some GNU tools differ from BSD defaults"
            ;;
        wsl)
            echo "Note: Running on Windows Subsystem for Linux"
            echo "  - Full Linux compatibility"
            echo "  - Windows filesystem at /mnt/c/"
            ;;
    esac
}

# ---------------------------------------------------------------------------
# Main: if run directly (not sourced), print matrix
# ---------------------------------------------------------------------------

# Check if being sourced or executed
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # Executed directly
    print_portability_matrix
else
    # Being sourced - just set variables
    detect_environment
fi
