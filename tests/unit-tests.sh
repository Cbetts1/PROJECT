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
# Test fixtures: create runtime-generated stub files that are gitignored
# ---------------------------------------------------------------------------
_STUB_OS_LOG="$OS_ROOT/var/log/os.log"
_STUB_OS_STATE="$OS_ROOT/proc/os.state"
_created_os_log=false
_created_os_state=false

mkdir -p "$OS_ROOT/var/log" "$OS_ROOT/proc"

if [ ! -f "$_STUB_OS_LOG" ]; then
    echo "[stub] os-kernel heartbeat stub" > "$_STUB_OS_LOG"
    _created_os_log=true
fi

if [ ! -f "$_STUB_OS_STATE" ]; then
    printf "boot_time=0\nkernel_pid=0\nos_version=0.1\nrunlevel=3\nlast_heartbeat=0\n" > "$_STUB_OS_STATE"
    _created_os_state=true
fi

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
# Cleanup test fixtures
# ---------------------------------------------------------------------------
[ "$_created_os_log" = true ]   && rm -f "$_STUB_OS_LOG"
[ "$_created_os_state" = true ] && rm -f "$_STUB_OS_STATE"

# ---------------------------------------------------------------------------
# filesystem.py — additional edge cases
# ---------------------------------------------------------------------------
echo
echo "=== filesystem.py — additional edge cases ==="

# 10. stat on a directory returns isdir: True
out=$(OS_ROOT="$OS_ROOT" python3 "$FS_PY" stat var/log 2>/dev/null)
echo "$out" | grep -q "isdir: True" \
    && pass "fs stat: isdir=True for directory" \
    || fail "fs stat: isdir should be True for a directory"

# 11. list on a non-directory path exits non-zero and emits an error
OS_ROOT="$OS_ROOT" python3 "$FS_PY" list proc/os.state 2>&1 | grep -qi "error\|not a dir" \
    && pass "fs list: error on non-directory path" \
    || fail "fs list: should error when path is not a directory"

# 12. read on a non-existent file exits non-zero and emits an error
OS_ROOT="$OS_ROOT" python3 "$FS_PY" read "tmp/does-not-exist-$$.txt" 2>&1 | grep -qi "error\|not found\|no such" \
    && pass "fs read: error on missing file" \
    || fail "fs read: should error when file does not exist"

# 13. CLI with unknown verb emits an error
OS_ROOT="$OS_ROOT" python3 "$FS_PY" unknownverb 2>&1 | grep -qi "unknown\|error" \
    && pass "fs cli: unknown verb produces error message" \
    || fail "fs cli: unknown verb should produce an error message"

# 14. CLI 'read' with no path argument exits non-zero
OS_ROOT="$OS_ROOT" python3 "$FS_PY" read 2>&1 | grep -qi "usage\|error" \
    && pass "fs cli: read with no args shows usage/error" \
    || fail "fs cli: read with no args should show usage/error"

# 15. CLI 'write' with no text argument exits non-zero
OS_ROOT="$OS_ROOT" python3 "$FS_PY" write "tmp/noarg-$$.txt" 2>&1 | grep -qi "usage\|error" \
    && pass "fs cli: write with missing text arg shows usage/error" \
    || fail "fs cli: write with missing text arg should show usage/error"

# 16. fs_write creates parent directories automatically
_nested="tmp/nested/subdir-$$/test.txt"
OS_ROOT="$OS_ROOT" python3 "$FS_PY" write "$_nested" "nested-content"
out=$(OS_ROOT="$OS_ROOT" python3 "$FS_PY" read "$_nested" 2>/dev/null)
[ "$out" = "nested-content" ] \
    && pass "fs write: creates parent directories automatically" \
    || fail "fs write: should create parent directories"
rm -rf "$OS_ROOT/tmp/nested"

