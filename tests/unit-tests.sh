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
# Test environment setup — create runtime files that are gitignored but
# expected to exist by the filesystem tests.
# ---------------------------------------------------------------------------
mkdir -p "$OS_ROOT/var/log" "$OS_ROOT/proc"
[ -f "$OS_ROOT/var/log/os.log" ] || touch "$OS_ROOT/var/log/os.log"
[ -f "$OS_ROOT/proc/os.state" ]  || printf "boot_time=0\nkernel_pid=0\nos_version=0.1\nrunlevel=3\nlast_heartbeat=0\n" > "$OS_ROOT/proc/os.state"

# ---------------------------------------------------------------------------
# filesystem.py tests
# ---------------------------------------------------------------------------
echo
echo "=== filesystem.py tests ==="

# Create runtime fixture files required by the tests below; these are
# excluded from version control (.gitignore) but must exist for the
# filesystem interface tests to exercise real paths.
mkdir -p "$OS_ROOT/var/log" "$OS_ROOT/proc"
_created_os_log=0
_created_os_state=0
if [ ! -f "$OS_ROOT/var/log/os.log" ]; then
    touch "$OS_ROOT/var/log/os.log"
    _created_os_log=1
fi
if [ ! -f "$OS_ROOT/proc/os.state" ]; then
    cat > "$OS_ROOT/proc/os.state" << 'EOF'
boot_time=0
kernel_pid=0
os_version=0.1
runlevel=3
last_heartbeat=0
EOF
    _created_os_state=1
fi

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

# Clean up fixture files created by this test run
[ "$_created_os_log"   = "1" ] && rm -f "$OS_ROOT/var/log/os.log"
[ "$_created_os_state" = "1" ] && rm -f "$OS_ROOT/proc/os.state"

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
# os-install upgrade subcommands
# ---------------------------------------------------------------------------
echo
echo "=== os-install upgrade tests ==="

_TEST_OS_ROOT=$(mktemp -d)
mkdir -p "$_TEST_OS_ROOT/usr/pkg" "$_TEST_OS_ROOT/var/pkg"

# Create a fake installed package with an upgrade script
mkdir -p "$_TEST_OS_ROOT/usr/pkg/testpkg"
printf '#!/bin/sh\necho "upgraded testpkg"\n' > "$_TEST_OS_ROOT/usr/pkg/testpkg/upgrade.sh"
chmod +x "$_TEST_OS_ROOT/usr/pkg/testpkg/upgrade.sh"
echo "testpkg" > "$_TEST_OS_ROOT/var/pkg/testpkg"

# upgrade-all: should call upgrade.sh for each installed package
out=$(OS_ROOT="$_TEST_OS_ROOT" sh "$OS_ROOT/bin/os-install" upgrade-all 2>/dev/null)
echo "$out" | grep -q "upgraded testpkg" && pass "os-install upgrade-all: calls upgrade.sh" || fail "os-install upgrade-all: should call upgrade.sh"
echo "$out" | grep -q "1 package" && pass "os-install upgrade-all: reports count" || fail "os-install upgrade-all: should report upgraded count"

# upgrade <pkg>: should call upgrade.sh for the named package
out=$(OS_ROOT="$_TEST_OS_ROOT" sh "$OS_ROOT/bin/os-install" upgrade testpkg 2>/dev/null)
echo "$out" | grep -q "upgraded testpkg" && pass "os-install upgrade <pkg>: calls upgrade.sh" || fail "os-install upgrade <pkg>: should call upgrade.sh"

# upgrade non-installed package: should error
out=$(OS_ROOT="$_TEST_OS_ROOT" sh "$OS_ROOT/bin/os-install" upgrade notinstalled 2>/dev/null; true)
echo "$out" | grep -qi "not installed" && pass "os-install upgrade: rejects non-installed pkg" || fail "os-install upgrade: should reject non-installed pkg"

