#!/bin/sh
# run-os.sh — Launch the AIOS-Lite virtual OS
# © 2026 Chris Betts | AIOSCPU Official | AI-generated, fully legal
#
# Resolves AIOS_HOME and OS_ROOT from script location, then boots the OS via
# OS/sbin/init.  All arguments are forwarded verbatim.
#
# Usage:
#   sh run-os.sh                     — boot + login shell (default)
#   sh run-os.sh --no-shell          — boot only, no interactive shell
#   sh run-os.sh --shell <name>      — boot + named shell

AIOS_HOME="$(cd "$(dirname "$0")" 2>/dev/null && pwd)"
export AIOS_HOME
export OS_ROOT="$AIOS_HOME/OS"

exec sh "$AIOS_HOME/OS/sbin/init" "$@"