# 17. fs_append creates the file when it does not exist
_new_file="tmp/append-new-$$.txt"
OS_ROOT="$OS_ROOT" python3 "$FS_PY" append "$_new_file" "first-line"
out=$(OS_ROOT="$OS_ROOT" python3 "$FS_PY" read "$_new_file" 2>/dev/null)
echo "$out" | grep -q "first-line" \
    && pass "fs append: creates file when it does not exist" \
    || fail "fs append: should create file on first append"
rm -f "$OS_ROOT/$_new_file"

# ---------------------------------------------------------------------------
# embed.mod — embed_text and embed_distance
# ---------------------------------------------------------------------------
echo
echo "=== embed.mod — embed_text / embed_distance tests ==="

# Load the embed module functions inline (POSIX sh compatible)
_embed_sh() {
    OS_ROOT="$OS_ROOT" sh -c ". \"$OS_ROOT/lib/aura-semantic/embed.mod\"; $1" 2>/dev/null
}

# 18. embed_text produces a comma-separated 5-component vector
emb=$(_embed_sh 'embed_text "hello world"')
count=$(echo "$emb" | tr ',' '\n' | grep -c '[0-9]')
[ "$count" -eq 5 ] \
    && pass "embed_text: returns 5-component vector" \
    || fail "embed_text: should return 5 components (got '$emb')"

# 19. embed_text is deterministic — same input gives same output
emb1=$(_embed_sh 'embed_text "deterministic test"')
emb2=$(_embed_sh 'embed_text "deterministic test"')
[ "$emb1" = "$emb2" ] \
    && pass "embed_text: deterministic — same input produces same vector" \
    || fail "embed_text: should be deterministic"

# 20. embed_distance of identical vectors is 0
dist=$(_embed_sh 'emb=$(embed_text "same text"); embed_distance "$emb" "$emb"')
[ "$dist" = "0" ] \
    && pass "embed_distance: identical vectors have distance 0" \
    || fail "embed_distance: identical vectors should have distance 0 (got '$dist')"

# 21. embed_distance of different texts is positive
dist=$(_embed_sh 'a=$(embed_text "apple"); b=$(embed_text "zzzzzzzquux999"); embed_distance "$a" "$b"')
[ "$dist" -gt 0 ] 2>/dev/null \
    && pass "embed_distance: different texts have distance > 0" \
    || fail "embed_distance: different texts should have distance > 0 (got '$dist')"

# ---------------------------------------------------------------------------
# aura-memory engine.mod — mem_delete, mem_tag, mem_list, mem_search
# ---------------------------------------------------------------------------
echo
echo "=== aura-memory engine: mem_delete / mem_tag / mem_list / mem_search ==="

_run_mem() {
    OS_ROOT="$OS_ROOT" sh -c ". \"$OS_ROOT/lib/aura-memory/engine.mod\"; $1" 2>/dev/null
}

# 22. mem_list returns content from index
_run_mem 'mem_set "listtest.key" "listtest_value"'
out=$(_run_mem 'mem_list')
echo "$out" | grep -q "listtest.key" \
    && pass "mem_list: returns entries from memory index" \
    || fail "mem_list: should return entries from memory index"

# 23. mem_search finds matching key
out=$(_run_mem 'mem_search "listtest"')
echo "$out" | grep -q "listtest.key" \
    && pass "mem_search: finds matching key by pattern" \
    || fail "mem_search: should find key matching pattern"

# 24. mem_delete removes the key
_run_mem 'mem_set "deltest.key" "del_value"'
_run_mem 'mem_delete "deltest.key"'
out=$(_run_mem 'mem_get "deltest.key"')
echo "$out" | grep -q "no memory" \
    && pass "mem_delete: deleted key returns '(no memory)'" \
    || fail "mem_delete: deleted key should return '(no memory)'"

# 25. mem_tag updates the tag field in the index
_run_mem 'mem_set "tagtest.key" "tag_value"'
_run_mem 'mem_tag "tagtest.key" "important urgent"'
out=$(_run_mem 'mem_list')
echo "$out" | grep "tagtest.key" | grep -q "important" \
    && pass "mem_tag: tag appears in memory index" \
    || fail "mem_tag: tag should appear in memory index"

