#!/bin/bash
# Unit tests for AIOS-Lite components
# Run: AIOS_HOME=$(pwd) OS_ROOT=$(pwd)/OS bash tests/unit-tests.sh

REPO_ROOT="${AIOS_HOME:-$(cd "$(dirname "$0")/.." && pwd)}"
OS_ROOT="${OS_ROOT:-$REPO_ROOT/OS}"
FS_PY="$OS_ROOT/lib/filesystem.py"

PASS=0
FAIL=0
ERRORS=""

pass() { echo "[PASS] $1"; PASS=$((PASS+1)); }
fail() { echo "[FAIL] $1"; FAIL=$((FAIL+1)); ERRORS="$ERRORS\n  - $1"; }

echo "Running unit tests..."

# ---------------------------------------------------------------------------
# filesystem.py tests
# ---------------------------------------------------------------------------
echo
echo "=== filesystem.py tests ==="

# 1. list OS/var/log
out=$(OS_ROOT="$OS_ROOT" python3 "$FS_PY" list var/log 2>/dev/null)
if echo "$out" | grep -q "os.log"; then
    pass "fs list: var/log contains os.log"
else
    fail "fs list: var/log should contain os.log"
fi

# 2. exists (positive)
result=$(OS_ROOT="$OS_ROOT" python3 "$FS_PY" exists proc/os.state 2>/dev/null)
[ "$result" = "true" ] && pass "fs exists: proc/os.state found" || fail "fs exists: proc/os.state not found"

# 3. exists (negative — file outside OS_ROOT)
out=$(OS_ROOT="$OS_ROOT" python3 "$FS_PY" exists ../../some/outside/path 2>/dev/null)
[ "$out" = "false" ] && pass "fs exists: outside path returns false" || fail "fs exists: outside path should return false"

# 4. path traversal blocked
OS_ROOT="$OS_ROOT" python3 "$FS_PY" read "../../etc/passwd" 2>&1 | grep -q "Access denied" \
    && pass "fs read: traversal blocked" || fail "fs read: traversal not blocked"

# 5. write + read roundtrip
_tmp_path="tmp/unit-test-$$.txt"
OS_ROOT="$OS_ROOT" python3 "$FS_PY" write "$_tmp_path" "hello-unit-test"
out=$(OS_ROOT="$OS_ROOT" python3 "$FS_PY" read "$_tmp_path" 2>/dev/null)
[ "$out" = "hello-unit-test" ] && pass "fs write/read roundtrip" || fail "fs write/read roundtrip"
rm -f "$OS_ROOT/$_tmp_path"

# 6. append + read (CLI append adds a trailing newline per call)
_tmp_path2="tmp/unit-append-$$.txt"
OS_ROOT="$OS_ROOT" python3 "$FS_PY" append "$_tmp_path2" "line1"
OS_ROOT="$OS_ROOT" python3 "$FS_PY" append "$_tmp_path2" "line2"
out=$(OS_ROOT="$OS_ROOT" python3 "$FS_PY" read "$_tmp_path2" 2>/dev/null)
echo "$out" | grep -q "line1" && echo "$out" | grep -q "line2" \
    && pass "fs append/read" || fail "fs append/read"
rm -f "$OS_ROOT/$_tmp_path2"

# 7. fs_log writes to aura.log
_prev_log=$(OS_ROOT="$OS_ROOT" python3 "$FS_PY" read var/log/aura.log 2>/dev/null | wc -l)
OS_ROOT="$OS_ROOT" python3 "$FS_PY" log var/log/aura.log "unit-test marker $$"
_new_log=$(OS_ROOT="$OS_ROOT" python3 "$FS_PY" read var/log/aura.log 2>/dev/null | wc -l)
[ "$_new_log" -gt "$_prev_log" ] && pass "fs log: appends to aura.log" || fail "fs log: should append to aura.log"

# 8. aura.log entry contains timestamp
OS_ROOT="$OS_ROOT" python3 "$FS_PY" read var/log/aura.log 2>/dev/null | grep -q "unit-test marker $$" \
    && pass "fs log: message appears in aura.log" || fail "fs log: message not found in aura.log"

# 9. stat returns expected keys
out=$(OS_ROOT="$OS_ROOT" python3 "$FS_PY" stat proc/os.state 2>/dev/null)
echo "$out" | grep -q "isfile: True" && pass "fs stat: isfile=True for regular file" || fail "fs stat: isfile should be True"