# Package with only install.sh (no upgrade.sh): falls back to reinstall
mkdir -p "$_TEST_OS_ROOT/usr/pkg/fallbackpkg"
printf '#!/bin/sh\necho "installed fallbackpkg"\n' > "$_TEST_OS_ROOT/usr/pkg/fallbackpkg/install.sh"
chmod +x "$_TEST_OS_ROOT/usr/pkg/fallbackpkg/install.sh"
echo "fallbackpkg" > "$_TEST_OS_ROOT/var/pkg/fallbackpkg"
out=$(OS_ROOT="$_TEST_OS_ROOT" sh "$OS_ROOT/bin/os-install" upgrade fallbackpkg 2>/dev/null)
echo "$out" | grep -q "installed fallbackpkg" && pass "os-install upgrade: falls back to install.sh" || fail "os-install upgrade: should fall back to install.sh when no upgrade.sh"

rm -rf "$_TEST_OS_ROOT"

# ---------------------------------------------------------------------------
# os-shell KNOWN_CMDS includes 'upgrade'
# ---------------------------------------------------------------------------
echo
echo "=== os-shell upgrade command registration test ==="

grep -q "upgrade" "$OS_ROOT/bin/os-shell" \
    && pass "os-shell: 'upgrade' present in script" \
    || fail "os-shell: 'upgrade' should be in script"

# Fuzzy match: 'upgradde' -> 'upgrade' (1 char off)
_KNOWN_CMDS_WITH_UPGRADE="$_KNOWN_CMDS upgrade"
fuzzy_match_upgrade_test() {
    input="$1"
    awk -v input="$input" -v cmds="$_KNOWN_CMDS_WITH_UPGRADE" '
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
r=$(fuzzy_match_upgrade_test "upgradde"); [ "$r" = "upgrade" ] && pass "fuzzy: upgradde -> upgrade" || fail "fuzzy: upgradde should -> upgrade (got '$r')"

# ---------------------------------------------------------------------------
# aura-agent: upgrade and version commands
# ---------------------------------------------------------------------------
echo
echo "=== aura-agent upgrade/version tests ==="

_AURA_AGENT="$REPO_ROOT/aura/aura-agent.py"
_AURA_CFG="$REPO_ROOT/aura/aura-config.json"
_AURA_EXPECTED_VERSION="v1.1"

if ! command -v python3 >/dev/null 2>&1; then
    echo "[SKIP] python3 not available - skipping aura-agent tests"
else
    # version command returns "AURA v1.1"
    out=$(printf 'version\nquit\n' | python3 "$_AURA_AGENT" --config "$_AURA_CFG" 2>/dev/null | grep -v "^AURA>" | head -5)
    echo "$out" | grep -q "$_AURA_EXPECTED_VERSION" && pass "aura-agent: version reports $_AURA_EXPECTED_VERSION" || fail "aura-agent: version should report $_AURA_EXPECTED_VERSION"

    # --version flag prints version and exits
    out=$(python3 "$_AURA_AGENT" --config "$_AURA_CFG" --version 2>/dev/null)
    echo "$out" | grep -q "$_AURA_EXPECTED_VERSION" && pass "aura-agent: --version flag works" || fail "aura-agent: --version flag should print $_AURA_EXPECTED_VERSION"

    # upgrade command exists and returns something (secure-run may not be present; just check no crash)
    out=$(printf 'upgrade\nquit\n' | python3 "$_AURA_AGENT" --config "$_AURA_CFG" 2>/dev/null | grep -v "^AURA>" | head -5)
    [ -n "$out" ] && pass "aura-agent: upgrade command responds" || fail "aura-agent: upgrade command should respond"

    # upgrade with bad flag returns error
    out=$(printf 'upgrade --badflg\nquit\n' | python3 "$_AURA_AGENT" --config "$_AURA_CFG" 2>/dev/null | grep -v "^AURA>" | head -5)
    echo "$out" | grep -qi "error" && pass "aura-agent: upgrade rejects bad flag" || fail "aura-agent: upgrade should reject bad flag"
fi

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