# ---------------------------------------------------------------------------
# aura-semantic engine.mod — semantic_delete, semantic_list, semantic_search
# ---------------------------------------------------------------------------
echo
echo "=== aura-semantic engine: semantic_delete / semantic_list / semantic_search ==="

_run_sem() {
    OS_ROOT="$OS_ROOT" sh -c "
. \"$OS_ROOT/lib/aura-semantic/embed.mod\"
. \"$OS_ROOT/lib/aura-semantic/engine.mod\"
$1" 2>/dev/null
}

# 26. semantic_list returns stored entries
_run_sem 'semantic_store "semlist.key" "semantic list test content"'
out=$(_run_sem 'semantic_list')
echo "$out" | grep -q "semlist.key" \
    && pass "semantic_list: returns stored semantic entries" \
    || fail "semantic_list: should return stored entries"

# 27. semantic_search returns results sorted by distance
_run_sem 'semantic_store "semsearch.a" "quick brown fox"'
_run_sem 'semantic_store "semsearch.b" "lazy sleeping dog"'
out=$(_run_sem 'semantic_search "quick brown fox"')
[ -n "$out" ] \
    && pass "semantic_search: returns results for a query" \
    || fail "semantic_search: should return results"

# 28. semantic_delete removes the key
_run_sem 'semantic_store "semdel.key" "delete this entry"'
_run_sem 'semantic_delete "semdel.key"'
out=$(_run_sem 'semantic_get "semdel.key"')
echo "$out" | grep -q "no semantic memory" \
    && pass "semantic_delete: deleted key returns '(no semantic memory)'" \
    || fail "semantic_delete: deleted key should return '(no semantic memory)'"

# ---------------------------------------------------------------------------
# aura-hybrid engine.mod — ctx_add / ctx_get, hybrid_recall, hybrid_best
# ---------------------------------------------------------------------------
echo
echo "=== aura-hybrid engine: ctx_add / ctx_get / hybrid_recall / hybrid_best ==="

_run_hyb() {
    OS_ROOT="$OS_ROOT" sh -c "
. \"$OS_ROOT/lib/aura-semantic/embed.mod\"
. \"$OS_ROOT/lib/aura-semantic/engine.mod\"
. \"$OS_ROOT/lib/aura-memory/engine.mod\"
. \"$OS_ROOT/lib/aura-hybrid/engine.mod\"
$1" 2>/dev/null
}

# 29. ctx_add + ctx_get roundtrip
_uniq="ctx-unit-test-$$"
_run_hyb "ctx_add \"$_uniq\""
out=$(_run_hyb 'ctx_get')
echo "$out" | grep -q "$_uniq" \
    && pass "hybrid: ctx_add/ctx_get roundtrip" \
    || fail "hybrid: ctx_add/ctx_get should work"

# 30. context window is capped at 50 lines
for i in $(seq 1 55); do
    _run_hyb "ctx_add \"line $i of 55\""
done
out=$(_run_hyb 'ctx_get' | wc -l)
[ "$out" -le 50 ] \
    && pass "hybrid: context window capped at 50 lines" \
    || fail "hybrid: context window should be capped at 50 lines (got $out)"

# 31. hybrid_recall returns structured output sections
_run_hyb 'mem_set "hybrecall.key" "recall_test_value"'
out=$(_run_hyb 'hybrid_recall "hybrecall"')
echo "$out" | grep -q "hybrid" \
    && pass "hybrid_recall: returns labeled output" \
    || fail "hybrid_recall: should return labeled output"

# 32. hybrid_best returns a non-empty result when a symbolic match exists
_run_hyb 'mem_set "hybtest.unique" "unique_hybrid_value"'
out=$(_run_hyb 'hybrid_best "hybtest"')
[ -n "$out" ] \
    && pass "hybrid_best: returns a result for a stored key" \
    || fail "hybrid_best: should return a result for a stored key"

# ---------------------------------------------------------------------------
# aura-policy engine.mod — policy_match positive and negative
# ---------------------------------------------------------------------------
echo
echo "=== aura-policy engine: policy_match ==="