# ---------------------------------------------------------------------------
# os-shell fuzzy matching (pure awk, sourced inline)
# ---------------------------------------------------------------------------
echo
echo "=== fuzzy command matching tests ==="

# Build the fuzzy match function standalone
_KNOWN_CMDS="ask recall sysinfo uptime disk ls cd read write start stop restart services status help exit quit"

fuzzy_match_test() {
    input="$1"
    awk -v input="$input" -v cmds="$_KNOWN_CMDS" '
    function min3(a, b, c,    m) { m=(a<b)?a:b; return(m<c)?m:c }
    function lev(s, t,    m, n, i, j, cost, dtbl) {
        m=length(s); n=length(t)
        if(m==0) return n; if(n==0) return m
        for(i=0;i<=m;i++) dtbl[i,0]=i
        for(j=0;j<=n;j++) dtbl[0,j]=j
        for(i=1;i<=m;i++) for(j=1;j<=n;j++) {
            cost=(substr(s,i,1)==substr(t,j,1))?0:1
            dtbl[i,j]=min3(dtbl[i-1,j]+1,dtbl[i,j-1]+1,dtbl[i-1,j-1]+cost)
        }
        return dtbl[m,n]
    }
    BEGIN {
        n=split(cmds,ca," "); best=999; bestcmd=""
        for(i=1;i<=n;i++) { dist=lev(input,ca[i]); if(dist<best){best=dist;bestcmd=ca[i]} }
        if(best<=2) print bestcmd
    }' /dev/null
}

# "sysinf" -> "sysinfo" (1 char off)
r=$(fuzzy_match_test "sysinf"); [ "$r" = "sysinfo" ] && pass "fuzzy: sysinf -> sysinfo" || fail "fuzzy: sysinf should -> sysinfo (got '$r')"

# "utime" -> "uptime" (1 char off)
r=$(fuzzy_match_test "utime"); [ "$r" = "uptime" ] && pass "fuzzy: utime -> uptime" || fail "fuzzy: utime should -> uptime (got '$r')"

# "servics" -> "services" (1 char off)
r=$(fuzzy_match_test "servics"); [ "$r" = "services" ] && pass "fuzzy: servics -> services" || fail "fuzzy: servics should -> services (got '$r')"

# "strt" -> "start" (edit dist 1)
r=$(fuzzy_match_test "strt"); [ "$r" = "start" ] && pass "fuzzy: strt -> start" || fail "fuzzy: strt should -> start (got '$r')"

# "xyz_totally_unknown" should NOT match
r=$(fuzzy_match_test "xyz_totally_unknown"); [ -z "$r" ] && pass "fuzzy: no match for garbage input" || fail "fuzzy: garbage input should not match (got '$r')"

# ---------------------------------------------------------------------------
# os-kernel heartbeat: monitor_services function
# ---------------------------------------------------------------------------
echo
echo "=== os-kernel monitor_services test ==="

_STATE_DIR=$(mktemp -d)
_AURA_LOG_FILE=$(mktemp)
_EVENTS_LOG=$(mktemp)

# Create a fake dead-PID pidfile (PID 1 will be init, but we use a nonsense high PID)
echo "99999999" > "$_STATE_DIR/fake-svc.pid"

# Inline the monitor_services function
monitor_services_test() {
    for pidfile in "$_STATE_DIR"/*.pid; do
        [ -f "$pidfile" ] || continue
        svcname=$(basename "$pidfile" .pid)
        pid=$(cat "$pidfile" 2>/dev/null)
        if [ -n "$pid" ] && ! [ -d "/proc/$pid" ]; then
            echo "[$(date '+%Y-%m-%dT%H:%M:%SZ')] [kernel] service dead: $svcname (pid=$pid)" >> "$_AURA_LOG_FILE"
            rm -f "$pidfile"
        fi
    done
}

monitor_services_test
grep -q "service dead: fake-svc" "$_AURA_LOG_FILE" && pass "heartbeat: dead service detected and logged" || fail "heartbeat: dead service should be logged"
[ ! -f "$_STATE_DIR/fake-svc.pid" ] && pass "heartbeat: stale pid file removed" || fail "heartbeat: stale pid file should be removed"

rm -rf "$_STATE_DIR" "$_AURA_LOG_FILE" "$_EVENTS_LOG"

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo
echo "================================"
echo "Results: $PASS passed, $FAIL failed"
if [ "$FAIL" -gt 0 ]; then
    printf "Failures:%b\n" "$ERRORS"
    exit 1
fi
echo "All tests passed."

