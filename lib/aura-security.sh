#!/usr/bin/env bash
# lib/aura-security.sh — Security utilities
# © 2026 Chris Betts | AIOSCPU Official
#
# Security functions for AIOS:
#   - sanitize_input() — strips shell metacharacters
#   - validate_path() — validates path stays within OS_ROOT
#   - audit_log() — writes security audit log

[[ -n "${_AURA_SECURITY_SH_LOADED:-}" ]] && return 0
_AURA_SECURITY_SH_LOADED=1

# shellcheck source=lib/aura-core.sh
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/aura-core.sh"

# Security log file
SECURITY_LOG="${OS_ROOT:-${AIOS_ROOT:-$PWD}/OS}/var/log/security.log"

# ---------------------------------------------------------------------------
# sanitize_input() — Strip shell metacharacters from user input
# ---------------------------------------------------------------------------
# Removes: ; | & ` $ ( ) { } [ ] < > newlines
# Use this on raw input before passing to shell commands
#
# Usage: sanitized=$(sanitize_input "$raw_input")
#
sanitize_input() {
    local input="$1"
    local max_length="${MAX_INPUT_LENGTH:-4096}"
    
    # Truncate to max length
    if [ ${#input} -gt "$max_length" ]; then
        input="${input:0:$max_length}"
    fi
    
    # Remove dangerous shell metacharacters
    # Keep: alphanumeric, space, basic punctuation (. , - _ / : @ #)
    local sanitized
    sanitized=$(printf '%s' "$input" | tr -d ';|&`$(){}[]<>\n\r' | tr -d "'" | tr -d '"')
    
    # Remove any remaining control characters except space
    sanitized=$(printf '%s' "$sanitized" | tr -cd '[:print:]')
    
    printf '%s' "$sanitized"
}

# ---------------------------------------------------------------------------
# validate_path() — Validate a path stays within OS_ROOT jail
# ---------------------------------------------------------------------------
# Wraps osroot_resolve() with additional checks
#
# Usage: if validate_path "/some/path"; then ... fi
#
# Returns: 0 if path is valid and within jail, 1 otherwise
#
validate_path() {
    local path="$1"
    local resolved
    
    # Check for obvious escape attempts
    case "$path" in
        *../*|*/..*|*..|..*)
            audit_log "BLOCKED" "path_escape" "Attempted path traversal: $path"
            return 1
            ;;
    esac
    
    # Check for null bytes
    if [[ "$path" == *$'\0'* ]]; then
        audit_log "BLOCKED" "null_byte" "Null byte in path: $path"
        return 1
    fi
    
    # Use osroot_resolve for the actual validation
    resolved=$(osroot_resolve "$path" 2>/dev/null) || {
        audit_log "BLOCKED" "path_resolve" "Failed to resolve path: $path"
        return 1
    }
    
    # Verify the resolved path is within OS_ROOT
    local os_root="${OS_ROOT:-${AIOS_ROOT:-$PWD}/OS}"
    if [[ ! "$resolved" =~ ^"$os_root" ]]; then
        audit_log "BLOCKED" "jail_escape" "Path escapes jail: $path -> $resolved"
        return 1
    fi
    
    return 0
}

# ---------------------------------------------------------------------------
# audit_log() — Write to security audit log
# ---------------------------------------------------------------------------
# Usage: audit_log "action" "category" "message"
#
# Example: audit_log "BLOCKED" "injection" "Suspicious input detected"
#
audit_log() {
    local action="${1:-UNKNOWN}"
    local category="${2:-general}"
    local message="${3:-}"
    
    # Get user if available
    local user="${USER:-${LOGNAME:-unknown}}"
    
    # Timestamp
    local ts
    ts=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    
    # Ensure log directory exists
    mkdir -p "$(dirname "$SECURITY_LOG")" 2>/dev/null || true
    
    # Write log entry
    printf '[%s] [%s] [%s] user=%s %s\n' "$ts" "$action" "$category" "$user" "$message" >> "$SECURITY_LOG" 2>/dev/null || true
    
    # Also log to structured log if security events logging is enabled
    if [[ "${LOG_SECURITY_EVENTS:-1}" == "1" ]]; then
        log_structured "SECURITY" "$category" "$message" "{\"action\":\"$action\",\"user\":\"$user\"}" 2>/dev/null || true
    fi
}

# ---------------------------------------------------------------------------
# check_exec_allowed() — Check if execution outside jail is allowed
# ---------------------------------------------------------------------------
# Returns 0 if allowed, 1 if blocked
#
check_exec_allowed() {
    local cmd="$1"
    
    if [[ "${ALLOW_EXEC_OUTSIDE_JAIL:-0}" == "0" ]]; then
        # Check if command is outside OS_ROOT
        local cmd_path
        cmd_path=$(command -v "$cmd" 2>/dev/null || echo "$cmd")
        
        local os_root="${OS_ROOT:-${AIOS_ROOT:-$PWD}/OS}"
        local aios_root="${AIOS_ROOT:-$PWD}"
        
        if [[ -n "$cmd_path" ]] && [[ ! "$cmd_path" =~ ^"$os_root" ]] && [[ ! "$cmd_path" =~ ^"$aios_root" ]]; then
            # Allow system utilities
            case "$cmd" in
                /bin/*|/usr/bin/*|bash|sh|python*|grep|awk|sed|cat|ls|mkdir|cp|mv|rm|date|head|tail|wc|sort|uniq)
                    return 0
                    ;;
                *)
                    audit_log "BLOCKED" "exec_jail" "Execution outside jail: $cmd"
                    return 1
                    ;;
            esac
        fi
    fi
    
    return 0
}

# Export functions for use in other scripts
export -f sanitize_input validate_path audit_log check_exec_allowed 2>/dev/null || true