_run_policy() {
    OS_ROOT="$OS_ROOT" sh -c "
. \"$OS_ROOT/lib/aura-policy/engine.mod\"
$1" 2>/dev/null
}

# 33. policy_match returns action for matching hook + 'any' pattern
out=$(_run_policy 'policy_match "heartbeat" "anything"')
echo "$out" | grep -q "autosys_check" \
    && pass "policy_match: 'any' pattern matches any payload" \
    || fail "policy_match: 'any' pattern should match any payload"

# 34. policy_match returns action for matching hook + specific pattern
out=$(_run_policy 'policy_match "message" "alert: something bad"')
echo "$out" | grep -q "autosys_alert" \
    && pass "policy_match: specific pattern matches payload containing keyword" \
    || fail "policy_match: pattern 'alert' should match payload with 'alert'"

# 35. policy_match returns nothing for non-matching hook
out=$(_run_policy 'policy_match "nonexistent_hook" "anything"')
[ -z "$out" ] \
    && pass "policy_match: no match for unknown hook" \
    || fail "policy_match: unknown hook should produce no match (got '$out')"

# ---------------------------------------------------------------------------
# llm_fallback — additional response patterns
# ---------------------------------------------------------------------------
echo
echo "=== llm_fallback — additional response patterns ==="

_llm() {
    OS_ROOT="$OS_ROOT" sh -c ". \"$OS_ROOT/lib/aura-llm/llm.mod\"; llm_fallback \"$1\"" 2>/dev/null
}

# 36. bridge/connect query
out=$(_llm "connect to device")
echo "$out" | grep -qi "bridge\|device\|connect" \
    && pass "llm_fallback: bridge/connect query returns relevant response" \
    || fail "llm_fallback: bridge/connect should return bridge response"

# 37. android/adb query
out=$(_llm "android adb device")
echo "$out" | grep -qi "android\|adb\|usb\|debug" \
    && pass "llm_fallback: android query returns relevant response" \
    || fail "llm_fallback: android query should return android response"

# 38. memory/remember query
out=$(_llm "recall from memory")
echo "$out" | grep -qi "memory\|mem\|semantic\|context\|store" \
    && pass "llm_fallback: memory/remember query returns memory response" \
    || fail "llm_fallback: memory query should return memory response"

# 39. help query
out=$(_llm "help me what can you do")
echo "$out" | grep -qi "help\|command\|manage\|bridge\|memory" \
    && pass "llm_fallback: help query returns help response" \
    || fail "llm_fallback: help query should return help response"

# 40. version/who query
out=$(_llm "who are you")
echo "$out" | grep -qi "aios\|version\|chris\|operating" \
    && pass "llm_fallback: version/who query returns identity response" \
    || fail "llm_fallback: version/who query should return identity response"

# 41. reboot/restart query
out=$(_llm "reboot the system")
echo "$out" | grep -qi "restart\|reboot\|kernel\|kernelctl" \
    && pass "llm_fallback: reboot query returns restart instruction" \
    || fail "llm_fallback: reboot query should return restart instruction"

# 42. mirror/ios query
out=$(_llm "mirror ios iphone")
echo "$out" | grep -qi "ios\|iphone\|imobiledevice\|bridge\|usb\|mount" \
    && pass "llm_fallback: ios/mirror query returns relevant response" \
    || fail "llm_fallback: ios/mirror query should return ios response"

# 43. unknown input falls back to a generic response
out=$(_llm "xyzzy frobnicator quux")
[ -n "$out" ] \
    && pass "llm_fallback: unknown input returns a non-empty fallback response" \
    || fail "llm_fallback: unknown input should return a non-empty response"

# ---------------------------------------------------------------------------
# lib/aura-core.sh — osroot_resolve, register_command, run_command
# ---------------------------------------------------------------------------
echo
echo "=== lib/aura-core.sh — osroot_resolve / register_command / run_command ==="

export AIOS_HOME="$REPO_ROOT"
export OS_ROOT="$OS_ROOT"

_run_core() {
    AIOS_HOME="$REPO_ROOT" OS_ROOT="$OS_ROOT" bash -c "
. \"$REPO_ROOT/lib/aura-core.sh\"
$1" 2>/dev/null
}

# 44. osroot_resolve: relative path stays inside OS_ROOT
out=$(_run_core 'osroot_resolve "var/log"')
case "$out" in
    "$OS_ROOT"/*) pass "osroot_resolve: relative path resolves inside OS_ROOT" ;;
    *) fail "osroot_resolve: relative path should resolve inside OS_ROOT (got '$out')" ;;
esac

# 45. osroot_resolve: absolute path is rebased under OS_ROOT (chroot-style)
out=$(_run_core 'osroot_resolve "/var/log"')
case "$out" in
    "$OS_ROOT"/*) pass "osroot_resolve: absolute path rebased under OS_ROOT" ;;
    *) fail "osroot_resolve: absolute path should be rebased under OS_ROOT (got '$out')" ;;
esac

# 46. osroot_resolve: traversal attempt is blocked (returns non-zero exit)
# Note: aura-core.sh uses set -o errexit, so we use 'if' to capture exit code
out=$(AIOS_HOME="$REPO_ROOT" OS_ROOT="$OS_ROOT" bash -c "
. \"$REPO_ROOT/lib/aura-core.sh\"
if osroot_resolve \"../../etc/passwd\" >/dev/null 2>&1; then
    echo allowed
else
    echo blocked
fi
" 2>/dev/null)
[ "$out" = "blocked" ] \
    && pass "osroot_resolve: traversal attempt is blocked (non-zero exit)" \
    || fail "osroot_resolve: traversal attempt should be blocked (got '$out')"

# 47. register_command + run_command: registered function is invoked
out=$(_run_core '
register_command "test.hello" "_say_hello"
_say_hello() { echo "hello_from_test_cmd"; }
run_command "test.hello"
')
echo "$out" | grep -q "hello_from_test_cmd" \
    && pass "register_command/run_command: registered function is dispatched" \
    || fail "register_command/run_command: registered function should be dispatched"

# 48. run_command: returns 127 for an unknown command
# Note: aura-core.sh uses set -o errexit; use 'if' to capture exit code
out=$(AIOS_HOME="$REPO_ROOT" OS_ROOT="$OS_ROOT" bash -c "
. \"$REPO_ROOT/lib/aura-core.sh\"
if run_command 'no_such_command_unittest'; then
    echo exit:0
else
    echo exit:\$?
fi
" 2>/dev/null)
echo "$out" | grep -q "exit:127" \
    && pass "run_command: returns 127 for unknown command" \
    || fail "run_command: should return 127 for unknown command (got '$out')"

# ---------------------------------------------------------------------------
# lib/aura-core.sh — log() output format
# ---------------------------------------------------------------------------
echo
echo "=== lib/aura-core.sh — log() output format ==="

# 49. log() writes message to log file
_tmplog=$(mktemp)
AIOS_HOME="$REPO_ROOT" OS_ROOT="$OS_ROOT" bash -c "
. \"$REPO_ROOT/lib/aura-core.sh\"
AIOS_LOG_FILE='$_tmplog'
log INFO 'test-log-message-$$'
" 2>/dev/null
grep -q "test-log-message-$$" "$_tmplog" \
    && pass "log: message written to log file" \
    || fail "log: message should be written to log file"
# 50. log() entry contains ISO-8601 timestamp
grep -qE "\[20[0-9]{2}-[0-9]{2}-[0-9]{2}T" "$_tmplog" \
    && pass "log: entry contains ISO-8601 timestamp" \
    || fail "log: entry should contain ISO-8601 timestamp"
# 51. log() entry contains log level
grep -q "\[INFO\]" "$_tmplog" \
    && pass "log: entry contains log level" \
    || fail "log: entry should contain log level"
rm -f "$_tmplog"

# ---------------------------------------------------------------------------
# lib/aura-typo.sh — aura_typo_suggest() via fuzzy.py
# ---------------------------------------------------------------------------
echo
echo "=== lib/aura-typo.sh — aura_typo_suggest ==="

_run_typo() {
    AIOS_HOME="$REPO_ROOT" OS_ROOT="$OS_ROOT" bash -c "
. \"$REPO_ROOT/lib/aura-typo.sh\"
aura_typo_suggest \"$1\"
" 2>/dev/null
}

# 52. suggest a known command for a close typo
out=$(_run_typo "hekp")
echo "$out" | grep -q "help" \
    && pass "aura_typo_suggest: 'hekp' suggests 'help'" \
    || fail "aura_typo_suggest: 'hekp' should suggest 'help' (got '$out')"

# 53. no suggestion for total garbage
out=$(_run_typo "zzzzzzqqqyyy_totally_unknown")
[ -z "$out" ] \
    && pass "aura_typo_suggest: no suggestion for garbage input" \
    || fail "aura_typo_suggest: garbage input should produce no suggestion (got '$out')"

# ---------------------------------------------------------------------------
# lib/aura-proc.sh — aura_proc_kill() PID validation
# ---------------------------------------------------------------------------
echo
echo "=== lib/aura-proc.sh — aura_proc_kill PID validation ==="

_run_proc() {
    AIOS_HOME="$REPO_ROOT" OS_ROOT="$OS_ROOT" bash -c "
. \"$REPO_ROOT/lib/aura-proc.sh\"
$1
" 2>&1
}

# 54. non-numeric PID is rejected with error message
out=$(_run_proc 'aura_proc_kill "notapid"')
echo "$out" | grep -qi "invalid\|pid" \
    && pass "aura_proc_kill: non-numeric PID rejected with error" \
    || fail "aura_proc_kill: non-numeric PID should produce an error (got '$out')"

# 55. empty PID is rejected with usage message
out=$(_run_proc 'aura_proc_kill ""')
echo "$out" | grep -qi "usage\|pid" \
    && pass "aura_proc_kill: empty PID shows usage message" \
    || fail "aura_proc_kill: empty PID should show usage message (got '$out')"

# ---------------------------------------------------------------------------
# lib/aura-fs.sh — aura_fs_rm OS_ROOT protection
# ---------------------------------------------------------------------------
echo
echo "=== lib/aura-fs.sh — aura_fs_rm protection ==="

_run_fs() {
    AIOS_HOME="$REPO_ROOT" OS_ROOT="$OS_ROOT" bash -c "
. \"$REPO_ROOT/lib/aura-fs.sh\"
$1
" 2>&1
}

# 56. aura_fs_rm refuses to remove OS_ROOT itself
out=$(_run_fs 'aura_fs_rm "."')
echo "$out" | grep -qi "refusing\|root\|error" \
    && pass "aura_fs_rm: refuses to remove OS_ROOT root" \
    || fail "aura_fs_rm: should refuse to remove OS_ROOT (got '$out')"

# 57. aura_fs_write with no args shows usage
out=$(_run_fs 'aura_fs_write')
echo "$out" | grep -qi "usage" \
    && pass "aura_fs_write: no args shows usage message" \
    || fail "aura_fs_write: no args should show usage message (got '$out')"

# 58. aura_fs_write/cat roundtrip within OS_ROOT (use fixed name to avoid $$ PID mismatch)
_FS_TEST_FILE="tmp/fs-sh-unit-test.txt"
_run_fs "aura_fs_write \"$_FS_TEST_FILE\" \"aura_fs_content\"" >/dev/null 2>&1
out=$(_run_fs "aura_fs_cat \"$_FS_TEST_FILE\"")
echo "$out" | grep -q "aura_fs_content" \
    && pass "aura_fs_write/cat: write then cat roundtrip" \
    || fail "aura_fs_write/cat: should write and read back content"
AIOS_HOME="$REPO_ROOT" OS_ROOT="$OS_ROOT" bash -c ". \"$REPO_ROOT/lib/aura-fs.sh\"; aura_fs_rm \"$_FS_TEST_FILE\"" >/dev/null 2>&1

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

